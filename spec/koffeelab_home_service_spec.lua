require("koffeelab.spec_helper")
local helper = require("koffeelab.spec_helper")

local MethodService = require("services/method_service")
local RecipeService = require("services/recipe_service")
local BrewService = require("services/brew_service")
local AddFlow = require("ui/recipe/add_flow")
local HomeService = require("services/home_service")

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

describe("services/home_service", function()
  local ids

  before_each(function()
    ids = helper.recipe_ready()
  end)

  after_each(function()
    helper.teardown()
  end)

  it("returns nil for every card on a fresh database", function()
    assert.is_nil(HomeService.recent())
    assert.is_nil(HomeService.most_brewed())
    assert.is_nil(HomeService.top_rated())
    assert.are.equal(0, HomeService.favourites_count())
  end)

  it("recent() is nil until a recipe has been brewed", function()
    make_recipe("pour_over", ids)
    assert.is_nil(HomeService.recent())
    assert.is_nil(HomeService.most_brewed())
  end)

  it("recent() is the most recently brewed recipe", function()
    local a = make_recipe("pour_over", ids, { title = "Alpha" })
    local b = make_recipe("espresso", ids, { title = "Bravo" })
    assert(BrewService.record { recipe_id = a.id })
    assert(BrewService.record { recipe_id = b.id })
    local r = HomeService.recent()
    assert.is_not_nil(r)
    assert.are.equal("Bravo", r.title)
    assert.are.equal("Espresso", r.method_name)
  end)

  it("most_brewed() ranks by brew count", function()
    local a = make_recipe("pour_over", ids, { title = "Alpha" })
    local b = make_recipe("pour_over", ids, { title = "Bravo" })
    assert(BrewService.record { recipe_id = a.id })
    assert(BrewService.record { recipe_id = b.id })
    assert(BrewService.record { recipe_id = b.id })
    assert.are.equal("Bravo", HomeService.most_brewed().title)
  end)

  it("top_rated() prefers a catalogue rating", function()
    make_recipe("pour_over", ids, { title = "Unrated" })
    make_recipe("pour_over", ids, { title = "Rated", rating = 5 })
    assert.are.equal("Rated", HomeService.top_rated().title)
  end)

  it("favourites_count() tracks the is_favorite flag", function()
    local a = make_recipe("pour_over", ids)
    assert.are.equal(0, HomeService.favourites_count())
    assert(RecipeService.set_favorite(a.id, true))
    assert.are.equal(1, HomeService.favourites_count())
  end)
end)
