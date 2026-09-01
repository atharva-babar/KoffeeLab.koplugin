-- Trivial sanity spec: proves the busted harness runs.
-- Real business-logic specs (db/, model/, services/) arrive from Phase 1 onward and
-- use an in-memory SQLite DB seeded per test.

describe("busted harness", function()
  it("runs a passing assertion", function()
    assert.are.equal(4, 2 + 2)
  end)

  it("has a working Lua runtime", function()
    assert.is_truthy(string.format("%.1f", 16.6667):match("16%.7"))
  end)
end)
