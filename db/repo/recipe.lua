-- db/repo/recipe.lua
-- Brew recipes and their children: steps (§1.12), method-parameter values (§1.9a),
-- flavor tags. Writes span four tables and always run in one transaction
-- (§Conventions 16). `get` returns the fully nested recipe without an is_active
-- filter (§1.21 — a detail view must render even when the bean was since disabled).
-- The referential guard for "used by N drinks" lives in the service layer.

local Query = require("db/query")
local Support = require("db/repo/support")

local Recipe = {}

-- Fixed columns on brew_recipes a caller may set (§1.9a). Method-specific values go
-- through param_values, not here.
local RECIPE_FIELDS = {
  "title",
  "method_id",
  "bean_id",
  "grinder_id",
  "grind_value",
  "dose_g",
  "water_g",
  "water_temp_c",
  "brew_time_sec",
  "output_weight_g",
  "acidity",
  "sweetness",
  "strength",
  "body",
  "brightness",
  "overall_rating",
  "notes",
}

local STEP_FIELDS = {
  "step_type",
  "start_time_sec",
  "duration_sec",
  "target_water_g",
  "target_total_water_g",
  "temperature_c",
  "value",
  "unit",
  "instruction",
  "note",
}

local SORT_CLAUSES = {
  rating = "r.overall_rating DESC, r.id DESC",
  brew_count = "st.brew_count DESC, r.id DESC",
  title = "r.title COLLATE NOCASE ASC, r.id ASC",
  updated = "r.updated_at DESC, r.id DESC",
}

