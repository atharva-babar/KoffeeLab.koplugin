-- ui/index.lua
-- Index root (TECH_SOLUTION §2.14): two choices — the base coffee recipes and the
-- custom drinks. Each row pushes its own filtered/sortable index screen.

local Nav = require("ui/nav")
local ScreenList = require("ui/screen_list")
local _ = require("gettext")

local Index = ScreenList:extend {
  name = "koffeelab_index",
  title = _("Index"),
  navbar = "index",
}

function Index:buildItems()
  return {
    {
      text = _("Base Coffee Recipes"),
      mandatory = "\u{203A}", -- ›
      _module = "ui/recipe/index",
      callback = function()
        Nav:push(require("ui/recipe/index"):new {})
      end,
    },
    {
      text = _("Custom Drinks"),
      mandatory = "\u{203A}",
      _module = "ui/drink/index",
      callback = function()
        Nav:push(require("ui/drink/index"):new {})
      end,
    },
  }
end

return Index
