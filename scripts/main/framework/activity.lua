---@alias ActivityEventName "activity_destroyed" | "tick" | "player_join" | "player_leave" | "player_move" | "actor_interaction" | "tile_interaction" | "object_interaction"

---@class Activity
---@field private _player_list Net.ActorId[]
---@field private _event_emitter any
---@field private _destroyed? boolean
local Activity = {
  net_event_whitelist = {
    player_move = 1,
    actor_interaction = 1,
    tile_interaction = 1,
    object_interaction = 1,
  }
}

---Internal usage only, use `ActivityManager:create_activity()` instead.
---@return Activity
function Activity:_new()
  local activity = {
    _player_list = {},
    _event_emitter = Net.EventEmitter.new(),
  }
  setmetatable(activity, self)
  self.__index = self

  return activity
end

---@param event_name ActivityEventName
---@param event any
function Activity:emit(event_name, event)
  self._event_emitter:emit(event_name, event)
end

---@param event_name ActivityEventName
---@param event_handler fun(event: any)
function Activity:on(event_name, event_handler)
  self._event_emitter:on(event_name, event_handler)
end

---@param player_id Net.ActorId
function Activity:_connect(player_id)
  table.insert(self._player_list, player_id)
  self._event_emitter:emit("player_join", { player_id = player_id })
end

---@param player_id Net.ActorId
function Activity:_disconnect(player_id)
  for i, other in ipairs(self._player_list) do
    if player_id == other then
      table.remove(self._player_list, i)

      self._event_emitter:emit("player_leave", { player_id = player_id })
      break
    end
  end
end

function Activity:player_list()
  return self._player_list
end

function Activity:destroy()
  if not self._destroyed then
    self._event_emitter:emit("activity_destroyed", {})
    self._destroyed = true
  end
end

function Activity:destroyed()
  return self._destroyed
end

return Activity
