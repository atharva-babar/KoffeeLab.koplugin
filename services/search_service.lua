-- services/search_service.lua
-- One entry point for the two index screens (§1.21, §2.14). It normalises the
-- caller's filter/sort options and delegates to the recipe / drink repos, which own
-- the LIKE-escaped, parameterised queries.

local RecipeRepo = require("db/repo/recipe")
local DrinkRepo = require("db/repo/drink")
local Support = require("services/support")

local SearchService = {}

SearchService.RECIPE_SORTS = { "rating", "brew_count", "title", "updated" }
SearchService.DRINK_SORTS = { "rating", "title", "updated" }

local function allowed(list, value, fallback)
  for _, v in ipairs(list) do
    if v == value then
      return value
    end
  end
  return fallback
end

--- @param opts { method_id?, search?, sort? }
function SearchService.recipes(opts)
  opts = opts or {}
  return Support.ok(RecipeRepo.list_for_index {
    method_id = opts.method_id,
    search = opts.search,
    sort = allowed(SearchService.RECIPE_SORTS, opts.sort, "updated"),
  })
end

--- @param opts { temperature_mode?, ingredient_id?, search?, sort? }
function SearchService.drinks(opts)
  opts = opts or {}
  local mode = opts.temperature_mode
  if mode ~= "hot" and mode ~= "cold" then
    mode = nil
  end
  return Support.ok(DrinkRepo.list_for_index {
    temperature_mode = mode,
    ingredient_id = opts.ingredient_id,
    search = opts.search,
    sort = allowed(SearchService.DRINK_SORTS, opts.sort, "updated"),
  })
end

return SearchService
