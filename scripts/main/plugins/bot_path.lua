local Direction = require("scripts/libs/direction")

---@class BotPathOptions
---@field bot_id ActorId
---@field path TilePosition[]
---@field speed? number
---@field players_block_movement? boolean
---@field radius? number

---@class BotPathBot
---@field id ActorId
---@field path TilePosition[]
---@field path_index number
---@field x number
---@field y number
---@field z number
---@field speed? number
---@field disabled? boolean
---@field players_block_movement? boolean
---@field radius? number

---@class BotPathPlugin
---@field private bots BotPathBot[]
---@field private ignored_players table<ActorId, boolean>
local BotPathPlugin = {}

---@param activity Activity
---@return BotPathPlugin
function BotPathPlugin:new(activity)
  local plugin = {
    bots = {},
    ignored_players = {}
  }
  setmetatable(plugin, self)
  self.__index = self

  plugin:init(activity)

  return plugin
end

---@param options BotPathOptions
function BotPathPlugin:register_bot(options)
  local position = Net.get_bot_position(options.bot_id)

  ---@type BotPathBot
  local bot = {
    id = options.bot_id,
    path = options.path,
    path_index = 2,
    x = position.x,
    y = position.y,
    z = position.z,
    speed = options.speed,
  }

  if options.players_block_movement then
    bot.players_block_movement = true
  end

  if options.radius then
    bot.radius = options.radius
  end

  table.insert(self.bots, bot)
end

function BotPathPlugin:ignore_player(player_id)
  self.ignored_players[player_id] = true
end

function BotPathPlugin:unignore_player(player_id)
  self.ignored_players[player_id] = nil
end

function BotPathPlugin:enable_bot(bot_id)
  for _, bot in ipairs(self.bots) do
    if bot.id == bot_id then
      bot.disabled = nil
      break
    end
  end
end

function BotPathPlugin:disable_bot(bot_id)
  for _, bot in ipairs(self.bots) do
    if bot.id == bot_id then
      bot.disabled = true
      break
    end
  end
end

function BotPathPlugin:remove_bot(bot_id)
  for i, bot in ipairs(self.bots) do
    if bot.id == bot_id then
      table.remove(self.bots, i)
      break
    end
  end
end

---@private
---@param activity Activity
function BotPathPlugin:init(activity)
  activity:on("tick", function()
    for _, bot in ipairs(self.bots) do
      if bot.disabled then
        goto continue
      end

      if bot.players_block_movement then
        local radius = bot.radius or 0.3
        local radius_sqr = radius * radius

        -- see if a player is in the way
        for _, player in ipairs(activity:player_list()) do
          if not self.ignored_players[player.id] then
            local player_diff_x = player.x - bot.x
            local player_diff_y = player.y - bot.y
            local player_diff_z = player.z - bot.z
            local player_sqr_dist =
                player_diff_x * player_diff_x +
                player_diff_y * player_diff_y +
                player_diff_z * player_diff_z

            if player_sqr_dist < radius_sqr then
              -- block movement
              goto continue
            end
          end
        end
      end

      local target_point = bot.path[bot.path_index]
      local diff_x = target_point.x - bot.x
      local diff_y = target_point.y - bot.y
      local diff_z = target_point.z - bot.z
      local speed = bot.speed or (1 / 16)

      local direction = Direction.diagonal_from_offset(diff_x, diff_y)

      local movement = Direction.unit_vector(direction)

      if diff_z < 0 then
        movement.z = -1
      elseif diff_z > 0 then
        movement.z = 1
      else
        movement.z = 0
      end

      bot.x = bot.x + movement.x * speed
      bot.y = bot.y + movement.y * speed
      bot.z = bot.z + movement.z * speed

      if diff_x * diff_x + diff_y * diff_y + diff_z * diff_z < speed * speed * 2 then
        -- reached point, snap to it, and pick next target
        bot.path_index = (bot.path_index % #bot.path) + 1
        bot.x = target_point.x
        bot.y = target_point.y
        bot.z = target_point.z
      end

      Net.move_bot(bot.id, bot.x, bot.y, bot.z)

      ::continue::
    end
  end)
end

return BotPathPlugin
