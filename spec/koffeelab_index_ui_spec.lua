require("koffeelab.spec_helper")
local helper = require("koffeelab.spec_helper")
local Nav = require("ui/nav")
local Screen = require("device").screen

local ConfigService = require("services/config_service")
local MethodService = require("services/method_service")
local RecipeService = require("services/recipe_service")
local DrinkService = require("services/drink_service")
local AddFlow = require("ui/recipe/add_flow")

local IndexRoot = require("ui/index")
local RecipeIndex = require("ui/recipe/index")
local DrinkIndex = require("ui/drink/index")
local DrinkDetail = require("ui/drink/detail")

-- Minimal ready-to-save draft for `slug`.
local function draft_for(slug, ids, overrides)
  local _, method = MethodService.get_by_slug(slug)
  local recipe = {
    method_id = method.id,
    title = (overrides and overrides.title) or ("Test " .. slug),
    bean_id = ids.bean_id,
    grinder_id = ids.grinder_id,
    grind_value = 15,
    dose_g = 18,
    water_g = slug ~= "espresso" and 250 or nil,
    water_temp_c = 94,
    brew_time_sec = 165,
    output_weight_g = slug == "espresso" and 36 or 210,
    overall_rating = overrides and overrides.rating or nil,
    notes = "",
  }
  return { recipe = recipe, method = method, steps = {}, params = {}, flavor_tag_ids = {} }
end

local function make_recipe(slug, ids, overrides)
  local ok, recipe = RecipeService.create(AddFlow.payload(draft_for(slug, ids, overrides)))
  assert(ok, recipe)
  return recipe
end

