local helper = require("koffeelab.spec_helper")
local ConfigService = require("services/config_service")
local RecipeService = require("services/recipe_service")
local BrewService = require("services/brew_service")
local DrinkService = require("services/drink_service")
local MethodService = require("services/method_service")
local SearchService = require("services/search_service")
local MethodRepo = require("db/repo/method")

describe("services", function()
  local ids

  before_each(function()
    ids = helper.recipe_ready()
  end)

  after_each(function()
    helper.teardown()
  end)

  local function espresso_id()
    return assert(MethodRepo.get_by_slug("espresso")).id
  end

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
      local ok = ConfigService.grinders.create {
        name = "Bad",
        unit_name = "clicks",
        min_value = 30,
        max_value = 1,
        step_value = 1,
      }
      assert.is_false(ok)

      local ok2 = ConfigService.grinders.create {
        name = "Bad2",
        unit_name = "clicks",
        min_value = 1,
        max_value = 30,
        step_value = 0,
      }
      assert.is_false(ok2)
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
      local ok, err = RecipeService.create { title = "", method_id = ids.method_id, dose_g = 15 }
      assert.is_false(ok)
      assert.are.equal("title is required", err)
    end)

    it("rejects dose ≤ 0", function()
      local ok, err =
        RecipeService.create { title = "R", method_id = ids.method_id, dose_g = 0, water_g = 200 }
      assert.is_false(ok)
      assert.is_truthy(err:match("dose"))
    end)

    it("rejects a sensory axis outside 1..5", function()
      local ok = RecipeService.create {
        title = "R",
        method_id = ids.method_id,
        dose_g = 15,
        water_g = 200,
        acidity = 7,
      }
      assert.is_false(ok)
    end)

    it("requires total water except for espresso", function()
      local ok = RecipeService.create { title = "V60", method_id = ids.method_id, dose_g = 15 }
      assert.is_false(ok)

      local ok2 = RecipeService.create { title = "Shot", method_id = espresso_id(), dose_g = 18 }
      assert.is_true(ok2)
    end)

    it("enforces required method parameters", function()
      -- Make the pour_over dripper_type parameter required.
      local pour_over = assert(MethodRepo.get_by_slug("pour_over"))
      local param = pour_over.parameters[1]
      assert(MethodRepo.update_user_method(pour_over.id, {}, {
        parameters = {
          {
            key = param.key,
            label = param.label,
            data_type = param.data_type,
            required = true,
          },
        },
      }))

      local ok, err = RecipeService.create {
        title = "V60",
        method_id = pour_over.id,
        dose_g = 15,
        water_g = 250,
      }
      assert.is_false(ok)
      assert.is_truthy(err:match(param.label))
    end)

    it("rejects a step type foreign to the method", function()
      local ok, err = RecipeService.create(
        { title = "V60", method_id = ids.method_id, dose_g = 15, water_g = 250 },
        { { step_type = "extract", start_time_sec = 0 } }
      )
      assert.is_false(ok)
      assert.is_truthy(err:match("extract"))
    end)

    it("blocks deleting a recipe used by a custom drink", function()
      local created = select(
        2,
        RecipeService.create {
          title = "Base",
          method_id = espresso_id(),
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
          method_id = ids.method_id,
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
          method_id = ids.method_id,
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
          method_id = espresso_id(),
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
    it("creates a user method and refuses to change a system slug", function()
      assert(MethodService.create {
        slug = "moka_pot",
        name = "Moka Pot",
        step_types = { "setup", "extract", "finish" },
      })
      local pour_over = assert(select(2, MethodService.get_by_slug("pour_over")))
      local ok, err = MethodService.update(pour_over.id, { slug = "not_pour_over" })
      assert.is_false(ok)
      assert.is_truthy(err:match("slug"))
    end)
  end)

  describe("search_service", function()
    it("clamps an unknown sort to a safe default", function()
      assert(
        RecipeService.create { title = "A", method_id = ids.method_id, dose_g = 15, water_g = 200 }
      )
      local ok, rows = SearchService.recipes { sort = "'; DROP TABLE brew_recipes; --" }
      assert.is_true(ok)
      assert.are.equal(1, #rows)
    end)
  end)
end)
