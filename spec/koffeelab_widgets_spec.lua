require("koffeelab.spec_helper")
local UIManager = require("ui/uimanager")
local Screen = require("device").screen
local Paths = require("ui/paths")
Paths.root = "plugins/KoffeeLab.koplugin"

describe("ui/widgets", function()
  it("Rating1to5 selects, clears and reports its value", function()
    local Rating1to5 = require("ui/widgets/rating")
    local seen
    local r = Rating1to5:new {
      on_change = function(v)
        seen = v
      end,
    }
    assert.is_nil(r:getValue())
    r:_select(4)
    assert.are.equal(4, r:getValue())
    assert.are.equal(4, seen)
    r:_select(4) -- tap again clears
    assert.is_nil(r:getValue())
    assert.is_nil(seen)

    r:setValue(3)
    r:paintTo(Screen.bb, 0, 0) -- must not error with a selection painted inverted
  end)

  it("FormScreen renders rows from fields and refreshes on set", function()
    local FormScreen = require("ui/widgets/form_screen")
    local saved = false
    local screen = FormScreen:new {
      title = "Form",
      values = { title = "V60" },
      fields = {
        {
          key = "title",
          label = "Title",
          display = function(v)
            return v.title
          end,
          edit = function(form)
            form:set("title", "AeroPress")
          end,
        },
      },
      actions = {
        {
          text = "Save",
          callback = function()
            saved = true
          end,
        },
      },
    }
    assert.are.equal("V60", screen.item_table[1].mandatory)
    assert.are.equal(2, #screen.item_table) -- one field + one action row

    screen:onMenuChoice(screen.item_table[1]) -- runs the field editor
    assert.are.equal("AeroPress", screen.values.title)
    assert.are.equal("AeroPress", screen.item_table[1].mandatory)

    screen:onMenuChoice(screen.item_table[2]) -- runs the action
    assert.is_true(saved)

    UIManager:show(screen)
    screen:paintTo(Screen.bb, 0, 0)
    UIManager:close(screen)
  end)

  it("modal helpers show and dismiss without error", function()
    local ListPicker = require("ui/widgets/list_picker")
    local NumberInput = require("ui/widgets/number_input")
    local ConfirmDialog = require("ui/widgets/confirm_dialog")

    local picked
    local lp = ListPicker.show {
      title = "Pick",
      items = { { text = "One", value = 1 }, { text = "Two", value = 2 } },
      current = 2,
      on_select = function(v)
        picked = v
      end,
    }
    assert.is_true(UIManager:isWidgetShown(lp))
    lp:onMenuChoice(lp.item_table[1])
    assert.are.equal(1, picked)
    assert.is_false(UIManager:isWidgetShown(lp))

    local ni = NumberInput.show {
      title = "Number",
      value = 15,
      min = 1,
      max = 30,
      step = 1,
      unit = "clicks",
      on_ok = function() end,
    }
    assert.is_true(UIManager:isWidgetShown(ni))
    UIManager:close(ni)

    local cd = ConfirmDialog.destructive {
      text = "Delete?",
      on_confirm = function() end,
    }
    assert.is_true(UIManager:isWidgetShown(cd))
    UIManager:close(cd)
  end)

  it("Card is tappable, repaints once and is inert without on_tap", function()
    local Card = require("ui/widgets/card")
    local TextWidget = require("ui/widget/textwidget")
    local taps = 0
    local card = Card:new {
      width = 200,
      height = 80,
      on_tap = function()
        taps = taps + 1
      end,
      TextWidget:new { text = "hi", face = require("ui/design").face("body") },
    }
    card:paintTo(Screen.bb, 0, 0)
    card:onTap()
    assert.are.equal(1, taps)

    local inert = Card:new {
      width = 200,
      height = 80,
      TextWidget:new { text = "x", face = require("ui/design").face("body") },
    }
    assert.is_nil(inert.ges_events.Tap)
    inert:onTap() -- must not error
  end)

  it("Tile renders an icon over a label and taps", function()
    local Tile = require("ui/widgets/tile")
    local tapped = false
    local tile = Tile:new {
      width = 160,
      height = 120,
      icon = "add",
      label = "Add Recipe",
      on_tap = function()
        tapped = true
      end,
    }
    assert.are.equal("Add Recipe", tile.label)
    tile:paintTo(Screen.bb, 0, 0)
    tile:onTap()
    assert.is_true(tapped)
  end)

  it("Navbar renders five cells and reports the tapped key", function()
    local Navbar = require("ui/widgets/navbar")
    local seen
    local nav = Navbar:new {
      width = 600,
      active = "home",
      on_select = function(key)
        seen = key
      end,
    }
    assert.are.equal(5, #nav._ranges)
    assert.is_true(Navbar.HEIGHT > 0)
    nav:paintTo(Screen.bb, 0, 0)
    -- a tap near the far right lands on the last cell (configurator)
    nav:onTap(nil, { pos = { x = 590, y = 0 } })
    assert.are.equal("configurator", seen)
  end)

  it("plugin SVG icons resolve and paint", function()
    local IconWidget = require("ui/widget/iconwidget")
    for _, name in ipairs { "home", "index", "add", "favorite", "configurator", "pour_over" } do
      local w = IconWidget:new {
        file = Paths.icon(name),
        width = 48,
        height = 48,
        is_icon = true,
        alpha = true,
      }
      w:paintTo(Screen.bb, 0, 0)
      w:free()
    end
  end)

  it("GrindDial maps the segmented control to a clamped value", function()
    local GrindDial = require("ui/widgets/grind_dial")
    local seen
    local d = GrindDial.show {
      value = 15,
      min = 1,
      max = 30,
      step = 1,
      default = 15,
      unit = "clicks",
      on_change = function(v)
        seen = v
      end,
    }
    assert.is_true(UIManager:isWidgetShown(d))
    d:paintTo(Screen.bb, 0, 0)

    d._adjust(1) -- first segment -> min
    assert.are.equal(1, seen)
    assert.are.equal(1, d._value())
    d._adjust("+")
    assert.are.equal(2, seen)
    d._adjust("-")
    d._adjust("-") -- clamps at min
    assert.are.equal(1, seen)

    UIManager:close(d)
  end)

  it("Home screen builds and its overflow menu opens", function()
    local HomeScreen = require("ui/home")
    local home = HomeScreen:new {}
    assert.is_not_nil(home.title_bar)
    home:paintTo(Screen.bb, 0, 0) -- full render path: frame + titlebar + button table
    home:onRightButton()
    -- close whatever the overflow opened
    UIManager:close(UIManager._window_stack[#UIManager._window_stack].widget)
  end)
end)
