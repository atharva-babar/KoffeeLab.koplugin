-- db/repo/drink.lua
-- Custom drinks (§1.16–§1.18): a base recipe + an amount of it, plus extra
-- ingredients and untimed process steps. Writes span three tables in one
-- transaction. `count_referencing_recipe` backs the recipe-delete guard (§3.9).

local Query = require("db/query")
local Support = require("db/repo/support")

local Drink = {}

local DRINK_FIELDS = {
  "title",
  "temperature_mode",
  "base_recipe_id",
  "base_amount",
  "base_unit",
  "rating",
  "comment",
}

local SORT_CLAUSES = {
  rating = "d.rating DESC, d.id DESC",
  title = "d.title COLLATE NOCASE ASC, d.id ASC",
  updated = "d.updated_at DESC, d.id DESC",
}

local function insert_children(conn, drink_id, ingredients, steps)
  for order, ing in ipairs(ingredients or {}) do
    Query.exec(
      conn,
      [[INSERT INTO custom_drink_ingredients (drink_id, ingredient_id, amount, unit, sort_order)
        VALUES (?, ?, ?, ?, ?)]],
      Support.args(drink_id, ing.ingredient_id, ing.amount, ing.unit, ing.sort_order or order)
    )
  end
  for order, step in ipairs(steps or {}) do
    Query.exec(
      conn,
      "INSERT INTO custom_drink_steps (drink_id, step_order, instruction, note) VALUES (?, ?, ?, ?)",
      { drink_id, order, step.instruction or "", step.note or "" }
    )
  end
end

local DRINK_INSERT_COLS = {}
for _, key in ipairs(DRINK_FIELDS) do
  DRINK_INSERT_COLS[#DRINK_INSERT_COLS + 1] = key
end
DRINK_INSERT_COLS[#DRINK_INSERT_COLS + 1] = "created_at"
DRINK_INSERT_COLS[#DRINK_INSERT_COLS + 1] = "updated_at"

function Drink.create(drink, ingredients, steps)
  return Support.transaction(function(conn)
    local now = Support.now()
    local values = { created_at = now, updated_at = now }
    for _, key in ipairs(DRINK_FIELDS) do
      values[key] = drink[key]
    end
    local res = Support.insert(conn, "custom_drinks", DRINK_INSERT_COLS, values)
    insert_children(conn, res.last_insert_rowid, ingredients, steps)
    return Drink.get(res.last_insert_rowid)
  end)
end

function Drink.update(id, drink, ingredients, steps)
  return Support.transaction(function(conn)
    local frag, params = Support.assignments(drink or {}, DRINK_FIELDS)
    if frag ~= "" then
      params[#params + 1] = Support.now()
      params[#params + 1] = id
      Query.exec(
        conn,
        "UPDATE custom_drinks SET " .. frag .. ", updated_at = ? WHERE id = ?",
        params
      )
    else
      Query.exec(
        conn,
        "UPDATE custom_drinks SET updated_at = ? WHERE id = ?",
        { Support.now(), id }
      )
    end
    if ingredients then
      Query.exec(conn, "DELETE FROM custom_drink_ingredients WHERE drink_id = ?", { id })
    end
    if steps then
      Query.exec(conn, "DELETE FROM custom_drink_steps WHERE drink_id = ?", { id })
    end
    insert_children(conn, id, ingredients, steps)
    return Drink.get(id)
  end)
end

--- Fully nested drink by id (no is_active filter). nil when absent.
function Drink.get(id)
  local conn = Support.conn()
  local drink = Query.one(conn, "SELECT * FROM custom_drinks WHERE id = ?", { id })
  if not drink then
    return nil
  end
  drink.ingredients = Query.all(
    conn,
    [[SELECT di.*, i.name AS ingredient_name
        FROM custom_drink_ingredients di
        JOIN ingredients i ON i.id = di.ingredient_id
       WHERE di.drink_id = ?
       ORDER BY di.sort_order, di.id]],
    { id }
  )
  drink.steps = Query.all(
    conn,
    "SELECT * FROM custom_drink_steps WHERE drink_id = ? ORDER BY step_order",
    { id }
  )
  drink.base_recipe = Query.one(
    conn,
    "SELECT id, title, output_weight_g FROM brew_recipes WHERE id = ?",
    { drink.base_recipe_id }
  )
  return drink
end

--- Every drink id, oldest first — for a full backup export (no is_active filter).
function Drink.all_ids()
  local out = {}
  for _, row in ipairs(Query.all(Support.conn(), "SELECT id FROM custom_drinks ORDER BY id")) do
    out[#out + 1] = row.id
  end
  return out
end

function Drink.delete(id)
  return Support.guard(function()
    local res = Query.exec(Support.conn(), "DELETE FROM custom_drinks WHERE id = ?", { id })
    return res.changes > 0
  end)
end

--- Index rows (§2.14). Active only; filters by temperature mode and/or a contained
--- ingredient; LIKE-escaped title search; sort rating|title|updated (default updated).
function Drink.list_for_index(opts)
  opts = opts or {}
  local where, params = { "d.is_active = 1" }, {}
  if opts.temperature_mode then
    where[#where + 1] = "d.temperature_mode = ?"
    params[#params + 1] = opts.temperature_mode
  end
  if opts.ingredient_id then
    where[#where + 1] =
      "EXISTS (SELECT 1 FROM custom_drink_ingredients di WHERE di.drink_id = d.id AND di.ingredient_id = ?)"
    params[#params + 1] = opts.ingredient_id
  end
  if opts.search and opts.search ~= "" then
    where[#where + 1] = "d.title LIKE ? ESCAPE '\\'"
    params[#params + 1] = Query.like_contains(opts.search)
  end
  local order = SORT_CLAUSES[opts.sort] or SORT_CLAUSES.updated
  local sql = string.format(
    [[SELECT d.*, r.title AS base_recipe_title
        FROM custom_drinks d
        JOIN brew_recipes r ON r.id = d.base_recipe_id
       WHERE %s
       ORDER BY %s]],
    table.concat(where, " AND "),
    order
  )
  return Query.all(Support.conn(), sql, params)
end

--- How many drinks use `recipe_id` as their base (§3.9 delete guard).
function Drink.count_referencing_recipe(recipe_id)
  local row = Query.one(
    Support.conn(),
    "SELECT COUNT(*) AS n FROM custom_drinks WHERE base_recipe_id = ?",
    { recipe_id }
  )
  return tonumber(row.n) or 0
end

return Drink
