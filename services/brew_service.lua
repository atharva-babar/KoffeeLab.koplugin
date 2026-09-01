-- services/brew_service.lua
-- Brew-session observations (§1.10). Thin validation: the recipe must exist, and the
-- optional rating / measured time must be in range (§3.14 shapes). Derived stats are
-- read straight from the recipe_stats view.

local SessionRepo = require("db/repo/session")
local RecipeRepo = require("db/repo/recipe")
local Support = require("services/support")

local BrewService = {}

function BrewService.record(fields)
  fields = fields or {}
  if not RecipeRepo.get(fields.recipe_id) then
    return Support.err("recipe not found")
  end
  local bad = Support.check {
    { Support.is_rating_or_nil(fields.session_rating), "rating must be 1–5" },
    { Support.is_nonneg_or_nil(fields.measured_brew_time_sec), "measured time must be ≥ 0" },
    { fields.comment == nil or type(fields.comment) == "string", "comment must be text" },
  }
  if bad then
    return Support.err(bad)
  end
  return Support.from_repo(SessionRepo.create(fields))
end

function BrewService.list_for_recipe(recipe_id)
  return Support.ok(SessionRepo.list_for_recipe(recipe_id))
end

function BrewService.get(id)
  local row = SessionRepo.get(id)
  if not row then
    return Support.err("session not found")
  end
  return Support.ok(row)
end

function BrewService.delete(id)
  local ok, err = SessionRepo.delete(id)
  if ok == nil then
    return Support.err(err or "database error")
  end
  if ok == false then
    return Support.err("session not found")
  end
  return Support.ok(true)
end

function BrewService.stats(recipe_id)
  return Support.ok(SessionRepo.stats(recipe_id))
end

return BrewService
