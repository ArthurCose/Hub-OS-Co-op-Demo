---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")
---@type FallingRockLib
local FallingRockLib = require("BattleNetwork.FallingRock")
---@type KonstAiLib
local AiLib = require("dev.konstinople.library.ai")
local IteratorLib = AiLib.IteratorLib

local HAMMER_SFX = bn_assets.load_audio("gaia_hammer.ogg")
local IMPACT_SFX = bn_assets.load_audio("guard.ogg")
local IMPACT_TEXTURE = bn_assets.load_texture("shield_impact.png")
local IMPACT_ANIM_PATH = bn_assets.fetch_animation_path("shield_impact.animation")
local TEXTURE = Resources.load_texture("battle.png")

local function spawn_particle(texture, animation_path, state, field, tile)
  local artifact = Artifact.new()
  artifact:set_texture(texture)
  artifact:sprite():set_layer(-5)

  local animation = artifact:animation()
  animation:load(animation_path)
  animation:set_state(state)
  animation:on_complete(function()
    artifact:erase()
  end)

  field:spawn(artifact, tile)

  return artifact
end

---@param user Entity
local function spawn_impact_particle(user)
  local artifact = spawn_particle(IMPACT_TEXTURE, IMPACT_ANIM_PATH, "DEFAULT", user:field(), user:current_tile())
  Resources.play_audio(IMPACT_SFX)

  artifact:set_offset(
    math.random(-Tile:width() * .5, Tile:width() * .5),
    -math.random(user:height() * .25, user:height() * .75)
  )

  return artifact
end

---@class GaiaProps
---@field damage number
---@field cracks? number
---@field root? boolean

