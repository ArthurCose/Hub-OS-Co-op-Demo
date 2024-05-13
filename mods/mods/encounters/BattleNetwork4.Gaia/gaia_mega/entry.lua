local shared_init = require("../shared/entry.lua")

local V1_PALETTE = Resources.load_texture("v1.palette.png")
local EX_PALETTE = Resources.load_texture("ex.palette.png")

---@param character Entity
function character_init(character)
  ---@type GaiaProps
  local gaia_props = {
    damage = 150,
    cracks = 3,
    root = true
  }

  character:set_name("GaiaMega")

  if character:rank() == Rank.EX then
    character:set_palette(EX_PALETTE)
    character:set_health(380)
    gaia_props.damage = 200
  else
    character:set_palette(V1_PALETTE)
    character:set_health(320)
  end

  shared_init(character, gaia_props)
end
