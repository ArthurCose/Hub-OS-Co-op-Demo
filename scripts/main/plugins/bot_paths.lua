local BotPaths = require("scripts/libs/bot_paths")

---@class BotPathsPlugin: BotPaths
local BotPathsPlugin = {}

---@param activity Activity
function BotPathsPlugin:new(activity)
  local paths = BotPaths:new()

  activity:on("activity_destroyed", function()
    paths:destroy()
  end)

  return paths
end

return BotPathsPlugin
