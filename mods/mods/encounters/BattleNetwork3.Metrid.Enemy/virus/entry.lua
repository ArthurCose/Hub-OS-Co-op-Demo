---@type KonstAiLib
local Ai = require("dev.konstinople.library.ai")
---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local METEOR_TEXTURE = bn_assets.load_texture("meteor.png")
local METEOR_ANIM_PATH = bn_assets.fetch_animation_path("meteor.animation")
local EXPLOSION_TEXTURE = bn_assets.load_texture("ring_explosion.png")
local EXPLOSION_ANIM_PATH = bn_assets.fetch_animation_path("ring_explosion.animation")
local EXPLOSION_SFX = Resources.load_audio("sounds/explosion.ogg")
local LANDING_SFX = bn_assets.load_audio("meteor_land.ogg")

local MobTracker = require("mob_tracker.lua")
local mob_tracker = MobTracker:new()

---@class Metrid : Entity
---@field _attack number
---@field _minimum_meteors number
---@field _maximum_meteors number
---@field _meteor_cooldown number
---@field _accuracy_chance number

---@param metrid Metrid
local function create_meteor(metrid)
    local meteor = Spell.new(metrid:team())
    meteor:set_tile_highlight(Highlight.Flash)
    meteor:set_facing(metrid:facing())
    local flags = Hit.Impact | Hit.Flash | Hit.Flinch | Hit.PierceGround
    if metrid:rank() == Rank.NM then
        flags = flags & ~Hit.Flash
    end
    meteor:set_hit_props(
        HitProps.new(
            metrid._attack,
            flags,
            Element.Fire,
            metrid:context(),
            Drag.None
        )
    )
    meteor:set_texture(METEOR_TEXTURE)
    local anim = meteor:animation()
    anim:load(METEOR_ANIM_PATH)
    anim:set_state("DEFAULT")
    anim:apply(meteor:sprite())
    meteor:sprite():set_layer(-2)
    local boom = EXPLOSION_TEXTURE
    local cooldown = 16
    local x = 224
    local increment_x = 14
    local increment_y = 14
    meteor:set_offset(meteor:offset().x + x * 0.5, meteor:offset().y - 224 * 0.5)
    meteor.on_update_func = function(self)
        if cooldown <= 0 then
            local tile = self:current_tile()
            if tile and tile:is_walkable() then
                tile:attack_entities(self)
                self:field():shake(5, 18)
                local explosion = Spell.new(self:team())
                explosion:set_texture(boom)
                local new_anim = explosion:animation()
                new_anim:load(EXPLOSION_ANIM_PATH)
                new_anim:set_state("DEFAULT")
                new_anim:apply(explosion:sprite())
                explosion:sprite():set_layer(-2)
                Resources.play_audio(LANDING_SFX)
                self:field():spawn(explosion, tile)
                new_anim:on_frame(3, function()
                    Resources.play_audio(EXPLOSION_SFX)
                end)
                new_anim:on_complete(function()
                    explosion:erase()
                end)
            end
            self:erase()
        else
            local offset = self:offset()
            self:set_offset(offset.x - increment_x * 0.5, offset.y + increment_y * 0.5)
            cooldown = cooldown - 1
        end
    end
    meteor.can_move_to_func = function(tile)
        return true
    end
    return meteor
end

local function find_best_target(virus)
    if not virus or virus and virus:deleted() then return end
    local target = nil          --Grab a basic target from the virus itself.
    local field = virus:field() --Grab the field so you can scan it.
    local query = function(c)
        return c:team() ~=
            virus:team()                                   --Make sure you're not targeting the same team, since that won't work for an attack.
    end
    local potential_threats = field:find_characters(query) --Find CHARACTERS, not entities, to attack.
    local goal_hp = 999999                                 --Start with a ridiculous health.
    if #potential_threats > 0 then                         --If the list is bigger than 0, we go in to a loop.
        for i = 1, #potential_threats, 1 do                --The pound sign, or hashtag if you're more familiar with that term, is used to denote length of a list or array in lua.
            local possible_target = potential_threats[i]   --Index with square brackets.
            --Make sure it exists, is not deleted, and that its health is less than the goal HP. First one always will be.
            if possible_target and not possible_target:deleted() and possible_target:health() <= goal_hp then
                --Make it the new target. This way the lowest HP target is attacked.
                target = possible_target
            end
        end
    end
    --Return whoever the target is.
    return target
