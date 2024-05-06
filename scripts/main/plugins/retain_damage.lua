---@class RetainDamagePlugin
---@field _listeners fun(player_id: string, health: number)[]
local RetainDamagePlugin = {}

---@param activity Activity
---@return RetainDamagePlugin
function RetainDamagePlugin:new(activity)
  local plugin = {
    _listeners = {}
  }
  setmetatable(plugin, self)
  self.__index = self

  plugin:init(activity)

  return plugin
end

---@param callback fun(player_id: string, health: number)
function RetainDamagePlugin:on_apply(callback)
  table.insert(self._listeners, callback)
end

---@param activity Activity
function RetainDamagePlugin:init(activity)
  local tracked_health = {}

  activity:on("tick", function()
    for _, player_id in ipairs(activity:player_list()) do
      local health_data = tracked_health[player_id]

      local max_health = Net.get_player_max_health(player_id)

      if max_health == 0 then
        -- player probably hasn't shared health data yet
        goto continue
      end

      if not tracked_health[player_id] then
        health_data = {}
        tracked_health[player_id] = health_data
      end

      health_data[1] = Net.get_player_health(player_id)
      health_data[2] = max_health

      ::continue::
    end
  end)

  activity:on("player_leave", function(event)
    tracked_health[event.player_id] = nil
  end)

  activity:on("player_avatar_change", function(event)
    local health_data = tracked_health[event.player_id]

    if not health_data then
      return
    end

    local damage_taken = health_data[2] - health_data[1]
    local health = Net.get_player_health(event.player_id)
    health = health - damage_taken
    health = math.max(health, 0)

    Net.set_player_health(event.player_id, health)

    for _, listener in ipairs(self._listeners) do
      listener(event.player_id, health)
    end
  end)
end

return RetainDamagePlugin
