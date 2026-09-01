local helper = require("koffeelab.spec_helper")
local Recipe = require("db/repo/recipe")
local Drink = require("db/repo/drink")
local Config = require("db/repo/config")
local Method = require("db/repo/method")

describe("db/repo/drink", function()
  local base

  before_each(function()
    helper.recipe_ready()
    local espresso = assert(Method.get_by_slug("espresso"))
    base = assert(Recipe.create {
      title = "Dark Crema",
      method_id = espresso.id,
      dose_g = 18,
      output_weight_g = 36,
    })
  end)

  after_each(function()
    helper.teardown()
  end)

  it("round-trips a drink with three ingredients and steps", function()
    local milk = assert(Config.ingredients.create { name = "Milk" })
    local ice = assert(Config.ingredients.create { name = "Ice" })
    local syrup = assert(Config.ingredients.create { name = "Vanilla syrup" })

    local drink = assert(Drink.create({
      title = "Iced Latte",
      temperature_mode = "cold",
      base_recipe_id = base.id,
      base_amount = 18,
      base_unit = "g",
      rating = 4,
    }, {
      { ingredient_id = milk.id, amount = 150, unit = "ml" },
      { ingredient_id = ice.id, amount = 80, unit = "g" },
      { ingredient_id = syrup.id, amount = 10, unit = "ml" },
    }, {
      { instruction = "Pull the shot over ice" },
      { instruction = "Top with milk", note = "cold, not steamed" },
    }))

    assert.are.equal(3, #drink.ingredients)
    assert.are.equal("Milk", drink.ingredients[1].ingredient_name)
    assert.are.equal(2, #drink.steps)
    assert.are.equal(36, tonumber(drink.base_recipe.output_weight_g))
  end)

  it("index filters by temperature mode and by ingredient", function()
    local milk = assert(Config.ingredients.create { name = "Milk" })
    local tonic = assert(Config.ingredients.create { name = "Tonic" })
    assert(Drink.create({
      title = "Hot Latte",
      temperature_mode = "hot",
      base_recipe_id = base.id,
      base_amount = 18,
    }, { { ingredient_id = milk.id, amount = 150, unit = "ml" } }))
    assert(Drink.create({
      title = "Espresso Tonic",
      temperature_mode = "cold",
      base_recipe_id = base.id,
      base_amount = 18,
    }, { { ingredient_id = tonic.id, amount = 120, unit = "ml" } }))

    assert.are.equal(2, #Drink.list_for_index())
    assert.are.equal(1, #Drink.list_for_index { temperature_mode = "cold" })
    local milky = Drink.list_for_index { ingredient_id = milk.id }
    assert.are.equal(1, #milky)
    assert.are.equal("Hot Latte", milky[1].title)
  end)

  it("count_referencing_recipe tracks base-recipe use", function()
    assert.are.equal(0, Drink.count_referencing_recipe(base.id))
    assert(Drink.create {
      title = "L",
      temperature_mode = "hot",
      base_recipe_id = base.id,
      base_amount = 18,
    })
    assert.are.equal(1, Drink.count_referencing_recipe(base.id))
  end)

  it("delete cascades ingredients and steps", function()
    local milk = assert(Config.ingredients.create { name = "Milk" })
    local drink = assert(
      Drink.create(
        { title = "L", temperature_mode = "hot", base_recipe_id = base.id, base_amount = 18 },
        { { ingredient_id = milk.id, amount = 150, unit = "ml" } }
      )
    )
    assert(Drink.delete(drink.id))
    assert.is_nil(Drink.get(drink.id))
  end)
end)
