local Activity = require("scripts/main/framework/activity")

---@class ActivityManager
---@field private _tracking table<any, Activity>
---@field private _activities Activity[]
---@field private _default_activity Activity
local ActivityManager = {
  _tracking = {},
  _activities = {},
}
ActivityManager.__index = ActivityManager
setmetatable(ActivityManager, ActivityManager)

function ActivityManager:create_activity()
  local activity = Activity:_new()
  table.insert(self._activities, activity)
  return activity
end

---@param player_id Net.ActorId
---@param activity Activity
function ActivityManager:join_activity(player_id, activity)
  local previous_activity = self._tracking[player_id]

  if previous_activity then
    previous_activity:_disconnect(player_id)
  end

  self._tracking[player_id] = activity
  activity:_connect(player_id)
end

---@private
function ActivityManager:_init()
  self._default_activity = self:create_activity()

  -- tick and clean up activities
  Net:on("tick", function(event)
    local pending_removal = {}

    for i, activity in ipairs(self._activities) do
      if activity:destroyed() then
        pending_removal[#pending_removal + 1] = i
      else
        activity:emit("tick", event)
      end
    end

    for i = #pending_removal, 1, -1 do
      local index = pending_removal[i]
      self._activities[index]:destroy()

      -- swap remove
      self._activities[index] = self._activities[#self._activities]
      self._activities[#self._activities] = nil
    end
  end)

  -- route events associated with players to activities
  Net:on_any(function(event_name, event)
    if not event.player_id or not Activity.net_event_whitelist[event_name] then
      -- not specific to players, or not whitelisted
      return
    end

    -- pass the event to the relevant activity
    local activity = self._tracking[event.player_id]

    if not activity then
      -- player removed or never loaded
      return
    end

    activity:emit(event_name, event)
  end)

  Net:on("player_request", function(event)
    -- start tracking activities
    self._tracking[event.player_id] = self._default_activity
  end)

  Net:on("player_disconnect", function(event)
    -- delete tracking
    local activity = self._tracking[event.player_id]
    self._tracking[event.player_id] = nil

    activity:_disconnect(event.player_id)
  end)
end

ActivityManager:_init()

return ActivityManager
