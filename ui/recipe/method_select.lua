-- ui/recipe/method_select.lua
-- Step 1 of Add Recipe: pick the brew method from large full-width cards. Hands
-- the chosen static method definition back through `on_pick`.

local ButtonTable = require("ui/widget/buttontable")
local CenterContainer = require("ui/widget/container/centercontainer")
local Geom = require("ui/geometry")
local MethodService = require("services/method_service")
local ScreenBase = require("ui/screen_base")
local _ = require("gettext")

local MethodSelect = ScreenBase:extend {
  name = "koffeelab_recipe_method_select",
  title = _("Select Brew Method"),
  on_pick = nil,
}

function MethodSelect:getContentWidget()
  local ok, methods = MethodService.list()
  methods = ok and methods or {}

  local rows = {}
  for _, method in ipairs(methods) do
    rows[#rows + 1] = {
      {
        text = method.name,
        callback = function()
          if self.on_pick then
            self:on_pick(method)
          end
        end,
      },
    }
  end

  return CenterContainer:new {
    dimen = Geom:new { w = self.screen_w, h = self.content_height },
    ButtonTable:new {
      width = math.floor(self.screen_w * 0.9),
      buttons = rows,
      show_parent = self,
    },
  }
end

return MethodSelect
