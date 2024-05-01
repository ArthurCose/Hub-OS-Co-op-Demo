---@class DoorsPluginObject
---@field area_id string
---@field object Net.Object
---@field open_count number

---@class DoorsPlugin
---@field private _area_doors table<string, table<any, DoorsPluginObject>>
local DoorsPlugin = {}

---@return DoorsPlugin
function DoorsPlugin:new()
  local plugin = {
    _area_doors = {}
  }
  setmetatable(plugin, self)
  self.__index = self

  return plugin
end

local open_door = function(area_id, door)
  -- just move it far away
  Net.move_object(area_id, door.object.id, -100, 0, 0)
end

local close_door = function(area_id, door)
  -- move it back
  local object = door.object
  Net.move_object(area_id, object.id, object.x, object.y, object.z)
end

---@param door DoorsPluginObject
local animate_state_change = Async.create_function(function(area_id, door, player_ids)
  local slide_duration = 0.5
  local wait_duration = 0.5
  local return_wait_duration = 1
  local return_slide_duration = 0.5

  local object = door.object

  for _, id in ipairs(player_ids) do
    Net.slide_player_camera(id, object.x, object.y, object.z, slide_duration)
  end

  -- delay before opening door
  Async.await(Async.sleep(slide_duration + wait_duration))

  if door.open_count > 0 then
    open_door(area_id, door)
  else
    close_door(area_id, door)
  end

  -- delay before returning the camera
  Async.await(Async.sleep(return_wait_duration))

  for _, id in ipairs(player_ids) do
    local x, y, z = Net.get_player_position_multi(id)
    Net.slide_player_camera(id, x, y, z, slide_duration)
  end

  Async.await(Async.sleep(return_slide_duration))

  for _, id in ipairs(player_ids) do
    Net.unlock_player_camera(id)
  end
end)

---@private
function DoorsPlugin:_ensure_door(area_id, object_id)
  local doors = self._area_doors[area_id]

  if not doors then
    doors = {}
    self._area_doors[area_id] = doors
  end

  local door = doors[object_id]

  if not door then
    door = {
      area_id = area_id,
      object = Net.get_object_by_id(area_id, object_id) --[[@as Net.Object]],
      open_count = 0
    }
    doors[object_id] = door
  end

  return door
end

---@param area_id string
---@param object_id number|string
---@param animate_list? Net.ActorId[]
function DoorsPlugin:stack_open(area_id, object_id, animate_list)
  local door = self:_ensure_door(area_id, object_id)

  door.open_count = door.open_count + 1

  if door.open_count == 1 then
    if animate_list then
      animate_state_change(area_id, door, animate_list)
    else
      open_door(area_id, door)
    end
  end
end

---@param area_id string
---@param object_id number|string
---@param animate_list? Net.ActorId[]
function DoorsPlugin:stack_close(area_id, object_id, animate_list)
  local door = self:_ensure_door(area_id, object_id)

  door.open_count = door.open_count - 1

  if door.open_count == 0 then
    if animate_list then
      animate_state_change(area_id, door, animate_list)
    else
      close_door(area_id, door)
    end
  end
end

return DoorsPlugin
