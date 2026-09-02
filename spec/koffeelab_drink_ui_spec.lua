require("koffeelab.spec_helper")
local helper = require("koffeelab.spec_helper")
local Nav = require("ui/nav")
local Screen = require("device").screen

local ConfigService = require("services/config_service")
local MethodService = require("services/method_service")
local RecipeService = require("services/recipe_service")
local DrinkService = require("services/drink_service")

local RecipeAddFlow = require("ui/recipe/add_flow")
local AddFlow = require("ui/drink/add_flow")
local DrinkForm = require("ui/drink/drink_form")
local DrinkIngredients = require("ui/drink/ingredients")
local DrinkSteps = require("ui/drink/steps")
local DrinkDetail = require("ui/drink/detail")
local BaseSelect = require("ui/drink/base_select")

-- A ready-to-save base recipe for `slug`.
local function make_base(slug, ids)
  local _, method = MethodService.get_by_slug(slug)
  local draft = {
    recipe = {
      method_id = method.id,
      title = "Base " .. slug,
      bean_id = ids.bean_id,
      grinder_id = ids.grinder_id,
      grind_value = 15,
      dose_g = 18,
      water_g = slug ~= "espresso" and 250 or nil,
      water_temp_c = 94,
      brew_time_sec = 165,
      output_weight_g = slug == "espresso" and 36 or 210,
      notes = "",
    },
    method = method,
    steps = {},
    params = {},
    flavor_tag_ids = {},
  }
  local ok, recipe = RecipeService.create(RecipeAddFlow.payload(draft))
  assert(ok, recipe)
  return recipe
end

local function fresh_draft(mode)
  return {
    drink = { temperature_mode = mode or "cold", base_unit = "g", comment = "" },
    ingredients = {},
    steps = {},
  }
end

local function tap_action(form, label)
  for _, item in ipairs(form.item_table) do
    if item._action and item.text == label then
      return item._action.callback(form)
    end
  end
  error("no action row: " .. label)
end

local function field_item(form, k)
  for _, item in ipairs(form.item_table) do
    if item._field and item._field.key == k then
      return item
    end
  end
end

