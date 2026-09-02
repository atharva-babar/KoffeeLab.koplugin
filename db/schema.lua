-- db/schema.lua
-- Schema v2 baseline DDL, one statement per array entry. The migration runner
-- applies DROP_LEGACY then STATEMENTS in a single transaction. Brew methods are
-- static code (methods/), not rows; method-specific recipe data and steps ride
-- in JSON columns on brew_recipes.

local Schema = {}

Schema.DROP_LEGACY = {
  [[DROP VIEW  IF EXISTS recipe_stats]],
  [[DROP TABLE IF EXISTS recipe_flavor_tags]],
  [[DROP TABLE IF EXISTS brew_recipe_steps]],
  [[DROP TABLE IF EXISTS brew_recipe_parameters]],
  [[DROP TABLE IF EXISTS brew_sessions]],
  [[DROP TABLE IF EXISTS custom_drink_steps]],
  [[DROP TABLE IF EXISTS custom_drink_ingredients]],
  [[DROP TABLE IF EXISTS custom_drinks]],
  [[DROP TABLE IF EXISTS brew_recipes]],
  [[DROP TABLE IF EXISTS brew_method_equipment]],
  [[DROP TABLE IF EXISTS brew_method_step_types]],
  [[DROP TABLE IF EXISTS brew_method_parameters]],
  [[DROP TABLE IF EXISTS brew_methods]],
  [[DROP TABLE IF EXISTS beans]],
  [[DROP TABLE IF EXISTS grinders]],
  [[DROP TABLE IF EXISTS ingredients]],
  [[DROP TABLE IF EXISTS flavor_tags]],
  [[DROP TABLE IF EXISTS app_metadata]],
}

Schema.STATEMENTS = {
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

  [[
    CREATE TABLE brew_recipes (
      id              INTEGER PRIMARY KEY,
      title           TEXT    NOT NULL,
      method_slug     TEXT    NOT NULL,
      bean_id         INTEGER REFERENCES beans(id),
      grinder_id      INTEGER REFERENCES grinders(id),
      grind_value     REAL,
      dose_g          REAL,
      water_g         REAL,
      water_temp_c    REAL,
      brew_time_sec   INTEGER,
      output_weight_g REAL,
      spec_json       TEXT    NOT NULL DEFAULT '{}',
      steps_json      TEXT    NOT NULL DEFAULT '[]',
      output_note     TEXT    NOT NULL DEFAULT '',
      acidity         INTEGER CHECK (acidity    IS NULL OR acidity    BETWEEN 1 AND 5),
      sweetness       INTEGER CHECK (sweetness  IS NULL OR sweetness  BETWEEN 1 AND 5),
      strength        INTEGER CHECK (strength   IS NULL OR strength   BETWEEN 1 AND 5),
      body            INTEGER CHECK (body       IS NULL OR body       BETWEEN 1 AND 5),
      brightness      INTEGER CHECK (brightness IS NULL OR brightness BETWEEN 1 AND 5),
      overall_rating  INTEGER CHECK (overall_rating IS NULL OR overall_rating BETWEEN 1 AND 5),
      notes           TEXT    NOT NULL DEFAULT '',
      is_favorite     INTEGER NOT NULL DEFAULT 0 CHECK (is_favorite IN (0,1)),
      created_at      INTEGER NOT NULL,
      updated_at      INTEGER NOT NULL,
      is_active       INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1))
    )
  ]],
  [[CREATE INDEX idx_recipes_method   ON brew_recipes(method_slug)]],
  [[CREATE INDEX idx_recipes_bean     ON brew_recipes(bean_id)]],
  [[CREATE INDEX idx_recipes_active   ON brew_recipes(is_active)]],
  [[CREATE INDEX idx_recipes_favorite ON brew_recipes(is_favorite)]],
  [[CREATE INDEX idx_recipes_title    ON brew_recipes(title COLLATE NOCASE)]],
  [[
    CREATE TABLE recipe_flavor_tags (
      recipe_id     INTEGER NOT NULL REFERENCES brew_recipes(id) ON DELETE CASCADE,
      flavor_tag_id INTEGER NOT NULL REFERENCES flavor_tags(id)   ON DELETE CASCADE,
      PRIMARY KEY (recipe_id, flavor_tag_id)
    )
  ]],
  [[CREATE INDEX idx_recipe_flavor_tags_tag ON recipe_flavor_tags(flavor_tag_id)]],

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

  [[
    CREATE TABLE app_metadata (
      key   TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ]],
}

return Schema
