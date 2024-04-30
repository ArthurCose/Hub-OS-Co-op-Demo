---@class Player
---@field activity? Activity
---@field id any
local Player = {}
Player.__index = Player

---@return Player
function Player:new(id)
  local player = {
    id = id
  }

  setmetatable(player, self)
  self.__index = self
  return player
end

function Player:message_with_mug_async(message)
  local mug = Net.get_player_mugshot(self.id)

  return Async.message_player(self.id, message, mug.texture_path, mug.animation_path)
end

---@param activity Activity
function Player:join_activity(activity)
  if self.activity then
    self:leave_activity()
  end

  self.activity = activity
  self.activity:connect(self)
end

function Player:leave_activity()
  if not self.activity then
    return
  end

  self.activity:disconnect(self)
  self.activity = nil
end

return Player
