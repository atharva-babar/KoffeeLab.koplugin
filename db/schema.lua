-- db/schema.lua
-- Schema v1 DDL, transcribed verbatim from TECH_SOLUTION_KoffeeLab_KOReader.md §1.22.
-- One statement per array entry; the migration runner applies them in order inside a
-- single transaction. Keep this list in sync with §1.22 and CURRENT_SCHEMA_VERSION
-- in db/migrations.lua.

local Schema = {}

Schema.STATEMENTS = {
  -- Configuration -----------------------------------------------------------
  [[
    CREATE TABLE beans (
      id           INTEGER PRIMARY KEY,
      name         TEXT    NOT NULL,
      roaster_name TEXT    NOT NULL DEFAULT '',
      roast_level  INTEGER NOT NULL DEFAULT 3 CHECK (roast_level BETWEEN 1 AND 5),
      created_at   INTEGER NOT NULL,
      updated_at   INTEGER NOT NULL,
      is_active    INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1))
    )
  ]],
  [[
    CREATE TABLE grinders (
      id         INTEGER PRIMARY KEY,
      name       TEXT    NOT NULL,
      unit_name  TEXT    NOT NULL,
      min_value  REAL    NOT NULL,
      max_value  REAL    NOT NULL,
      step_value REAL    NOT NULL CHECK (step_value > 0),
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      is_active  INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
      CHECK (min_value <= max_value)
    )
  ]],
  [[
    CREATE TABLE ingredients (
      id         INTEGER PRIMARY KEY,
      name       TEXT    NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      is_active  INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1))
    )
  ]],
  [[CREATE UNIQUE INDEX idx_ingredients_name ON ingredients(name)]],
  [[
    CREATE TABLE flavor_tags (
      id         INTEGER PRIMARY KEY,
      name       TEXT    NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      is_active  INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1))
    )
  ]],
  [[CREATE UNIQUE INDEX idx_flavor_tags_name ON flavor_tags(name)]],

  -- Brew methods ----------------------------------------------------------------
  [[
    CREATE TABLE brew_methods (
      id          INTEGER PRIMARY KEY,
      slug        TEXT    NOT NULL UNIQUE,
      name        TEXT    NOT NULL,
      icon        TEXT,
      description TEXT    NOT NULL DEFAULT '',
      is_system   INTEGER NOT NULL DEFAULT 0 CHECK (is_system IN (0,1)),
      is_active   INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
      sort_order  INTEGER NOT NULL DEFAULT 0,
      created_at  INTEGER NOT NULL,
      updated_at  INTEGER NOT NULL
    )
  ]],
  [[
    CREATE TABLE brew_method_parameters (
      id            INTEGER PRIMARY KEY,
      method_id     INTEGER NOT NULL REFERENCES brew_methods(id) ON DELETE CASCADE,
      key           TEXT    NOT NULL,
      label         TEXT    NOT NULL,
      data_type     TEXT    NOT NULL CHECK (data_type IN ('int','real','text','bool','duration')),
      unit          TEXT,
      required      INTEGER NOT NULL DEFAULT 0 CHECK (required IN (0,1)),
      default_value TEXT,
      min_value     REAL,
      max_value     REAL,
      sort_order    INTEGER NOT NULL DEFAULT 0,
      UNIQUE (method_id, key)
    )
  ]],
  [[
    CREATE TABLE brew_method_step_types (
      method_id  INTEGER NOT NULL REFERENCES brew_methods(id) ON DELETE CASCADE,
      step_type  TEXT    NOT NULL,
      sort_order INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (method_id, step_type)
    )
  ]],
  [[
    CREATE TABLE brew_method_equipment (
      id         INTEGER PRIMARY KEY,
      method_id  INTEGER NOT NULL REFERENCES brew_methods(id) ON DELETE CASCADE,
      name       TEXT    NOT NULL,
      sort_order INTEGER NOT NULL DEFAULT 0
    )
  ]],
  [[CREATE INDEX idx_method_equipment_method ON brew_method_equipment(method_id)]],

  -- Catalogue: recipes --------------------------------------------------------
  [[
    CREATE TABLE brew_recipes (
      id             INTEGER PRIMARY KEY,
      title          TEXT    NOT NULL,
      method_id      INTEGER NOT NULL REFERENCES brew_methods(id),
      bean_id        INTEGER REFERENCES beans(id),
      grinder_id     INTEGER REFERENCES grinders(id),
      grind_value    REAL,
      dose_g         REAL,
      water_g        REAL,
      water_temp_c   REAL,
      brew_time_sec  INTEGER,
      output_weight_g REAL,
      acidity        INTEGER CHECK (acidity    IS NULL OR acidity    BETWEEN 1 AND 5),
      sweetness      INTEGER CHECK (sweetness  IS NULL OR sweetness  BETWEEN 1 AND 5),
      strength       INTEGER CHECK (strength   IS NULL OR strength   BETWEEN 1 AND 5),
      body           INTEGER CHECK (body       IS NULL OR body       BETWEEN 1 AND 5),
      brightness     INTEGER CHECK (brightness IS NULL OR brightness BETWEEN 1 AND 5),
      overall_rating INTEGER CHECK (overall_rating IS NULL OR overall_rating BETWEEN 1 AND 5),
      notes          TEXT    NOT NULL DEFAULT '',
      created_at     INTEGER NOT NULL,
      updated_at     INTEGER NOT NULL,
      is_active      INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1))
    )
  ]],
  [[CREATE INDEX idx_recipes_method ON brew_recipes(method_id)]],
  [[CREATE INDEX idx_recipes_bean   ON brew_recipes(bean_id)]],
  [[CREATE INDEX idx_recipes_active ON brew_recipes(is_active)]],
  [[CREATE INDEX idx_recipes_title  ON brew_recipes(title COLLATE NOCASE)]],
  [[
    CREATE TABLE brew_recipe_parameters (
      recipe_id INTEGER NOT NULL REFERENCES brew_recipes(id) ON DELETE CASCADE,
      param_id  INTEGER NOT NULL REFERENCES brew_method_parameters(id),
      value     TEXT,
      PRIMARY KEY (recipe_id, param_id)
    )
  ]],
  [[
    CREATE TABLE brew_recipe_steps (
      id                   INTEGER PRIMARY KEY,
      recipe_id            INTEGER NOT NULL REFERENCES brew_recipes(id) ON DELETE CASCADE,
      step_order           INTEGER NOT NULL,
      step_type            TEXT    NOT NULL,
      start_time_sec       INTEGER CHECK (start_time_sec IS NULL OR start_time_sec >= 0),
      duration_sec         INTEGER CHECK (duration_sec   IS NULL OR duration_sec   >= 0),
      target_water_g       REAL    CHECK (target_water_g IS NULL OR target_water_g >= 0),
      target_total_water_g REAL    CHECK (target_total_water_g IS NULL OR target_total_water_g >= 0),
      temperature_c        REAL,
      value                REAL,
      unit                 TEXT,
      instruction          TEXT    NOT NULL DEFAULT '',
      note                 TEXT    NOT NULL DEFAULT '',
      UNIQUE (recipe_id, step_order)
    )
  ]],
  [[CREATE INDEX idx_recipe_steps_recipe ON brew_recipe_steps(recipe_id)]],
  [[
    CREATE TABLE recipe_flavor_tags (
      recipe_id     INTEGER NOT NULL REFERENCES brew_recipes(id) ON DELETE CASCADE,
      flavor_tag_id INTEGER NOT NULL REFERENCES flavor_tags(id)   ON DELETE CASCADE,
      PRIMARY KEY (recipe_id, flavor_tag_id)
    )
  ]],
  [[CREATE INDEX idx_recipe_flavor_tags_tag ON recipe_flavor_tags(flavor_tag_id)]],

  -- History: brew sessions --------------------------------------------------------
  [[
    CREATE TABLE brew_sessions (
      id                     INTEGER PRIMARY KEY,
      recipe_id              INTEGER NOT NULL REFERENCES brew_recipes(id) ON DELETE CASCADE,
      brewed_at              INTEGER NOT NULL,
      session_rating         INTEGER CHECK (session_rating IS NULL OR session_rating BETWEEN 1 AND 5),
      measured_brew_time_sec INTEGER CHECK (measured_brew_time_sec IS NULL OR measured_brew_time_sec >= 0),
      comment                TEXT    NOT NULL DEFAULT '',
      created_at             INTEGER NOT NULL
    )
  ]],
  [[CREATE INDEX idx_sessions_recipe ON brew_sessions(recipe_id)]],
  [[CREATE INDEX idx_sessions_brewed ON brew_sessions(brewed_at)]],
  [[
    CREATE VIEW recipe_stats AS
    SELECT r.id AS recipe_id,
           COUNT(s.id)           AS brew_count,
           AVG(s.session_rating) AS avg_session_rating,
           MAX(s.brewed_at)      AS last_brewed_at
    FROM brew_recipes r
    LEFT JOIN brew_sessions s ON s.recipe_id = r.id
    GROUP BY r.id
  ]],

  -- Drinks ------------------------------------------------------------------
  [[
    CREATE TABLE custom_drinks (
      id               INTEGER PRIMARY KEY,
      title            TEXT    NOT NULL,
      temperature_mode TEXT    NOT NULL CHECK (temperature_mode IN ('hot','cold')),
      base_recipe_id   INTEGER NOT NULL REFERENCES brew_recipes(id),
      base_amount      REAL    NOT NULL CHECK (base_amount > 0),
      base_unit        TEXT    NOT NULL DEFAULT 'g',
      rating           INTEGER CHECK (rating IS NULL OR rating BETWEEN 1 AND 5),
      comment          TEXT    NOT NULL DEFAULT '',
      created_at       INTEGER NOT NULL,
      updated_at       INTEGER NOT NULL,
      is_active        INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1))
    )
  ]],
  [[CREATE INDEX idx_drinks_base   ON custom_drinks(base_recipe_id)]],
  [[CREATE INDEX idx_drinks_mode   ON custom_drinks(temperature_mode)]],
  [[CREATE INDEX idx_drinks_active ON custom_drinks(is_active)]],
  [[
    CREATE TABLE custom_drink_ingredients (
      id            INTEGER PRIMARY KEY,
      drink_id      INTEGER NOT NULL REFERENCES custom_drinks(id) ON DELETE CASCADE,
      ingredient_id INTEGER NOT NULL REFERENCES ingredients(id),
      amount        REAL    NOT NULL CHECK (amount >= 0),
      unit          TEXT    NOT NULL,
      sort_order    INTEGER NOT NULL DEFAULT 0
    )
  ]],
  [[CREATE INDEX idx_drink_ingredients_drink ON custom_drink_ingredients(drink_id)]],
  [[CREATE INDEX idx_drink_ingredients_ing   ON custom_drink_ingredients(ingredient_id)]],
  [[
    CREATE TABLE custom_drink_steps (
      id          INTEGER PRIMARY KEY,
      drink_id    INTEGER NOT NULL REFERENCES custom_drinks(id) ON DELETE CASCADE,
      step_order  INTEGER NOT NULL,
      instruction TEXT    NOT NULL DEFAULT '',
      note        TEXT    NOT NULL DEFAULT '',
      UNIQUE (drink_id, step_order)
    )
  ]],
  [[CREATE INDEX idx_drink_steps_drink ON custom_drink_steps(drink_id)]],

  -- System ----------------------------------------------------------------------
  [[
    CREATE TABLE app_metadata (
      key   TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ]],
}

return Schema
