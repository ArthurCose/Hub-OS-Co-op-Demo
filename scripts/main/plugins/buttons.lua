local Rectangle = require("scripts/libs/rectangle")

---@alias ButtonsPluginCallback fun(button: ButtonsPluginObject, player_id: Net.ActorId)

---@class ButtonsPluginObject
---@field press_count number
---@field collision Net.Object
---@field visual? Net.Object

---@class ButtonsPluginPlayer
---@field button_index number

---@class ButtonsPlugin
---@field area_id string
---@field buttons ButtonsPluginObject[]
---@field state_listeners ButtonsPluginCallback[]
local ButtonsPlugin = {}

---@param activity Activity
---@param area_id string
---@return ButtonsPlugin
function ButtonsPlugin:new(activity, area_id)
  local plugin = {
    area_id = area_id,
    buttons = {},
    state_listeners = {}
  }
  setmetatable(plugin, self)
  self.__index = self

  plugin:init(activity)

  return plugin
end

---@private
---@param activity Activity
function ButtonsPlugin:init(activity)
  local player_data_map = {}

  activity:on("player_join", function(event)
    player_data_map[event.player_id] = {}
  end)

  activity:on("player_leave", function(event)
    local player_data = player_data_map[event.player_id]
    player_data_map[event.player_id] = nil

    if player_data.button_index then
      self:release_button(player_data.button_index)
    end
  end)

  activity:on("player_move", function(event)
    -- buttons
    local player_data = player_data_map[event.player_id]
    local old_button_index = player_data.button_index
    player_data.button_index = nil

    for i, button in ipairs(self.buttons) do
      if button.collision.z ~= event.z or not Rectangle.contains_point(button.collision, event) then
        goto continue
      end

      player_data.button_index = i
      self:press_button(event.player_id, i)

      break
      ::continue::
    end

    if old_button_index then
      self:release_button(event.player_id, old_button_index)
    end
  end)
end

---@param object Net.Object
function ButtonsPlugin:register_button(object)
  local button = {
    collision = object,
    press_count = 0,
    visual = Net.get_object_by_id(self.area_id, object.custom_properties.Object)
  }

  self.buttons[#self.buttons + 1] = button
end

---@param callback ButtonsPluginCallback
function ButtonsPlugin:on_state_change(callback)
  table.insert(self.state_listeners, callback)
end

---@private
function ButtonsPlugin:press_button(player_id, button_index)
  local button = self.buttons[button_index]
  button.press_count = button.press_count + 1

  if button.press_count ~= 1 then
    -- ignore anything other than the first press
    return
  end

  -- update visual
  local visual = button.visual

  if visual then
    visual.data.gid = visual.data.gid + 1
    Net.set_object_data(self.area_id, visual.id, visual.data)
  end

  for _, listener in ipairs(self.state_listeners) do
    listener(button, player_id)
  end
end

---@private
function ButtonsPlugin:release_button(player_id, button_index)
  local button = self.buttons[button_index]
  button.press_count = button.press_count - 1

  if button.press_count ~= 0 then
    -- ignore anything other than the last release
    return
  end

  -- update visual
  local visual = button.visual

  if visual then
    visual.data.gid = visual.data.gid - 1
    Net.set_object_data(self.area_id, visual.id, visual.data)
  end

  for _, listener in ipairs(self.state_listeners) do
    listener(button, player_id)
  end
end

return ButtonsPlugin
