--Functions for easy reuse in scripts
--Unnamed version (Custom modifications)
--Version 1.8 (optionally ignore neutral team for get_first_target_ahead, add is_tile_free_for_movement)
--Version 1.7 (fixed find targets ahead getting non character/obstacles)

local battle_helpers = {}

function battle_helpers.spawn_visual_artifact(character, tile, texture, animation_path, animation_state, position_x,
                                              position_y, dont_flip_offset)
    local visual_artifact = Artifact.new()
    --visual_artifact:hide()
    visual_artifact:set_texture(texture)
    local anim = visual_artifact:animation()
    local sprite = visual_artifact:sprite()
    local field = character:field()
    local facing = character:facing()
    anim:load(animation_path)
    anim:set_state(animation_state)
    anim:on_complete(function()
        visual_artifact:delete()
    end)
    if facing == Direction.Left and not dont_flip_offset then
        position_x = position_x * -1
    end
    visual_artifact:set_facing(facing)
    visual_artifact:set_offset(position_x * 0.5, position_y * 0.5)
    anim:apply(sprite)
    field:spawn(visual_artifact, tile:x(), tile:y())
    return visual_artifact
end

function battle_helpers.find_all_enemies(user)
    local field = user:field()
    local user_team = user:team()
    local list = field:find_characters( --[[hittable patch--]] function(entity)
        if not entity:hittable() then return end
        ( --[[end hittable patch--]] function(character)
            if character:team() ~= user_team then
                --if you are not with me, you are against me
                return true
            end
        end --[[hittable patch--]])(entity)
    end --[[end hittable patch--]])
    return list
end

function battle_helpers.find_targets_ahead(user)
    local field = user:field()
    local user_tile = user:current_tile()
    local user_team = user:team()
    local user_facing = user:facing()
    local list = field:find_entities( --[[hittable patch--]] function(entity)
        if not entity:hittable() then return end
        ( --[[end hittable patch--]] function(entity)
            if Character.from(entity) == nil and Obstacle.from(entity) == nil then
                return false
            end
            local entity_tile = entity:current_tile()
            if entity_tile:y() == user_tile:y() and entity:team() ~= user_team then
                if user_facing == Direction.Left then
                    if entity_tile:x() < user_tile:x() then
                        return true
                    end
                elseif user_facing == Direction.Right then
                    if entity_tile:x() > user_tile:x() then
                        return true
                    end
                end
                return false
            end
        end --[[hittable patch--]])(entity)
    end --[[end hittable patch--]])
    return list
end

function battle_helpers.get_first_target_ahead(user, ignore_neutral_team)
    local facing = user:facing()
    local targets = battle_helpers.find_targets_ahead(user)
    local filtered_targets = {}
    if ignore_neutral_team then
        for index, target in ipairs(targets) do
            if target:team() ~= Team.Other then
                filtered_targets[#filtered_targets + 1] = target
            end
        end
    else
        filtered_targets = targets
    end
    table.sort(filtered_targets, function(a, b)
        return a:current_tile():x() > b:current_tile():x()
    end)
    if #filtered_targets == 0 then
        return nil
    end
    if filtered_targets == Direction.Left then
        return filtered_targets[1]
    else
        return filtered_targets[#filtered_targets]
    end
end

function battle_helpers.drop_trace_fx(target_artifact, lifetime_ms)
    --drop an afterimage artifact mimicking the appearance of an existing spell/artifact/character and fade it out over it's lifetime_ms
    local fx = Artifact.new()
    local anim = target_artifact:animation()
    local field = target_artifact:field()
    local offset = target_artifact:offset()
    local texture = target_artifact:texture()
    local elevation = target_artifact:elevation()
    fx:set_facing(target_artifact:facing())
    fx:set_texture(texture)
    fx:animation():copy_from(anim)
    fx:animation():set_state(anim:state())
    fx:set_offset(offset.x * 0.5, offset.y * 0.5)
    fx:set_elevation(elevation)
    fx:animation():apply(fx:sprite())
    fx.starting_lifetime_ms = lifetime_ms
    fx.lifetime_ms = lifetime_ms
    fx.on_update_func = function(self)
        self.lifetime_ms = math.max(0, self.lifetime_ms - math.floor((1 / 60) * 1000))
        local alpha = math.floor((fx.lifetime_ms / fx.starting_lifetime_ms) * 255)
        self:set_color(Color.new(0, 0, 0, alpha))

        if self.lifetime_ms == 0 then
            self:erase()
        end
    end

    local tile = target_artifact:current_tile()
    field:spawn(fx, tile:x(), tile:y())
    return fx
end

return battle_helpers
