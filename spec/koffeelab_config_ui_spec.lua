require("koffeelab.spec_helper")
local helper = require("koffeelab.spec_helper")
local Nav = require("ui/nav")
local Screen = require("device").screen

local ConfigService = require("services/config_service")
local TextInput = require("ui/widgets/text_input")

describe("ui/config (Configurator)", function()
  before_each(function()
    helper.migrated_connection()
    Nav:closeAll()
  end)

  after_each(function()
    Nav:closeAll()
    helper.teardown()
  end)

  it("Configurator lists its categories and paints", function()
    local Configurator = require("ui/configurator")
    local screen = Nav:push(Configurator:new {})
    assert.are.equal(5, #screen.item_table)
    assert.are.equal("Beans", screen.item_table[1].text)
    assert.are.equal("Backup & Restore", screen.item_table[5].text)
    for _, item in ipairs(screen.item_table) do
      assert.are_not.equal("Brew Methods", item.text)
    end
    screen:paintTo(Screen.bb, 0, 0)
  end)

  it("opens a category screen from the Configurator", function()
    local Configurator = require("ui/configurator")
    local screen = Nav:push(Configurator:new {})
    screen:onMenuChoice(screen.item_table[1]) -- Beans
    assert.are.equal(2, Nav:depth())
    assert.are.equal("koffeelab_config_beans", Nav:top().name)
    Nav:top():paintTo(Screen.bb, 0, 0)
  end)

  it("Home builds and the Configurator opens on top of it", function()
    local HomeScreen = require("ui/home")
    local Configurator = require("ui/configurator")
    Nav:reset(HomeScreen:new {})
    assert.are.equal(1, Nav:depth())
    Nav:push(Configurator:new {}) -- what the Home "Configurator" button does
    assert.are.equal(2, Nav:depth())
    assert.are.equal("koffeelab_configurator", Nav:top().name)
    Nav:pop()
    assert.are.equal("koffeelab_home", Nav:top().name)
  end)

  describe("Beans", function()
    local Beans = require("ui/config/beans")
    local EntityForm = require("ui/config/entity_form")

    it("shows an empty state, then the bean after it is added", function()
      local list = Nav:push(Beans:new {})
      -- row 1 is "+ Add Bean", row 2 the empty-state hint
      assert.is_true(list.item_table[1].text:find("Add Bean", 1, true) ~= nil)
      assert.are.equal(2, #list.item_table)

      local form = EntityForm.build {
        nav = Nav,
        title = "New Bean",
        service = ConfigService.beans,
        fields = {
          { key = "roaster_name", label = "Roaster", kind = "text" },
          { key = "name", label = "Bean name", kind = "text" },
          {
            key = "roast_level",
            label = "Roast",
            kind = "pick",
            options = require("util/constants").ROAST_LEVELS,
            default = 3,
          },
        },
        on_saved = function()
          list:reload()
        end,
      }
      Nav:push(form)
      form.values.name = "Ethiopia Guji"
      form.values.roaster_name = "Blue Tokai"
      -- last action row = Save
      form:onMenuChoice(form.item_table[#form.item_table])

      local ok, rows = ConfigService.beans.list {}
      assert.is_true(ok)
      assert.are.equal(1, #rows)
      assert.are.equal("Ethiopia Guji", rows[1].name)

      assert.are.equal(2, #list.item_table) -- "+ Add" + the new bean, no empty hint
      assert.are.equal("Ethiopia Guji", list.item_table[2].text)
    end)

    it("disable hides a bean from the default list but the Configurator still shows it", function()
      assert(ConfigService.beans.create { name = "Old Bean" })
      local list = Nav:push(Beans:new {})
      local bean = list.item_table[2]._entity

      local form = EntityForm.build {
        nav = Nav,
        title = "Edit Bean",
        service = ConfigService.beans,
        entity = bean,
        fields = { { key = "name", label = "Name", kind = "text" } },
        on_saved = function()
          list:reload()
        end,
      }
      Nav:push(form)
      -- action rows: [Save] [Disable]; Disable is last, and confirms
      form:onMenuChoice(form.item_table[#form.item_table])
      local UIManager = require("ui/uimanager")
      local box = UIManager._window_stack[#UIManager._window_stack].widget
      assert.is_function(box.ok_callback)
      box.ok_callback()
      UIManager:close(box)

      local _, active = ConfigService.beans.list {}
      assert.are.equal(0, #active)
      local _, all = ConfigService.beans.list { include_inactive = true }
      assert.are.equal(1, #all)

      -- the Configurator list still renders it, flagged disabled
      assert.are.equal(2, #list.item_table)
      assert.is_true(list.item_table[2].mandatory:find("disabled", 1, true) ~= nil)
    end)
  end)

  describe("Grinders", function()
    local Grinders = require("ui/config/grinders")
    local EntityForm = require("ui/config/entity_form")

    it("rejects min > max and keeps the form open", function()
      local list = Nav:push(Grinders:new {})
      local popped = false
      local nav_stub = setmetatable({
        pop = function()
          popped = true
        end,
      }, { __index = Nav })

      local form = EntityForm.build {
        nav = nav_stub,
        title = "New Grinder",
        service = ConfigService.grinders,
        fields = {
          { key = "name", label = "Name", kind = "text" },
          { key = "unit_name", label = "Unit", kind = "text" },
          { key = "min_value", label = "Min", kind = "number" },
          { key = "max_value", label = "Max", kind = "number" },
          { key = "step_value", label = "Step", kind = "number" },
        },
        on_saved = function()
          list:reload()
        end,
      }
      Nav:push(form)
      form.values.name = "Bad"
      form.values.unit_name = "clicks"
      form.values.min_value = 30
      form.values.max_value = 5
      form.values.step_value = 1
      form:onMenuChoice(form.item_table[#form.item_table]) -- Save

      assert.is_false(popped)
      local _, rows = ConfigService.grinders.list { include_inactive = true }
      assert.are.equal(0, #rows)
    end)
  end)

  describe("Ingredients / Flavor Tags (single-field, inline dialog)", function()
    local Ingredients = require("ui/config/ingredients")
    local FlavorTags = require("ui/config/flavor_tags")

    local function stub_text(value)
      local orig = TextInput.show
      TextInput.show = function(opts)
        opts.on_ok(value)
      end
      finally(function()
        TextInput.show = orig
      end)
    end

    it("adds an ingredient straight from a text dialog, no form screen", function()
      local list = Nav:push(Ingredients:new {})
      local depth = Nav:depth()
      stub_text("Oat milk")
      list:on_add()
      assert.are.equal(depth, Nav:depth()) -- no EntityForm pushed
      local _, rows = ConfigService.ingredients.list {}
      assert.are.equal(1, #rows)
      assert.are.equal("Oat milk", rows[1].name)
      assert.are.equal("Oat milk", list.item_table[2].text)
    end)

    it("renames a flavor tag inline", function()
      assert(ConfigService.flavor_tags.create { name = "Choco" })
      local list = Nav:push(FlavorTags:new {})
      local entity = list.item_table[2]._entity
      stub_text("Chocolate")
      list:on_edit(entity)
      local _, rows = ConfigService.flavor_tags.list {}
      assert.are.equal("Chocolate", rows[1].name)
    end)

    it("surfaces a duplicate-name error without crashing", function()
      assert(ConfigService.ingredients.create { name = "Milk" })
      local list = Nav:push(Ingredients:new {})
      stub_text("Milk")
      list:on_add()
      local _, rows = ConfigService.ingredients.list {}
      assert.are.equal(1, #rows)
    end)
  end)
end)
