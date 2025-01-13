local BotPaths = require("scripts/libs/bot_paths")
local LetsGoPlugin = require("scripts/main/plugins/lets_go")
local SpikeyPlugin = require("scripts/main/plugins/spikey")
local ButtonsPlugin = require("scripts/main/plugins/buttons")
local DoorsPlugin = require("scripts/main/plugins/doors")
local RetainDamagePlugin = require("scripts/main/plugins/retain_damage")
local ExplodingEffect = require("scripts/main/utils/exploding_effect")
local Direction = require("scripts/libs/direction")
local Ampstr = require("scripts/libs/ampstr")

local SURPRISED_EMOTE = "EXCLAMATION MARK!"

---@class CoopMission
---@field alive_time number
---@field area_id any
---@field activity Activity
---@field bot_paths BotPaths
---@field lets_go_plugin LetsGoPlugin
---@field spikey_plugin SpikeyPlugin
---@field buttons_plugin ButtonsPlugin
---@field doors_plugin DoorsPlugin
---@field retain_damage_plugin RetainDamagePlugin
---@field spawn_points Net.Object[]
---@field default_encounter_path string
---@field boss_object Net.Object
---@field boss_bot_id any
---@field boss_door Net.Object
---@field boss_buttons_pressed number
---@field boss_ready_points Net.Object[]
---@field ampstr_bot_id any
local CoopMission = {}

---@return CoopMission
function CoopMission:new(activity, base_area_id)
  local area_id = tostring(Net.system_random())
  Net.clone_area(base_area_id, area_id)

  local mission = {
    alive_time = 0,
    area_id = area_id,
    activity = activity,
    bot_paths = BotPaths:new(),
    lets_go_plugin = LetsGoPlugin:new(activity),
    spikey_plugin = SpikeyPlugin:new(activity),
    buttons_plugin = ButtonsPlugin:new(activity),
    doors_plugin = DoorsPlugin:new(),
    retain_damage_plugin = RetainDamagePlugin:new(activity),
    spawn_points = {},
    default_encounter_path = Net.get_area_custom_property(area_id, "Default Encounter"),
    boss_buttons_pressed = 0,
    boss_ready_points = {},
  }
  setmetatable(mission, self)
  self.__index = self

  mission:init(activity)

  return mission
end

