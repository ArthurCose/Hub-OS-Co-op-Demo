---@alias ActivityEventName "activity_destroyed" | "tick" | "player_join" | "player_leave" | "player_move" | "actor_interaction" | "tile_interaction" | "object_interaction"

---@class Activity
---@field private _player_list Player[]
---@field private _event_emitter any
local Activity = {
  net_event_whitelist = {
    player_move = 1,
    actor_interaction = 1,
    tile_interaction = 1,
    object_interaction = 1,
  }
}

---@return Activity
function Activity:new()
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
---@param player? Player
function Activity:emit(event_name, event, player)
  self._event_emitter:emit(event_name, event, player)
end

---@param event_name ActivityEventName
---@param event_handler fun(event: any, player?: Player)
function Activity:on(event_name, event_handler)
  self._event_emitter:on(event_name, event_handler)
end

---@param player Player
function Activity:connect(player)
  table.insert(self._player_list, player)
  self._event_emitter:emit("player_join", { player_id = player.id }, player)
end

---@param player Player
function Activity:disconnect(player)
  for i, other in ipairs(self._player_list) do
    if player == other then
      table.remove(self._player_list, i)
    end

    self._event_emitter:emit("player_leave", { player_id = player.id }, player)
    break
  end
end

function Activity:player(player_id)
  for _, player in ipairs(self._player_list) do
    if player.id == player_id then
      return player
    end
  end
end

function Activity:player_list()
  return self._player_list
end

function Activity:player_count()
  return #self._player_list
end

function Activity:destroy()
  self._event_emitter:emit("activity_destroyed", {})
end

return Activity
