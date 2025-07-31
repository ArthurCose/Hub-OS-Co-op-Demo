---@param encounter Encounter
function encounter_init(encounter)
  if encounter:player_count() == 2 then
    encounter:spawn_player(0, 2, 1)
    encounter:spawn_player(1, 2, 3)
  end

  -- + +
  for x = 0, 6 do
    for y = 1, 3 do
      local add_grass = y == 2 or (x == 2 or x == 5)

      if add_grass then
        local tile = Field.tile_at(x, y) --[[@as Tile]]
        tile:set_state(TileState.Grass)
      end
    end
  end

  encounter:create_spawner("BattleNetwork6.CircusMan.Enemy", Rank.RV)
      :spawn_at(5, 2)
end
