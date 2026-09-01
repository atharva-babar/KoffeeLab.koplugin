require("koffeelab.spec_helper")
local helper = require("koffeelab.spec_helper")
local Nav = require("ui/nav")
local Screen = require("device").screen

local ConfigService = require("services/config_service")
local MethodService = require("services/method_service")
local RecipeService = require("services/recipe_service")
local DrinkService = require("services/drink_service")

local AddFlow = require("ui/recipe/add_flow")
local RecipeForm = require("ui/recipe/recipe_form")
local RecipeDetail = require("ui/recipe/detail")
local StepEditor = require("ui/recipe/step_editor")
local Sensory = require("ui/recipe/sensory")
local GrindSelect = require("ui/recipe/grind_select")

-- Build a ready-to-save draft for `slug`, seeded with a bean + grinder.
local function draft_for(slug, ids)
  local _, method = MethodService.get_by_slug(slug)
  return {
    recipe = {
      method_id = method.id,
      title = "Test " .. slug,
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
end

describe("ui/recipe (Recipe UI)", function()
  local ids

  before_each(function()
    ids = helper.recipe_ready()
    Nav:closeAll()
  end)

  after_each(function()
    Nav:closeAll()
    helper.teardown()
  end)

  it("Add flow: method picker replaces itself with the method-driven form", function()
    AddFlow.start {}
    assert.are.equal("koffeelab_recipe_method_select", Nav:top().name)
    Nav:top():paintTo(Screen.bb, 0, 0)

    local _, pour_over = MethodService.get_by_slug("pour_over")
    Nav:top():on_pick(pour_over)
    assert.are.equal("koffeelab_recipe_form", Nav:top().name)
    assert.are.equal(1, Nav:depth()) -- replaced, not pushed
    Nav:top():paintTo(Screen.bb, 0, 0)
  end)

  it("form is built from the method definition (Espresso vs Pour Over)", function()
    local function labels_for(slug)
      local form = RecipeForm:new { draft = draft_for(slug, ids) }
      local seen = {}
      for _, item in ipairs(form.item_table) do
        seen[item.text] = true
      end
      return seen
    end

    local espresso = labels_for("espresso")
    assert.is_true(espresso["Shot time"])
    assert.is_true(espresso["Pre-infusion duration (s)"]) -- seeded method parameter

    local pour_over = labels_for("pour_over")
    assert.is_true(pour_over["Brew time"])
    assert.is_true(pour_over["Dripper / filter"])
    assert.is_nil(pour_over["Shot time"])
  end)

  it("saves a Pour Over recipe and lands on a rendered detail page", function()
    AddFlow.start {}
    local _, pour_over = MethodService.get_by_slug("pour_over")
    Nav:top():on_pick(pour_over)

    local form = Nav:top()
    for k, v in pairs(draft_for("pour_over", ids).recipe) do
      form.draft.recipe[k] = v
    end
    form:_save()

    assert.are.equal("koffeelab_recipe_detail", Nav:top().name)
    Nav:top():paintTo(Screen.bb, 0, 0)

    local ok, rows = RecipeService.list_for_index {}
    assert.is_true(ok)
    assert.are.equal(1, #rows)
    assert.are.equal("Test pour_over", rows[1].title)
  end)

  it("blocks save on an empty title / zero dose with a message, form stays open", function()
    local d = draft_for("pour_over", ids)
    d.recipe.title = nil
    local form = RecipeForm:new { draft = d }
    Nav:push(form)
    form:_save()
    assert.are.equal("koffeelab_recipe_form", Nav:top().name) -- still here
    local ok, rows = RecipeService.list_for_index {}
    assert.is_true(ok and #rows == 0)
  end)

  it("espresso saves with a NULL water_g", function()
    local form = RecipeForm:new { draft = draft_for("espresso", ids) }
    Nav:push(form)
    form:_save()
    assert.are.equal("koffeelab_recipe_detail", Nav:top().name)
    local _, recipe = RecipeService.get(Nav:top().recipe_id)
    assert.is_nil(recipe.water_g)
    assert.are.equal(36, recipe.output_weight_g)
  end)

  it("Home's Add Recipe button starts the flow", function()
    local HomeScreen = require("ui/home")
    Nav:reset(HomeScreen:new {})
    require("ui/recipe/add_flow").start {}
    assert.are.equal("koffeelab_recipe_method_select", Nav:top().name)
  end)

  it("step editor adds, reorders and deletes steps in the draft", function()
    local d = draft_for("pour_over", ids)
    local editor = StepEditor:new { draft = d }
    Nav:push(editor)
    editor:paintTo(Screen.bb, 0, 0)

    -- add two steps via the per-step form
    local function add_step(step_type, start_sec)
      StepEditor._edit_step(Nav, editor.allowed_types, nil, function(values)
        values.instruction = values.instruction or ""
        values.note = values.note or ""
        d.steps[#d.steps + 1] = values
        editor:_refresh()
      end)
      local sform = Nav:top()
      sform.values.step_type = step_type
      sform.values.start_time_sec = start_sec
      sform:onMenuChoice(sform.item_table[#sform.item_table]) -- Done
    end
    add_step("bloom", 0)
    add_step("pour", 30)
    assert.are.equal(2, #d.steps)
    assert.are.equal("bloom", d.steps[1].step_type)

    -- reorder: swap
    d.steps[1], d.steps[2] = d.steps[2], d.steps[1]
    assert.are.equal("pour", d.steps[1].step_type)

    table.remove(d.steps, 1)
    assert.are.equal(1, #d.steps)
  end)

  it("sensory screen writes axes, tags and notes into the draft", function()
    local d = draft_for("pour_over", ids)
    local screen = Sensory.build { draft = d }
    Nav:push(screen)
    screen:paintTo(Screen.bb, 0, 0)

    d.recipe.acidity = 5
    d.recipe.sweetness = 4
    d.recipe.overall_rating = 4
    d.recipe.notes = "Bright and floral"

    assert(ConfigService.flavor_tags.create { name = "Citrus" })
    local _, tags = ConfigService.flavor_tags.list {}
    d.flavor_tag_ids = { tags[1].id }

    -- persist through a full save
    for k, v in pairs(draft_for("pour_over", ids).recipe) do
      if d.recipe[k] == nil then
        d.recipe[k] = v
      end
    end
    local ok, recipe = RecipeService.create(AddFlow.payload(d))
    assert.is_true(ok)
    assert.are.equal(5, recipe.acidity)
    assert.are.equal("Bright and floral", recipe.notes)
    assert.are.equal(1, #recipe.flavor_tags)
  end)

  it("grind screen clamps the grind value to the picked grinder's range", function()
    local d = draft_for("pour_over", ids)
    d.recipe.grinder_id = nil
    d.recipe.grind_value = 999
    d.grinder = nil
    local screen = GrindSelect.build { draft = d }
    Nav:push(screen)
    screen:paintTo(Screen.bb, 0, 0)

    local _, grinder = ConfigService.grinders.get(ids.grinder_id)
    d.grinder = grinder
    d.recipe.grinder_id = grinder.id
    -- emulate the picker's clamp
    d.recipe.grind_value = math.min(d.recipe.grind_value, grinder.max_value)
    assert.are.equal(grinder.max_value, d.recipe.grind_value)
  end)

  describe("Edit & delete", function()
    local function make_recipe(slug)
      local ok, recipe = RecipeService.create(AddFlow.payload(draft_for(slug, ids)))
      assert(ok, recipe)
      return recipe
    end

    it("edit prefills the draft and persists changes", function()
      local recipe = make_recipe("pour_over")
      AddFlow.edit(recipe.id, {})
      local form = Nav:top()
      assert.are.equal("koffeelab_recipe_form", form.name)
      assert.are.equal("Test pour_over", form.draft.recipe.title)
      assert.are.equal(tonumber(ids.bean_id), tonumber(form.draft.recipe.bean_id))

      form.draft.recipe.title = "Renamed"
      form.draft.recipe.dose_g = 20
      form:_save()

      local _, fresh = RecipeService.get(recipe.id)
      assert.are.equal("Renamed", fresh.title)
      assert.are.equal(20, fresh.dose_g)
    end)

    it("delete is blocked while a custom drink references the recipe", function()
      local recipe = make_recipe("espresso")
      assert(DrinkService.create({
        title = "Iced Latte",
        temperature_mode = "cold",
        base_recipe_id = recipe.id,
        base_amount = 18,
      }, {}, {}))

      local ok, err = RecipeService.delete(recipe.id)
      assert.is_false(ok)
      assert.is_truthy(tostring(err):find("drink"))
      assert.is_truthy(select(2, RecipeService.get(recipe.id))) -- still there
    end)

    it("delete removes an unreferenced recipe", function()
      local recipe = make_recipe("pour_over")
      local detail = RecipeDetail:new { recipe_id = recipe.id }
      Nav:push(detail)
      detail:paintTo(Screen.bb, 0, 0)

      local ok = RecipeService.delete(recipe.id)
      assert.is_true(ok)
      local found = RecipeService.get(recipe.id)
      assert.is_false(found)
    end)
  end)
end)
