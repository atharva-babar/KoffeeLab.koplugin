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
  -- Thread the plugin root to sub-modules before any screen is built.
  require("ui/paths").root = self.path
  -- Open + migrate the database once per session (TECH_SOLUTION §3.3). A failure
  -- is non-fatal: the menu entry still registers and reports the error on open.
  if Bootstrap.ensure() then
    -- First run (or just after a schema rebuild): fill the catalogue with sample
    -- recipes/drinks so there is something to browse. Best-effort.
    local SampleData = require("services/sample_data")
    if not SampleData.loaded() then
      local ok, err = SampleData.load()
      if not ok then
        logger.warn("KoffeeLab: sample data load failed:", tostring(err))
      end
    end
  end
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
