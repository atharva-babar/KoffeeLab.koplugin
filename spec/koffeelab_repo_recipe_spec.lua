local helper = require("koffeelab.spec_helper")
local Recipe = require("db/repo/recipe")
local Session = require("db/repo/session")
local Config = require("db/repo/config")
local Method = require("db/repo/method")

describe("db/repo/recipe", function()
  local ids

  before_each(function()
    ids = helper.recipe_ready()
  end)

  after_each(function()
    helper.teardown()
  end)

  local function param_id(slug, key)
    local m = assert(Method.get_by_slug(slug))
    for _, p in ipairs(m.parameters) do
      if p.key == key then
        return p.id
      end
    end
    error("no param " .. key)
  end

  it("round-trips a multi-step recipe with params and tags", function()
    local tag = assert(Config.flavor_tags.create { name = "Floral" })
    local recipe = assert(
      Recipe.create(
        {
          title = "Ethiopia Guji V60",
          method_id = ids.method_id,
          bean_id = ids.bean_id,
          grinder_id = ids.grinder_id,
          grind_value = 18,
          dose_g = 15,
          water_g = 250,
          water_temp_c = 93.5,
          acidity = 4,
        },
        {
          { step_type = "bloom", start_time_sec = 0, duration_sec = 30, target_water_g = 50 },
          { step_type = "pour", start_time_sec = 30, target_total_water_g = 150 },
          { step_type = "finish", start_time_sec = 165 },
        },
        { { param_id = param_id("pour_over", "dripper_type"), value = "Hario V60 02" } },
        { tag.id }
      )
    )

    assert.are.equal("Ethiopia Guji V60", recipe.title)
    assert.are.equal(3, #recipe.steps)
    assert.are.equal("bloom", recipe.steps[1].step_type)
    assert.are.equal(1, #recipe.parameters)
    assert.are.equal("Hario V60 02", recipe.parameters[1].value)
    assert.are.equal(1, #recipe.flavor_tags)
    assert.are.equal(0, recipe.stats.brew_count)

    local fetched = assert(Recipe.get(recipe.id))
    assert.are.equal(93.5, fetched.water_temp_c)
  end)

  it("update replaces the step set without a unique-order collision", function()
    local recipe = assert(Recipe.create({ title = "R", method_id = ids.method_id, dose_g = 15 }, {
      { step_type = "bloom", start_time_sec = 0 },
      { step_type = "pour", start_time_sec = 30 },
      { step_type = "finish", start_time_sec = 60 },
    }))
    -- Reordered + one fewer step.
    local updated = assert(Recipe.update(recipe.id, { title = "R2" }, {
      { step_type = "pour", start_time_sec = 0 },
      { step_type = "bloom", start_time_sec = 30 },
    }))
    assert.are.equal("R2", updated.title)
    assert.are.equal(2, #updated.steps)
    assert.are.equal("pour", updated.steps[1].step_type)
    assert.are.equal(1, tonumber(updated.steps[1].step_order))
  end)

  it("list_for_index filters by method and search, and sorts", function()
    assert(Recipe.create {
      title = "Ethiopia Guji",
      method_id = ids.method_id,
      dose_g = 15,
      overall_rating = 3,
    })
    assert(Recipe.create {
      title = "Colombia Huila",
      method_id = ids.method_id,
      dose_g = 15,
      overall_rating = 5,
    })
    local espresso = assert(Method.get_by_slug("espresso"))
    assert(Recipe.create { title = "Dark Crema", method_id = espresso.id, dose_g = 18 })

    assert.are.equal(3, #Recipe.list_for_index())
    assert.are.equal(2, #Recipe.list_for_index { method_id = ids.method_id })

    local hits = Recipe.list_for_index { search = "ethio" }
    assert.are.equal(1, #hits)
    assert.are.equal("Ethiopia Guji", hits[1].title)

    local by_rating = Recipe.list_for_index { sort = "rating" }
    assert.are.equal("Colombia Huila", by_rating[1].title)
  end)

  it("recipe_stats reflect sessions after they are added", function()
    local recipe = assert(Recipe.create { title = "R", method_id = ids.method_id, dose_g = 15 })
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

  it("delete removes the recipe and cascades its children", function()
    local recipe = assert(Recipe.create({ title = "R", method_id = ids.method_id, dose_g = 15 }, {
      { step_type = "bloom", start_time_sec = 0 },
    }))
    assert(Recipe.delete(recipe.id))
    assert.is_nil(Recipe.get(recipe.id))
  end)
end)
