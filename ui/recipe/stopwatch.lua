-- ui/recipe/stopwatch.lua
-- Tap-to-capture stopwatch (TECH_SOLUTION §2.16a; design-language §4.8). The
-- elapsed-time display is STATIC — repainted only when the user taps a tile
-- (Start / Split / Stop / Use / Restart). No scheduleIn, no refresh loop; between
-- taps the screen never changes. Each tap reads os.time(); on Stop the elapsed
-- seconds and any splits are handed back through `on_capture`.

local CardRow = require("ui/widgets/card_row")
local Design = require("ui/design")
local Device = require("device")
local Format = require("util/format")
local Geom = require("ui/geometry")
local KvList = require("ui/widgets/kv_list")
local ScreenCard = require("ui/screen_card")
local SectionCard = require("ui/widgets/section_card")
local CenterContainer = require("ui/widget/container/centercontainer")
local TextWidget = require("ui/widget/textwidget")
local Tile = require("ui/widgets/tile")
local _ = require("gettext")
local Screen = Device.screen

local Stopwatch = ScreenCard:extend {
  name = "koffeelab_recipe_stopwatch",
  title = _("Capture Brew Time"),
  navbar = { "home", "back" },
  on_capture = nil, -- function(elapsed_sec_or_nil, splits_array)
}

function Stopwatch:init()
  self.state = "idle" -- idle | running | stopped
  self.start_time = nil
  self.elapsed = 0
  self.splits = {} -- elapsed-second marks
  ScreenCard.init(self)
end

function Stopwatch:_shown_elapsed()
  if self.state == "running" and self.start_time then
    return os.time() - self.start_time
  end
  return self.elapsed
end

-- act -> { label } for the current state; drives the tile row + specs.
function Stopwatch:_actions()
  if self.state == "idle" then
    return { { act = "start", label = _("Start") } }
  elseif self.state == "running" then
    return { { act = "split", label = _("Split") }, { act = "stop", label = _("Stop") } }
  end
  return { { act = "use", label = _("Use this time") }, { act = "restart", label = _("Restart") } }
end

function Stopwatch:buildCards()
  local inner = self.card_w - 2 * Design.pad.card

  local hero = CenterContainer:new {
    dimen = Geom:new { w = inner, h = Screen:scaleBySize(56) },
    TextWidget:new {
      text = Format.duration(self:_shown_elapsed()) or "0:00",
      face = Design.face("display"),
    },
  }
  local cards = {
    SectionCard:new {
      width = self.card_w,
      title = _("Elapsed"),
      show_parent = self,
      body = hero,
    },
  }

  self.action_tiles = {}
  local acts = self:_actions()
  local widths = CardRow.cellWidths(self.screen_w, #acts)
  local tile_h = Screen:scaleBySize(64)
  local tiles = {}
  for i, a in ipairs(acts) do
    local t = Tile:new {
      width = widths[i],
      height = tile_h,
      icon = a.act == "start" and "brew_again" or a.act == "use" and "save" or "next",
      label = a.label,
      show_parent = self,
      on_tap = function()
        self:_do(a.act)
      end,
    }
    self.action_tiles[a.act] = t
    tiles[i] = t
  end
  cards[#cards + 1] = CardRow.new { width = self.screen_w, cards = tiles }

  if #self.splits > 0 then
    local rows = {}
    for i, s in ipairs(self.splits) do
      rows[#rows + 1] = { string.format("#%d", i), Format.duration(s) or "0:00" }
    end
    cards[#cards + 1] = SectionCard:new {
      width = self.card_w,
      title = _("Splits"),
      show_parent = self,
      body = KvList.new(inner, rows),
    }
  end
  return cards
end

Stopwatch._repaint = ScreenCard.refresh

function Stopwatch:_do(act)
  if act == "start" then
    self.state = "running"
    self.start_time = os.time()
    self.elapsed = 0
    self.splits = {}
  elseif act == "split" and self.start_time then
    self.splits[#self.splits + 1] = os.time() - self.start_time
  elseif act == "stop" and self.start_time then
    self.elapsed = os.time() - self.start_time
    self.state = "stopped"
  elseif act == "restart" then
    self.state = "idle"
    self.start_time = nil
    self.elapsed = 0
    self.splits = {}
  elseif act == "use" then
    if self.on_capture then
      self.on_capture(self.elapsed > 0 and self.elapsed or nil, self.splits)
    end
    return self:onReturn()
  end
  if act then
    self:_repaint()
  end
  return true
end

return Stopwatch
