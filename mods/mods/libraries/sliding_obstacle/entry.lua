---@class SlidingObstacle
local SlidingObstacle = {}
SlidingObstacle.__index = SlidingObstacle

-- big poof for main
-- little poof for particles
-- collision texture + animation required "BREAKING"

function SlidingObstacle:set_texture(texture)
  self.texture = texture
end

function SlidingObstacle:set_animation_path(animation_path)
  self.animation_path = animation_path
end

function SlidingObstacle:set_animation_state(animation_state)
  self.animation_state = animation_state
end

--- Optional
function SlidingObstacle:set_collision_texture(texture)
  self.collision_texture = texture
end

--- Optional
function SlidingObstacle:set_collision_animation_path(path)
  self.collision_animation_path = path
end

--- Optional
function SlidingObstacle:set_collision_animation_state(state)
  self.collision_state = state
end

--- Defaults:
--- - 500 for Boulders
--- - 200 for Cubes
function SlidingObstacle:set_health(health)
  self.health = health
end

--- Defaults:
--- - 400 for Boulders
--- - 200 for Cubes
function SlidingObstacle:set_damage(damage)
  self.damage = damage
end

--- Element.Break by default
function SlidingObstacle:set_element(element)
  self.element = element
end

--- Will last forever if unset, 6000 is a standard duration for cubes
function SlidingObstacle:set_duration(duration)
  self.duration = duration
end

--- Will last forever if unset, 6000 is a standard duration for cubes
function SlidingObstacle:set_delete_func(delete_func)
  self.delete_func = delete_func
end

function SlidingObstacle:create_obstacle()
  local obstacle = Obstacle.new(Team.Other)
  obstacle:set_texture(self.texture)
  local anim = obstacle:animation()
  anim:load(self.animation_path)
  anim:set_state(self.animation_state or "DEFAULT")
  anim:set_playback(Playback.Loop)

  -- set height based on animation
  local sprite = obstacle:sprite()
  anim:apply(sprite)
  obstacle:set_height(sprite:origin().y)

  -- set health
  obstacle:set_health(self.health or 200)

  local rule = DefenseRule.new(DefensePriority.Body, DefenseOrder.CollisionOnly)
  rule.defense_func = function(_, _, _, hit_props)
    if
        hit_props.element == Element.Break or
        hit_props.secondary_element == Element.Break or
        hit_props.flags & Hit.PierceGuard ~= 0
    then
      obstacle:delete()
    end
  end
  rule.filter_func = function(hit_props)
    if hit_props.drag.distance > 0 then
      -- force a drag distance of one, we'll handle moving further
      hit_props.drag.distance = 1
    end

    return hit_props
  end
  obstacle:add_defense_rule(rule)

  -- define default collision hitprops
  obstacle:set_hit_props(HitProps.new(
    self.damage or 200,
    Hit.Impact | Hit.Flinch | Hit.Flash | Hit.PierceGuard,
    self.element or Element.Break,
    nil,
    Drag.None
  ))

  -- upon tangible collision
  obstacle.on_collision_func = function()
    -- spawn collision artifact
    if self.collision_texture then
      local movement_offset = obstacle:movement_offset()

      local artifact = Artifact.new()
      artifact:set_texture(self.collision_texture)
      artifact:sprite():set_layer(-3)

      if self.collision_animation_path then
        local animation = artifact:animation()
        animation:load(self.collision_animation_path)
        animation:set_state(self.collision_state or "DEFAULT")
        animation:on_complete(function()
          artifact:erase()
        end)
      end

      artifact:set_offset(movement_offset.x, movement_offset.y - obstacle:height() / 2)
      obstacle:field():spawn(artifact, obstacle:current_tile())
    end

    -- delete
    obstacle:delete()
  end

  -- upon passing the defense check, does nothing
  obstacle.on_attack_func = function() end

  obstacle.can_move_to_func = function(tile)
    -- we can move as long as the tile is walkable
    -- and there's no obstacles already on it
    if not tile:is_walkable() then
      return false
    end

    local cube_team = obstacle:team()
    local obstacles_here = false

    tile:find_obstacles(function(obstacle)
      if obstacle:team() == cube_team then
        obstacles_here = true
      end

      return false
    end)

    return not obstacles_here
  end

  -- slide + duration tracker
  local remaining_time = self.duration
  local continue_slide = false
  local prev_tile = {}
  local cube_speed = 4

  obstacle.on_update_func = function(self)
    if remaining_time then
      if remaining_time == 0 then
        self:delete()
      end

      remaining_time = remaining_time - 1
    end

    local tile = obstacle:current_tile()

    if not tile then
      obstacle:delete()
    end

    if tile:is_edge() then
      obstacle:delete()
    end

    tile:attack_entities(self)

    local direction = self:facing()

    if self:is_sliding() then
      table.insert(prev_tile, 1, tile)
      prev_tile[cube_speed + 1] = nil
      local target_tile = tile:get_tile(direction, 1)
      if self:can_move_to(target_tile) then
        continue_slide = true
      else
        continue_slide = false
      end
    else
      -- become aware of which direction you just moved in, turn to face that direction
      if prev_tile[cube_speed] then
        if prev_tile[cube_speed]:get_tile(direction, 1):x() ~= tile:x() then
          direction = self:facing_away()
          self:set_facing(direction)
        end
      end
    end
    if not self:is_sliding() and continue_slide then
      self:slide(self:get_tile(direction, 1), cube_speed)
    end
  end

  if self.delete_func then
    obstacle.on_delete_func = self.delete_func
  end

  return obstacle
end

---@class SlidingObstacleLib
local SlidingObstacleLib = {
  new_boulder = function()
    ---@type SlidingObstacle
    local sliding_obstacle = {}
    setmetatable(sliding_obstacle, SlidingObstacle)
    sliding_obstacle:set_health(500)
    sliding_obstacle:set_damage(400)
    return sliding_obstacle
  end,
  new_cube = function()
    ---@type SlidingObstacle
    local sliding_obstacle = {}
    setmetatable(sliding_obstacle, SlidingObstacle)
    sliding_obstacle:set_health(200)
    sliding_obstacle:set_damage(200)
    return sliding_obstacle
  end,
}

return SlidingObstacleLib
