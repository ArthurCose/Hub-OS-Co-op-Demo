---@class DoorsPluginObject
---@field object Net.Object
---@field open_count number

---@class DoorsPlugin
---@field private area_id string
---@field private doors table<any, DoorsPluginObject>
local DoorsPlugin = {}

---@param area_id string
---@return DoorsPlugin
function DoorsPlugin:new(area_id)
  local plugin = {
    area_id = area_id,
    doors = {}
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

---@param object_id any
---@param animate_list? Net.ActorId[]
function DoorsPlugin:stack_open(object_id, animate_list)
  local door = self.doors[object_id]

  if not door then
    door = {
      object = Net.get_object_by_id(self.area_id, object_id) --[[@as Net.Object]],
      open_count = 0
    }
    self.doors[object_id] = door
  end

  door.open_count = door.open_count + 1

  if door.open_count == 1 then
    if animate_list then
      animate_state_change(self.area_id, door, animate_list)
    else
      open_door(self.area_id, door)
    end
  end
end

---@param object_id any
---@param animate_list? Net.ActorId[]
function DoorsPlugin:stack_close(object_id, animate_list)
  local door = self.doors[object_id]

  if not door then
    door = {
      object = Net.get_object_by_id(self.area_id, object_id) --[[@as Net.Object]],
      open_count = 0
    }
    self.doors[object_id] = door
  end

  door.open_count = door.open_count - 1

  if door.open_count == 0 then
    if animate_list then
      animate_state_change(self.area_id, door, animate_list)
    else
      close_door(self.area_id, door)
    end
  end
end

return DoorsPlugin
