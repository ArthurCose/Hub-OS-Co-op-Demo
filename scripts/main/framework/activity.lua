---@alias ActivityEventName "activity_destroyed" | "tick" | "player_join" | "player_leave" | "player_avatar_change" | "player_area_transfer" | "player_move" | "actor_interaction" | "tile_interaction" | "object_interaction"

---@class Activity
---@field private _player_list Net.ActorId[]
---@field private _player_area table<Net.ActorId, string>
---@field private _area_players table<string, Net.ActorId[] >
---@field private _event_emitter any
---@field private _destroyed? boolean
---@field private _update_area fun(event)
local Activity = {
  net_event_whitelist = {
    player_area_transfer = 1,
    player_avatar_change = 1,
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
    _player_area = {},
    _area_players = {},
    _event_emitter = Net.EventEmitter.new(),
  }
  setmetatable(activity, self)
  self.__index = self

  activity:_init()

  return activity
end

---@private
function Activity:_init()
  self._update_area = function(event)
    self:_remove_from_area(event.player_id)
    self:_add_to_area(event.player_id, Net.get_player_area(event.player_id))
  end

  Net:on("player_area_transfer", self._update_area)
  Net:on("player_join", self._update_area)
end

---@private
function Activity:_remove_from_area(player_id)
  local old_area = self._player_area[player_id]
  local player_list = self._area_players[old_area]

  if not player_list then
    return
  end

  for i, id in ipairs(player_list) do
    if id == player_id then
      table.remove(player_list, i)
      break
    end
  end
end

---@private
function Activity:_add_to_area(player_id, area_id)
  local player_list = self._area_players[area_id]

  if not player_list then
    player_list = {}
    self._area_players[area_id] = player_list
  end

  table.insert(player_list, player_id)
  self._player_area[player_id] = area_id
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
  self:_add_to_area(player_id, Net.get_player_area(player_id))
  self._event_emitter:emit("player_join", { player_id = player_id })
end

---@param player_id Net.ActorId
function Activity:_disconnect(player_id)
  for i, other in ipairs(self._player_list) do
    if player_id == other then
      table.remove(self._player_list, i)
      self:_remove_from_area(player_id)
      self._player_area[player_id] = nil

      self._event_emitter:emit("player_leave", { player_id = player_id })
      break
    end
  end
end

function Activity:player_list()
  return self._player_list
end

---@param player_id Net.ActorId
function Activity:player_area(player_id)
  return self._player_area[player_id]
end

---@param area_id string
function Activity:players_in_area(area_id)
  local list = self._area_players[area_id]

  if not list then
    list = {}
    self._area_players[area_id] = list
  end

  return list
end

function Activity:destroy()
  if not self._destroyed then
    self._event_emitter:emit("activity_destroyed", {})
    self._destroyed = true
    Net:remove_listener("player_join", self._update_area)
    Net:remove_listener("player_area_transfer", self._update_area)
  end
end

function Activity:destroyed()
  return self._destroyed
end

return Activity
