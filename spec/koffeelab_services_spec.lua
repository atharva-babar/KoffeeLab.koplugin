local helper = require("koffeelab.spec_helper")
local ConfigService = require("services/config_service")
local RecipeService = require("services/recipe_service")
local BrewService = require("services/brew_service")
local DrinkService = require("services/drink_service")
local MethodService = require("services/method_service")
local SearchService = require("services/search_service")

describe("services", function()
  local ids

  before_each(function()
    ids = helper.recipe_ready()
  end)

  after_each(function()
    helper.teardown()
  end)

  describe("config_service", function()
    it("rejects an empty bean name and blocks hard delete", function()
      local ok, err = ConfigService.beans.create { name = "   " }
      assert.is_false(ok)
      assert.is_truthy(err)

      local blocked, msg = ConfigService.beans.delete(1)
      assert.is_false(blocked)
      assert.is_truthy(msg:match("disabled"))
    end)

    it("enforces grinder min ≤ max and step > 0", function()
      assert.is_false((ConfigService.grinders.create {
        name = "Bad",
        unit_name = "clicks",
        min_value = 30,
        max_value = 1,
        step_value = 1,
      }))
      assert.is_false((ConfigService.grinders.create {
        name = "Bad2",
        unit_name = "clicks",
        min_value = 1,
        max_value = 30,
        step_value = 0,
      }))
    end)

    it("surfaces the duplicate-ingredient error from the repo", function()
      assert(select(2, ConfigService.ingredients.create { name = "Milk" }))
      local ok, err = ConfigService.ingredients.create { name = "Milk" }
      assert.is_false(ok)
      assert.is_truthy(err)
    end)
  end)

  describe("recipe_service", function()
    it("rejects an empty title", function()
      local ok, err =
        RecipeService.create { title = "", method_slug = ids.method_slug, dose_g = 15 }
      assert.is_false(ok)
      assert.are.equal("title is required", err)
    end)

    it("rejects an unknown method", function()
      local ok, err = RecipeService.create { title = "R", method_slug = "chemex_pro", dose_g = 15 }
      assert.is_false(ok)
      assert.is_truthy(err:match("brew method"))
    end)

    it("rejects dose ≤ 0", function()
      local ok = RecipeService.create {
        title = "R",
        method_slug = ids.method_slug,
        dose_g = 0,
        water_g = 200,
      }
      assert.is_false(ok)
    end)

    it("rejects a sensory axis outside 1..5", function()
      assert.is_false((RecipeService.create {
        title = "R",
        method_slug = ids.method_slug,
        dose_g = 15,
        water_g = 200,
        acidity = 7,
      }))
    end)

    it("requires total water for pour over but not espresso", function()
      assert.is_false(
        (RecipeService.create { title = "V60", method_slug = "pour_over", dose_g = 15 })
      )
      assert.is_true((RecipeService.create {
        title = "Shot",
        method_slug = "espresso",
        dose_g = 18,
        output_weight_g = 36,
      }))
    end)

    it("rejects an invalid enum value for a method parameter", function()
      local ok, err = RecipeService.create(
        { title = "V60", method_slug = "pour_over", dose_g = 15, water_g = 250 },
        nil,
        { dripper = "Not a real dripper" }
      )
      assert.is_false(ok)
      assert.is_truthy(err:match("Dripper"))
    end)

    it("rejects a step type foreign to the method", function()
      local ok, err = RecipeService.create(
        { title = "V60", method_slug = "pour_over", dose_g = 15, water_g = 250 },
        { { step_type = "extract", start_time = 0 } }
      )
      assert.is_false(ok)
      assert.is_truthy(err:match("extract"))
    end)

    it("stores and reads back method spec and steps", function()
      local ok, recipe = RecipeService.create(
        { title = "V60", method_slug = "pour_over", dose_g = 15, water_g = 250 },
        { { step_type = "bloom", start_time = 0, water = 45 } },
        { dripper = "Origami" }
      )
      assert.is_true(ok)
      local got = select(2, RecipeService.get(recipe.id))
      assert.are.equal("Origami", got.spec.dripper)
      assert.are.equal(45, got.steps[1].water)
      assert.are.equal("Pour Over", got.method_name)
    end)

    it("toggles the favourite flag", function()
      local recipe = select(
        2,
        RecipeService.create { title = "R", method_slug = "pour_over", dose_g = 15, water_g = 200 }
      )
      assert(RecipeService.set_favorite(recipe.id, true))
      assert.are.equal(1, #select(2, SearchService.recipes { favorite = true }))
    end)

    it("blocks deleting a recipe used by a custom drink", function()
      local created = select(
        2,
        RecipeService.create {
          title = "Base",
          method_slug = "espresso",
          dose_g = 18,
          output_weight_g = 36,
        }
      )
      assert(DrinkService.create {
        title = "Latte",
        temperature_mode = "hot",
        base_recipe_id = created.id,
        base_amount = 18,
      })
      local ok, err = RecipeService.delete(created.id)
      assert.is_false(ok)
      assert.is_truthy(err:match("1 custom drink"))
    end)

    it("deletes an unreferenced recipe", function()
      local created = select(
        2,
        RecipeService.create {
          title = "Lonely",
          method_slug = ids.method_slug,
          dose_g = 15,
          water_g = 200,
        }
      )
      assert.is_true((RecipeService.delete(created.id)))
    end)
  end)

  describe("brew_service", function()
    local recipe_id

    before_each(function()
      recipe_id = select(
        2,
        RecipeService.create {
          title = "R",
          method_slug = ids.method_slug,
          dose_g = 15,
          water_g = 200,
        }
      ).id
    end)

    it("records a session and reflects it in stats", function()
      assert(BrewService.record { recipe_id = recipe_id, session_rating = 4 })
      assert(BrewService.record { recipe_id = recipe_id, session_rating = 5 })
      local stats = select(2, BrewService.stats(recipe_id))
      assert.are.equal(2, tonumber(stats.brew_count))
      assert.are.equal(4.5, tonumber(stats.avg_session_rating))
    end)

    it("rejects an out-of-range rating and a negative measured time", function()
      assert.is_false((BrewService.record { recipe_id = recipe_id, session_rating = 9 }))
      assert.is_false((BrewService.record { recipe_id = recipe_id, measured_brew_time_sec = -5 }))
    end)
  end)

  describe("drink_service", function()
    local base_id

    before_each(function()
      base_id = select(
        2,
        RecipeService.create {
          title = "Base",
          method_slug = "espresso",
          dose_g = 18,
          output_weight_g = 36,
        }
      ).id
    end)

    it("rejects a bad temperature_mode and base_amount ≤ 0", function()
      assert.is_false((DrinkService.create {
        title = "D",
        temperature_mode = "lukewarm",
        base_recipe_id = base_id,
        base_amount = 18,
      }))
      assert.is_false((DrinkService.create {
        title = "D",
        temperature_mode = "hot",
        base_recipe_id = base_id,
        base_amount = 0,
      }))
    end)

    it("creates a valid drink", function()
      local milk = select(2, ConfigService.ingredients.create { name = "Milk" })
      assert(DrinkService.create({
        title = "Latte",
        temperature_mode = "hot",
        base_recipe_id = base_id,
        base_amount = 18,
      }, { { ingredient_id = milk.id, amount = 150, unit = "ml" } }))
      assert.are.equal(1, #select(2, DrinkService.list_for_index()))
    end)
  end)

  describe("method_service", function()
    it("lists the built-in methods and rejects unknown slugs", function()
      assert.are.equal(5, #select(2, MethodService.list()))
      assert.is_false((MethodService.get("moka_pot")))
      assert.are.equal("Espresso", select(2, MethodService.get("espresso")).name)
    end)
  end)

  describe("search_service", function()
    it("clamps an unknown sort to a safe default", function()
      assert(RecipeService.create {
        title = "A",
        method_slug = ids.method_slug,
        dose_g = 15,
        water_g = 200,
      })
      local ok, rows = SearchService.recipes { sort = "'; DROP TABLE brew_recipes; --" }
      assert.is_true(ok)
      assert.are.equal(1, #rows)
    end)
  end)
end)