---@private
---@param activity Activity
function CoopMission:init(activity)
  local ampstr_message

  local object_ids = Net.list_objects(self.area_id)

  for _, object_id in ipairs(object_ids) do
    local object = Net.get_object_by_id(self.area_id, object_id)

    if object.name == "Spawn" then
      self.spawn_points[#self.spawn_points + 1] = object
    elseif object.name == "Virus" then
      local bot_id = Net.create_bot({
        area_id = self.area_id,
        solid = false,
        warp_in = false,
        texture_path = object.custom_properties["Texture"],
        animation_path = object.custom_properties["Animation"],
        x = object.x,
        y = object.y,
        z = object.z,
      })

      local path = {
        {
          x = object.x,
          y = object.y,
          z = object.z,
        }
      }
      local next_id = tonumber(object.custom_properties["Next"])

      while next_id ~= nil and next_id ~= object.id do
        local next_object = Net.get_object_by_id(self.area_id, next_id)

        path[#path].next = #path + 1
        table.insert(path, {
          x = next_object.x,
          y = next_object.y,
          z = next_object.z
        })
        next_id = tonumber(next_object.custom_properties["Next"])
      end

      path[#path].next = 1

      self.lets_go_plugin:register_bot({
        bot_id = bot_id,
        package_path = self.default_encounter_path,
        radius = 0.45,
        shared = true
      })

      self.bot_paths:init_bot(bot_id, {
        path = path,
        speed = tonumber(object.custom_properties["Speed"])
      })
    elseif object.name == "Spikey" then
      local bot_id = Net.create_bot({
        area_id = self.area_id,
        solid = false,
        warp_in = false,
        texture_path = object.custom_properties["Texture"],
        animation_path = object.custom_properties["Animation"],
        x = object.x,
        y = object.y,
        z = object.z,
        direction = object.custom_properties["Direction"],
      })

      self.lets_go_plugin:register_bot({
        bot_id = bot_id,
        package_path = object.custom_properties["Encounter"] or self.default_encounter_path,
        radius = 0.7,
        shared = true
      })

      self.spikey_plugin:register_bot({
        bot_id = bot_id,
        fire_interval = 1.2,
        fire_offset = tonumber(object.custom_properties["Fire Offset"]),
        fire_speed = 4 / 16,
        fire_radius = 0.5,
        fire_distance_limit = 4.5,
        fire_texture_path = "/server/assets/bots/spikey_fireball.png",
        fire_animation_path = "/server/assets/bots/spikey_fireball.animation"
      })
    elseif object.name == "Button" then
      self.buttons_plugin:register_button({
        area_id = self.area_id,
        collision = object,
        visual = Net.get_object_by_id(self.area_id, object.custom_properties.Object),
      })
    elseif object.name == "Boss Door" then
      self.boss_door = object
    elseif object.name == "Boss Ready" then
      self.boss_ready_points[#self.boss_ready_points + 1] = object
    elseif object.name == "Boss" then
      self.boss_object = object

      self.boss_bot_id = Net.create_bot({
        name = "???",
        area_id = self.area_id,
        x = object.x,
        y = object.y,
        z = object.z,
        texture_path = object.custom_properties["Texture"],
        animation_path = object.custom_properties["Animation"],
        direction = object.custom_properties["Direction"],
        solid = true
      })
    elseif object.name == "Ampstr" then
      self.ampstr_bot_id = Net.create_bot({
        name = "Ampstr",
        area_id = self.area_id,
        x = object.x,
        y = object.y,
        z = object.z,
        texture_path = Ampstr.TEXTURE,
        animation_path = Ampstr.ANIMATION,
        direction = object.custom_properties.Direction,
        solid = true
      })

      ampstr_message = object.custom_properties.Message or "Yippee! Thanks for saving me!"
    end
  end

  self.retain_damage_plugin:on_apply(function(player_id, health)
    if health <= 0 then
      self:delete_player(player_id)
    end
  end)

  -- deal fireball damage
  self.spikey_plugin:on_fireball_collision(function(_, fireball_id, player_id)
    ExplodingEffect:new(fireball_id, { radius = 0, limit = 1 })

    local health = Net.get_player_health(player_id)

    health = math.max(health - 150, 0)

    Net.set_player_health(player_id, health)

    if health == 0 then
      self:delete_player(player_id)
    else
      -- trap the player for a bit
      local _, _, z = Net.get_player_position_multi(player_id)

      Net.animate_player_properties(player_id, {
        {
          properties = { { property = "Z", value = z } },
          duration = 0.2
        }
      })
    end
  end)

  -- pause attacks and movements when viruses are in an encounter
  self.lets_go_plugin:on_collision(function(bot_id, player_id)
    if self.bot_paths:bot_initialized(bot_id) then
      self.bot_paths:pause_path(bot_id)
    end

    self.spikey_plugin:disable_bot(bot_id)
    Net.set_player_emote(player_id, SURPRISED_EMOTE)
  end)

  self.lets_go_plugin:on_encounter_end(function(bot_id)
    if self.bot_paths:bot_initialized(bot_id) then
      self.bot_paths:resume_path(bot_id)
    end

    self.spikey_plugin:enable_bot(bot_id)
  end)

  -- handle encounter results
  self.lets_go_plugin:on_results(function(bot_id, event)
    -- update health + emotion
    Net.set_player_health(event.player_id, event.health)
    Net.set_player_emotion(event.player_id, event.emotion)

    if event.health == 0 then
      -- deleted, kick out to the index
      self:delete_player(event.player_id)
    elseif not event.ran then
      -- victory
      local still_exists = self.lets_go_plugin:drop_bot(bot_id)
      self.bot_paths:drop_bot(bot_id)
      self.spikey_plugin:drop_bot(bot_id)

      if still_exists then
        Async.sleep(1).and_then(function()
          -- explode + delete after 3s
          local effect = ExplodingEffect:new(bot_id)

          Async.sleep(0.7).and_then(function()
            effect:remove()
            Net.remove_bot(bot_id)
          end)
        end)
      end
    end
  end)

  -- handle button presses
  self.buttons_plugin:on_state_change(function(button)
    if button.press_count == 0 then
      self:release_button(button)
    else
      self:press_button(button)
    end
  end)

  -- handle ampstr interaction
  activity:on("actor_interaction", function(event)
    if event.button ~= 0 or event.actor_id ~= self.ampstr_bot_id then
      return
    end

    -- face the player
    local player_position = Net.get_player_position(event.player_id)
    local bot_position = Net.get_bot_position(event.actor_id)
    Net.set_bot_direction(event.actor_id, Direction.diagonal_from_points(bot_position, player_position))

    Ampstr.message_player(event.player_id, ampstr_message)

    local mug = Net.get_player_mugshot(event.player_id)
    Async.message_player(
      event.player_id,
      "I guess this was the data we needed.",
      mug.texture_path,
      mug.animation_path
    ).and_then(function()
      -- return to the index
      Net.transfer_server(event.player_id, "hubos.konstinople.dev", true)
    end)
  end)

  -- setup players
  activity:on("player_join", function(event)
    self:connect(event.player_id)
  end)

  activity:on("player_leave", function()
    if #activity:player_list() == 0 then
      activity:destroy()
    end
  end)

  -- cleanup
  activity:on("activity_destroyed", function()
    self.bot_paths:destroy()

    for _, id in ipairs(Net.list_bots(self.area_id)) do
      Net.remove_bot(id)
    end

    Net.remove_area(self.area_id)
  end)
end

function CoopMission:delete_player(player_id)
  Net.transfer_server(player_id, "hubos.konstinople.dev", true)
end

---@param player_id Net.ActorId
function CoopMission:connect(player_id)
  local point = table.remove(self.spawn_points, 1)

  if not point then
    Net.kick_player(player_id, "Too many players in mission")
    return
  end

  local direction = point.custom_properties.Direction

  Net.transfer_player(player_id, self.area_id, true, point.x, point.y, point.z, direction)
end

local function calculate_walk_time(tile_distance)
  return tile_distance * 0.5
end

local function find_closest_point(points, start)
  local closest_dist = 99999999
  local closest = points[1]

  for _, point in ipairs(points) do
    local dist = math.abs(point.x - start.x) + math.abs(point.y - start.y) + math.abs(point.z - start.z)

    if dist < closest_dist then
      closest_dist = dist
      closest = point
    end
  end

  return closest
end

---@param self CoopMission
CoopMission.animate_boss_intro = Async.create_function(function(self)
  -- collect player ids
  local player_ids = self.activity:player_list()

  -- config
  local slide_duration = 0.25
  local wait_duration = 0.5

  for _, id in ipairs(player_ids) do
    Net.slide_player_camera(id, self.boss_door.x, self.boss_door.y, self.boss_door.z, slide_duration)
  end

  -- delay before opening door
  Async.await(Async.sleep(slide_duration + wait_duration))

  -- just move it far away
  self.doors_plugin:stack_open(self.area_id, self.boss_door.id)

  -- walk to the boss
  local keyframes
  local animation_time = 0

  Net.synchronize(function()
    for i, id in ipairs(player_ids) do
      keyframes = {}
      animation_time = 0

      local start_point = Net.get_player_position(id)
      local end_point = find_closest_point(self.boss_ready_points, start_point)

      local first_axis_property
      local second_axis_property
      local first_axis
      local second_axis

      if math.abs(math.floor(start_point.x) - math.floor(end_point.x)) < math.abs(math.floor(start_point.y) - math.floor(end_point.y)) then
        -- closer to the end on the x axis, we need to move to the door on the x axis
        first_axis = "x"
        first_axis_property = "X"
        second_axis = "y"
        second_axis_property = "Y"
      else
        first_axis = "y"
        first_axis_property = "Y"
        second_axis = "x"
        second_axis_property = "X"
      end

      local first_axis_walk_time = calculate_walk_time(math.abs(self.boss_door[first_axis] - start_point[first_axis]))
      local second_axis_walk_time = calculate_walk_time(math.abs(end_point[second_axis] - start_point[second_axis]))
      local end_walk_time = calculate_walk_time(math.abs(end_point[first_axis] - self.boss_door[first_axis]))

      -- delay
      keyframes[#keyframes + 1] = {
        properties = {
          { property = "X", value = start_point.x, ease = "Linear" },
          { property = "Y", value = start_point.y, ease = "Linear" },
        },
        duration = i * 0.7
      }

      -- walk to door
      keyframes[#keyframes + 1] = {
        properties = {
          { property = first_axis_property,  value = self.boss_door[first_axis], ease = "Linear" },
          -- don't move on second axis
          { property = second_axis_property, value = start_point[second_axis],   ease = "Linear" },
        },
        duration = first_axis_walk_time
      }

      -- walk down bridge
      keyframes[#keyframes + 1] = {
        properties = {
          { property = second_axis_property, value = end_point[second_axis],     ease = "Linear" },
          -- don't move on first axis
          { property = first_axis_property,  value = self.boss_door[first_axis], ease = "Linear" },
        },
        duration = second_axis_walk_time
      }

      -- walk to end point
      keyframes[#keyframes + 1] = {
        properties = {
          { property = first_axis_property,  value = end_point[first_axis],  ease = "Linear" },
          -- don't move on second axis
          { property = second_axis_property, value = end_point[second_axis], ease = "Linear" },
        },
        duration = end_walk_time
      }

      Net.animate_player_properties(id, keyframes)

      for _, keyframe in ipairs(keyframes) do
        animation_time = animation_time + keyframe.duration
      end

      Async.sleep(animation_time + 0.03).and_then(function()
        -- face boss
        Net.animate_player_properties(id, { {
          properties = { { property = "Direction", value = self.boss_object.custom_properties.Direction } },
          duration = 0
        } })
      end)
    end
  end)

  -- reveal the boss and emote
  Async.await(Async.sleep(animation_time * 0.5))

  for _, id in ipairs(player_ids) do
    Net.slide_player_camera(id, self.boss_object.x, self.boss_object.y, self.boss_object.z, slide_duration)
  end

  Net.set_bot_emote(self.boss_bot_id, SURPRISED_EMOTE)

  -- message players
  Async.await(Async.sleep(animation_time * 0.5 + 0.1))

  Net.set_bot_direction(self.boss_bot_id,
    Direction.reverse(string.upper(self.boss_object.custom_properties["Direction"])))

  local intro_message = self.boss_object.custom_properties["Intro Message"]

  if intro_message then
    local message_promises = {}

    for _, id in ipairs(player_ids) do
      message_promises[#message_promises + 1] = Async.message_player(
        id,
        self.boss_object.custom_properties["Intro Message"],
        self.boss_object.custom_properties["Mug Texture"],
        self.boss_object.custom_properties["Mug Animation"]
      )
    end

    -- wait for everyone to read the message before starting the encounter
    Async.await_all(message_promises)
  else
    Async.await(Async.sleep(1))
  end

  local battle_promises = Async.initiate_netplay(
    player_ids,
    self.boss_object.custom_properties.Encounter
  )

  for _, promise in ipairs(battle_promises) do
    promise.and_then(function(event)
      if not event then
        -- player disconnected
        return
      end

      -- unlock input on completion and update health
      Net.unlock_player_input(event.player_id)
      Net.set_player_health(event.player_id, event.health)
      Net.set_player_emotion(event.player_id, event.emotion)

      if event.ran or event.health == 0 then
        -- ran or deleted, kick out to the index
        self:delete_player(event.player_id)
      else
        -- assume victory, remove the boss bot
        Net.remove_bot(self.boss_bot_id, true)
      end
    end)
  end

  -- wait a bit, then unlock cameras
  Async.await(Async.sleep(3))

  for _, id in ipairs(player_ids) do
    Net.unlock_player_camera(id)
  end
end)

function CoopMission:press_button(button)
  local door_id = button.collision.custom_properties.Door

  if door_id then
    self.doors_plugin:stack_open(self.area_id, door_id, self.activity:player_list())
  else
    -- default to the boss door
    self.boss_buttons_pressed = self.boss_buttons_pressed + 1

    if self.boss_buttons_pressed == 2 then
      self:animate_boss_intro()
    end
  end
end

---@param button ButtonsPlugin.Button
function CoopMission:release_button(button)
  -- update connection
  local door_id = button.collision.custom_properties.Door

  if door_id then
    self.doors_plugin:stack_close(self.area_id, door_id)
  elseif self.boss_buttons_pressed ~= 2 then
    -- default to the boss door
    self.boss_buttons_pressed = self.boss_buttons_pressed - 1
  end
end

return CoopMission
