require("koffeelab.spec_helper")
require("ui/paths").root = "plugins/KoffeeLab.koplugin"
local Screen = require("device").screen
local TextWidget = require("ui/widget/textwidget")
local Design = require("ui/design")

local function txt(s)
  return TextWidget:new { text = s, face = Design.face("body") }
end

describe("ui/widgets v2 cards", function()
  local W = Screen:getWidth()

  it("Card: grey, borderless, tappable once, inert without on_tap", function()
    local Card = require("ui/widgets/card")
    local taps = 0
    local c = Card:new {
      width = 300,
      on_tap = function()
        taps = taps + 1
      end,
      txt("hi"),
    }
    assert.are.equal(0, c.frame.bordersize)
    assert.are.equal(Design.color.card, c.frame.background)
    c:paintTo(Screen.bb, 0, 0)
    c:onTap()
    assert.are.equal(1, taps)

    local inert = Card:new { width = 300, txt("x") }
    assert.is_nil(inert.ges_events.Tap)
    inert:onTap()
  end)

  it("CardRow: equal + fractional cell widths, centred layout", function()
    local CardRow = require("ui/widgets/card_row")
    local Card = require("ui/widgets/card")
    local eq = CardRow.cellWidths(W, 2)
    assert.are.equal(2, #eq)
    assert.are.equal(eq[1], eq[2])
    local split = CardRow.cellWidths(W, { 0.6, 0.4 })
    assert.is_true(split[1] > split[2])

    local row = CardRow.new {
      width = W,
      cards = { Card:new { width = eq[1], txt("a") }, Card:new { width = eq[2], txt("b") } },
    }
    row:paintTo(Screen.bb, 0, 0)
  end)

  it("SectionCard: title + body slot", function()
    local SectionCard = require("ui/widgets/section_card")
    local s = SectionCard:new { width = W - 32, title = "Brew Details", body = txt("body") }
    assert.are.equal("Brew Details", s.title)
    s:paintTo(Screen.bb, 0, 0)
  end)

  it("TileStrip: wraps chips, never exceeds its width", function()
    local TileStrip = require("ui/widgets/tile_strip")
    local strip = TileStrip:new {
      width = 240,
      items = {
        { label = "Beans", value = "Ethiopia Guji 18 g" },
        { label = "Water", value = "300 mL / 94 C" },
        { label = "Grind", value = "Comandante 22" },
        { label = "Output", value = "1:16" },
      },
    }
    strip:paintTo(Screen.bb, 0, 0)
    assert.is_true(#strip.chips == 4)
    assert.is_true(strip:getSize().w <= 240)
  end)

  it("StatCard: up to 3 tappable lines + header tap; inert when empty", function()
    local StatCard = require("ui/widgets/stat_card")
    local opened, header_opened = {}, false
    local card = StatCard:new {
      width = 280,
      height = 120,
      header = "Recent",
      on_header = function()
        header_opened = true
      end,
      items = {
        {
          text = "V60 Morning",
          on_tap = function()
            opened[1] = true
          end,
        },
        {
          text = "AeroPress Quick",
          on_tap = function()
            opened[2] = true
          end,
        },
        {
          text = "Cold Brew Batch",
          on_tap = function()
            opened[3] = true
          end,
        },
        {
          text = "ignored 4th",
          on_tap = function()
            opened[4] = true
          end,
        },
      },
    }
    assert.are.equal(3, #card.lines)
    assert.is_falsy(card.inert)
    card:paintTo(Screen.bb, 0, 0)
    card.lines[2]:onTap()
    assert.is_true(opened[2])
    card.header_line:onTap()
    assert.is_true(header_opened)

    local empty = StatCard:new { width = 280, height = 120, header = "Favourites", items = {} }
    assert.is_true(empty.inert)
    assert.are.equal(0, #empty.lines)
    empty:paintTo(Screen.bb, 0, 0)
  end)

  it("ScreenCard: builds a scrolling card stack and refreshes once", function()
    local ScreenCard = require("ui/screen_card")
    local SectionCard = require("ui/widgets/section_card")
    local n = 2
    local Detail = ScreenCard:extend { name = "koffeelab_cards_spec_screen" }
    function Detail:buildCards()
      local out = {}
      for i = 1, n do
        out[i] = SectionCard:new { width = self.card_w, title = "S" .. i, body = txt("b") }
      end
      return out
    end
    local screen = Detail:new {}
    assert.are.equal(2, #screen.cards)
    screen:paintTo(Screen.bb, 0, 0)
    n = 4
    screen:refresh()
    assert.are.equal(4, #screen.cards)
    screen:paintTo(Screen.bb, 0, 0)
  end)
end)
