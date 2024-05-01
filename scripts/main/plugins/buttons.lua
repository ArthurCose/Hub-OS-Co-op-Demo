local Rectangle = require("scripts/libs/rectangle")

---@alias ButtonsPlugin.Callback fun(button: ButtonsPlugin.Button, player_id: Net.ActorId)

---@class ButtonsPlugin.Options
---@field area_id string
---@field collision Net.Object
---@field visual? Net.Object

---@class ButtonsPlugin.Button
---@field collision Net.Object
---@field visual? Net.Object
---@field press_count number

---@class ButtonsPlugin
---@field private _area_buttons table<string, ButtonsPlugin.Button[]>
---@field private _state_listeners ButtonsPlugin.Callback[]
local ButtonsPlugin = {}

---@param activity Activity
---@return ButtonsPlugin
function ButtonsPlugin:new(activity)
  local plugin = {
    _area_buttons = {},
    _state_listeners = {}
  }
  setmetatable(plugin, self)
  self.__index = self

  plugin:init(activity)

  return plugin
end

---@private
---@param activity Activity
function ButtonsPlugin:init(activity)
  local player_presses = {}

  activity:on("player_leave", function(event)
    local button_index = player_presses[event.player_id]
    player_presses[event.player_id] = nil

    if button_index then
      self:release_button(button_index)
    end
  end)

  activity:on("player_move", function(event)
    local area_id = activity:player_area(event.player_id)
    local old_button_index = player_presses[event.player_id]
    player_presses[event.player_id] = nil

    local buttons = self._area_buttons[area_id]

    if buttons then
      for i, button in ipairs(buttons) do
        if button.collision.z ~= event.z or not Rectangle.contains_point(button.collision, event) then
          goto continue
        end

        player_presses[event.player_id] = i
        self:press_button(event.player_id, area_id, i)

        break
        ::continue::
      end
    end

    if old_button_index then
      self:release_button(event.player_id, area_id, old_button_index)
    end
  end)
end

---@param options ButtonsPlugin.Options
function ButtonsPlugin:register_button(options)
  local button = {
    collision = options.collision,
    visual = options.visual,
    press_count = 0,
  }

  local buttons = self._area_buttons[options.area_id]

  if not buttons then
    buttons = {}
    self._area_buttons[options.area_id] = buttons
  end

  table.insert(buttons, button)
end

---@param callback ButtonsPlugin.Callback
function ButtonsPlugin:on_state_change(callback)
  table.insert(self._state_listeners, callback)
end

---@private
function ButtonsPlugin:press_button(player_id, area_id, button_index)
  local button = self._area_buttons[area_id][button_index]
  button.press_count = button.press_count + 1

  if button.press_count ~= 1 then
    -- ignore anything other than the first press
    return
  end

  -- update visual
  local visual = button.visual

  if visual then
    visual.data.gid = visual.data.gid + 1
    Net.set_object_data(area_id, visual.id, visual.data)
  end

  for _, listener in ipairs(self._state_listeners) do
    listener(button, player_id)
  end
end

---@private
function ButtonsPlugin:release_button(player_id, area_id, button_index)
  local button = self._area_buttons[area_id][button_index]
  button.press_count = button.press_count - 1

  if button.press_count ~= 0 then
    -- ignore anything other than the last release
    return
  end

  -- update visual
  local visual = button.visual

  if visual then
    visual.data.gid = visual.data.gid - 1
    Net.set_object_data(area_id, visual.id, visual.data)
  end

  for _, listener in ipairs(self._state_listeners) do
    listener(button, player_id)
  end
end

return ButtonsPlugin
