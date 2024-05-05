local GAIA_ID = "BattleNetwork4.Gaia.Enemy"
local METTAUR_ID = "BattleNetwork6.Mettaur.Enemy"
local METRID_ID = "BattleNetwork3.Metrid.Enemy"

---@class BattleNetwork6.CubesAndBouldersLib
local CubesAndBoulders = require("BattleNetwork6.Libraries.CubesAndBoulders")
local Boulder = CubesAndBoulders.new_boulder()

---@param encounter Encounter
function encounter_init(encounter)
  if encounter:player_count() == 2 then
    encounter:spawn_player(0, 2, 1)
    encounter:spawn_player(1, 2, 3)
  end

  local field = encounter:field()

  local layouts = {
    function()
      -- wide bolt
      for y = 1, 3 do
        for x = 1, 6 do
          local add_grass =
              not ((y == 1 and x == 1)) and
              not ((y == 3 and x == 6))

          if add_grass then
            local tile = field:tile_at(x, y)
            tile:set_state(TileState.Grass)
          end
        end
      end

      field:spawn(Boulder:create_obstacle(), 1, 3)
      field:spawn(Boulder:create_obstacle(), 5, 2)

      encounter:create_spawner(METTAUR_ID, Rank.V3)
          :spawn_at(4, 2)
      encounter:create_spawner(METRID_ID, Rank.V1)
          :spawn_at(6, 1)
    end,
    function()
      -- oval
      for x = 0, 6 do
        for y = 1, 3 do
          local add_grass =
              not ((y == 1 or y == 3) and (x == 1 or x == 6))

          if add_grass then
            local tile = field:tile_at(x, y)
            tile:set_state(TileState.Grass)
          end
        end
      end

      encounter:create_spawner(METTAUR_ID, Rank.V3)
          :spawn_at(4, 2)
      encounter:create_spawner(METTAUR_ID, Rank.V2)
          :spawn_at(5, 3)
      encounter:create_spawner(METTAUR_ID, Rank.V3)
          :spawn_at(6, 1)
    end,
    function()
      -- full
      for x = 1, 6 do
        for y = 1, 3 do
          local tile = field:tile_at(x, y)
          tile:set_state(TileState.Grass)
        end
      end

      field:spawn(Boulder:create_obstacle(), 5, 3)
      field:spawn(Boulder:create_obstacle(), 1, 2)

      encounter:create_spawner(METTAUR_ID, Rank.V3)
          :spawn_at(4, 2)
      encounter:create_spawner(METTAUR_ID, Rank.V3)
          :spawn_at(6, 3)
      encounter:create_spawner(METRID_ID, Rank.V1)
          :spawn_at(6, 1)
    end,
    function()
      -- >
      for x = 0, 6 do
        for y = 1, 3 do
          local add_grass =
              not ((y == 1 or y == 3) and x == 6) and
              not (y == 2 and x == 1)

          if add_grass then
            local tile = field:tile_at(x, y)
            tile:set_state(TileState.Grass)
          end
        end
      end

      field:spawn(Boulder:create_obstacle(), 3, 2)
      field:spawn(Boulder:create_obstacle(), 5, 1)

      encounter:create_spawner(GAIA_ID, Rank.EX)
          :spawn_at(4, 3)
      encounter:create_spawner(METRID_ID, Rank.V1)
          :spawn_at(6, 2)
    end
  }

  layouts[math.random(#layouts)]()
end
