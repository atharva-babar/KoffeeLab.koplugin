local helper = require("koffeelab.spec_helper")
local Recipe = require("db/repo/recipe")
local Session = require("db/repo/session")
local Config = require("db/repo/config")

describe("db/repo/recipe", function()
  local ids

  before_each(function()
    ids = helper.recipe_ready()
  end)

  after_each(function()
    helper.teardown()
  end)

  it("round-trips a recipe with spec, steps and tags via JSON columns", function()
    local tag = assert(Config.flavor_tags.create { name = "Floral" })
    local recipe = assert(Recipe.create({
      title = "Ethiopia Guji V60",
      method_slug = ids.method_slug,
      bean_id = ids.bean_id,
      grinder_id = ids.grinder_id,
      grind_value = 18,
      dose_g = 15,
      water_g = 250,
      water_temp_c = 93.5,
      acidity = 4,
      output_note = "sweet, tea-like",
      spec = { dripper = "V60" },
      steps = {
        { step_type = "bloom", start_time = 0, water = 50 },
        { step_type = "pour", start_time = 45, water = 200 },
      },
    }, { tag.id }))

    assert.are.equal("Ethiopia Guji V60", recipe.title)
    assert.are.equal(2, #recipe.steps)
    assert.are.equal("bloom", recipe.steps[1].step_type)
    assert.are.equal("V60", recipe.spec.dripper)
    assert.are.equal("sweet, tea-like", recipe.output_note)
    assert.are.equal(1, #recipe.flavor_tags)
    assert.are.equal(0, recipe.stats.brew_count)

    local fetched = assert(Recipe.get(recipe.id))
    assert.are.equal(93.5, fetched.water_temp_c)
    assert.are.equal(200, fetched.steps[2].water)
  end)

  it("update replaces the step set and spec", function()
    local recipe = assert(Recipe.create {
      title = "R",
      method_slug = ids.method_slug,
      dose_g = 15,
      spec = { dripper = "V60" },
      steps = { { step_type = "bloom", start_time = 0 }, { step_type = "pour", start_time = 30 } },
    })
    local updated = assert(Recipe.update(recipe.id, {
      title = "R2",
      spec = { dripper = "Origami" },
      steps = { { step_type = "pour", start_time = 0 } },
    }))
    assert.are.equal("R2", updated.title)
    assert.are.equal(1, #updated.steps)
    assert.are.equal("Origami", updated.spec.dripper)
  end)

  it("keeps steps and spec when update omits them", function()
    local recipe = assert(Recipe.create {
      title = "R",
      method_slug = ids.method_slug,
      dose_g = 15,
      spec = { dripper = "V60" },
      steps = { { step_type = "bloom", start_time = 0 } },
    })
    local updated = assert(Recipe.update(recipe.id, { title = "R2" }))
    assert.are.equal(1, #updated.steps)
    assert.are.equal("V60", updated.spec.dripper)
  end)

  it("list_for_index filters by method_slug, favorite and search, and sorts", function()
    assert(Recipe.create {
      title = "Ethiopia Guji",
      method_slug = "pour_over",
      dose_g = 15,
      overall_rating = 3,
    })
    local fav = assert(Recipe.create {
      title = "Colombia Huila",
      method_slug = "pour_over",
      dose_g = 15,
      overall_rating = 5,
    })
    assert(Recipe.set_favorite(fav.id, true))
    assert(Recipe.create { title = "Dark Crema", method_slug = "espresso", dose_g = 18 })

    assert.are.equal(3, #Recipe.list_for_index())
    assert.are.equal(2, #Recipe.list_for_index { method_slug = "pour_over" })
    assert.are.equal(1, #Recipe.list_for_index { favorite = true })

    local hits = Recipe.list_for_index { search = "ethio" }
    assert.are.equal(1, #hits)
    assert.are.equal("Ethiopia Guji", hits[1].title)

    local by_rating = Recipe.list_for_index { sort = "rating" }
    assert.are.equal("Colombia Huila", by_rating[1].title)
  end)

  it("recipe_stats reflect sessions after they are added", function()
    local recipe = assert(Recipe.create { title = "R", method_slug = ids.method_slug, dose_g = 15 })
    assert(Session.create { recipe_id = recipe.id, session_rating = 4 })
    assert(Session.create { recipe_id = recipe.id, session_rating = 5 })

    local row
    for _, r in ipairs(Recipe.list_for_index()) do
      if r.id == recipe.id then
        row = r
      end
    end
    assert.are.equal(2, tonumber(row.brew_count))
    assert.are.equal(4.5, tonumber(row.avg_session_rating))
  end)

  it("delete removes the recipe", function()
    local recipe = assert(Recipe.create { title = "R", method_slug = ids.method_slug, dose_g = 15 })
    assert(Recipe.delete(recipe.id))
    assert.is_nil(Recipe.get(recipe.id))
  end)
end)
