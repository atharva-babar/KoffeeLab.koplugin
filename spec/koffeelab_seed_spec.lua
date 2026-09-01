local helper = require("koffeelab.spec_helper")
local Seed = require("db/seed")

local EXPECTED_SLUGS = { "pour_over", "aeropress", "french_press", "espresso", "cold_brew" }

local function scalar(conn, sql, ...)
  local stmt = conn:prepare(sql)
  if select("#", ...) > 0 then
    stmt:bind(...)
  end
  local row = stmt:step()
  stmt:close()
  return row and row[1] or nil
end

describe("db/seed", function()
  local conn

  before_each(function()
    conn = helper.migrated_connection()
  end)

  after_each(function()
    helper.teardown()
  end)

  it("inserts the five system methods", function()
    assert.are.equal(5, tonumber(scalar(conn, "SELECT COUNT(*) FROM brew_methods")))
    assert.are.equal(
      5,
      tonumber(scalar(conn, "SELECT COUNT(*) FROM brew_methods WHERE is_system = 1"))
    )
    for _, slug in ipairs(EXPECTED_SLUGS) do
      assert.are.equal(
        1,
        tonumber(scalar(conn, "SELECT COUNT(*) FROM brew_methods WHERE slug = ?", slug)),
        "missing method: " .. slug
      )
    end
  end)

  it("gives every method its step types and parameters", function()
    for _, method in ipairs(Seed.SYSTEM_METHODS) do
      local method_id =
        tonumber(scalar(conn, "SELECT id FROM brew_methods WHERE slug = ?", method.slug))
      assert.are.equal(
        #method.step_types,
        tonumber(
          scalar(conn, "SELECT COUNT(*) FROM brew_method_step_types WHERE method_id = ?", method_id)
        ),
        method.slug .. " step type count"
      )
      assert.are.equal(
        #method.parameters,
        tonumber(
          scalar(conn, "SELECT COUNT(*) FROM brew_method_parameters WHERE method_id = ?", method_id)
        ),
        method.slug .. " parameter count"
      )
    end
  end)

  it("stores step types in declared order", function()
    local method_id = tonumber(scalar(conn, "SELECT id FROM brew_methods WHERE slug = 'pour_over'"))
    local stmt = conn:prepare(
      "SELECT step_type FROM brew_method_step_types WHERE method_id = ? ORDER BY sort_order"
    )
    stmt:bind1(1, method_id)
    local got = {}
    while true do
      local row = stmt:step()
      if not row then
        break
      end
      got[#got + 1] = row[1]
    end
    stmt:close()
    assert.are.same({ "bloom", "pour", "wait", "finish" }, got)
  end)

  it("does not duplicate rows when run again", function()
    Seed.seed_system_methods(conn)
    assert.are.equal(5, tonumber(scalar(conn, "SELECT COUNT(*) FROM brew_methods")))
    local total_steps = tonumber(scalar(conn, "SELECT COUNT(*) FROM brew_method_step_types"))
    local total_params = tonumber(scalar(conn, "SELECT COUNT(*) FROM brew_method_parameters"))
    Seed.seed_system_methods(conn)
    assert.are.equal(
      total_steps,
      tonumber(scalar(conn, "SELECT COUNT(*) FROM brew_method_step_types"))
    )
    assert.are.equal(
      total_params,
      tonumber(scalar(conn, "SELECT COUNT(*) FROM brew_method_parameters"))
    )
  end)
end)
