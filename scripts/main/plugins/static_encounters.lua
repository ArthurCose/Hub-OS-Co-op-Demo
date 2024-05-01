local Rectangle = require("scripts/libs/rectangle")

local SURPRISED_EMOTE = "EXCLAMATION MARK!"

---@class StaticEncounterOptions
---@field package_path string
---@field bounds { x: number, y: number, z: number, width: number, height: number }
---@field shared? boolean

---@class StaticEncounter
---@field package_path string
---@field bounds { x: number, y: number, z: number, width: number, height: number }
---@field shared? boolean
---@field activated boolean
---@field caught_players any[]

---@class StaticEncountersPlugin
---@field private encounters StaticEncounter[]
---@field private caught_players table<Net.ActorId, boolean>
---@field private results_listeners fun(event)[]
local StaticEncountersPlugin = {}

---@param activity Activity
---@return StaticEncountersPlugin
function StaticEncountersPlugin:new(activity)
  local plugin = {
    encounters = {},
    caught_players = {},
    results_listeners = {}
  }
  setmetatable(plugin, self)
  self.__index = self

  plugin:init(activity)

  return plugin
end

---@param options StaticEncounterOptions
function StaticEncountersPlugin:register_encounter(options)
  table.insert(self.encounters, {
    package_path = options.package_path,
    bounds = options.bounds,
    shared = options.shared,
    caught_players = {},
    activated = false
  })
end

---@private
---@param activity Activity
function StaticEncountersPlugin:init(activity)
  activity:on("player_move", function(event)
    local already_caught = self.caught_players[event.player_id]

    -- encounters
    if not already_caught then
      for _, encounter in ipairs(self.encounters) do
        if encounter.bounds.z ~= event.z or not Rectangle.contains_point(encounter.bounds, event) then
          goto continue
        end

        if not encounter.activated then
          encounter.activated = true

          local delay = 3

          if not encounter.shared then
            self:remove_encounter(encounter)
            -- reduce wait time
            delay = 1
          end

          Async.sleep(delay).and_then(function()
            self:start_encounter(encounter)
          end)
        end

        Net.lock_player_input(event.player_id)
        Net.set_player_emote(event.player_id, SURPRISED_EMOTE)
        encounter.caught_players[#encounter.caught_players + 1] = event.player_id

        self.caught_players[event.player_id] = true

        break

        ::continue::
      end
    end
  end)
end

---@private
function StaticEncountersPlugin:remove_encounter(encounter)
  for i, other in ipairs(self.encounters) do
    if encounter == other then
      table.remove(self.encounters, i)
      break
    end
  end
end

---@param callback fun(event)
function StaticEncountersPlugin:on_results(callback)
  table.insert(self.results_listeners, callback)
end

---@private
---@param encounter StaticEncounter
function StaticEncountersPlugin:start_encounter(encounter)
  -- remove encounter from list to prevent catching more players
  self:remove_encounter(encounter)

  -- start encounter
  local promises

  if #encounter.caught_players == 1 then
    promises = {
      Async.initiate_encounter(
        encounter.caught_players[1],
        encounter.package_path,
        { player_count = 1 }
      )
    }
  else
    promises = Async.initiate_netplay(
      encounter.caught_players,
      encounter.package_path,
      { player_count = #encounter.caught_players }
    )
  end

  for _, promise in ipairs(promises) do
    promise.and_then(function(event)
      -- unmark player as in encounter
      self.caught_players[event.player_id] = nil

      if not event then
        -- player disconnected
        return
      end

      -- unlock input on completion
      Net.unlock_player_input(event.player_id)

      for _, listener in ipairs(self.results_listeners) do
        listener(event)
      end
    end)
  end
end

return StaticEncountersPlugin
