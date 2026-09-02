-- services/home_service.lua
-- The four Home-screen stat cards. Each returns a plain index row (title,
-- method_name, overall_rating, avg_session_rating, brew_count, id) or nil when
-- there is nothing to show.

local Search = require("services/search_service")

local HomeService = {}

local function first_row(opts)
  local _, rows = Search.recipes(opts)
  return rows and rows[1]
end

--- Most recently brewed recipe, or nil when nothing has been brewed.
function HomeService.recent()
  local r = first_row { sort = "recent", limit = 1 }
  return (r and tonumber(r.brew_count or 0) > 0) and r or nil
end

--- Recipe with the highest brew count, or nil.
function HomeService.most_brewed()
  local r = first_row { sort = "brew_count", limit = 1 }
  return (r and tonumber(r.brew_count or 0) > 0) and r or nil
end

--- Highest-rated recipe (catalogue rating, else session average), or nil.
function HomeService.top_rated()
  local r = first_row { sort = "rating", limit = 1 }
  return (r and (r.overall_rating or r.avg_session_rating)) and r or nil
end

--- How many recipes are flagged as favourites.
function HomeService.favourites_count()
  local _, rows = Search.recipes { favorite = true }
  return rows and #rows or 0
end

return HomeService
