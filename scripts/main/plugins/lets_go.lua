local Direction = require("scripts/libs/direction")

---@class LetsGoBotOptions
---@field bot_id Net.ActorId
---@field package_path string
---@field radius? number
---@field shared? boolean

---@class LetsGoBot
---@field id Net.ActorId
---@field package_path string
---@field radius? number
---@field shared? boolean
---@field in_encounter? boolean
---@field activated? boolean
---@field caught_players Net.ActorId[]

---@class LetsGoPlugin
---@field private bots LetsGoBot[]
---@field private caught_players table<Net.ActorId, boolean>
---@field private collision_listeners fun(bot_id: Net.ActorId, player_id: Net.ActorId)[]
---@field private results_listeners fun(bot_id: Net.ActorId, event)[]
---@field private start_listeners fun(bot_id: Net.ActorId, players: Net.ActorId[])[]
---@field private end_listeners fun(bot_id: Net.ActorId, players: Net.ActorId[])[]
local LetsGoPlugin = {}

---@param activity Activity
---@return LetsGoPlugin
function LetsGoPlugin:new(activity)
  local plugin = {
    bots = {},
    caught_players = {},
    collision_listeners = {},
    results_listeners = {},
    start_listeners = {},
    end_listeners = {},
  }
  setmetatable(plugin, self)
  self.__index = self

  plugin:init(activity)

  return plugin
end

---@param options LetsGoBotOptions
function LetsGoPlugin:register_bot(options)
  ---@type LetsGoBot
  local bot = {
    id = options.bot_id,
    package_path = options.package_path,
    caught_players = {}
  }

  if options.radius then
    bot.radius = options.radius
  end

  if options.shared then
    bot.shared = options.shared
  end

  table.insert(self.bots, bot)
end

function LetsGoPlugin:remove_bot(bot_id)
  for i, bot in ipairs(self.bots) do
    if bot.id == bot_id then
      table.remove(self.bots, i)
      break
    end
  end
end

---@private
---@param activity Activity
function LetsGoPlugin:init(activity)
  activity:on("tick", function()
    for _, bot in ipairs(self.bots) do
      if bot.in_encounter then
        goto continue_bots
      end

      local position = Net.get_bot_position(bot.id)
      local radius = bot.radius or 0.3
      local radius_sqr = radius * radius

      -- see if a player is range
      for _, player in ipairs(activity:player_list()) do
        if self.caught_players[player.id] then
          goto continue_players
        end

        local player_diff_x = player.x - position.x
        local player_diff_y = player.y - position.y
        local player_diff_z = player.z - position.z
        local player_sqr_dist =
            player_diff_x * player_diff_x +
            player_diff_y * player_diff_y +
            player_diff_z * player_diff_z

        if player_sqr_dist < radius_sqr then
          table.insert(bot.caught_players, player.id)
          self.caught_players[player.id] = true

          Net.lock_player_input(player.id)

          -- face the bot
          local direction = Direction.from_points(player, position)
          Net.animate_player_properties(player.id, { {
            properties = { { property = "Direction", value = direction } }
          } })

          if not bot.activated then
            bot.activated = true

            -- face the player
            Net.set_bot_direction(bot.id, Direction.reverse(direction))

            -- resolve delay before starting the encounter
            local delay = 3

            if not bot.shared then
              -- reduce wait time
              delay = 1
            end

            Async.sleep(delay).and_then(function()
              self:start_encounter(bot)
            end)
          end

          for _, listener in ipairs(self.collision_listeners) do
            listener(bot.id, player.id)
          end

          if not bot.shared then
            bot.in_encounter = true
            goto continue_bots
          end
        end

        ::continue_players::
      end

      ::continue_bots::
    end
  end)
end

---@param callback fun(bot_id: Net.ActorId, player_id: Net.ActorId)
function LetsGoPlugin:on_collision(callback)
  table.insert(self.collision_listeners, callback)
end

---@param callback fun(bot_id: Net.ActorId, event)
function LetsGoPlugin:on_results(callback)
  table.insert(self.results_listeners, callback)
end

---@param callback fun(bot_id: Net.ActorId, players: Net.ActorId[])
function LetsGoPlugin:on_encounter_start(callback)
  table.insert(self.start_listeners, callback)
end

---@param callback fun(bot_id: Net.ActorId, players: Net.ActorId[])
function LetsGoPlugin:on_encounter_end(callback)
  table.insert(self.end_listeners, callback)
end

---@private
---@param bot LetsGoBot
function LetsGoPlugin:start_encounter(bot)
  -- mark the bot as in_encounter prevent catching more players
  bot.in_encounter = true

  for _, player_id in ipairs(bot.caught_players) do
    Net.set_player_emote(player_id, "")
  end

  -- start encounter
  local promises

  if #bot.caught_players == 1 then
    promises = {
      Async.initiate_encounter(
        bot.caught_players[1],
        bot.package_path,
        { player_count = 1 }
      )
    }
  else
    promises = Async.initiate_netplay(
      bot.caught_players,
      bot.package_path,
      { player_count = #bot.caught_players }
    )
  end

  local count = 0

  for _, promise in ipairs(promises) do
    promise.and_then(function(event)
      -- wait a bit before allowing encounters for the player again
      Async.sleep(3).and_then(function()
        self.caught_players[event.player_id] = nil
      end)

      count = count + 1

      if event then
        -- unlock input on completion
        Net.unlock_player_input(event.player_id)

        -- call listeners
        for _, listener in ipairs(self.results_listeners) do
          listener(bot.id, event)
        end
      end

      if count == #promises then
        bot.in_encounter = nil
        bot.activated = nil
        bot.caught_players = {}

        -- call listeners
        for _, listener in ipairs(self.end_listeners) do
          listener(bot.id, bot.caught_players)
        end
      end
    end)
  end

  -- call listeners
  for _, listener in ipairs(self.start_listeners) do
    listener(bot.id, bot.caught_players)
  end
end

return LetsGoPlugin
