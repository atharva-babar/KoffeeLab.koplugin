-- ui/configurator.lua
-- The Configurator category list (TECH_SOLUTION §2.19): the entities recipes and
-- drinks depend on. Each row pushes its own management screen through Nav.
-- Hardware / gesture Back and the titlebar chevron route to `Nav:pop()`.

local Menu = require("ui/widget/menu")
local Placeholder = require("ui/placeholder")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local Configurator = Menu:extend {
  name = "koffeelab_configurator",
  covers_fullscreen = true,
  is_borderless = true,
  is_popout = false,
  is_enable_shortcut = false,
  with_bottom_line = true,
  title_bar_left_icon = "chevron.left",
  title = _("Configurator"),
}

-- module path -> title. Loaded lazily so a broken feature screen cannot stop the
-- Configurator itself from opening.
local CATEGORIES = {
  { title = _("Beans"), module = "ui/config/beans" },
  { title = _("Grinders"), module = "ui/config/grinders" },
  { title = _("Ingredients"), module = "ui/config/ingredients" },
  { title = _("Flavor Tags"), module = "ui/config/flavor_tags" },
  { title = _("Brew Methods"), module = "ui/config/methods" },
  { title = _("Backup & Restore"), module = "ui/backup" },
}

function Configurator:init()
  self.item_table = {}
  for _i, cat in ipairs(CATEGORIES) do -- luacheck: ignore _i
    self.item_table[#self.item_table + 1] = {
      text = cat.title,
      mandatory = "\u{203A}", -- ›
      _cat = cat,
    }
  end
  Menu.init(self)
end

function Configurator:onMenuChoice(item)
  local cat = item._cat
  if cat.placeholder then
    self.nav:push(Placeholder:new { title = cat.title, message = cat.placeholder })
    return true
  end
  local screen = require(cat.module):new {}
  self.nav:push(screen)
  return true
end

function Configurator:_back()
  if self.nav then
    self.nav:pop()
  else
    UIManager:close(self)
  end
  return true
end

Configurator.onClose = Configurator._back
Configurator.onLeftButtonTap = Configurator._back

return Configurator
