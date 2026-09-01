require("koffeelab.spec_helper")
local helper = require("koffeelab.spec_helper")
local Nav = require("ui/nav")
local Screen = require("device").screen

local ConfigService = require("services/config_service")
local MethodService = require("services/method_service")

describe("ui/config (Configurator)", function()
  before_each(function()
    helper.migrated_connection()
    Nav:closeAll()
  end)

  after_each(function()
    Nav:closeAll()
    helper.teardown()
  end)

  it("Configurator lists the six categories and paints", function()
    local Configurator = require("ui/configurator")
    local screen = Nav:push(Configurator:new {})
    assert.are.equal(6, #screen.item_table)
    assert.are.equal("Beans", screen.item_table[1].text)
    assert.are.equal("Backup & Restore", screen.item_table[6].text)
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

  describe("Brew Methods", function()
    local Methods = require("ui/config/methods")
    local MethodForm = require("ui/config/method_form")
    local MethodDetail = require("ui/config/method_detail")

    it("lists the five system methods and paints a detail view", function()
      local list = Nav:push(Methods:new {})
      -- 1 add row + 5 system methods
      assert.are.equal(6, #list.item_table)

      local pour_over
      for _, item in ipairs(list.item_table) do
        if item._entity and item._entity.slug == "pour_over" then
          pour_over = item._entity
        end
      end
      assert.is_not_nil(pour_over)

      local detail = Nav:push(MethodDetail:new { method = pour_over })
      detail:paintTo(Screen.bb, 0, 0)
      -- system methods expose no Edit action
      local has_edit = false
      for _, item in ipairs(detail.item_table) do
        if item._action == "edit" then
          has_edit = true
        end
      end
      assert.is_false(has_edit)
    end)

    it("builds a user method with params + steps, then deactivates it", function()
      local list = Nav:push(Methods:new {})
      local saved = false
      local form = MethodForm:new {
        on_saved = function()
          saved = true
          list:reload()
        end,
      }
      Nav:push(form)
      form.values.name = "Moka Pot"
      form.values.icon = "MP"
      form.values.parameters = {
        { key = "pressure", label = "Stove level", data_type = "int", required = 0 },
        { key = "prep", label = "Prep note", data_type = "text", required = 0 },
      }
      form.values.step_types = { "setup", "extract", "finish" }
      form:_save()
      assert.is_true(saved)

      local ok, methods = MethodService.list { include_inactive = true }
      assert.is_true(ok)
      local moka
      for _, m in ipairs(methods) do
        if m.name == "Moka Pot" then
          moka = m
        end
      end
      assert.is_not_nil(moka)
      assert.are.equal("moka_pot", moka.slug)
      assert.are.equal(2, #moka.parameters)
      assert.are.equal(3, #moka.step_types)

      local detail = Nav:push(MethodDetail:new { method = moka })
      local toggle, has_edit
      for _, item in ipairs(detail.item_table) do
        if item._action == "toggle" then
          toggle = item
        elseif item._action == "edit" then
          has_edit = true
        end
      end
      assert.is_not_nil(toggle)
      assert.is_true(has_edit) -- user methods expose Edit
      detail:onMenuChoice(toggle)
      local UIManager = require("ui/uimanager")
      local box = UIManager._window_stack[#UIManager._window_stack].widget
      box.ok_callback()
      UIManager:close(box)

      local _, fresh = MethodService.get(moka.id)
      assert.are.equal(0, tonumber(fresh.is_active))
    end)
  end)
end)
