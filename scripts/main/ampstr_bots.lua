math.randomseed()

local Direction = require("scripts/libs/direction")
local Ampstr = require("scripts/libs/ampstr")

---@class AmpstrBotData
---@field conversation_count number
---@field message string

---@type table<string, AmpstrBotData>
local bots = {}

Net:on("actor_interaction", function(event)
  local bot_data = bots[event.actor_id]

  if event.button ~= 0 or not bot_data then
    return
  end

  -- face the player
  local player_position = Net.get_player_position(event.player_id)
  local bot_position = Net.get_bot_position(event.actor_id)
  Net.set_bot_direction(event.actor_id, Direction.diagonal_from_points(bot_position, player_position))

  if Ampstr.serious(event.player_id) then
    return
  end

  -- start conversation
  Ampstr.message_player(event.player_id, bot_data.message)
end)

return {
  create_bot_from_object = function(area_id, object)
    ---@type AmpstrBotData
    local bot_data = {
      conversation_count = 0,
      message = object.custom_properties.Message,
    }

    local bot_id = Net.create_bot({
      name = "Ampstr",
      area_id = area_id,
      x = object.x,
      y = object.y,
      z = object.z,
      texture_path = Ampstr.TEXTURE,
      animation_path = Ampstr.ANIMATION,
      direction = object.custom_properties.Direction,
      solid = true
    })

    bots[bot_id] = bot_data

    return bot_id
  end,
  delete_bot = function(bot_id)
    Net.remove_bot(bot_id)
    bots[bot_id] = nil
  end
}
