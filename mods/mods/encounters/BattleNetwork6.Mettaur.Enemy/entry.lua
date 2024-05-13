local package_id = "BattleNetwork6.Mettaur.Enemy"

function encounter_init(mob)
    --can setup backgrounds, music, and field here
    local test_spawner = mob:create_spawner(package_id, Rank.V1)
    test_spawner:spawn_at(4, 1)

    test_spawner = mob:create_spawner(package_id, Rank.V2)
    test_spawner:spawn_at(5, 2)

    test_spawner = mob:create_spawner(package_id, Rank.V3)
    test_spawner:spawn_at(6, 3)
end
