-- db/repo/recipe.lua
-- Brew recipes and their flavor tags. Method parameters and the step list are
-- stored as JSON columns (spec_json / steps_json); create/update take Lua tables
-- and this module owns the encode/decode. Writes run in one transaction. `get`
-- never filters on is_active so a detail view renders after its bean is disabled.

local rapidjson = require("rapidjson")
local Query = require("db/query")
local Support = require("db/repo/support")

local Recipe = {}

local RECIPE_FIELDS = {
  "title",
  "method_slug",
  "bean_id",
  "grinder_id",
  "grind_value",
  "dose_g",
  "water_g",
  "water_temp_c",
  "brew_time_sec",
  "output_weight_g",
  "spec_json",
  "steps_json",
  "output_note",
  "acidity",
  "sweetness",
  "strength",
  "body",
  "brightness",
  "overall_rating",
  "notes",
  "is_favorite",
}

local SORT_CLAUSES = {
  rating = "r.overall_rating DESC, r.id DESC",
  brew_count = "st.brew_count DESC, r.id DESC",
  title = "r.title COLLATE NOCASE ASC, r.id ASC",
  updated = "r.updated_at DESC, r.id DESC",
  recent = "st.last_brewed_at IS NULL, st.last_brewed_at DESC, r.id DESC",
}

local INSERT_COLS = {}
for _, key in ipairs(RECIPE_FIELDS) do
  INSERT_COLS[#INSERT_COLS + 1] = key
end
INSERT_COLS[#INSERT_COLS + 1] = "created_at"
INSERT_COLS[#INSERT_COLS + 1] = "updated_at"

local function encode_spec(spec)
  if type(spec) ~= "table" or next(spec) == nil then
    return "{}"
  end
  return rapidjson.encode(spec, { sort_keys = true })
end

local function encode_steps(steps)
  if type(steps) ~= "table" or #steps == 0 then
    return "[]"
  end
  return rapidjson.encode(steps)
end

local function decoded(str, fallback)
  if type(str) ~= "string" or str == "" then
    return fallback
  end
  local ok, value = pcall(rapidjson.decode, str)
  if not ok or type(value) ~= "table" then
    return fallback
  end
  return value
end

-- Fold caller-facing `spec` / `steps` tables into the JSON columns.
local function with_json(recipe)
  local out = {}
  for k, v in pairs(recipe) do
    out[k] = v
  end
  if recipe.spec ~= nil then
    out.spec_json = encode_spec(recipe.spec)
  end
  if recipe.steps ~= nil then
    out.steps_json = encode_steps(recipe.steps)
  end
  out.spec, out.steps = nil, nil
  return out
end

local function insert_tags(conn, recipe_id, flavor_tag_ids)
  for _, tag_id in ipairs(flavor_tag_ids or {}) do
    Query.exec(
      conn,
      "INSERT INTO recipe_flavor_tags (recipe_id, flavor_tag_id) VALUES (?, ?)",
      { recipe_id, tag_id }
    )
  end
end

function Recipe.create(recipe, flavor_tag_ids)
  return Support.transaction(function(conn)
    local now = Support.now()
    local values = with_json(recipe)
    values.created_at, values.updated_at = now, now
    local res = Support.insert(conn, "brew_recipes", INSERT_COLS, values)
    insert_tags(conn, res.last_insert_rowid, flavor_tag_ids)
    return Recipe.get(res.last_insert_rowid)
  end)
end

function Recipe.update(id, recipe, flavor_tag_ids)
  return Support.transaction(function(conn)
    local frag, params = Support.assignments(with_json(recipe or {}), RECIPE_FIELDS)
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
    if flavor_tag_ids then
      Query.exec(conn, "DELETE FROM recipe_flavor_tags WHERE recipe_id = ?", { id })
      insert_tags(conn, id, flavor_tag_ids)
    end
    return Recipe.get(id)
  end)
end

function Recipe.set_favorite(id, favorite)
  return Support.guard(function()
    local res = Query.exec(
      Support.conn(),
      "UPDATE brew_recipes SET is_favorite = ?, updated_at = ? WHERE id = ?",
      { favorite and 1 or 0, Support.now(), id }
    )
    return res.changes > 0
  end)
end

--- Fully nested recipe by id (no is_active filter). nil when absent.
function Recipe.get(id)
  local conn = Support.conn()
  local recipe = Query.one(conn, "SELECT * FROM brew_recipes WHERE id = ?", { id })
  if not recipe then
    return nil
  end
  recipe.spec = decoded(recipe.spec_json, {})
  recipe.steps = decoded(recipe.steps_json, {})
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
function Recipe.find_by_title(title, method_slug)
  if method_slug then
    return Query.one(
      Support.conn(),
      "SELECT * FROM brew_recipes WHERE title = ? AND method_slug = ? ORDER BY id LIMIT 1",
      { title, method_slug }
    )
  end
  return Query.one(
    Support.conn(),
    "SELECT * FROM brew_recipes WHERE title = ? ORDER BY id LIMIT 1",
    { title }
  )
end

function Recipe.delete(id)
  return Support.guard(function()
    local res = Query.exec(Support.conn(), "DELETE FROM brew_recipes WHERE id = ?", { id })
    return res.changes > 0
  end)
end

--- Index rows joined to recipe_stats. Active recipes only, LIKE-escaped title
--- search, one of the documented sorts (default: updated).
function Recipe.list_for_index(opts)
  opts = opts or {}
  local where, params = { "r.is_active = 1" }, {}
  if opts.method_slug then
    where[#where + 1] = "r.method_slug = ?"
    params[#params + 1] = opts.method_slug
  end
  if opts.favorite then
    where[#where + 1] = "r.is_favorite = 1"
  end
  if opts.search and opts.search ~= "" then
    where[#where + 1] = "r.title LIKE ? ESCAPE '\\'"
    params[#params + 1] = Query.like_contains(opts.search)
  end
  local order = SORT_CLAUSES[opts.sort] or SORT_CLAUSES.updated
  local sql = string.format(
    [[SELECT r.*, st.brew_count, st.avg_session_rating, st.last_brewed_at
        FROM brew_recipes r
        JOIN recipe_stats st ON st.recipe_id = r.id
       WHERE %s
       ORDER BY %s]],
    table.concat(where, " AND "),
    order
  )
  if opts.limit then
    sql = sql .. " LIMIT " .. tonumber(opts.limit)
  end
  return Query.all(Support.conn(), sql, params)
end

return Recipe