end

---@param metrid Metrid
local function create_meteor_action(metrid)
    local action = Action.new(metrid)
    action:set_lockout(ActionLockout.new_sequence())
    local init_step = action:create_step()
    local meteor_step = action:create_step()

    local metrid_anim = metrid:animation()

    local function create_component()
        local meteor_component = metrid:create_component(Lifetime.Battle)
        local count = math.random(metrid._minimum_meteors, metrid._maximum_meteors)
        local attack_cooldown_max = metrid._meteor_cooldown
        local highlight_cooldown_max = 24
        local highlight_cooldown = 24
        local attack_cooldown = 0
        local accuracy_chance = metrid._accuracy_chance
        local desired_cooldown = 0
        local next_tile = nil

        if metrid:rank() == Rank.NM then
            desired_cooldown = attack_cooldown_max - 16
        end

        local field = metrid:field()
        meteor_component.on_update_func = function()
            if metrid:deleted() then return end
            if count <= 0 then
                metrid_anim:set_state("DRESS")
                metrid_anim:on_complete(function()
                    mob_tracker:advance_a_turn()
                    meteor_step:complete_step()
                end)
                meteor_component:eject()
                return
            end

            if next_tile ~= nil then
                next_tile:set_highlight(Highlight.Flash)
            end

            if highlight_cooldown <= 0 then
                local tile_list = metrid:field():find_tiles(function(tile)
                    return tile:team() ~= metrid:team() and tile:is_walkable()
                end)

                --Use less than or equal to copmarison to confirm a d100 roll of accuracy.
                --Example: if a Metrid has an accuracy chance of 20, then a 1 to 100 roll will
                --Only target the player's tile on a roll of 1-20, leading to an 80% chance of
                --Targeting a random player tile.
                if math.random(1, 100) <= accuracy_chance then
                    local target = find_best_target(metrid)
                    if target ~= nil then
                        next_tile = target:current_tile()
                    else
                        next_tile = tile_list[math.random(1, #tile_list)]
                    end
                else
                    next_tile = tile_list[math.random(1, #tile_list)]
                end
                highlight_cooldown = highlight_cooldown_max
            else
                highlight_cooldown = highlight_cooldown - 1
            end

            if attack_cooldown <= desired_cooldown and next_tile ~= nil then
                count = count - 1
                attack_cooldown_max = attack_cooldown_max
                attack_cooldown = attack_cooldown_max
                field:spawn(create_meteor(metrid), next_tile)
            else
                attack_cooldown = attack_cooldown - 1
            end
        end
    end

    action.on_execute_func = function()
        metrid_anim:set_state("DISROBE")
        metrid_anim:on_complete(function()
            metrid_anim:set_state("ATTACK")
            metrid_anim:set_playback(Playback.Loop)
            init_step:complete_step()
            create_component()
        end)
    end

    return action
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

---@param metrid Entity
local function setup_random_tile(metrid)
    local preferred_tiles = metrid:field():find_tiles(function(tile)
        if not metrid:can_move_to(tile) then
            return false
        end

        local forward_tile = tile:get_tile(tile:facing(), 1)
        if not forward_tile then
            return false
        end

        local has_obstacle
        forward_tile:find_obstacles(function()
            has_obstacle = true
            return false
        end)

        return has_obstacle
    end)

    if #preferred_tiles ~= 0 then
        return preferred_tiles[math.random(#preferred_tiles)]
    end

    local tiles = metrid:field():find_tiles(function(tile)
        return metrid:can_move_to(tile)
    end)

    if #tiles ~= 0 then
        return tiles[math.random(#tiles)]
    end

    return nil
end

---@param entity Entity
local function create_setup_factory(entity)
    local function target_tile_callback()
        local tile = setup_random_tile(entity)
        if tile then
            entity:set_facing(tile:facing())
            return tile
        end
    end

    return function()
        return bn_assets.MobMoveAction.new(entity, "MEDIUM", target_tile_callback)
    end
end

---@param self Metrid
function character_init(self)
    --Obtain the rank of the virus.
    --This can be V1, V2, V3, EX, SP, R1, R2, or NM.
    --There's also RV, DS, virus, Beta, and Omega in the next build.
    local rank = self:rank()
    self:set_height(38)
    --Set its name, health, and attack based on rank.
    --Start with V2 because Omega will share a name with V1, just with a symbol.
    self._minimum_meteors = 4
    self._maximum_meteors = 8
    local idle_max = 40
    self._accuracy_chance = 20
    self._meteor_cooldown = 32
    if rank == Rank.V2 then
        self:set_name("Metrod")
        self:set_texture(Resources.load_texture("Metrod.png"))
        self:set_health(200)
        self._attack = 80
        idle_max = 30
    elseif rank == Rank.V3 then
        self:set_name("Metrodo")
        self:set_texture(Resources.load_texture("Metrodo.png"))
        self:set_health(250)
        self._attack = 120
        idle_max = 20
    else
        --All ranks like this will be called Metrid, so use that name.
        self:set_name("Metrid")
        if rank == Rank.NM then
            self:set_texture(Resources.load_texture("MetridNM.png"))
            self:set_health(500)
            self._attack = 300
            idle_max = 16
            self._minimum_meteors = 20
            self._maximum_meteors = 40
            self._accuracy_chance = 40
        elseif rank == Rank.SP then
            self:set_texture(Resources.load_texture("Omega.png"))
            self:set_health(300)
            self._attack = 200
            idle_max = 16
        else
            --If unsupported, assume rank 1.
            self:set_texture(Resources.load_texture("Metrid.png"))
            self:set_health(150)
            self._attack = 40
        end
    end
    self:set_element(Element.Fire)
    self:add_aux_prop(StandardEnemyAux.new())
    local anim = self:animation()
    anim:load("Metrid.animation")
    anim:set_state("IDLE")
    anim:apply(self:sprite())
    anim:set_playback(Playback.Loop)

    self.on_battle_start_func = function()
        mob_tracker:add_by_id(self:id())
    end
    self.on_delete_func = function()
        mob_tracker:remove_by_id(self:id())
        self:default_character_delete()
    end
    self.on_idle_func = function()
        anim:set_state("IDLE")
        anim:set_playback(Playback.Loop)
    end

    local ai = Ai.new_ai(self)
    local plan = ai:create_plan()
    local move_factory = create_move_factory(self)
    local idle_factory = Ai.create_idle_action_factory(self, idle_max, idle_max)
    local setup_factory = create_setup_factory(self)
    local attack_factory = function()
        return create_meteor_action(self)
    end

    plan:set_action_iter_factory(function()
        return Ai.IteratorLib.chain(
            Ai.IteratorLib.flatten(Ai.IteratorLib.take(5, function()
                -- move + idle
                return Ai.IteratorLib.chain(
                    Ai.IteratorLib.take(1, move_factory),
                    Ai.IteratorLib.take(1, idle_factory)
                )
            end)),
            Ai.IteratorLib.flatten(Ai.IteratorLib.take(1, function()
                -- attempt attack

                if mob_tracker:get_active_mob() ~= self:id() then
                    -- not our turn, return empty iterator
                    return function() return nil end
                end

                -- setup + attack
                return Ai.IteratorLib.chain(
                    Ai.IteratorLib.take(1, setup_factory),
                    Ai.IteratorLib.take(1, idle_factory),
                    Ai.IteratorLib.take(1, attack_factory)
                )
            end))
        )
    end)
end
