---@type KonstAiLib
local Ai = require("dev.konstinople.library.ai")
---@type BattleNetworkAssetsLib
local bn_assets = require("BattleNetwork.Assets")

---@class Spikey : Entity
---@field cascade_frame_index number
---@field setup_success boolean

local debug = false
local function debug_print(text)
    if debug then
        print("[spikey] " .. text)
    end
end

---@param entity Entity
local function default_random_tile(entity)
    local tiles = entity:field():find_tiles(function(tile)
        return entity:can_move_to(tile) and tile ~= entity:current_tile()
    end)

    if #tiles == 0 then
        return nil
    end

    return tiles[math.random(#tiles)]
end

---@param entity Entity
local function create_move_factory(entity)
    local function target_tile_callback()
        local tile = default_random_tile(entity)
        if tile then
            entity:set_facing(tile:facing())
            return tile
        end
    end

    return function()
        return bn_assets.MobMoveAction.new(entity, "MEDIUM", target_tile_callback)
    end
end

---@param self Entity
local function setup_random_tile(self)
    local tiles = Ai.find_setup_tiles(self, function(enemy, suggest)
        local next_tile = enemy:get_tile(enemy:facing(), 1)

        while next_tile ~= nil do
            -- avoid positions that would be blocked by obstacles
            local obstacle_found = false
            next_tile:find_obstacles(function(o)
                if o:hittable() then
                    obstacle_found = true
                end

                return false
            end)

            if obstacle_found then
                break
            end

            -- suggest the first tile we can move to
            if self:can_move_to(next_tile) then
                suggest(next_tile)
                break
            end

            next_tile = next_tile:get_tile(enemy:facing(), 1)
        end
    end)

    if #tiles ~= 0 then
        return tiles[math.random(#tiles)]
    end

    return nil
end

---@param entity Spikey
local function create_setup_factory(entity)
    local function target_tile_callback()
        local tile = setup_random_tile(entity)
        if not tile then
            tile = default_random_tile(entity)
        else
            entity.setup_success = true
        end

        if tile then
            entity:set_facing(tile:facing())
            return tile
        end
    end

    return function()
        return bn_assets.MobMoveAction.new(entity, "MEDIUM", target_tile_callback)
    end
end

local function spawn_fireball(owner, tile, direction, damage, cascade_frame_index)
    debug_print("in spawn fireball")
    local team = owner:team()
    local field = owner:field()
    local fireball_texture = Resources.load_texture("fireball.png")
    local fireball_sfx = Resources.load_audio("sfx.ogg")
    local explosion_texture = Resources.load_texture("spell_explosion.png")
    Resources.play_audio(fireball_sfx)
    local spell = Spell.new(team)
    spell:set_texture(fireball_texture)
    spell:set_facing(direction)

    spell:set_tile_highlight(Highlight.Solid)
    spell:set_hit_props(
        HitProps.new(
            damage,
            Hit.Impact | Hit.Flash,
            Element.Fire,
            owner:context(),
            Drag.None
        )
    )
    local sprite = spell:sprite()
    sprite:set_layer(-1)
    local animation = spell:animation()
    animation:load("fireball.animation")
    animation:set_state("DEFAULT")
    animation:set_playback(Playback.Loop)
    animation:apply(sprite)

    local has_hit = false
    local slide_started = false
    spell.on_update_func = function(self)
        local own_tile = self:current_tile()
        own_tile:attack_entities(self)
        --Erase spell if we're on an edge and we've started sliding, but AREN'T currently sliding. Make it clean.
        if own_tile:is_edge() and not self:is_sliding() and slide_started then self:delete() end

        --Destination is one tile ahead.
        local dest = self:get_tile(spell:facing(), 1)
        --If a hit has not landed...
        if not has_hit then
            --Slide for the fireball's slide time. 12f for V1, 9f for V2, 6f for V3. Signal the slide has started.
            self:slide(dest, cascade_frame_index, function()
                slide_started = true
            end)
        end
    end
    local function rank_relevant_boom(attack, explosion_table)
        for explosions = 1, #explosion_table, 1 do
            if explosion_table[explosions] and not explosion_table[explosions]:is_edge() then
                local hitbox = Hitbox.new(spell:team())
                hitbox:set_hit_props(attack:copy_hit_props())
                local fx = Spell.new(attack:team())
                fx:set_texture(explosion_texture)
                local fx_anim = fx:animation()
                fx_anim:load("spell_explosion.animation")
                fx_anim:set_state("Default")
                fx_anim:apply(fx:sprite())
                fx:sprite():set_layer(-2)
                fx_anim:on_complete(function() fx:erase() end)
                field:spawn(fx, explosion_table[explosions])
                field:spawn(hitbox, explosion_table[explosions])
            end
        end
        attack:erase()
    end

    spell.on_collision_func = function(self, other)
        has_hit = true
        local explosion_tiles = {}
        local rank = owner:rank()
        if rank == Rank.V1 or rank == Rank.SP then
            explosion_tiles = { self:current_tile(), self:get_tile(self:facing(), 1) }
        elseif rank == Rank.V2 then
            explosion_tiles = { self:current_tile(), self:get_tile(Direction.join(self:facing(), Direction.Up), 1),
                self:get_tile(Direction.join(self:facing(), Direction.Down), 1) }
        elseif rank == Rank.V3 then
            explosion_tiles = { self:current_tile(), self:get_tile(Direction.Up, 1), self:get_tile(Direction.Down, 1) }
        end
        rank_relevant_boom(self, explosion_tiles)
    end
    field:spawn(spell, tile)
end

local function create_fireball_action(character)
    debug_print("started fireball action")
    local action_name = "fireball"
    local facing = character:facing()
    debug_print('action ' .. action_name)
    --Set the damage. Default is 30.
    local damage = 30
    local rank = character:rank()
    if rank == Rank.V2 then
        damage = 60
    elseif rank == Rank.V3 then
        damage = 90
    elseif rank == Rank.SP then
        damage = 150
    end
    local action = Action.new(character, "ATTACK")
    action:set_lockout(ActionLockout.new_animation())
    action.on_execute_func = function(self, user)
        self:add_anim_action(2, function()
            character:set_counterable(true)
        end)
        self:add_anim_action(4, function()
            local tile = character:get_tile(facing, 1)
            spawn_fireball(character, tile, facing, damage, character.cascade_frame_index)
        end)
        self:add_anim_action(6, function()
            character:set_counterable(false)
        end)
    end
    character.ai_taken_turn = true
    return action
end

-- Required function, main package information
---@param self Spikey
function character_init(self)
    debug_print("package_init called")
    -- Load character resources
    local animation = self:animation()
    animation:load("battle.animation")
    -- Set up character meta
    self:set_texture(Resources.load_texture("battle.greyscaled.png"))
    self:set_height(50)
    self:set_name("Spikey")
    self:set_element(Element.Fire)
    local rank = self:rank()

    local moves_before_attack = 0
    if rank == Rank.V2 then
        self:set_health(140)
        self:set_palette(Resources.load_texture("battle_v2.palette.png"))
        moves_before_attack = 6
        self.cascade_frame_index = 10
    elseif rank == Rank.V3 then
        self:set_health(190)
        self:set_palette(Resources.load_texture("battle_v3.palette.png"))
        moves_before_attack = 5
        self.cascade_frame_index = 5
    elseif rank == Rank.SP then
        self:set_health(260)
        self:set_palette(Resources.load_texture("battle_v4.palette.png"))
        moves_before_attack = 3
        self.cascade_frame_index = 3
    else
        self:set_health(90)
        self:set_palette(Resources.load_texture("battle_v1.palette.png"))
        moves_before_attack = 7
        self.cascade_frame_index = 16
    end

    --defense rules
    self:add_defense_rule(DefenseVirusBody.new())

    -- Initial state
    animation:set_state("IDLE")
    animation:set_playback(Playback.Loop)

    self.on_idle_func = function()
        animation:set_state("IDLE")
        animation:set_playback(Playback.Loop)
    end

    local ai = Ai.new_ai(self)
    local plan = ai:create_plan()
    local move_factory = create_move_factory(self)
    local idle_factory = Ai.create_idle_action_factory(self, 40, 40)
    local setup_factory = create_setup_factory(self)
    local attack_factory = function()
        if self.setup_success then
            return create_fireball_action(self)
        end
    end

    plan:set_action_iter_factory(function()
        return Ai.IteratorLib.chain(
            Ai.IteratorLib.flatten(Ai.IteratorLib.take(moves_before_attack, function()
                self.setup_success = false

                -- move + idle
                return Ai.IteratorLib.chain(
                    Ai.IteratorLib.take(1, move_factory),
                    Ai.IteratorLib.take(1, idle_factory)
                )
            end)),
            Ai.IteratorLib.take(1, setup_factory),
            Ai.IteratorLib.take(1, attack_factory),
            Ai.IteratorLib.take(1, idle_factory)
        )
    end)
end
