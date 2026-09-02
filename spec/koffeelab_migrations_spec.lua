local helper = require("koffeelab.spec_helper")
local Migrations = require("db/migrations")

local function names_of(conn, type_)
  local out = {}
  local stmt = conn:prepare("SELECT name FROM sqlite_master WHERE type = ? ORDER BY name")
  stmt:bind1(1, type_)
  while true do
    local row = stmt:step()
    if not row then
      break
    end
    out[row[1]] = true
  end
  stmt:close()
  return out
end

describe("db/migrations", function()
  after_each(function()
    helper.teardown()
  end)

  it("brings a fresh DB to schema version 2", function()
    local conn = helper.fresh_connection()
    assert.are.equal(Migrations.CURRENT_SCHEMA_VERSION, Migrations.run(conn))
    assert.are.equal(2, tonumber(conn:rowexec("PRAGMA user_version")))
  end)

  it("creates the v2 tables and leaves no legacy method tables", function()
    local conn = helper.fresh_connection()
    Migrations.run(conn)
    local tables = names_of(conn, "table")
    for _, name in ipairs {
      "beans",
      "grinders",
      "ingredients",
      "flavor_tags",
      "brew_recipes",
      "recipe_flavor_tags",
      "brew_sessions",
      "custom_drinks",
      "custom_drink_ingredients",
      "custom_drink_steps",
      "app_metadata",
    } do
      assert.is_true(tables[name] == true, "missing table: " .. name)
    end
    for _, gone in ipairs {
      "brew_methods",
      "brew_method_parameters",
      "brew_method_step_types",
      "brew_method_equipment",
      "brew_recipe_parameters",
      "brew_recipe_steps",
    } do
      assert.is_nil(tables[gone], "table should be gone: " .. gone)
    end
    assert.is_true(names_of(conn, "view").recipe_stats == true)
  end)

  it("gives brew_recipes the new method_slug and JSON columns", function()
    local conn = helper.fresh_connection()
    Migrations.run(conn)
    local cols = {}
    local stmt = conn:prepare("PRAGMA table_info(brew_recipes)")
    while true do
      local row = stmt:step()
      if not row then
        break
      end
      cols[row[2]] = true
    end
    stmt:close()
    for _, name in ipairs { "method_slug", "spec_json", "steps_json", "output_note", "is_favorite" } do
      assert.is_true(cols[name] == true, "missing column: " .. name)
    end
    assert.is_nil(cols.method_id)
  end)

  it("is a no-op on the second run", function()
    local conn = helper.fresh_connection()
    Migrations.run(conn)
    local Config = require("db/repo/config")
    assert(Config.beans.create { name = "Keep me", roaster_name = "R" })
    assert.are.equal(Migrations.CURRENT_SCHEMA_VERSION, Migrations.run(conn))
    assert.are.equal(1, tonumber(conn:rowexec("SELECT COUNT(*) FROM beans")))
  end)

  it("rolls the whole migration back when a statement fails", function()
    local Schema = require("db/schema")
    local bad = "CREATE TABLE koffeelab_deliberately_broken ("
    table.insert(Schema.STATEMENTS, bad)
    finally(function()
      for i = #Schema.STATEMENTS, 1, -1 do
        if Schema.STATEMENTS[i] == bad then
          table.remove(Schema.STATEMENTS, i)
        end
      end
    end)

    local conn = helper.fresh_connection()
    local ok, err = Migrations.run(conn)
    assert.is_nil(ok)
    assert.is_truthy(err)
    assert.are.equal(0, tonumber(conn:rowexec("PRAGMA user_version")))
    assert.are.equal(
      0,
      tonumber(
        conn:rowexec("SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = 'beans'")
      )
    )
  end)
end)