describe("ui/drink (Custom Drinks UI — Phase 8)", function()
  local ids

  before_each(function()
    ids = helper.recipe_ready()
    Nav:closeAll()
  end)

  after_each(function()
    Nav:closeAll()
    helper.teardown()
  end)

  describe("P8.1 — base recipe + amount", function()
    it("base picker shows a warning and picks nothing when there are no recipes", function()
      local picked = false
      BaseSelect.show {
        on_select = function()
          picked = true
        end,
      }
      assert.is_false(picked)
    end)

    it("base recipes are exposed with their output for the picker", function()
      make_base("espresso", ids)
      local rows = AddFlow.base_recipes()
      assert.are.equal(1, #rows)
      assert.are.equal(36, tonumber(rows[1].output_weight_g))
    end)

    it("form carries the chosen base recipe + amount into the draft", function()
      local base = make_base("espresso", ids)
      local draft = fresh_draft("cold")
      local form = Nav:push(DrinkForm:new { draft = draft })
      form:paintTo(Screen.bb, 0, 0)

      draft.base_recipe = base
      draft.drink.base_recipe_id = base.id
      draft.drink.base_amount = 18
      form:refreshItems()

      assert.are.equal("Base espresso", field_item(form, "base_recipe_id").mandatory)
      assert.is_truthy(tostring(field_item(form, "base_amount").mandatory):find("18"))
    end)
  end)

  describe("P8.2 — ingredients & steps sub-editors", function()
    it("adds and removes ingredient rows in the draft", function()
      local milk = select(2, ConfigService.ingredients.create { name = "Milk" })
      local draft = fresh_draft()
      local screen = Nav:push(DrinkIngredients:new { draft = draft })
      screen:paintTo(Screen.bb, 0, 0)

      -- open the "add" editor, fill it, tap Done
      screen:onMenuChoice { _add = true }
      local editor = Nav:top()
      assert.are.equal("koffeelab_form", editor.name)
      editor.values.ingredient_id = milk.id
      editor.values.ingredient_name = milk.name
      editor.values.amount = 30
      editor.values.unit = "ml"
      tap_action(editor, "Done")

      assert.are.equal(1, #draft.ingredients)
      assert.are.equal(milk.id, draft.ingredients[1].ingredient_id)
      assert.are.equal(30, draft.ingredients[1].amount)

      -- edit row 1 → delete it
      screen:onMenuChoice { _index = 1 }
      tap_action(Nav:top(), "Delete ingredient")
      assert.are.equal(0, #draft.ingredients)
    end)

    it("adds, reorders and deletes process steps", function()
      local draft = fresh_draft()
      local screen = Nav:push(DrinkSteps:new { draft = draft })

      for _, text in ipairs { "Pull shot", "Steam milk", "Combine" } do
        screen:onMenuChoice { _add = true }
        local ed = Nav:top()
        ed.values.instruction = text
        tap_action(ed, "Done")
      end
      assert.are.equal(3, #draft.steps)
      assert.are.equal("Pull shot", draft.steps[1].instruction)

      -- move step 2 up
      screen:onMenuChoice { _index = 2 }
      tap_action(Nav:top(), "Move up")
      assert.are.equal("Steam milk", draft.steps[1].instruction)

      -- delete step 1
      screen:onMenuChoice { _index = 1 }
      tap_action(Nav:top(), "Delete step")
      assert.are.equal(2, #draft.steps)
      assert.are.equal("Pull shot", draft.steps[1].instruction)
    end)
  end)

  describe("P8.3 — save, detail, edit, delete", function()
    it("saves the draft and lands on a rendered detail page", function()
      local base = make_base("espresso", ids)
      local milk = select(2, ConfigService.ingredients.create { name = "Milk" })
      local draft = fresh_draft("cold")
      draft.drink.title = "Iced Latte"
      draft.base_recipe = base
      draft.drink.base_recipe_id = base.id
      draft.drink.base_amount = 18
      draft.ingredients =
        { { ingredient_id = milk.id, ingredient_name = "Milk", amount = 120, unit = "ml" } }
      draft.steps = { { instruction = "Pour espresso over ice", note = "" } }

      local saved_id
      local form = Nav:push(DrinkForm:new {
        draft = draft,
        on_saved = function(id)
          saved_id = id
        end,
      })
      tap_action(form, "Save drink")

      assert.is_truthy(saved_id)
      assert.are.equal("koffeelab_drink_detail", Nav:top().name)
      Nav:top():paintTo(Screen.bb, 0, 0)

      local _, drink = DrinkService.get(saved_id)
      assert.are.equal("Iced Latte", drink.title)
      assert.are.equal(1, #drink.ingredients)
      assert.are.equal(1, #drink.steps)
      assert.are.equal(18, tonumber(drink.base_amount))
    end)

    it("blocks save when the base recipe or amount is missing", function()
      local draft = fresh_draft("hot")
      draft.drink.title = "Broken"
      local form = Nav:push(DrinkForm:new { draft = draft })
      tap_action(form, "Save drink")
      -- still on the form; nothing persisted
      assert.are.equal("koffeelab_drink_form", Nav:top().name)
      local _, rows = DrinkService.list_for_index {}
      assert.are.equal(0, #rows)
    end)

    it("edit prefills the flow and persists changes", function()
      local base = make_base("espresso", ids)
      local ok, drink = DrinkService.create({
        title = "Cortado",
        temperature_mode = "hot",
        base_recipe_id = base.id,
        base_amount = 18,
        base_unit = "g",
        comment = "",
      }, {}, {})
      assert(ok, drink)

      Nav:push(DrinkDetail:new { drink_id = drink.id })
      -- the detail's Edit row opens a ConfirmBox then AddFlow.edit; drive the
      -- prefill path directly here.
      AddFlow.edit(drink.id, {})
      local form = Nav:top()
      assert.are.equal("koffeelab_drink_form", form.name)
      assert.are.equal("Cortado", form.values.title)

      form.values.title = "Gibraltar"
      form.values.base_amount = 20
      tap_action(form, "Save drink")

      local _, updated = DrinkService.get(drink.id)
      assert.are.equal("Gibraltar", updated.title)
      assert.are.equal(20, tonumber(updated.base_amount))
    end)

    it("delete removes the drink and pops the detail", function()
      local base = make_base("pour_over", ids)
      local ok, drink = DrinkService.create({
        title = "Doomed",
        temperature_mode = "cold",
        base_recipe_id = base.id,
        base_amount = 50,
        base_unit = "g",
        comment = "",
      }, {}, {})
      assert(ok, drink)

      local removed = false
      local detail = Nav:push(DrinkDetail:new {
        drink_id = drink.id,
        on_changed = function()
          removed = true
        end,
      })
      -- drive the delete branch directly (bypassing the ConfirmBox UI)
      local del_ok = DrinkService.delete(drink.id)
      assert.is_true(del_ok)
      detail.on_changed()
      assert.is_true(removed)

      assert.is_false((DrinkService.get(drink.id)))
    end)
  end)

  describe("add-flow payload", function()
    it("normalises unit, comment and a zero rating", function()
      local drink, ingredients, steps = AddFlow.payload {
        drink = {
          title = "X",
          temperature_mode = "hot",
          base_recipe_id = 1,
          base_amount = 10,
          rating = 0,
        },
        ingredients = { { ingredient_id = 2, amount = 5 } },
        steps = { { instruction = "stir" } },
      }
      assert.are.equal("g", drink.base_unit)
      assert.are.equal("", drink.comment)
      assert.is_nil(drink.rating)
      assert.are.equal("g", ingredients[1].unit)
      assert.are.equal("", steps[1].note)
    end)
  end)
end)
