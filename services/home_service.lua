-- services/home_service.lua
-- The four Home-screen stat cards. Each `*_list(n)` returns up to n plain index
-- rows (title, method_name, overall_rating, avg_session_rating, brew_count, id);
-- the singular helpers return the first row (or nil / a count) for callers that
-- only want the headline.

local Search = require("services/search_service")

local HomeService = {}

local function rows(opts)
  local _, r = Search.recipes(opts)
  return r or {}
end

local function brewed_only(list)
  local out = {}
  for _, r in ipairs(list) do
    if tonumber(r.brew_count or 0) > 0 then
      out[#out + 1] = r
    end
  end
  return out
end

--- Most recently saved recipes (created or edited), newest first.
function HomeService.recently_saved_list(n)
  return rows { sort = "updated", limit = n }
end

--- Recipes with the highest brew counts.
function HomeService.most_brewed_list(n)
  return brewed_only(rows { sort = "brew_count", limit = n })
end

--- Highest-rated recipes (catalogue rating, else session average).
function HomeService.top_rated_list(n)
  local out = {}
  for _, r in ipairs(rows { sort = "rating", limit = n }) do
    if r.overall_rating or r.avg_session_rating then
      out[#out + 1] = r
    end
  end
  return out
end

--- Recipes flagged as favourites.
function HomeService.favourites_list(n)
  return rows { favorite = true, sort = "rating", limit = n }
end

function HomeService.recently_saved()
  return HomeService.recently_saved_list(1)[1]
end

function HomeService.most_brewed()
  return HomeService.most_brewed_list(1)[1]
end

function HomeService.top_rated()
  return HomeService.top_rated_list(1)[1]
end

--- How many recipes are flagged as favourites.
function HomeService.favourites_count()
  return #rows { favorite = true }
end

return HomeService
