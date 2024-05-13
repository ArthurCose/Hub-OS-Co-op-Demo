---@type IteratorLib
local IteratorLib = require("dev.konstinople.library.iterator")

---A function that returns a new Action on every call, or nil to signify the end
---@alias ActionIterator fun(): Action?

---@class AiPlan
---@field private _weight number
---@field private _usable_after number
---@field private _action_iter_factory fun(): ActionIterator
local AiPlan = {}
AiPlan.__index = AiPlan

---@return AiPlan
function AiPlan.new()
  local plan = {}
  setmetatable(plan, AiPlan)
  return plan
end

---Automatically calls AiPlan:set_action_iter_factory()
---@param action_factory fun(): Action
function AiPlan.new_single_action(action_factory)
  local plan = AiPlan.new()

  plan:set_action_iter_factory(function()
    return IteratorLib.take(1, action_factory)
  end)

  return plan
end

function AiPlan:set_weight(weight)
  self._weight = weight
end

function AiPlan:weight()
  return self._weight or 1
end

---Unlocks the plan to be usable after `roll` rolls
---@param roll number
function AiPlan:set_usable_after(roll)
  self._usable_after = roll
end

function AiPlan:usable_after()
  return self._usable_after or 0
end

---@param iter_factory fun(): ActionIterator a factory function, that returns an ActionIterator
---@see ActionIterator
function AiPlan:set_action_iter_factory(iter_factory)
  self._action_iter_factory = iter_factory
end

function AiPlan:action_iter_factory()
  return self._action_iter_factory
end

---@class Ai
---@field private _entity Entity
---@field private _plans AiPlan[]
---@field private _rolls number
---@field private _action_iter? ActionIterator
---@field private _component Component
local Ai = {}
Ai.__index = Ai

---@param plans AiPlan[]
local function pick_plan(rolls, plans)
  -- resolve total weight
  local combined_weight = 0

  for _, plan in ipairs(plans) do
    if plan:usable_after() <= rolls then
      combined_weight = combined_weight + plan:weight()
    end
  end

  local roll = math.random() * combined_weight

  -- resolve roll
  for _, plan in ipairs(plans) do
    if plan:usable_after() <= rolls then
      roll = roll - plan:weight()

      if roll < 0 then
        return plan
      end
    end
  end

  return plans[#plans]
end

---@return Ai
---@param entity Entity
function Ai.new(entity)
  local ai = {
    _entity = entity,
    _plans = {},
    _rolls = 0
  }
  setmetatable(ai, Ai)

  ai:_create_component()

  return ai
end

function Ai:create_plan()
  local plan = AiPlan.new()
  self:add_plan(plan)
  return plan
end

---@param plan AiPlan
function Ai:add_plan(plan)
  self._plans[#self._plans + 1] = plan
end

function Ai:cancel_plan()
  self._action_iter = nil
end

function Ai:eject()
  self._component:eject()
end

---@private
function Ai:_create_component()
  self._component = self._entity:create_component(Lifetime.Local)

  self._component.on_update_func = function()
    if self._entity:has_actions() then
      return
    end

    local action
    local attempts = 0

    while true do
      while not self._action_iter do
        local plan = pick_plan(self._rolls, self._plans)
        self._rolls = self._rolls + 1

        if not plan then
          -- no plans
          return
        end

        local iter_factory = plan:action_iter_factory()

        if not iter_factory then
          -- no factory
          error("An AiPlan is missing action_iter_factory")
        end

        self._action_iter = iter_factory()

        if not self._action_iter then
          error("An AiPlan's action_iter_factory returned nil")
        end

        attempts = attempts + 1

        if attempts >= 5 then
          error("AI failed to find an action after 5 attempts.")
        end
      end


      action = self._action_iter()

      if action then
        break
      end

      self._action_iter = nil
    end

    ---@diagnostic disable-next-line: param-type-mismatch
    self._entity:queue_action(action)
  end
end

---@class KonstAiLib
local Lib = {
  new_ai = Ai.new,
  new_plan = AiPlan.new,
  new_single_action_plan = AiPlan.new_single_action,
  Ai = Ai,
  AiPlan = AiPlan,
  IteratorLib = IteratorLib,
}

---@param entity Entity
---@param card_props CardProperties
function Lib.create_card_action_factory(entity, card_props)
  return function()
    return Action.from_card(entity, card_props)
  end
end

---@param entity Entity
---@param min_duration number
---@param max_duration number
---@param think_callback? fun(entity: Entity): boolean Return true to end the action early, actions should be queued here to make the most of it.
function Lib.create_idle_action_factory(entity, min_duration, max_duration, think_callback)
  return function()
    local action = Action.new(entity)
    action:set_lockout(ActionLockout.new_sequence())

    local step = action:create_step()

    local duration = math.random(min_duration, max_duration)

    action.on_execute_func = function()
      local component = entity:create_component(Lifetime.Local)

      component.on_update_func = function()
        duration = duration - 1

        local complete_early = false

        if think_callback and not entity:is_inactionable() and not entity:is_immobile() then
          complete_early = think_callback(entity)
        end

        if complete_early or duration <= 0 then
          step:complete_step()
        end
      end

      action.on_action_end_func = function()
        component:eject()
      end
    end

    return action
  end
end

---Used to find good tiles to teleport to before an attack.
---@param entity Entity
---@param tile_suggester fun(entity: Entity, suggest: fun(tile: Tile?)) `suggest()` can be called multiple times to suggest multiple tiles
---@param tile_filter? fun(tile: Tile): boolean If no tile_filter is passed in, it will default to test if the tile passes `entity:can_move_to()`
---@param entity_filter? fun(entity: Entity): boolean If no entity_filter is passed in, it will default to test if the entity is a non team Character
---@return Tile[]
function Lib.find_setup_tiles(entity, tile_suggester, tile_filter, entity_filter)
  local tiles = {}

  if not entity_filter then
    entity_filter = function(other)
      return other:team() ~= entity:team() and Character.from(other) ~= nil and other:hittable()
    end
  end

  if not tile_filter then
    tile_filter = function(tile)
      return entity:can_move_to(tile)
    end
  end

  local suggest = function(tile)
    if tile and tile_filter(tile) then
      tiles[#tiles + 1] = tile
    end
  end

  local find_entity_callback = function(other)
    if entity_filter(other) then
      tile_suggester(other, suggest)
    end

    return false
  end

  local field = entity:field()
  field:find_characters(find_entity_callback)
  field:find_obstacles(find_entity_callback)

  return tiles
end

return Lib
