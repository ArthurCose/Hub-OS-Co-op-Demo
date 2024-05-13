---@type SlidingObstacleLib
local SlidingObstacleLib = require("dev.konstinople.library.sliding_obstacle")
---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

---@class BattleNetwork6.Libraries.CubesAndBoulders
local Lib = {}

local HIT_TEXTURE = bn_assets.load_texture("bn6_hit_effects.png")
local HIT_ANIMATION_PATH = bn_assets.fetch_animation_path("bn6_hit_effects.animation")
local ROCK_DEBRIS_TEXTURE = bn_assets.load_texture("rock_debris_bn6.png")
local ROCK_DEBRIS_ANIMATION_PATH = bn_assets.fetch_animation_path("rock_debris_bn6.animation")

local PARTICLE_ACC = 1

local function spawn_rock_particle(parent, remaining_time)
  local field = parent:field()
  local position = parent:movement_offset()
  position.y = position.y - parent:height() / 2

  local artifact = Artifact.new()
  artifact:set_offset(position.x, position.y)
  artifact:set_texture(ROCK_DEBRIS_TEXTURE)
  artifact:sprite():set_layer(-2)


  local animation = artifact:animation()
  animation:load(ROCK_DEBRIS_ANIMATION_PATH)

  if math.random(2) == 1 then
    animation:set_state("LEFT")
  else
    animation:set_state("RIGHT")
  end

  local vel_x = math.random() * 4 - 2
  local vel_y = math.random(-10, -5)

  artifact.on_update_func = function()
    position.x = position.x + vel_x
    position.y = position.y + vel_y
    vel_y = vel_y + PARTICLE_ACC

    artifact:set_offset(position.x, position.y)

    remaining_time = remaining_time - 1

    if remaining_time <= 0 then
      artifact:erase()
      local poof = bn_assets.ParticlePoof.new("SMALL")
      poof:set_offset(position.x, position.y)
      poof:sprite():set_layer(-2)
      field:spawn(poof, artifact:current_tile())
    end
  end

  field:spawn(artifact, parent:current_tile())
end

local function shatter_rock(entity)
  entity:erase()

  local poof = bn_assets.ParticlePoof.new()
  local offset = entity:movement_offset()
  poof:set_offset(offset.x, offset.y - entity:height() / 2)
  poof:sprite():set_layer(-2)
  entity:field():spawn(poof, entity:current_tile())

  spawn_rock_particle(entity, 20)
  spawn_rock_particle(entity, 15)
end

local function shatter_ice(entity)
  entity:erase()

  local poof = bn_assets.ParticlePoof.new()
  local offset = entity:movement_offset()
  poof:set_offset(offset.x, offset.y - entity:height() / 2)
  poof:sprite():set_layer(-2)
  entity:field():spawn(poof, entity:current_tile())
end

function Lib.new_ice_cube()
  local IceCube = SlidingObstacleLib.new_cube()
  IceCube:set_texture(bn_assets.load_texture("cube_bn6.png"))
  IceCube:set_animation_path(bn_assets.fetch_animation_path("cube_bn6.animation"))
  IceCube:set_animation_state("ICE")
  IceCube:set_collision_texture(HIT_TEXTURE)
  IceCube:set_collision_animation_path(HIT_ANIMATION_PATH)
  IceCube:set_collision_animation_state("AQUA")
  IceCube:set_element(Element.Aqua)
  IceCube:set_health(60)
  IceCube:set_duration(6000)
  IceCube:set_delete_func(shatter_ice)

  return IceCube
end

function Lib.new_rock_cube()
  local RockCube = SlidingObstacleLib.new_cube()
  RockCube:set_texture(bn_assets.load_texture("cube_bn6.png"))
  RockCube:set_animation_path(bn_assets.fetch_animation_path("cube_bn6.animation"))
  RockCube:set_animation_state("ROCK")
  RockCube:set_collision_texture(HIT_TEXTURE)
  RockCube:set_collision_animation_path(HIT_ANIMATION_PATH)
  RockCube:set_collision_animation_state("BREAKING")
  RockCube:set_duration(6000)
  RockCube:set_delete_func(shatter_rock)

  return RockCube
end

function Lib.new_boulder()
  local Boulder = SlidingObstacleLib.new_boulder()
  Boulder:set_texture(bn_assets.load_texture("boulder_bn6.png"))
  Boulder:set_animation_path(bn_assets.fetch_animation_path("boulder_bn6.animation"))
  Boulder:set_collision_texture(HIT_TEXTURE)
  Boulder:set_collision_animation_path(HIT_ANIMATION_PATH)
  Boulder:set_collision_animation_state("BREAKING")
  Boulder:set_delete_func(shatter_rock)

  return Boulder
end

return Lib
