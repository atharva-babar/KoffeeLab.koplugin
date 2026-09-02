local helper = require("koffeelab.spec_helper")
local Recipe = require("db/repo/recipe")
local Session = require("db/repo/session")

describe("db/repo/session", function()
  local recipe

  before_each(function()
    local ids = helper.recipe_ready()
    recipe = assert(Recipe.create { title = "R", method_slug = ids.method_slug, dose_g = 15 })
  end)

  after_each(function()
    helper.teardown()
  end)

  it("inserts sessions and derives count / average from the view", function()
    assert(Session.create { recipe_id = recipe.id, session_rating = 4, comment = "bright" })
    assert(Session.create { recipe_id = recipe.id, session_rating = 5 })

    local stats = Session.stats(recipe.id)
    assert.are.equal(2, tonumber(stats.brew_count))
    assert.are.equal(4.5, tonumber(stats.avg_session_rating))
  end)

  it("allows null rating / time / comment", function()
    local s = assert(Session.create { recipe_id = recipe.id })
    assert.is_nil(s.session_rating)
    assert.is_nil(s.measured_brew_time_sec)
    assert.are.equal("", s.comment)
  end)

  it("lists sessions newest first and deletes one", function()
    local a = assert(Session.create { recipe_id = recipe.id, brewed_at = 1000 })
    local b = assert(Session.create { recipe_id = recipe.id, brewed_at = 2000 })
    local list = Session.list_for_recipe(recipe.id)
    assert.are.equal(b.id, list[1].id)
    assert.are.equal(a.id, list[2].id)

    assert(Session.delete(b.id))
    assert.are.equal(1, tonumber(Session.stats(recipe.id).brew_count))
  end)

  it("returns zeroed stats for a recipe with no sessions", function()
    local stats = Session.stats(recipe.id)
    assert.are.equal(0, tonumber(stats.brew_count))
    assert.is_nil(stats.avg_session_rating)
  end)
end)
