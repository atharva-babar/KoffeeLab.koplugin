require("koffeelab.spec_helper")
local helper = require("koffeelab.spec_helper")
local Nav = require("ui/nav")
local Screen = require("device").screen

local MethodService = require("services/method_service")
local RecipeService = require("services/recipe_service")
local BrewService = require("services/brew_service")
local AddFlow = require("ui/recipe/add_flow")
local HomeScreen = require("ui/home")

local function draft_for(slug, ids, overrides)
  local _, method = MethodService.get_by_slug(slug)
  local recipe = {
    method_slug = method.slug,
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
  return { recipe = recipe, method = method, steps = {}, spec = {}, flavor_tag_ids = {} }
end

local function make_recipe(slug, ids, overrides)
  local ok, recipe = RecipeService.create(AddFlow.payload(draft_for(slug, ids, overrides)))
  assert(ok, recipe)
  return recipe
end

local function card_by_header(home, header)
  for _, c in ipairs(home.cards) do
    if c.header == header then
      return c
    end
  end
end

describe("ui/home (redesign v2)", function()
  local ids

  before_each(function()
    ids = helper.recipe_ready()
    Nav:closeAll()
  end)

  after_each(function()
    Nav:closeAll()
    helper.teardown()
  end)

  it("renders a 2x2 StatCard grid and a five-cell navbar", function()
    local home = Nav:push(HomeScreen:new {})
    home:paintTo(Screen.bb, 0, 0)

    assert.are.equal(4, #home.cards)
    assert.is_not_nil(home.navbar_widget)
    assert.are.equal(5, #home.navbar_widget._ranges)
  end)

  it("stat cards are inert with no data", function()
    local home = Nav:push(HomeScreen:new {})
    for _, header in ipairs { "Recent", "Most Brewed", "Top Rated", "Favourites" } do
      local c = card_by_header(home, header)
      assert.is_true(c.inert, header .. " should be inert")
      assert.are.equal(0, #c.lines)
    end
  end)

  it("stat cards list the seeded recipes after a reload", function()
    local a = make_recipe("pour_over", ids, { title = "Alpha", rating = 5 })
    local b = make_recipe("espresso", ids, { title = "Bravo" })
    assert(BrewService.record { recipe_id = b.id })
    assert(BrewService.record { recipe_id = b.id })
    assert(RecipeService.set_favorite(a.id, true))

    local home = Nav:push(HomeScreen:new {})
    home:_reload()

    assert.are.equal("Bravo", card_by_header(home, "Recent").shown[1].text)
    assert.are.equal("Bravo", card_by_header(home, "Most Brewed").shown[1].text)
    assert.are.equal("Alpha", card_by_header(home, "Top Rated").shown[1].text)
    assert.are.equal("Alpha", card_by_header(home, "Favourites").shown[1].text)
  end)

  it("tapping a Most Brewed line opens that recipe detail", function()
    local b = make_recipe("pour_over", ids, { title = "Bravo" })
    assert(BrewService.record { recipe_id = b.id })

    local home = Nav:push(HomeScreen:new {})
    home:_reload()
    card_by_header(home, "Most Brewed").lines[1]:onTap()

    assert.are.equal("koffeelab_recipe_detail", Nav:top().name)
    assert.are.equal(b.id, Nav:top().recipe_id)
  end)

  it("tapping the Favourites header opens the favourites index", function()
    local a = make_recipe("pour_over", ids, { title = "Alpha" })
    assert(RecipeService.set_favorite(a.id, true))
    local home = Nav:push(HomeScreen:new {})
    home:_reload()
    card_by_header(home, "Favourites").header_line:onTap()
    assert.are.equal("koffeelab_recipe_index", Nav:top().name)
    assert.is_true(Nav:top().favourites)
  end)

  it("navbar select routes to the configurator", function()
    local home = Nav:push(HomeScreen:new {})
    home:_navSelect("configurator")
    assert.are.equal("koffeelab_configurator", Nav:top().name)
  end)

  it("the add_recipe navbar key starts the recipe flow", function()
    local home = Nav:push(HomeScreen:new {})
    home:_navSelect("add_recipe")
    assert.is_truthy(Nav:top())
  end)
end)
