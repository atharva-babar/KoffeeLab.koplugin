require("koffeelab.spec_helper")
local Nav = require("ui/nav")
local ScreenBase = require("ui/screen_base")
local UIManager = require("ui/uimanager")

local function make_screen(tag)
  local S = ScreenBase:extend { name = "koffeelab_test_" .. tag, title = tag }
  return S:new {}
end

describe("ui/nav", function()
  before_each(function()
    Nav:closeAll()
  end)

  after_each(function()
    Nav:closeAll()
  end)

  it("push / pop keep the stack and UIManager in step", function()
    local a, b, c = make_screen("A"), make_screen("B"), make_screen("C")

    Nav:push(a)
    Nav:push(b)
    Nav:push(c)
    assert.are.equal(3, Nav:depth())
    assert.is_true(UIManager:isWidgetShown(a))
    assert.is_true(UIManager:isWidgetShown(c))
    assert.are.equal(c, Nav:top())

    assert.are.equal(b, Nav:pop())
    assert.are.equal(2, Nav:depth())
    assert.is_false(UIManager:isWidgetShown(c))

    assert.are.equal(a, Nav:pop())
    assert.is_nil(Nav:pop()) -- last screen: stack now empty
    assert.are.equal(0, Nav:depth())
    assert.is_false(UIManager:isWidgetShown(a))
  end)

  it("the on-screen back button and hardware Back both pop", function()
    Nav:push(make_screen("A"))
    local b = Nav:push(make_screen("B"))

    -- titlebar chevron
    b.title_bar.left_icon_tap_callback()
    assert.are.equal(1, Nav:depth())

    -- hardware / gesture Back routes through onClose
    local a = Nav:top()
    a:onClose()
    assert.are.equal(0, Nav:depth())
  end)

  it("replace swaps the top screen without changing depth", function()
    Nav:push(make_screen("A"))
    local b = Nav:push(make_screen("B"))
    local b2 = make_screen("B2")

    Nav:replace(b2)
    assert.are.equal(2, Nav:depth())
    assert.are.equal(b2, Nav:top())
    assert.is_false(UIManager:isWidgetShown(b))
    assert.is_true(UIManager:isWidgetShown(b2))
  end)

  it("reset tears the whole stack down and starts fresh", function()
    Nav:push(make_screen("A"))
    Nav:push(make_screen("B"))
    local home = make_screen("Home")

    Nav:reset(home)
    assert.are.equal(1, Nav:depth())
    assert.are.equal(home, Nav:top())
  end)

  it("does not leak widgets into the window stack", function()
    local before = #UIManager._window_stack
    Nav:push(make_screen("A"))
    Nav:push(make_screen("B"))
    Nav:pop()
    Nav:pop()
    assert.are.equal(before, #UIManager._window_stack)
  end)
end)
