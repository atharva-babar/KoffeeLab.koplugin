-- db/repo/session.lua
-- Brew sessions (§1.10): lightweight observations against a recipe. Derived
-- brew_count / average come from the recipe_stats view, never a stored column
-- (§1.10 "Brew count and session average").

local Query = require("db/query")
local Support = require("db/repo/support")

local Session = {}

--- Insert a session. `brewed_at` defaults to now; rating / time / comment optional.
function Session.create(fields)
  return Support.guard(function()
    local res = Query.exec(
      Support.conn(),
      [[INSERT INTO brew_sessions
          (recipe_id, brewed_at, session_rating, measured_brew_time_sec, comment, created_at)
        VALUES (?, ?, ?, ?, ?, ?)]],
      Support.args(
        fields.recipe_id,
        fields.brewed_at or Support.now(),
        fields.session_rating,
        fields.measured_brew_time_sec,
        fields.comment or "",
        Support.now()
      )
    )
    return Session.get(res.last_insert_rowid)
  end)
end

function Session.get(id)
  return Query.one(Support.conn(), "SELECT * FROM brew_sessions WHERE id = ?", { id })
end

--- Sessions for a recipe, newest first. `brewed_at` can be wrong (device clock), so
--- `id` is the stable tiebreaker (§Conventions 11).
function Session.list_for_recipe(recipe_id)
  return Query.all(
    Support.conn(),
    "SELECT * FROM brew_sessions WHERE recipe_id = ? ORDER BY brewed_at DESC, id DESC",
    { recipe_id }
  )
end

function Session.delete(id)
  return Support.guard(function()
    local res = Query.exec(Support.conn(), "DELETE FROM brew_sessions WHERE id = ?", { id })
    return res.changes > 0
  end)
end

--- Derived stats from the recipe_stats view. Always returns a table, even for a
--- recipe with no sessions yet.
function Session.stats(recipe_id)
  local row =
    Query.one(Support.conn(), "SELECT * FROM recipe_stats WHERE recipe_id = ?", { recipe_id })
  return row
    or {
      recipe_id = recipe_id,
      brew_count = 0,
      avg_session_rating = nil,
      last_brewed_at = nil,
    }
end

return Session
