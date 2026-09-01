local HomeScreen = require("ui/home")
local Nav = require("ui/nav")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local logger = require("logger")

local KoffeeLab = WidgetContainer:extend {
  name = "koffeelab",
  is_doc_only = false,
}

function KoffeeLab:init()
  logger.dbg("KoffeeLab: init")
  self.ui.menu:registerToMainMenu(self)
end

function KoffeeLab:addToMainMenu(menu_items)
  menu_items.koffeelab = {
    text = _("KoffeeLab"),
    sorting_hint = "tools",
    callback = function()
      Nav:reset(HomeScreen:new {})
    end,
  }
end

return KoffeeLab
