-- db/seed.lua
-- System brew-method seed data (part of migration 1, TECH_SOLUTION §1.22 "Seed
-- data"). Inserts the five built-in methods with their allowed step types and
-- their optional method parameters (the "parameter" rows of the §1.9a matrix,
-- with §1.15 as the reference for step sequences). Idempotent, keyed on `slug`.
--
-- No beans / grinders / ingredients / flavor tags are seeded — the user creates
-- those in the Configurator.

local Seed = {}

-- Each method: slug, name, icon (text abbreviation until real assets land),
-- sort_order, ordered step_types, and parameter definitions.
Seed.SYSTEM_METHODS = {
  {
    slug = "pour_over",
    name = "Pour Over",
    icon = "V60",
    sort_order = 1,
    step_types = { "bloom", "pour", "wait", "finish" },
    parameters = {
      { key = "dripper_type", label = "Dripper / filter", data_type = "text" },
    },
  },
  {
    slug = "aeropress",
    name = "AeroPress",
    icon = "AP",
    sort_order = 2,
    step_types = { "setup", "bloom", "stir", "pour", "wait", "press", "bypass", "finish" },
    parameters = {
      {
        key = "orientation",
        label = "Orientation",
        data_type = "text",
        default_value = "standard",
      },
      {
        key = "bypass_water_g",
        label = "Bypass water",
        data_type = "real",
        unit = "g",
        min_value = 0,
      },
      { key = "filter_type", label = "Filter type", data_type = "text" },
    },
  },
  {
    slug = "french_press",
    name = "French Press",
    icon = "FP",
    sort_order = 3,
    step_types = { "pour", "immerse", "wait", "stir", "plunge", "decant", "finish" },
    parameters = {
      {
        key = "steep_before_crust_break_sec",
        label = "Steep before crust break",
        data_type = "duration",
        min_value = 0,
      },
    },
  },
  {
    slug = "espresso",
    name = "Espresso",
    icon = "ESP",
    sort_order = 4,
    step_types = { "setup", "preinfuse", "extract", "finish" },
    parameters = {
      {
        key = "preinfusion_sec",
        label = "Pre-infusion duration",
        data_type = "duration",
        unit = "s",
        min_value = 0,
      },
    },
  },
  {
    slug = "cold_brew",
    name = "Cold Brew",
    icon = "CB",
    sort_order = 5,
    step_types = { "pour", "immerse", "wait", "decant", "finish" },
    parameters = {
      { key = "dilution_ratio", label = "Dilution ratio", data_type = "text" },
    },
  },
}

local function method_id_by_slug(conn, slug)
  local stmt = conn:prepare("SELECT id FROM brew_methods WHERE slug = ?")
  stmt:bind1(1, slug)
  local row = stmt:step()
  stmt:close()
  return row and tonumber(row[1]) or nil
end

local function insert_method(conn, method, now)
  local stmt = conn:prepare([[
    INSERT INTO brew_methods
      (slug, name, icon, description, is_system, is_active, sort_order, created_at, updated_at)
    VALUES (?, ?, ?, '', 1, 1, ?, ?, ?)
  ]])
  stmt:bind(method.slug, method.name, method.icon, method.sort_order, now, now)
  stmt:step()
  stmt:close()
  return tonumber(conn:rowexec("SELECT last_insert_rowid()"))
end

local function insert_step_types(conn, method_id, step_types)
  local stmt = conn:prepare([[
    INSERT INTO brew_method_step_types (method_id, step_type, sort_order)
    VALUES (?, ?, ?)
  ]])
  for order, step_type in ipairs(step_types) do
    stmt:reset():clearbind():bind(method_id, step_type, order):step()
  end
  stmt:close()
end

local function insert_parameters(conn, method_id, parameters)
  local stmt = conn:prepare([[
    INSERT INTO brew_method_parameters
      (method_id, key, label, data_type, unit, required, default_value, min_value, max_value, sort_order)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  ]])
  for order, param in ipairs(parameters) do
    stmt
      :reset()
      :clearbind()
      :bind(
        method_id,
        param.key,
        param.label,
        param.data_type,
        param.unit,
        param.required or 0,
        param.default_value,
        param.min_value,
        param.max_value,
        order
      )
      :step()
  end
  stmt:close()
end

--- Insert any missing system methods. Existing ones (matched by slug) are left
--- untouched, so calling this repeatedly is safe.
function Seed.seed_system_methods(conn)
  local now = os.time()
  for _, method in ipairs(Seed.SYSTEM_METHODS) do
    if not method_id_by_slug(conn, method.slug) then
      local method_id = insert_method(conn, method, now)
      insert_step_types(conn, method_id, method.step_types)
      insert_parameters(conn, method_id, method.parameters)
    end
  end
end

return Seed
