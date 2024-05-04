local SPIKEY_ID = "BattleNetwork3.Character.Spikey"

function encounter_init(encounter)
  if encounter:player_count() == 2 then
    encounter:spawn_player(0, 2, 1)
    encounter:spawn_player(1, 2, 3)
  end

  local field = encounter:field()

  if math.random(2) == 1 then
    -- bolt
    for y = 1, 3 do
      local x_end = 4

      if y == 2 then
        x_end = 5
      end

      for x = 2, x_end do
        local tile = field:tile_at(x, y)
        if y == 3 then
          tile = field:tile_at(x + 1, y)
        end
        tile:set_state(TileState.Grass)
      end
    end

    encounter:create_spawner(SPIKEY_ID, Rank.V3)
        :spawn_at(4, 1)
    encounter:create_spawner(SPIKEY_ID, Rank.V3)
        :spawn_at(5, 3)
  else
    -- slash
    for x = 0, 3 do
      for y = 1, 3 do
        local tile = field:tile_at(x + y, y)
        tile:set_state(TileState.Grass)
      end
    end

    encounter:create_spawner(SPIKEY_ID, Rank.V2)
        :spawn_at(5, 1)
    encounter:create_spawner(SPIKEY_ID, Rank.V3)
        :spawn_at(4, 2)
    encounter:create_spawner(SPIKEY_ID, Rank.V2)
        :spawn_at(5, 3)
  end
end