-- Result rows carry `_recipe_id` / `_drink_id`; the leading rows are controls.
local function result_titles(screen, key)
  local out = {}
  for _, item in ipairs(screen.item_table) do
    if item[key] then
      out[#out + 1] = item.text
    end
  end
  return out
end

describe("ui index / search (Phase 6)", function()
  local ids

  before_each(function()
    ids = helper.recipe_ready()
    Nav:closeAll()
  end)

  after_each(function()
    Nav:closeAll()
    helper.teardown()
  end)

  it("Index root lists the two sections and opens each", function()
    local root = Nav:push(IndexRoot:new {})
    assert.are.equal(2, #root.item_table)
    root:paintTo(Screen.bb, 0, 0)

    root:onMenuChoice(root.item_table[1])
    assert.are.equal("koffeelab_recipe_index", Nav:top().name)
    Nav:pop()

    root:onMenuChoice(root.item_table[2])
    assert.are.equal("koffeelab_drink_index", Nav:top().name)
  end)

  describe("recipe index", function()
    it("lists every active recipe with a method / rating / brew-count note", function()
      make_recipe("pour_over", ids)
      make_recipe("espresso", ids)

      local screen = Nav:push(RecipeIndex:new {})
      screen:paintTo(Screen.bb, 0, 0)
      assert.are.equal(2, #result_titles(screen, "_recipe_id"))

      -- the note on a row renders the joined method name
      for _, item in ipairs(screen.item_table) do
        if item._recipe_id then
          assert.is_truthy(item.mandatory:find("brew"))
        end
      end
    end)

    it("filters by method", function()
      make_recipe("pour_over", ids)
      make_recipe("espresso", ids)
      local _, espresso = MethodService.get_by_slug("espresso")

      local screen = Nav:push(RecipeIndex:new {})
      screen.method_id = espresso.id
      screen:_refresh()

      local titles = result_titles(screen, "_recipe_id")
      assert.are.equal(1, #titles)
      assert.are.equal("Test espresso", titles[1])
    end)

    it("filters by a title substring and switches sort without error", function()
      make_recipe("pour_over", ids, { title = "Morning V60" })
      make_recipe("pour_over", ids, { title = "Afternoon Chemex" })

      local screen = Nav:push(RecipeIndex:new {})
      screen.search = "chemex"
      screen:_refresh()
      assert.are.same({ "Afternoon Chemex" }, result_titles(screen, "_recipe_id"))

      screen.sort = "title"
      screen:_refresh()
      assert.are.equal(1, #result_titles(screen, "_recipe_id"))
    end)

    it("opens the recipe detail when a result row is tapped", function()
      local recipe = make_recipe("pour_over", ids)
      local screen = Nav:push(RecipeIndex:new {})
      local tapped
      for _, item in ipairs(screen.item_table) do
        if item._recipe_id then
          tapped = item
        end
      end
      screen:onMenuChoice(tapped)
      assert.are.equal("koffeelab_recipe_detail", Nav:top().name)
      assert.are.equal(recipe.id, Nav:top().recipe_id)
      Nav:top():paintTo(Screen.bb, 0, 0)
    end)

    it("shows an empty-state row when nothing matches", function()
      local screen = Nav:push(RecipeIndex:new {})
      assert.are.equal(0, #result_titles(screen, "_recipe_id"))
      screen:paintTo(Screen.bb, 0, 0)
    end)
  end)

  describe("drink index", function()
    local function make_drink(fields, ingredients)
      local ok, drink = DrinkService.create(fields, ingredients or {}, {})
      assert(ok, drink)
      return drink
    end

    local function seed_drinks()
      local base = make_recipe("espresso", ids)
      local mok, milk = ConfigService.ingredients.create { name = "Milk" }
      assert(mok, milk)
      local iok, ice = ConfigService.ingredients.create { name = "Ice" }
      assert(iok, ice)
      make_drink({
        title = "Flat White",
        temperature_mode = "hot",
        base_recipe_id = base.id,
        base_amount = 36,
        rating = 4,
      }, { { ingredient_id = milk.id, amount = 120, unit = "ml" } })
      make_drink({
        title = "Iced Latte",
        temperature_mode = "cold",
        base_recipe_id = base.id,
        base_amount = 36,
      }, {
        { ingredient_id = milk.id, amount = 150, unit = "ml" },
        { ingredient_id = ice.id, amount = 80, unit = "g" },
      })
      return { milk = milk, ice = ice, base = base }
    end

    it("lists drinks and filters by temperature", function()
      seed_drinks()
      local screen = Nav:push(DrinkIndex:new {})
      screen:paintTo(Screen.bb, 0, 0)
      assert.are.equal(2, #result_titles(screen, "_drink_id"))

      screen.temperature_mode = "cold"
      screen:_refresh()
      assert.are.same({ "Iced Latte" }, result_titles(screen, "_drink_id"))
    end)

    it("filters by an ingredient", function()
      local seeded = seed_drinks()
      local screen = Nav:push(DrinkIndex:new {})
      screen.ingredient_id = seeded.ice.id
      screen:_refresh()
      assert.are.same({ "Iced Latte" }, result_titles(screen, "_drink_id"))
    end)

    it("opens the drink detail when a result row is tapped", function()
      local seeded = seed_drinks()
      local screen = Nav:push(DrinkIndex:new {})
      local tapped
      for _, item in ipairs(screen.item_table) do
        if item._drink_id then
          tapped = item
        end
      end
      screen:onMenuChoice(tapped)
      assert.are.equal("koffeelab_drink_detail", Nav:top().name)
      Nav:top():paintTo(Screen.bb, 0, 0)
      assert.is_truthy(seeded)
    end)
  end)

  it("drink detail renders base recipe, amount and derived remaining", function()
    local base = make_recipe("espresso", ids) -- output 36 g
    local ok, drink = DrinkService.create({
      title = "Cortado",
      temperature_mode = "hot",
      base_recipe_id = base.id,
      base_amount = 20,
    }, {}, {})
    assert(ok, drink)

    local detail = Nav:push(DrinkDetail:new { drink_id = drink.id })
    detail:paintTo(Screen.bb, 0, 0)
    local seen = {}
    for _, item in ipairs(detail.item_table) do
      seen[item.text] = item.mandatory
    end
    assert.are.equal("Test espresso", seen["Base recipe"])
    assert.is_truthy(seen["Remaining of batch"]:find("16")) -- 36 - 20
  end)
end)
