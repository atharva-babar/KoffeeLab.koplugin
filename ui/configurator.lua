-- ui/configurator.lua
-- The Configurator category list (TECH_SOLUTION §2.19): the entities recipes and
-- drinks depend on. Each row pushes its own management screen through Nav.

local Nav = require("ui/nav")
local ScreenList = require("ui/screen_list")
local _ = require("gettext")

local Configurator = ScreenList:extend {
  name = "koffeelab_configurator",
  title = _("Configurator"),
  navbar = "configurator",
}

-- module path -> title, loaded lazily so a broken feature screen cannot stop the
-- Configurator itself from opening.
local CATEGORIES = {
  { title = _("Beans"), module = "ui/config/beans" },
  { title = _("Grinders"), module = "ui/config/grinders" },
  { title = _("Ingredients"), module = "ui/config/ingredients" },
  { title = _("Flavor Tags"), module = "ui/config/flavor_tags" },
  { title = _("Backup & Restore"), module = "ui/backup" },
}

function Configurator:buildItems()
  local items = {}
  for _i, cat in ipairs(CATEGORIES) do -- luacheck: ignore _i
    items[#items + 1] = {
      text = cat.title,
      mandatory = "\u{203A}", -- ›
      _cat = cat,
      callback = function()
        Nav:push(require(cat.module):new {})
      end,
    }
  end
  return items
end

return Configurator
