-- ui/recipe/method_select.lua
-- Step 1 of Add Recipe: pick the brew method from a grid of icon tiles. Hands the
-- chosen static method definition back through `on_pick`.

local CardRow = require("ui/widgets/card_row")
local Design = require("ui/design")
local Device = require("device")
local Geom = require("ui/geometry")
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

  local gap = Design.gap
  local w = CardRow.cellWidths(self.screen_w, 2)[1]
  local tile_h = Screen:scaleBySize(104)

  self.tiles = {}
  for _, method in ipairs(methods) do
    self.tiles[#self.tiles + 1] = Tile:new {
      width = w,
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

  local grid = VerticalGroup:new { align = "center" }
  for i = 1, #self.tiles, 2 do
    if i > 1 then
      grid[#grid + 1] = VerticalSpan:new { width = gap }
    end
    local pair = { self.tiles[i] }
    if self.tiles[i + 1] then
      pair[#pair + 1] = self.tiles[i + 1]
    end
    grid[#grid + 1] = CardRow.new { width = self.screen_w, cards = pair }
  end

  return TopContainer:new {
    dimen = Geom:new { w = self.screen_w, h = self.content_height },
    VerticalGroup:new {
      align = "center",
      VerticalSpan:new { width = Design.pad.page },
      grid,
    },
  }
end

return MethodSelect
