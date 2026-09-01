-- ui/recipe/method_select.lua
-- Step 1 of the Add Recipe flow (TECH_SOLUTION §2.4): pick the brew method from
-- large full-width cards. Only active methods are listed (system + user). On a
-- tap the screen hands the chosen method row back through `on_pick`; the flow
-- (ui/recipe/add_flow) then builds the method-driven recipe form.

local ButtonTable = require("ui/widget/buttontable")
local CenterContainer = require("ui/widget/container/centercontainer")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local MethodService = require("services/method_service")
local ScreenBase = require("ui/screen_base")
local TextBoxWidget = require("ui/widget/textboxwidget")
local _ = require("gettext")

local MethodSelect = ScreenBase:extend {
  name = "koffeelab_recipe_method_select",
  title = _("Select Brew Method"),
  on_pick = nil, -- required: function(method_row)
}

function MethodSelect:getContentWidget()
  local ok, methods = MethodService.list {}
  methods = ok and methods or {}

  if #methods == 0 then
    return CenterContainer:new {
      dimen = Geom:new { w = self.screen_w, h = self.content_height },
      TextBoxWidget:new {
        text = _("No active brew methods. Enable one in Configurator › Brew Methods."),
        face = Font:getFace("infofont"),
        width = math.floor(self.screen_w * 0.8),
        alignment = "center",
      },
    }
  end

  local rows = {}
  for _idx, method in ipairs(methods) do -- luacheck: ignore _idx
    local label = method.name
    if method.icon and method.icon ~= "" then
      label = method.icon .. "  " .. label
    end
    rows[#rows + 1] = {
      {
        text = label,
        callback = function()
          if self.on_pick then
            self:on_pick(method)
          end
        end,
      },
    }
  end

  local buttons = ButtonTable:new {
    width = math.floor(self.screen_w * 0.9),
    buttons = rows,
    show_parent = self,
  }
  return CenterContainer:new {
    dimen = Geom:new { w = self.screen_w, h = self.content_height },
    buttons,
  }
end

return MethodSelect
