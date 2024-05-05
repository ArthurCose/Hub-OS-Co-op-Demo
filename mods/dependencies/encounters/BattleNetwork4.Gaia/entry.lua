function encounter_init(mob)
  mob:create_spawner("BattleNetwork4.Gaia.Enemy", Rank.V1)
      :spawn_at(4, 2)

  mob:create_spawner("BattleNetwork4.Gaia.Enemy", Rank.EX)
      :spawn_at(5, 2)

  mob:create_spawner("BattleNetwork4.Gaia+.Enemy", Rank.V1)
      :spawn_at(4, 1)

  mob:create_spawner("BattleNetwork4.Gaia+.Enemy", Rank.EX)
      :spawn_at(5, 1)

  mob:create_spawner("BattleNetwork4.GaiaMega.Enemy", Rank.V1)
      :spawn_at(4, 3)

  mob:create_spawner("BattleNetwork4.GaiaMega.Enemy", Rank.EX)
      :spawn_at(5, 3)
end
