local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
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
      UIManager:show(InfoMessage:new {
        text = _("KoffeeLab — coming soon"),
      })
    end,
  }
end

return KoffeeLab
