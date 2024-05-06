---@param encounter Encounter
function encounter_init(encounter)
  if encounter:player_count() == 2 then
    encounter:spawn_player(0, 2, 1)
    encounter:spawn_player(1, 2, 3)
  end

  local field = encounter:field()

  -- + +
  for x = 0, 6 do
    for y = 1, 3 do
      local add_grass = y == 2 or (x == 2 or x == 5)

      if add_grass then
        local tile = field:tile_at(x, y) --[[@as Tile]]
        tile:set_state(TileState.Grass)
      end
    end
  end

  encounter:create_spawner("BattleNetwork6.CircusMan.Enemy", Rank.SP)
      :spawn_at(5, 2)
end
