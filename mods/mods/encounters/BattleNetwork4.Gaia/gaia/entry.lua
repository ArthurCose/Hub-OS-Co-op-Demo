local shared_init = require("../shared/entry.lua")

local V1_PALETTE = Resources.load_texture("v1.palette.png")
local EX_PALETTE = Resources.load_texture("ex.palette.png")

---@param character Entity
function character_init(character)
  ---@type GaiaProps
  local gaia_props = {
    damage = 20,
  }

  character:set_name("Gaia")

  if character:rank() == Rank.EX then
    character:set_palette(EX_PALETTE)
    character:set_health(150)
    gaia_props.damage = 40
    gaia_props.cracks = 1
    gaia_props.root = true
  else
    character:set_palette(V1_PALETTE)
    character:set_health(100)
  end

  shared_init(character, gaia_props)
end
