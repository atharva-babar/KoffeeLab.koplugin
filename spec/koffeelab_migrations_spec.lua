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

  it("brings a fresh DB to the current schema version", function()
    local conn = helper.fresh_connection()
    assert.are.equal(Migrations.CURRENT_SCHEMA_VERSION, Migrations.run(conn))
    assert.are.equal(1, tonumber(conn:rowexec("PRAGMA user_version")))
  end)

  it("creates every table, index and view from the schema", function()
    local conn = helper.fresh_connection()
    Migrations.run(conn)

    local tables = names_of(conn, "table")
    for _, name in ipairs {
      "beans",
      "grinders",
      "ingredients",
      "flavor_tags",
      "brew_methods",
      "brew_method_parameters",
      "brew_method_step_types",
      "brew_method_equipment",
      "brew_recipes",
      "brew_recipe_parameters",
      "brew_recipe_steps",
      "recipe_flavor_tags",
      "brew_sessions",
      "custom_drinks",
      "custom_drink_ingredients",
      "custom_drink_steps",
      "app_metadata",
    } do
      assert.is_true(tables[name] == true, "missing table: " .. name)
    end

    local indexes = names_of(conn, "index")
    for _, name in ipairs {
      "idx_ingredients_name",
      "idx_flavor_tags_name",
      "idx_method_equipment_method",
      "idx_recipes_method",
      "idx_recipes_bean",
      "idx_recipes_active",
      "idx_recipes_title",
      "idx_recipe_steps_recipe",
      "idx_recipe_flavor_tags_tag",
      "idx_sessions_recipe",
      "idx_sessions_brewed",
      "idx_drinks_base",
      "idx_drinks_mode",
      "idx_drinks_active",
      "idx_drink_ingredients_drink",
      "idx_drink_ingredients_ing",
      "idx_drink_steps_drink",
    } do
      assert.is_true(indexes[name] == true, "missing index: " .. name)
    end

    assert.is_true(names_of(conn, "view").recipe_stats == true)
  end)

  it("is a no-op on the second run", function()
    local conn = helper.fresh_connection()
    Migrations.run(conn)
    local method_count = tonumber(conn:rowexec("SELECT COUNT(*) FROM brew_methods"))
    assert.are.equal(Migrations.CURRENT_SCHEMA_VERSION, Migrations.run(conn))
    assert.are.equal(method_count, tonumber(conn:rowexec("SELECT COUNT(*) FROM brew_methods")))
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
