local ModDownloader = require("scripts/libs/mod_downloader")

local package_ids = {
  -- encounters
  "BattleNetwork3.Enemy.Spikey",
  "BattleNetwork3.Metrid",
  "BattleNetwork4.Gaia",
  "BattleNetwork6.Mettaur",
  -- libraries
  "BattleNetwork.Assets",
  "BattleNetwork.FallingRock",
  "BattleNetwork6.Libraries.CubesAndBoulders",
  "dev.konstinople.library.iterator",
  "dev.konstinople.library.ai",
  "dev.konstinople.library.sliding_obstacle",
  -- statuses
  "BattleNetwork6.Statuses.Cage",
  -- tile states
  "BattleNetwork6.TileStates.Grass",
}

ModDownloader.maintain(package_ids)

-- preload
Net:on("player_connect", function(event)
  Net.provide_package_for_player(event.player_id, ModDownloader.resolve_asset_path("BattleNetwork.Assets"))
end)
