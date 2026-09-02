-- ui/index.lua
-- Index root (TECH_SOLUTION §2.14; design-language §4.2): two big centred tiles —
-- the base coffee recipes and the custom drinks. Each pushes its own
-- filterable/sortable index screen.

local Device = require("device")
local Nav = require("ui/nav")
local ScreenCard = require("ui/screen_card")
local Tile = require("ui/widgets/tile")
local _ = require("gettext")
local Screen = Device.screen

local Index = ScreenCard:extend {
  name = "koffeelab_index",
  title = _("Index"),
  navbar = "index",
}

function Index:buildCards()
  local h = Screen:scaleBySize(120)
  self.tiles = {
    Tile:new {
      width = self.card_w,
      height = h,
      icon = "pour_over",
      label = _("Coffee Recipes"),
      show_parent = self,
      on_tap = function()
        Nav:push(require("ui/recipe/index"):new {})
      end,
    },
    Tile:new {
      width = self.card_w,
      height = h,
      icon = "custom_drink",
      label = _("Custom Drinks"),
      show_parent = self,
      on_tap = function()
        Nav:push(require("ui/drink/index"):new {})
      end,
    },
  }
  return { self.tiles[1], self.tiles[2] }
end

return Index
