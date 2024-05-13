local GRASS_HEAL_INTERVAL = 20
local GRASS_SLOWED_HEAL_INTERVAL = 180

---@param custom_state CustomTileState
function tile_state_init(custom_state)
  local field = custom_state:field()
  local tracked_auxprops = {}

  custom_state.on_entity_enter_func = function(self, entity)
    if not Character.from(entity) and not Obstacle.from(entity) then
      return
    end

    if tracked_auxprops[entity:id()] then
      -- already applied
      return
    end

    local double_damage_prop = AuxProp.new()
        :require_hit_element(Element.Fire)
        :increase_hit_damage("DAMAGE")
    entity:add_aux_prop(double_damage_prop)

    local heal_fast_aux_prop = AuxProp.new()
        :require_element(Element.Wood)
        :require_interval(GRASS_HEAL_INTERVAL)
        :require_health(Compare.GE, 9)
        :recover_health(1)
    entity:add_aux_prop(heal_fast_aux_prop)

    local heal_slow_aux_prop = AuxProp.new()
        :require_element(Element.Wood)
        :require_interval(GRASS_SLOWED_HEAL_INTERVAL)
        :require_health(Compare.LT, 9)
        :recover_health(1)
    entity:add_aux_prop(heal_slow_aux_prop)

    tracked_auxprops[entity:id()] = { double_damage_prop, heal_fast_aux_prop, heal_slow_aux_prop }
  end

  custom_state.on_entity_leave_func = function(self, entity)
    local aux_props = tracked_auxprops[entity:id()]

    if not aux_props then
      return
    end

    if entity:current_tile():state() == TileState.Grass then
      -- no need to remove aux props
      return
    end

    for _, aux_prop in ipairs(aux_props) do
      entity:remove_aux_prop(aux_prop)
    end

    tracked_auxprops[entity:id()] = nil
  end

  custom_state.change_request_func = function(self, tile)
    for id in pairs(tracked_auxprops) do
      local entity = field:get_entity(id)

      if not entity then
        tracked_auxprops[id] = nil
        goto continue
      end

      if entity:current_tile() == tile then
        local aux_props = tracked_auxprops[id]

        for _, aux_prop in ipairs(aux_props) do
          entity:remove_aux_prop(aux_prop)
        end

        tracked_auxprops[entity:id()] = nil
      end

      ::continue::
    end

    return true
  end
end
