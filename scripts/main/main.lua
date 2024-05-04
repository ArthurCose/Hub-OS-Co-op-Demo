math.randomseed()

local CoopMission = require("scripts/main/coop-mission")
local ActivityManager = require("scripts/main/framework/activity_manager")
local URI = require("scripts/libs/schemeless-uri")

---@type table<any, Activity>
local activity_code_map = {}

Net:on("player_request", function(event)
  local data = event.data

  if string.sub(data, 1, 1) == '?' then
    data = string.sub(data, 2)
  end

  local query = URI.parse_query(data)
  local code = query.code

  if not code then
    -- kick player
    Net.kick_player(event.player_id, "missing activity code")
    return
  end

  -- find or create activity
  local activity = activity_code_map[code]

  if not activity then
    -- create activity
    activity = ActivityManager:create_activity()
    activity:on("activity_destroyed", function()
      activity_code_map[code] = nil
    end)

    CoopMission:new(activity, "default")

    activity_code_map[code] = activity
  end

  ActivityManager:join_activity(event.player_id, activity)
end)

Net:on("player_connect", function(event)
  -- preload package on the client
  Net.provide_package_for_player(event.player_id, "/server/mods/circus/spikey")
end)
