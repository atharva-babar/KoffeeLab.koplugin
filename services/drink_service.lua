-- services/drink_service.lua
-- Custom-drink validation (§3.14 Custom drink) and CRUD. temperature_mode is an
-- enum; the base recipe must exist; base_amount and every ingredient amount must be
-- positive / non-negative.

local DrinkRepo = require("db/repo/drink")
local RecipeRepo = require("db/repo/recipe")
local ConfigRepo = require("db/repo/config")
local Support = require("services/support")

local DrinkService = {}

local TEMPERATURE_MODES = { hot = true, cold = true }

local function validate(drink, ingredients)
  local bad = Support.check {
    { Support.is_nonempty_string(drink.title), "title is required" },
    { TEMPERATURE_MODES[drink.temperature_mode] == true, "choose hot or cold" },
    { drink.base_recipe_id ~= nil, "choose a base recipe" },
    {
      type(drink.base_amount) == "number" and drink.base_amount > 0,
      "base amount must be greater than 0",
    },
    { Support.is_rating_or_nil(drink.rating), "rating must be 1–5" },
  }
  if bad then
    return bad
  end
  if not RecipeRepo.get(drink.base_recipe_id) then
    return "base recipe no longer exists"
  end
  for i, ing in ipairs(ingredients or {}) do
    if ing.ingredient_id == nil or not ConfigRepo.ingredients.get(ing.ingredient_id) then
      return string.format("ingredient %d no longer exists", i)
    end
    if not (type(ing.amount) == "number" and ing.amount >= 0) then
      return string.format("ingredient %d: amount must be ≥ 0", i)
    end
    if not Support.is_nonempty_string(ing.unit) then
      return string.format("ingredient %d: unit is required", i)
    end
  end
end

function DrinkService.create(drink, ingredients, steps)
  drink = drink or {}
  local bad = validate(drink, ingredients)
  if bad then
    return Support.err(bad)
  end
  return Support.from_repo(DrinkRepo.create(drink, ingredients, steps))
end

function DrinkService.update(id, drink, ingredients, steps)
  local current = DrinkRepo.get(id)
  if not current then
    return Support.err("drink not found")
  end
  local candidate = {}
  for k, v in pairs(current) do
    candidate[k] = v
  end
  for k, v in pairs(drink or {}) do
    candidate[k] = v
  end
  local check_ingredients = ingredients
  if check_ingredients == nil then
    check_ingredients = current.ingredients
  end
  local bad = validate(candidate, check_ingredients)
  if bad then
    return Support.err(bad)
  end
  return Support.from_repo(DrinkRepo.update(id, drink or {}, ingredients, steps))
end

function DrinkService.get(id)
  local drink = DrinkRepo.get(id)
  if not drink then
    return Support.err("drink not found")
  end
  return Support.ok(drink)
end

function DrinkService.list_for_index(opts)
  return Support.ok(DrinkRepo.list_for_index(opts))
end

function DrinkService.delete(id)
  local ok, err = DrinkRepo.delete(id)
  if ok == nil then
    return Support.err(err or "database error")
  end
  if ok == false then
    return Support.err("drink not found")
  end
  return Support.ok(true)
end

return DrinkService
