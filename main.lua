local Bootstrap = require("db/bootstrap")
local HomeScreen = require("ui/home")
local InfoMessage = require("ui/widget/infomessage")
local Nav = require("ui/nav")
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
  -- Open + migrate the database once per session (TECH_SOLUTION §3.3). A failure
  -- is non-fatal: the menu entry still registers and reports the error on open.
  Bootstrap.ensure()
  self.ui.menu:registerToMainMenu(self)
end

function KoffeeLab:addToMainMenu(menu_items)
  menu_items.koffeelab = {
    text = _("KoffeeLab"),
    sorting_hint = "tools",
    callback = function()
      local ok, err = Bootstrap.ensure()
      if not ok then
        UIManager:show(InfoMessage:new {
          text = _("KoffeeLab could not open its database:") .. "\n" .. tostring(err),
          icon = "notice-warning",
        })
        return
      end
      Nav:reset(HomeScreen:new {})
    end,
  }
end

return KoffeeLab
