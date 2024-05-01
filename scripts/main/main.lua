math.randomseed()

local Player = require("scripts/main/player")
local CoopMission = require("scripts/main/coop-mission")
local Activity = require("scripts/main/activity")
local URI = require("scripts/libs/schemeless-uri")

---@type table<any, Player>
local players = {}
---@type Activity[]
local activities = {}
---@type table<any, Activity>
local activity_code_map = {}

-- tick and clean up activities
Net:on("tick", function(event)
  local pending_removal = {}

  for i, activity in ipairs(activities) do
    if activity:player_count() == 0 then
      pending_removal[#pending_removal + 1] = i
    end

    activity:emit("tick", event)
  end

  for i = #pending_removal, 1, -1 do
    local index = pending_removal[i]
    activities[index]:destroy()

    -- swap remove
    activities[index] = activities[#activities]
    activities[#activities] = nil
  end
end)

-- route events associated with players to activities
Net:on_any(function(event_name, event)
  if not event.player_id or not Activity.net_event_whitelist[event_name] then
    -- not specific to players, or not whitelisted
    return
  end

  -- pass the event to the relevant activity
  local player = players[event.player_id]

  if not player then
    -- player removed or never loaded
    return
  end

  if not player.activity then
    -- player isn't in an activity
    return
  end

  if event_name == "player_join" then
    local position = Net.get_player_position(player.id)
    player.x = position.x
    player.y = position.y
    player.z = position.z
  end

  player.activity:emit(event_name, event, player)

  if event_name == "player_move" then
    player.x = event.x
    player.y = event.y
    player.z = event.z
  end
end)

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

  -- create player
  local player = Player:new(event.player_id)
  players[event.player_id] = player

  -- find or create activity
  local activity = activity_code_map[code]

  if not activity then
    -- create activity
    activity = Activity:new()
    activity:on("activity_destroyed", function()
      activity_code_map[code] = nil
    end)

    CoopMission:new(activity, "default")

    activities[#activities + 1] = activity
    activity_code_map[code] = activity
  end

  player:join_activity(activity)
end)

Net:on("player_disconnect", function(event)
  local player = players[event.player_id]
  players[event.player_id] = nil

  if player then
    player:leave_activity()
  end
end)
