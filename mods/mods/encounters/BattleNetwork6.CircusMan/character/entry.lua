---@type KonstAiLib
local Ai = require("dev.konstinople.library.ai")
---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local TEXTURE = Resources.load_texture("battle.png")
local ANIMATION_PATH = "battle.animation"
local SHADOW_TEXTURE = Resources.load_texture("shadow.png")
local CLAP_SFX = bn_assets.load_audio("circusman_clap.ogg")
local CAGE_SFX = bn_assets.load_audio("circusman_cage.ogg")
-- temp sound
local RING_SFX = bn_assets.load_audio("firehit1.ogg")
-- todo: clap hit particle
-- local HIT_EFFECT_TEXTURE = bn_assets.load_texture("bn6_hit_effects.png")
-- local HIT_EFFECT_ANIMATION_PATH = bn_assets.fetch_animation_path("bn6_hit_effects.animation")
-- cage particle
local IMPACT_TEXTURE = bn_assets.load_texture("buster_charged_impact.png")
local IMPACT_ANIMATION_PATH = bn_assets.fetch_animation_path("buster_charged_impact.animation")
local CAGE_HIT_SFX = bn_assets.load_audio("hit.ogg")

---@param texture string
---@param animation_path string
---@param state string
local function create_particle(texture, animation_path, state)
    local artifact = Artifact.new()
    artifact:set_texture(texture)
    local animation = artifact:animation()
    animation:load(animation_path)
    animation:set_state(state)
    animation:on_complete(function()
        artifact:erase()
    end)

    return artifact
end

---@class CircusMan: Entity
---@field set_state_all fun(state: string, playback?: Playback)
---@field set_hands_visible fun(visible: boolean)
---@field max_attempts number
---@field damage number
---@field cage_hits number
---@field cage_hit_flags number

