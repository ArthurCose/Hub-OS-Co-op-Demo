local Rectangle = require("scripts/libs/rectangle")

local SURPRISED_EMOTE = "EXCLAMATION MARK!"

---@class StaticEncountersPlugin.EncounterOptions
---@field package_path string
---@field area_id string
---@field bounds { x: number, y: number, z: number, width: number, height: number }
---@field shared? boolean

---@class StaticEncountersPlugin.Encounter
---@field package_path string
---@field bounds { x: number, y: number, z: number, width: number, height: number }
---@field shared? boolean
---@field activated boolean
---@field caught_players any[]

---@class StaticEncountersPlugin
---@field private _area_encounters table<string, StaticEncountersPlugin.Encounter[]>
---@field private _caught_players table<Net.ActorId, boolean>
---@field private _results_listeners fun(event)[]
local StaticEncountersPlugin = {}

---@param activity Activity
---@return StaticEncountersPlugin
function StaticEncountersPlugin:new(activity)
  local plugin = {
    _encounters = {},
    _caught_players = {},
    _results_listeners = {}
  }
  setmetatable(plugin, self)
  self.__index = self

  plugin:init(activity)

  return plugin
end

---@param options StaticEncountersPlugin.EncounterOptions
function StaticEncountersPlugin:register_encounter(options)
  local encounters = self._area_encounters[options.area_id]

  if not encounters then
    encounters = {}
    self._area_encounters[options.area_id] = encounters
  end

  table.insert(encounters, {
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
    local already_caught = self._caught_players[event.player_id]
    local area_id = activity:player_area(event.player_id)
    local encounters = self._area_encounters[area_id]

    -- encounters
    if not already_caught and encounters then
      for _, encounter in ipairs(encounters) do
        if encounter.bounds.z ~= event.z or not Rectangle.contains_point(encounter.bounds, event) then
          goto continue
        end

        if not encounter.activated then
          encounter.activated = true

          local delay = 3

          if not encounter.shared then
            self:remove_encounter(area_id, encounter)
            -- reduce wait time
            delay = 1
          end

          Async.sleep(delay).and_then(function()
            self:start_encounter(area_id, encounter)
          end)
        end

        Net.lock_player_input(event.player_id)
        Net.set_player_emote(event.player_id, SURPRISED_EMOTE)
        encounter.caught_players[#encounter.caught_players + 1] = event.player_id

        self._caught_players[event.player_id] = true

        break

        ::continue::
      end
    end
  end)
end

---@private
function StaticEncountersPlugin:remove_encounter(area_id, encounter)
  local encounters = self._area_encounters[area_id]

  for i, other in ipairs(encounters) do
    if encounter == other then
      table.remove(encounters, i)
      break
    end
  end
end

---@param callback fun(event)
function StaticEncountersPlugin:on_results(callback)
  table.insert(self._results_listeners, callback)
end

---@private
---@param encounter StaticEncountersPlugin.Encounter
function StaticEncountersPlugin:start_encounter(area_id, encounter)
  -- remove encounter from list to prevent catching more players
  self:remove_encounter(area_id, encounter)

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
      self._caught_players[event.player_id] = nil

      if not event then
        -- player disconnected
        return
      end

      -- unlock input on completion
      Net.unlock_player_input(event.player_id)

      for _, listener in ipairs(self._results_listeners) do
        listener(event)
      end
    end)
  end
end

return StaticEncountersPlugin
