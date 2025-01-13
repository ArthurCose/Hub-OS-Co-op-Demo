local Direction = require("scripts/libs/direction")

---@class SpikeyPlugin.Bot
---@field id Net.ActorId
---@field area_id string
---@field dist_limit number
---@field interval number
---@field fire_speed number
---@field fire_texture string
---@field fire_animation string
---@field fire_radius number
---@field elapsed number
---@field disabled? boolean

---@class SpikeyPlugin.BotOptions
---@field bot_id Net.ActorId
---@field fire_interval number in seconds
---@field fire_offset? number in seconds
---@field fire_speed number in tile distance per tick
---@field fire_radius number in tile distance
---@field fire_distance_limit number in tile distance
---@field fire_texture_path string
---@field fire_animation_path string

---@class SpikeyPlugin.FireballBot
---@field id Net.ActorId
---@field parent SpikeyPlugin.Bot
---@field x number
---@field y number
---@field z number
---@field vel_x number
---@field vel_y number
---@field dist number

---@class SpikeyPlugin
---@field private _spikeys SpikeyPlugin.Bot[]
---@field private _fireballs SpikeyPlugin.FireballBot[]
---@field private _ignored_players table<Net.ActorId, boolean>
---@field private _collision_listeners fun(spikey_bot_id: Net.ActorId, fireball_bot_id: Net.ActorId, player_id: Net.ActorId)[]
local SpikeyPlugin = {}

---@param activity Activity
---@return SpikeyPlugin
function SpikeyPlugin:new(activity)
  local plugin = {
    _spikeys = {},
    _fireballs = {},
    _ignored_players = {},
    _collision_listeners = {}
  }
  setmetatable(plugin, self)
  self.__index = self

  plugin:init(activity)

  return plugin
end

---@param options SpikeyPlugin.BotOptions
function SpikeyPlugin:register_bot(options)
  ---@type SpikeyPlugin.Bot
  local bot = {
    id = options.bot_id,
    area_id = Net.get_bot_area(options.bot_id),
    dist_limit = options.fire_distance_limit,
    interval = options.fire_interval,
    fire_speed = options.fire_speed,
    fire_radius = options.fire_radius,
    fire_texture = options.fire_texture_path,
    fire_animation = options.fire_animation_path,
    elapsed = options.fire_offset or 0
  }

  table.insert(self._spikeys, bot)
end

function SpikeyPlugin:ignore_player(player_id)
  self._ignored_players[player_id] = true
end

function SpikeyPlugin:unignore_player(player_id)
  self._ignored_players[player_id] = nil
end

function SpikeyPlugin:enable_bot(bot_id)
  for _, bot in ipairs(self._spikeys) do
    if bot.id == bot_id then
      bot.disabled = nil
      break
    end
  end
end

function SpikeyPlugin:disable_bot(bot_id)
  for _, bot in ipairs(self._spikeys) do
    if bot.id == bot_id then
      bot.disabled = true
      break
    end
  end
end

function SpikeyPlugin:drop_bot(bot_id)
  for i, bot in ipairs(self._spikeys) do
    if bot.id == bot_id then
      table.remove(self._spikeys, i)
      return true
    end
  end
  return false
end

---@param callback fun(spikey_bot_id: Net.ActorId, fireball_bot_id: Net.ActorId, player_id: Net.ActorId)
function SpikeyPlugin:on_fireball_collision(callback)
  table.insert(self._collision_listeners, callback)
end

---@param activity Activity
function SpikeyPlugin:init(activity)
  activity:on("tick", function(event)
    -- spawn fireballs from spikeys
    for _, bot in ipairs(self._spikeys) do
      if bot.disabled then
        goto continue
      end

      local old_elapsed = bot.elapsed
      bot.elapsed = (bot.elapsed + event.delta_time) % bot.interval

      if old_elapsed > bot.elapsed then
        -- create fireball

        local x, y, z = Net.get_bot_position_multi(bot.id)
        local direction = Net.get_bot_direction(bot.id)
        local vec_x, vec_y = Direction.unit_vector_multi(direction)

        x = x + vec_x * 0.5
        y = y + vec_y * 0.5

        local fireball_id = Net.create_bot({
          area_id = bot.area_id,
          texture_path = bot.fire_texture,
          animation_path = bot.fire_animation,
          warp_in = false,
          x = x,
          y = y,
          z = z,
          direction = direction,
        })

        ---@type SpikeyPlugin.FireballBot
        local fireball_bot = {
          id = fireball_id,
          parent = bot,
          x = x,
          y = y,
          z = z,
          vel_x = vec_x * bot.fire_speed,
          vel_y = vec_y * bot.fire_speed,
          dist = 0,
        }

        table.insert(self._fireballs, fireball_bot)
      end

      ::continue::
    end

    -- update fireballs
    for i = #self._fireballs, 1, -1 do
      local bot = self._fireballs[i]

      local radius_sqr = bot.parent.fire_radius * bot.parent.fire_radius

      -- test from the past to account for interpolation / lag
      local test_x = bot.x - bot.vel_x * 2
      local test_y = bot.y - bot.vel_y * 2

      for _, player_id in ipairs(activity:players_in_area(bot.parent.area_id)) do
        if not self._ignored_players[player_id] then
          local player_x, player_y, player_z = Net.get_player_position_multi(player_id)
          local player_diff_x = player_x - test_x
          local player_diff_y = player_y - test_y
          local player_diff_z = player_z - bot.z
          local player_sqr_dist =
              player_diff_x * player_diff_x +
              player_diff_y * player_diff_y +
              player_diff_z * player_diff_z

          if player_sqr_dist < radius_sqr then
            for _, listener in ipairs(self._collision_listeners) do
              listener(bot.parent.id, bot.id, player_id)
            end

            self:remove_fireball(i)

            goto continue
          end
        end
      end

      bot.x = bot.x + bot.vel_x
      bot.y = bot.y + bot.vel_y
      bot.dist = bot.dist + bot.parent.fire_speed

      if bot.dist >= bot.parent.dist_limit then
        self:remove_fireball(i)
        goto continue
      end

      Net.move_bot(bot.id, bot.x, bot.y, bot.z)

      ::continue::
    end
  end)
end

---@private
function SpikeyPlugin:remove_fireball(i)
  Net.remove_bot(self._fireballs[i].id)

  -- swap remove
  local last_index = #self._fireballs
  self._fireballs[i] = self._fireballs[last_index]
  self._fireballs[last_index] = nil
end

return SpikeyPlugin
