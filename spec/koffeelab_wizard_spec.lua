require("koffeelab.spec_helper")
require("ui/paths").root = "plugins/KoffeeLab.koplugin"
local Nav = require("ui/nav")
local Screen = require("device").screen
local Wizard = require("ui/widgets/wizard")

-- A 2-page wizard over a plain draft table.
local function make(draft, on_save)
  local W = Wizard:extend { name = "koffeelab_wizard_spec" }
  function W:init()
    self.wizard_title = "Test"
    self.values = draft
    self.pages = {
      {
        title = "One",
        fields = {
          {
            key = "name",
            label = "Name",
            display = function(v)
              return v.name
            end,
            edit = function(w)
              w:set("name", "edited")
            end,
          },
        },
        validate = function(v)
          if not v.name or v.name == "" then
            return "name required"
          end
        end,
      },
      {
        title = "Two",
        fields = {
          {
            key = "note",
            label = "Note",
            display = function(v)
              return v.note
            end,
            edit = function() end,
          },
        },
      },
    }
    self.on_save = on_save
    Wizard.init(self)
  end
  return W:new {}
end

describe("ui/widgets/wizard", function()
  after_each(function()
    Nav:closeAll()
  end)

  it("renders the current page's field cards and a flat all_fields list", function()
    local w = Nav:push(make { name = "Ada" })
    w:paintTo(Screen.bb, 0, 0)
    assert.are.equal(2, #w.all_fields)
    assert.are.equal(1, #w.item_table) -- page 1 has one field
    assert.are.equal("Name", w.item_table[1].text)
    assert.are.equal("Ada", w.item_table[1].mandatory)
  end)

  it("next validates the page then advances; save only on the last page", function()
    local saved = false
    local w = Nav:push(make({ name = "" }, function()
      saved = true
    end))

    -- page 1 invalid -> next is a no-op
    w:onNavAction("next")
    assert.are.equal(1, w.page_index)

    w.values.name = "Ada"
    w:onNavAction("next")
    assert.are.equal(2, w.page_index)
    assert.are.equal("Note", w.item_table[1].text)

    w:onNavAction("save")
    assert.is_true(saved)
  end)

  it("Back steps to the previous page before it pops", function()
    local w = Nav:push(make { name = "Ada" })
    w:onNavAction("next")
    assert.are.equal(2, w.page_index)
    assert.is_true(w:_goBack())
    assert.are.equal(1, w.page_index)
    assert.are.equal(1, Nav:depth()) -- still on the wizard
  end)

  it("a field card edit writes back and rebuilds", function()
    local draft = { name = "Ada" }
    local w = Nav:push(make(draft))
    w.pages[1].fields[1].edit(w)
    assert.are.equal("edited", draft.name)
    assert.are.equal("edited", w.item_table[1].mandatory)
  end)

  it("save runs every page's validator, not just the last", function()
    local saved = false
    local w = Nav:push(make({ name = "Ada" }, function()
      saved = true
    end))
    w:onNavAction("next")
    w.values.name = "" -- invalidate page 1 from page 2
    w:onNavAction("save")
    assert.is_false(saved)
  end)
end)
