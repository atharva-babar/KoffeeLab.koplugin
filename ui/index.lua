-- ui/index.lua
-- Index root (TECH_SOLUTION §2.14): two choices — the base coffee recipes and the
-- custom drinks. Each row pushes its own filtered/sortable index screen through
-- Nav. Built on KOReader's Menu so Back and large tap targets come for free.

local Menu = require("ui/widget/menu")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local Index = Menu:extend {
  name = "koffeelab_index",
  covers_fullscreen = true,
  is_borderless = true,
  is_popout = false,
  is_enable_shortcut = false,
  with_bottom_line = true,
  title_bar_left_icon = "chevron.left",
  title = _("Index"),
}

function Index:init()
  self.item_table = {
    {
      text = _("Base Coffee Recipes"),
      mandatory = "\u{203A}", -- ›
      _module = "ui/recipe/index",
    },
    {
      text = _("Custom Drinks"),
      mandatory = "\u{203A}",
      _module = "ui/drink/index",
    },
  }
  Menu.init(self)
end

function Index:onMenuChoice(item)
  local screen = require(item._module):new {}
  self.nav:push(screen)
  return true
end

function Index:_back()
  if self.nav then
    self.nav:pop()
  else
    UIManager:close(self)
  end
  return true
end

Index.onClose = Index._back
Index.onLeftButtonTap = Index._back

return Index
