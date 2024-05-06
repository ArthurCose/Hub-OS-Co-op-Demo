---@param encounter Encounter
function encounter_init(encounter)
  encounter:create_spawner("BattleNetwork6.CircusMan.Enemy", Rank.V1)
      :spawn_at(5, 2)
end
