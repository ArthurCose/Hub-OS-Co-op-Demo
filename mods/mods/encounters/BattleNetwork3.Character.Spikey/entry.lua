function encounter_init(mob)
    local character_package_id = "BattleNetwork3.Character.Spikey"
    --can setup backgrounds, music, and field here
    local test_spawner = mob:create_spawner(character_package_id, Rank.V1)
    test_spawner:spawn_at(4, 1)
    test_spawner = mob:create_spawner(character_package_id, Rank.V2)
    test_spawner:spawn_at(4, 3)
    test_spawner = mob:create_spawner(character_package_id, Rank.V3)
    test_spawner:spawn_at(6, 1)
    test_spawner = mob:create_spawner(character_package_id, Rank.SP)
    test_spawner:spawn_at(6, 3)
end
