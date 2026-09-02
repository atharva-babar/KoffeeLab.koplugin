require("koffeelab.spec_helper")
require("ui/paths").root = "plugins/KoffeeLab.koplugin"
local Screen = require("device").screen
local ScrollList = require("ui/widgets/scroll_list")

describe("ui/widgets/scroll_list", function()
  local function make(items)
    return ScrollList:new {
      width = Screen:getWidth(),
      height = Screen:getHeight() - 100,
      items = items,
    }
  end

  it("builds mixed row kinds and paints", function()
    local list = make {
      { text = "Section", mandatory = "2", kind = "head" },
      { text = "Dose", mandatory = "18 g", on_tap = function() end },
      { text = "wrapped note that is inert", kind = "text" },
    }
    assert.are.equal(3, #list:rows())
    assert.is_not_nil(list.cropping_widget)
    list:paintTo(Screen.bb, 0, 0)
  end)

  it("fires on_tap for a normal row only", function()
    local hits = { normal = 0 }
    local list = make {
      {
        text = "Header",
        kind = "head",
        on_tap = function()
          hits.head = true
        end,
      },
      {
        text = "Row",
        on_tap = function()
          hits.normal = hits.normal + 1
        end,
      },
    }
    -- reach into the built group: row 2 is the tappable VerticalGroup's [1]
    local row_group = list._group[2]
    local tappable = row_group[1]
    tappable:onTap()
    assert.are.equal(1, hits.normal)
    assert.is_nil(hits.head)
  end)

  it("setItems rebuilds and keeps :rows() in sync", function()
    local list = make { { text = "a" } }
    list:setItems { { text = "b" }, { text = "c" } }
    assert.are.equal(2, #list:rows())
    list:paintTo(Screen.bb, 0, 0)
  end)
end)