local STEP_COLS = { "recipe_id", "step_order" }
for _, key in ipairs(STEP_FIELDS) do
  STEP_COLS[#STEP_COLS + 1] = key
end

local function insert_children(conn, recipe_id, steps, param_values, flavor_tag_ids)
  for order, step in ipairs(steps or {}) do
    local values = { recipe_id = recipe_id, step_order = order }
    for _, key in ipairs(STEP_FIELDS) do
      values[key] = step[key]
    end
    Support.insert(conn, "brew_recipe_steps", STEP_COLS, values)
  end

  for _, pv in ipairs(param_values or {}) do
    Query.exec(
      conn,
      "INSERT INTO brew_recipe_parameters (recipe_id, param_id, value) VALUES (?, ?, ?)",
      Support.args(recipe_id, pv.param_id, pv.value)
    )
  end

  for _, tag_id in ipairs(flavor_tag_ids or {}) do
    Query.exec(
      conn,
      "INSERT INTO recipe_flavor_tags (recipe_id, flavor_tag_id) VALUES (?, ?)",
      { recipe_id, tag_id }
    )
  end
end

local RECIPE_INSERT_COLS = {}
for _, key in ipairs(RECIPE_FIELDS) do
  RECIPE_INSERT_COLS[#RECIPE_INSERT_COLS + 1] = key
end
RECIPE_INSERT_COLS[#RECIPE_INSERT_COLS + 1] = "created_at"
RECIPE_INSERT_COLS[#RECIPE_INSERT_COLS + 1] = "updated_at"

--- Insert a recipe with its steps, parameter values and flavor tags.
function Recipe.create(recipe, steps, param_values, flavor_tag_ids)
  return Support.transaction(function(conn)
    local now = Support.now()
    local values = { created_at = now, updated_at = now }
    for _, key in ipairs(RECIPE_FIELDS) do
      values[key] = recipe[key]
    end
    local res = Support.insert(conn, "brew_recipes", RECIPE_INSERT_COLS, values)
    insert_children(conn, res.last_insert_rowid, steps, param_values, flavor_tag_ids)
    return Recipe.get(res.last_insert_rowid)
  end)
end

--- Replace the recipe's columns and its whole set of steps / params / tags. Steps
--- are delete-and-reinsert, so `UNIQUE(recipe_id, step_order)` never collides (§1.12).
function Recipe.update(id, recipe, steps, param_values, flavor_tag_ids)
  return Support.transaction(function(conn)
    local frag, params = Support.assignments(recipe or {}, RECIPE_FIELDS)
    if frag ~= "" then
      params[#params + 1] = Support.now()
      params[#params + 1] = id
      Query.exec(
        conn,
        "UPDATE brew_recipes SET " .. frag .. ", updated_at = ? WHERE id = ?",
        params
      )
    else
      Query.exec(conn, "UPDATE brew_recipes SET updated_at = ? WHERE id = ?", { Support.now(), id })
    end

    if steps then
      Query.exec(conn, "DELETE FROM brew_recipe_steps WHERE recipe_id = ?", { id })
    end
    if param_values then
      Query.exec(conn, "DELETE FROM brew_recipe_parameters WHERE recipe_id = ?", { id })
    end
    if flavor_tag_ids then
      Query.exec(conn, "DELETE FROM recipe_flavor_tags WHERE recipe_id = ?", { id })
    end
    insert_children(conn, id, steps, param_values, flavor_tag_ids)
    return Recipe.get(id)
  end)
end

--- Fully nested recipe by id (no is_active filter — §1.21). nil when absent.
function Recipe.get(id)
  local conn = Support.conn()
  local recipe = Query.one(conn, "SELECT * FROM brew_recipes WHERE id = ?", { id })
  if not recipe then
    return nil
  end
  recipe.steps = Query.all(
    conn,
    "SELECT * FROM brew_recipe_steps WHERE recipe_id = ? ORDER BY step_order",
    { id }
  )
  recipe.parameters = Query.all(
    conn,
    [[SELECT rp.param_id, rp.value, mp.key, mp.label, mp.data_type, mp.unit
        FROM brew_recipe_parameters rp
        JOIN brew_method_parameters mp ON mp.id = rp.param_id
       WHERE rp.recipe_id = ?
       ORDER BY mp.sort_order, mp.id]],
    { id }
  )
  recipe.flavor_tags = Query.all(
    conn,
    [[SELECT ft.id, ft.name
        FROM recipe_flavor_tags rft
        JOIN flavor_tags ft ON ft.id = rft.flavor_tag_id
       WHERE rft.recipe_id = ?
       ORDER BY ft.name COLLATE NOCASE]],
    { id }
  )
  local stats = Query.one(conn, "SELECT * FROM recipe_stats WHERE recipe_id = ?", { id })
  recipe.stats = stats
    or { recipe_id = id, brew_count = 0, avg_session_rating = nil, last_brewed_at = nil }
  return recipe
end

--- Every recipe id, oldest first — for a full backup export (no is_active filter).
function Recipe.all_ids()
  local out = {}
  for _, row in ipairs(Query.all(Support.conn(), "SELECT id FROM brew_recipes ORDER BY id")) do
    out[#out + 1] = row.id
  end
  return out
end

--- First recipe whose title matches exactly (optionally scoped to a method), or nil.
--- Used by JSON import to resolve a drink's base recipe.
function Recipe.find_by_title(title, method_id)
  if method_id then
    return Query.one(
      Support.conn(),
      "SELECT * FROM brew_recipes WHERE title = ? AND method_id = ? ORDER BY id LIMIT 1",
      { title, method_id }
    )
  end
  return Query.one(
    Support.conn(),
    "SELECT * FROM brew_recipes WHERE title = ? ORDER BY id LIMIT 1",
    { title }
  )
end

--- Hard delete (children cascade). Caller must have cleared the drink-reference guard.
function Recipe.delete(id)
  return Support.guard(function()
    local res = Query.exec(Support.conn(), "DELETE FROM brew_recipes WHERE id = ?", { id })
    return res.changes > 0
  end)
end

--- Index rows joined to recipe_stats (§1.21). Active recipes only, LIKE-escaped
--- title search, one of the four documented sorts (default: updated).
function Recipe.list_for_index(opts)
  opts = opts or {}
  local where, params = { "r.is_active = 1" }, {}
  if opts.method_id then
    where[#where + 1] = "r.method_id = ?"
    params[#params + 1] = opts.method_id
  end
  if opts.search and opts.search ~= "" then
    where[#where + 1] = "r.title LIKE ? ESCAPE '\\'"
    params[#params + 1] = Query.like_contains(opts.search)
  end
  local order = SORT_CLAUSES[opts.sort] or SORT_CLAUSES.updated
  local sql = string.format(
    [[SELECT r.*, st.brew_count, st.avg_session_rating, st.last_brewed_at, m.name AS method_name, m.slug AS method_slug
        FROM brew_recipes r
        JOIN recipe_stats st ON st.recipe_id = r.id
        JOIN brew_methods m ON m.id = r.method_id
       WHERE %s
       ORDER BY %s]],
    table.concat(where, " AND "),
    order
  )
  return Query.all(Support.conn(), sql, params)
end

return Recipe
