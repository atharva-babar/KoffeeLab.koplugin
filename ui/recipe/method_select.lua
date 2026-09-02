-- ui/recipe/method_select.lua
-- Step 1 of Add Recipe: pick the brew method from a grid of icon tiles. Hands the
-- chosen static method definition back through `on_pick`.

local Design = require("ui/design")
local Device = require("device")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local MethodService = require("services/method_service")
local ScreenBase = require("ui/screen_base")
local Tile = require("ui/widgets/tile")
local TopContainer = require("ui/widget/container/topcontainer")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local _ = require("gettext")
local Screen = Device.screen

local MethodSelect = ScreenBase:extend {
  name = "koffeelab_recipe_method_select",
  title = _("Select Brew Method"),
  on_pick = nil,
}

function MethodSelect:getContentWidget()
  local ok, methods = MethodService.list()
  methods = ok and methods or {}

  local pad = Design.pad.lg
  local gap = Design.pad.md
  local tile_w = math.floor((self.screen_w - 2 * pad - gap) / 2)
  local tile_h = Screen:scaleBySize(104)

  self.tiles = {}
  for _, method in ipairs(methods) do
    self.tiles[#self.tiles + 1] = Tile:new {
      width = tile_w,
      height = tile_h,
      icon = method.icon or "add",
      label = method.name,
      show_parent = self,
      on_tap = function()
        if self.on_pick then
          self:on_pick(method)
        end
      end,
    }
  end

  local grid = VerticalGroup:new { align = "left" }
  for i = 1, #self.tiles, 2 do
    if i > 1 then
      grid[#grid + 1] = VerticalSpan:new { width = gap }
    end
    local rowg = HorizontalGroup:new { align = "top", self.tiles[i] }
    if self.tiles[i + 1] then
      rowg[#rowg + 1] = HorizontalSpan:new { width = gap }
      rowg[#rowg + 1] = self.tiles[i + 1]
    end
    grid[#grid + 1] = rowg
  end

  return TopContainer:new {
    dimen = Geom:new { w = self.screen_w, h = self.content_height },
    VerticalGroup:new {
      align = "left",
      VerticalSpan:new { width = pad },
      HorizontalGroup:new { HorizontalSpan:new { width = pad }, grid },
    },
  }
end

return MethodSelect
