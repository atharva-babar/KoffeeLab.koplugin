local helper = require("koffeelab.spec_helper")
local Query = require("db/query")

describe("db/query", function()
  local conn

  before_each(function()
    conn = helper.fresh_connection()
    conn:exec([[
      CREATE TABLE t (
        id    INTEGER PRIMARY KEY,
        name  TEXT,
        score REAL
      )
    ]])
    conn:exec("INSERT INTO t (name, score) VALUES ('alpha', 1.5), ('beta', 2.0), ('gamma', 3.0)")
  end)

  after_each(function()
    helper.teardown()
  end)

  describe("all", function()
    it("returns every row as a column-name-keyed table", function()
      local rows = Query.all(conn, "SELECT id, name, score FROM t ORDER BY id")
      assert.are.equal(3, #rows)
      assert.are.equal("alpha", rows[1].name)
      assert.are.equal(1.5, rows[1].score)
      assert.are.equal(1, tonumber(rows[1].id))
    end)

    it("returns an empty array when nothing matches", function()
      local rows = Query.all(conn, "SELECT * FROM t WHERE name = ?", { "nobody" })
      assert.are.same({}, rows)
    end)

    it("binds string and number parameters", function()
      local rows =
        Query.all(conn, "SELECT name FROM t WHERE score >= ? AND name <> ?", { 2.0, "beta" })
      assert.are.equal(1, #rows)
      assert.are.equal("gamma", rows[1].name)
    end)

    it("binds nil as SQL NULL", function()
      local rows = Query.all(conn, "SELECT ? IS NULL AS is_null", { n = 1 })
      assert.are.equal(1, tonumber(rows[1].is_null))
    end)
  end)

  describe("one", function()
    it("returns the first row", function()
      local row = Query.one(conn, "SELECT name FROM t ORDER BY score DESC")
      assert.are.equal("gamma", row.name)
    end)

    it("returns nil when there is no row", function()
      assert.is_nil(Query.one(conn, "SELECT * FROM t WHERE id = ?", { 999 }))
    end)
  end)

  describe("exec", function()
    it("reports affected rows and the last inserted rowid", function()
      local res = Query.exec(conn, "INSERT INTO t (name, score) VALUES (?, ?)", { "delta", 4.0 })
      assert.are.equal(1, res.changes)
      assert.are.equal(4, res.last_insert_rowid)

      local upd = Query.exec(conn, "UPDATE t SET score = score + 1 WHERE score >= ?", { 2.0 })
      assert.are.equal(3, upd.changes)
    end)
  end)

  describe("like_escape", function()
    it("escapes %, _ and backslash", function()
      assert.are.equal("100\\%\\_x\\\\y", Query.like_escape("100%_x\\y"))
    end)

    it("builds a contains pattern and matches literally", function()
      Query.exec(conn, "INSERT INTO t (name, score) VALUES (?, ?)", { "50%_off", 9.0 })
      local rows = Query.all(
        conn,
        "SELECT name FROM t WHERE name LIKE ? ESCAPE '\\'",
        { Query.like_contains("%_") }
      )
      assert.are.equal(1, #rows)
      assert.are.equal("50%_off", rows[1].name)
    end)
  end)
end)