---@param character Entity
---@param gaia_props GaiaProps
return function(character, gaia_props)
  -- basic look

  character:set_height(39.0)
  character:set_texture(TEXTURE)

  local animation = character:animation()
  animation:load(_folder_path .. "battle.animation")
  animation:set_state("DEFAULT")

  -- defense rules
  character:add_aux_prop(StandardEnemyAux.new())
  local invincible = true

  local iron_body_rule = DefenseRule.new(DefensePriority.Action, DefenseOrder.Always)
  iron_body_rule.can_block_func = function(judge, _, _, hit_props)
    if not invincible then
      return
    end

    if hit_props.flags & Hit.PierceGuard ~= 0 then
      -- pierced
      return
    end

    if hit_props.flags & Hit.Impact == 0 then
      -- non impact
      return
    end

    judge:block_damage()


    if judge:impact_blocked() then
      return
    end

    judge:block_impact()

    spawn_impact_particle(character)
  end

  iron_body_rule.filter_statuses_func = function(hit_props)
    hit_props.flags = hit_props.flags & ~Hit.Flash
    return hit_props
  end

  character:add_defense_rule(iron_body_rule)

  -- ai

  local ai = AiLib.new_ai(character)
  local attack_spell

  local plan = ai:create_plan()
  plan:set_action_iter_factory(function()
    return IteratorLib.chain(
      IteratorLib.take(1, AiLib.create_idle_action_factory(character, 60 * 2, 60 * 5)),
      -- make vulnerable
      IteratorLib.take(1, function()
        local action = Action.new(character)
        action:set_lockout(ActionLockout.new_sequence())
        action.on_execute_func = function()
          invincible = false
        end

        local step = action:create_step()
        local i = 0

        step.on_update_func = function()
          if i < 30 then
            if math.floor(i / 2) % 2 == 0 then
              animation:set_state("COLOR")
            else
              animation:set_state("DEFAULT")
            end
          end

          i = i + 1

          if i >= 60 then
            step:complete_step()
          end
        end

        return action
      end),
      -- attack
      IteratorLib.take(1, function()
        local action = Action.new(character, "ATTACK")
        action:add_anim_action(5, function()
          local field = character:field()
          local tile = character:get_tile(character:facing(), 1)
          local hit_tile = tile and tile:is_walkable()

          if hit_tile then
            Resources.play_audio(HAMMER_SFX)

            -- shake the screen for 40f
            local SHAKE_DURATION = 40
            field:shake(5, SHAKE_DURATION)

            -- crack tiles
            if gaia_props.cracks then
              local tiles = field:find_tiles(function(tile) return tile:team() ~= character:team() end)

              for _ = 1, gaia_props.cracks do
                local crack_tile = tiles[math.random(#tiles)]

                if crack_tile:is_walkable() then
                  crack_tile:set_state(TileState.Cracked)
                end
              end
            end

            -- spawn effects
            local effects_spell = Spell.new(character:team())
            effects_spell:set_hit_props(
              HitProps.new(
                0,
                Hit.PierceGround,
                Element.None
              )
            )

            local effects_time = 0

            effects_spell.on_update_func = function()
              effects_time = effects_time + 1

              -- apply root
              if gaia_props.root then
                -- todo: move to hit prop when we can change status durations so this only applies for one frame
                field:find_characters(function(other)
                  if other:team() ~= character:team() then
                    other:apply_status(Hit.Root, 1)
                  end
                  return false
                end)
              end

              -- pierce ground
              field:find_tiles(function(tile)
                tile:attack_entities(effects_spell)
                return false
              end)

              -- spawn rocks
              if effects_time == 30 then
                local enemy_tiles = field:find_tiles(function(tile)
                  return tile:team() ~= character:team() and not tile:is_edge()
                end)

                local remaining_rocks = 3

                -- try to hit enemies with the rocks
                for i = #enemy_tiles, 1, -1 do
                  local has_enemy = false

                  local enemy_tile = enemy_tiles[i]
                  enemy_tile:find_characters(function(other)
                    if other:team() ~= character:team() then
                      has_enemy = true
                    end
                    return false
                  end)

                  if has_enemy then
                    table.remove(enemy_tiles, i)

                    local rock = FallingRockLib.create_falling_rock(character:team(), gaia_props.damage)
                    field:spawn(rock, enemy_tile)

                    remaining_rocks = remaining_rocks - 1

                    if remaining_rocks == 0 then
                      break
                    end
                  end
                end

                -- drop rocks on random tiles
                for _ = 1, math.min(#enemy_tiles, remaining_rocks) do
                  local rock_tile = table.remove(enemy_tiles, math.random(#enemy_tiles))

                  local rock = FallingRockLib.create_falling_rock(character:team(), gaia_props.damage)
                  field:spawn(rock, rock_tile)
                end
              end

              if effects_time > SHAKE_DURATION then
                effects_spell:erase()
              end
            end

            field:spawn(effects_spell, tile)
          end

          -- spawn attack
          attack_spell = Spell.new(character:team())
          attack_spell:set_hit_props(
            HitProps.new(
              gaia_props.damage,
              Hit.Impact | Hit.Flinch | Hit.Flash | Hit.PierceGuard | Hit.PierceGround,
              Element.None,
              character:context()
            )
          )

          attack_spell.on_update_func = function()
            if character:deleted() then
              attack_spell:erase()
              return
            end

            character:get_tile(character:facing(), 1):attack_entities(attack_spell)
          end

          field:spawn(attack_spell, tile)
        end)
        return action
      end),
      -- wait 30f
      IteratorLib.take(1, AiLib.create_idle_action_factory(character, 40, 40)),
      -- spawn rocks
      -- wait 60f
      IteratorLib.take(1, AiLib.create_idle_action_factory(character, 40, 40)),
      -- return swing and make invulnerable again
      IteratorLib.take(1, function()
        local action = Action.new(character, "RELEASE")
        action.on_execute_func = function()
          attack_spell:erase()
        end
        action.on_action_end_func = function()
          invincible = true
          animation:set_state("IDLE")
        end
        return action
      end)
    )
  end)
end