---@param entity Entity
local function default_random_tile(entity)
    local target_x = 1

    if entity:facing() == Direction.Left then
        target_x = 6
    end

    local tiles = entity:field():find_tiles(function(tile)
        return tile:x() == target_x and entity:can_move_to(tile) and tile ~= entity:current_tile()
    end)

    if #tiles == 0 then
        return nil
    end

    return tiles[math.random(#tiles)]
end

---@param entity CircusMan
local function create_move_factory(entity)
    local animation = entity:animation()

    return function()
        local action = Action.new(entity)
        action:set_lockout(ActionLockout.new_sequence())

        local start_step = action:create_step()

        local jump_step = action:create_step()
        jump_step.on_update_func = function()
            if not entity:is_moving() then
                jump_step:complete_step()
            end
        end

        local end_step = action:create_step()
        end_step.on_update_func = function()
            end_step.on_update_func = nil

            -- we just want the shadow back on the main sprite
            -- seems like this state is unused
            entity.set_state_all("JUMP_END")
            end_step:complete_step()
        end

        action.on_execute_func = function()
            local target_tile = default_random_tile(entity)

            entity.set_state_all("JUMP_START")

            animation:on_complete(function()
                entity.set_state_all("JUMP")
                entity:show_shadow(true)

                -- if our target was taken during our animation, pick a new target
                if not entity:can_move_to(target_tile) then
                    target_tile = default_random_tile(entity)
                end

                if target_tile then
                    entity:jump(target_tile, Tile:height() * 3.5, 30)
                else
                    jump_step:complete_step()
                end

                start_step:complete_step()
            end)
        end

        action.on_action_end_func = function()
            entity:show_shadow(false)
        end

        return action
    end
end

---@param entity CircusMan
---@param callback fun(success: boolean)
local function spawn_clap(entity, callback)
    local team = entity:team()
    local field = entity:field()

    local main_spell = Spell.new(team)
    main_spell:set_hit_props(
        HitProps.new(
            entity.damage,
            Hit.Impact | Hit.Flinch | Hit.Flash,
            Element.None,
            entity:context()
        )
    )

    local spell_top = Spell.new(team)
    spell_top:set_texture(TEXTURE)
    spell_top:sprite():set_layer(5)
    spell_top:set_facing(entity:facing())

    local spell_bottom = Spell.new(team)
    spell_bottom:set_texture(TEXTURE)
    spell_bottom:sprite():set_layer(-5)
    spell_bottom:set_facing(entity:facing())

    local top_animation = spell_top:animation()
    top_animation:load(ANIMATION_PATH)
    top_animation:set_state("CLAP_TOP")
    local bottom_animation = spell_bottom:animation()
    bottom_animation:load(ANIMATION_PATH)
    bottom_animation:set_state("CLAP_BOTTOM")
    bottom_animation:on_complete(function()
        spell_top:delete()
        main_spell:delete()
        spell_bottom:delete()
    end)

    local success = false
    local hit_sides = false
    local hit_center = false
    bottom_animation:on_frame(2, function()
        hit_sides = true
    end)
    bottom_animation:on_frame(3, function()
        hit_sides = false
        hit_center = true
    end)

    main_spell.on_attack_func = function()
        success = true
    end

    main_spell.on_delete_func = function()
        callback(success)
        main_spell:erase()
    end

    local time = 0

    main_spell.on_update_func = function()
        local tile = main_spell:current_tile()
        local x = tile:x()
        local top_tile = field:tile_at(x, 1) --[[@as Tile]]
        local center_tile = field:tile_at(x, 2) --[[@as Tile]]
        local bottom_tile = field:tile_at(x, 3) --[[@as Tile]]

        time = time + 1

        if time <= 12 then
            top_tile:set_highlight(Highlight.Flash)
            center_tile:set_highlight(Highlight.Flash)
            bottom_tile:set_highlight(Highlight.Flash)
        end

        if time == 12 then
            field:spawn(spell_top, tile)
            field:spawn(spell_bottom, tile)
            entity.set_hands_visible(false)
        end

        if hit_sides then
            top_tile:attack_entities(main_spell)
            bottom_tile:attack_entities(main_spell)
        end

        if hit_center then
            center_tile:attack_entities(main_spell)
            Resources.play_audio(CLAP_SFX)
            hit_center = false
        end
    end

    -- find a place to spawn
    local x = 2
    local enemies = field:find_characters(function(enemy)
        return enemy:team() ~= team and enemy:hittable()
    end)

    if #enemies ~= 0 then
        local enemy = enemies[math.random(#enemies)]
        x = enemy:current_tile():x()
    else
        local tiles = field:find_tiles(function(tile)
            return tile:team() ~= team
        end)
        local tile = tiles[math.random(#tiles)]
        x = tile:x()
    end

    field:spawn(main_spell, x, 2)
end

---@param entity CircusMan
local function create_clap_factory(entity)
    return function()
        local action = Action.new(entity)
        action:set_lockout(ActionLockout.new_sequence())

        local action_ended = false
        action.on_action_end_func = function()
            action_ended = true
        end

        -- clap start + end animations appear unused in BN6

        -- local start_step = action:create_step()
        -- start_step.on_update_func = function()
        --     start_step.on_update_func = nil

        --     entity.set_state_all("CLAP_START")
        --     animation:on_complete(function()
        --         start_step:complete_step()
        --     end)
        -- end

        local add_end_step = function()
            -- local end_step = action:create_step()
            -- end_step.on_update_func = function()
            --     end_step.on_update_func = nil

            --     entity.set_state_all("CLAP_END")
            --     animation:on_complete(function()
            --         end_step:complete_step()
            --     end)
            -- end
        end

        local claps = 0
        local add_clap_step

        add_clap_step = function()
            claps = claps + 1

            local step = action:create_step()

            step.on_update_func = function()
                step.on_update_func = nil

                spawn_clap(entity, function(success)
                    if action_ended then
                        return
                    end

                    if not success and claps < entity.max_attempts then
                        add_clap_step()
                    else
                        add_end_step()
                    end

                    step:complete_step()
                end)

                entity.set_state_all("CLAP")
            end
        end

        add_clap_step()

        return action
    end
end

---@param entity Entity
local function lion_random_tile(entity)
    local test_direction = entity:facing_away()
    local tiles = Ai.find_setup_tiles(entity, function(enemy, suggest)
        local next_tile = enemy:get_tile(test_direction, 1)

        while next_tile ~= nil do
            local tile_after = next_tile:get_tile(test_direction, 1)

            if entity:can_move_to(next_tile) and tile_after and not tile_after:is_edge() then
                suggest(next_tile)
            end

            next_tile = tile_after
        end
    end)

    if #tiles ~= 0 then
        return tiles[math.random(#tiles)]
    end

    return nil
end

---@param ring Entity
local function spawn_lion(ring, damage)
    local lion = Spell.new(ring:team())
    lion:set_texture(TEXTURE)

    lion:set_hit_props(
        HitProps.new(
            damage,
            Hit.Impact | Hit.Flinch | Hit.Flash,
            Element.None,
            lion:context()
        )
    )

    local animation = lion:animation()
    animation:load(ANIMATION_PATH)
    animation:set_state("LION")
    animation:set_playback(Playback.Loop)

    lion.on_update_func = function()
        lion:current_tile():attack_entities(lion)

        if lion:is_moving() then
            return
        end

        local next_tile = lion:get_tile(lion:facing(), 1)

        if next_tile then
            lion:slide(next_tile, 6)
        else
            lion:delete()
        end
    end

    lion.on_collision_func = function()
        lion:delete()
    end

    ring:field():spawn(lion, ring:current_tile())
end

---@param entity CircusMan
local function spawn_ring_of_fire(entity)
    local field = entity:field()
    local tile = lion_random_tile(entity)

    if not tile then
        return
    end

    local team = entity:team()
    local ring = Spell.new(team)
    ring:set_texture(TEXTURE)
    local ring_animation = ring:animation()
    ring_animation:load(ANIMATION_PATH)
    ring_animation:set_state("RING_OF_FIRE")
    ring_animation:set_playback(Playback.Loop)

    ring.on_spawn_func = function()
        Resources.play_audio(RING_SFX)
    end

    local time = 0

    ring.on_update_func = function()
        time = time + 1

        if time == 10 then
            --- note: entity could be deleted here
            --- but still safe to use the damage property
            spawn_lion(ring, entity.damage)
        end

        if time >= 24 then
            ring:delete()
        end
    end

    field:spawn(ring, tile)
end

---@param entity CircusMan
local function create_lion_factory(entity)
    local animation = entity:animation()

    return function()
        local action = Action.new(entity)
        action:set_lockout(ActionLockout.new_sequence())

        for _ = 1, entity.max_attempts do
            local start_step = action:create_step()
            start_step.on_update_func = function()
                start_step.on_update_func = nil

                entity.set_state_all("WHIP_START")
                animation:on_complete(function()
                    start_step:complete_step()
                end)
            end

            local step = action:create_step()

            step.on_update_func = function()
                step.on_update_func = nil

                entity.set_state_all("WHIP")
                animation:on_frame(3, function()
                    spawn_ring_of_fire(entity)
                end)
                animation:on_complete(function()
                    step:complete_step()
                end)
            end
        end

        return action
    end
end

---@param entity CircusMan
---@param callback fun(success: boolean)
local function spawn_cage(entity, callback)
    local team = entity:team()
    local field = entity:field()

    local cage = Obstacle.new(team)
    cage:set_health(50)
    cage:set_facing(entity:facing())
    cage:enable_hitbox(false)
    cage:enable_sharing_tile(true)
    cage:set_texture(TEXTURE)

    local cage_sprite = cage:sprite()
    cage_sprite:set_layer(-100)

    cage:set_hit_props(
        HitProps.new(
            5,
            entity.cage_hit_flags,
            Element.None,
            entity:context()
        )
    )

    local cage_animation = cage:animation()
    cage_animation:load(ANIMATION_PATH)
    cage_animation:set_state("CAGE_HOVER")

    local HIT_RATE = 8
    local MAX_ELEVATION = Tile:height() * 4
    local success = false
    local allow_attack = false
    local attack_time = 0
    local time = 0

    local function rise_up_and_erase()
        local rise_time = 0

        local component = cage:create_component(Lifetime.ActiveBattle)
        component.on_update_func = function()
            rise_time = rise_time + 1

            local progress = rise_time / 10
            cage:set_elevation(progress * MAX_ELEVATION)

            if rise_time == 10 then
                callback(success)
                cage:erase()
            end
        end
    end

    cage.on_delete_func = function()
        if allow_attack then
            cage_animation:set_state("CAGE_RELEASE")
            cage_animation:on_complete(function()
                rise_up_and_erase()
            end)
        else
            rise_up_and_erase()
        end
    end

    local function capture_enemies()
        local captured_enemy = false

        cage:current_tile():find_characters(function(character)
            character:set_remaining_status_time(Hit.Cage, 2)

            if character:team() ~= team then
                captured_enemy = true
            end

            return false
        end)

        return captured_enemy
    end

    cage.on_update_func = function()
        time = time + 1

        local tile = cage:current_tile()

        if time <= 3 then
            tile:set_highlight(Highlight.Solid)
        end

        if time <= 17 then
            local progress = 1 - (time - 7) / 10
            cage:set_elevation(progress * MAX_ELEVATION)
        end

        if time == 17 and capture_enemies() then
            success = true
            Resources.play_audio(CAGE_SFX)
            cage_animation:set_state("CAGE_CAPTURE")
            cage_animation:on_complete(function()
                cage_animation:set_state("CAGE_STRUGGLE")
                cage_animation:set_playback(Playback.Loop)
                cage:enable_hitbox(true)
                cage:enable_sharing_tile(false)
                allow_attack = true
            end)
        end

        if not success then
            if time == 25 then
                cage:delete()
            end
            return
        end

        local holding_enemies = capture_enemies()

        if not allow_attack then
            return
        end

        if not holding_enemies then
            -- end early if there's no one in our cage
            cage:delete()
            return
        end

        attack_time = attack_time + 1

        if attack_time % HIT_RATE == 0 then
            -- hit
            tile:attack_entities(cage)

            -- play sfx
            Resources.play_audio(CAGE_HIT_SFX)

            -- spawn particle
            local particle = create_particle(IMPACT_TEXTURE, IMPACT_ANIMATION_PATH, "DEFAULT")
            particle:sprite():set_layer(cage_sprite:layer() - 1)
            particle:set_offset(
                (math.random() * 2 - 1) * Tile:width(),
                -math.random(0, Tile:height() * 2)
            )
            field:spawn(particle, tile)
        end

        if attack_time == HIT_RATE * entity.cage_hits then
            cage:delete()
        end
    end

    -- figure out where to spawn
    local enemies = field:find_characters(function(enemy)
        return enemy:team() ~= team and entity:hittable()
    end)

    if #enemies == 0 then
        callback(success)
        return
    end

    local enemy = enemies[math.random(#enemies)]
    field:spawn(cage, enemy:current_tile())
end

---@param entity CircusMan
local function create_cage_factory(entity)
    local animation = entity:animation()
    local sprite = entity:sprite()

    return function()
        local action = Action.new(entity)
        action:set_lockout(ActionLockout.new_sequence())
        local action_ended = false

        local start_step = action:create_step()
        start_step.on_update_func = function()
            start_step.on_update_func = nil

            entity.set_state_all("DISAPPEAR_START")
            animation:on_complete(function()
                entity.set_state_all("DISAPPEAR")
                animation:on_complete(function()
                    start_step:complete_step()
                    entity:enable_hitbox(false)
                    sprite:set_visible(false)
                end)
            end)
        end

        local add_end_step = function()
            local end_step = action:create_step()
            end_step.on_update_func = function()
                end_step.on_update_func = nil

                sprite:set_visible(true)
                entity.set_state_all("APPEAR")
                animation:on_complete(function()
                    end_step:complete_step()
                end)
            end
        end

        local cages = 0
        local add_cage_step

        add_cage_step = function()
            cages = cages + 1

            local step = action:create_step()

            step.on_update_func = function()
                step.on_update_func = nil

                spawn_cage(entity, function(hit)
                    if action_ended then
                        return
                    end

                    if not hit and cages < entity.max_attempts then
                        add_cage_step()
                    else
                        add_end_step()
                    end

                    step:complete_step()
                end)
            end
        end

        add_cage_step()

        action.on_action_end_func = function()
            entity:enable_hitbox(true)
            sprite:set_visible(true)
            action_ended = true
        end

        return action
    end
end


---@param entity CircusMan
function character_init(entity)
    entity:set_name("CrcusMan")
    entity:set_height(60)
    entity.cage_hit_flags = Hit.Impact | Hit.PierceInvis | Hit.Flinch

    local rank = entity:rank()
    if rank == Rank.V1 then
        entity:set_health(700)
        entity.damage = 20
        entity.cage_hits = 23
        entity.max_attempts = 2
    elseif rank == Rank.EX then
        entity:set_health(1200)
        entity.damage = 50
        entity.cage_hits = 30
        entity.max_attempts = 3
        entity.cage_hit_flags = entity.cage_hit_flags | Hit.Paralyze
    elseif rank == Rank.SP then
        entity:set_health(1600)
        entity.damage = 100
        entity.cage_hits = 38
        entity.max_attempts = 4
        entity.cage_hit_flags = entity.cage_hit_flags | Hit.Confuse
    elseif rank == Rank.RV then
        entity:set_health(2100)
        entity.damage = 130
        entity.cage_hits = 45
        entity.max_attempts = 5
        entity.cage_hit_flags = entity.cage_hit_flags | Hit.Blind
    end

    entity:set_texture(TEXTURE)
    entity:set_shadow(SHADOW_TEXTURE)
    local animation = entity:animation()
    animation:load(ANIMATION_PATH)

    local left_hands = entity:sprite():create_node()
    left_hands:set_texture(TEXTURE)
    left_hands:use_root_shader(true)
    left_hands:set_layer(-1)

    local right_hands = entity:sprite():create_node()
    right_hands:set_texture(TEXTURE)
    right_hands:use_root_shader(true)
    right_hands:set_layer(1)

    local left_hands_animation = Animation.new(ANIMATION_PATH)
    local right_hands_animation = Animation.new(ANIMATION_PATH)

    function entity.set_hands_visible(visible)
        left_hands:set_visible(visible)
        right_hands:set_visible(visible)
    end

    function entity.set_state_all(state, playback)
        if left_hands_animation:has_state("HANDS_LEFT_" .. state) then
            left_hands_animation:set_state("HANDS_LEFT_" .. state)
            left_hands_animation:apply(left_hands)
            right_hands_animation:set_state("HANDS_RIGHT_" .. state)
            right_hands_animation:apply(right_hands)
            entity.set_hands_visible(true)
        else
            entity.set_hands_visible(false)
        end

        animation:set_state(state)

        if playback then
            left_hands_animation:set_playback(playback)
            right_hands_animation:set_playback(playback)
            animation:set_playback(playback)
        end
    end

    entity.on_update_func = function()
        left_hands_animation:apply(right_hands)
        right_hands_animation:apply(right_hands)
        left_hands_animation:update()
        right_hands_animation:update()
    end

    entity.set_state_all("IDLE", Playback.Loop)

    entity:register_status_callback(Hit.Flinch, function()
        entity:cancel_movement()
        entity:cancel_actions()

        local action = Action.new(entity)
        action:set_lockout(ActionLockout.new_sequence())

        local step = action:create_step()
        local time = 0
        step.on_update_func = function()
            time = time + 1
            if time >= 14 then
                step:complete_step()
            end
        end

        action.on_execute_func = function()
            entity.set_state_all("FLINCH")
        end

        entity:queue_action(action)
    end)

    local ai = Ai.new_ai(entity)
    local move_factory = create_move_factory(entity)
    local clap_factory = create_clap_factory(entity)
    local lion_factory = create_lion_factory(entity)
    local cage_factory = create_cage_factory(entity)

    local clap_plan = ai:create_plan()
    clap_plan:set_weight(5)
    clap_plan:set_action_iter_factory(function()
        return Ai.IteratorLib.chain(
            Ai.IteratorLib.take(1, move_factory),
            Ai.IteratorLib.take(1, clap_factory)
        )
    end)

    local lion_plan = ai:create_plan()
    lion_plan:set_weight(4)
    lion_plan:set_action_iter_factory(function()
        return Ai.IteratorLib.chain(
            Ai.IteratorLib.take(1, move_factory),
            Ai.IteratorLib.take(1, lion_factory)
        )
    end)

    local cage_plan = ai:create_plan()
    cage_plan:set_weight(2)
    cage_plan:set_usable_after(2)
    cage_plan:set_action_iter_factory(function()
        return Ai.IteratorLib.chain(
            Ai.IteratorLib.take(1, move_factory),
            Ai.IteratorLib.take(1, cage_factory)
        )
    end)
end
