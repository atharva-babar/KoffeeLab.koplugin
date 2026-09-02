-- services/search_service.lua
-- One entry point for the two index screens. Normalises the caller's filter/sort
-- options and delegates to the repos, which own the parameterised queries.

local RecipeService = require("services/recipe_service")
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

function SearchService.recipes(opts)
  opts = opts or {}
  return RecipeService.list_for_index {
    method_slug = opts.method_slug,
    favorite = opts.favorite,
    search = opts.search,
    sort = allowed(SearchService.RECIPE_SORTS, opts.sort, "updated"),
    limit = opts.limit,
  }
end

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
