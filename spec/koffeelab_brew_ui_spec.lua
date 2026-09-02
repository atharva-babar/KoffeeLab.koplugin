require("koffeelab.spec_helper")
local helper = require("koffeelab.spec_helper")
local Nav = require("ui/nav")
local Screen = require("device").screen

local MethodService = require("services/method_service")
local RecipeService = require("services/recipe_service")
local BrewService = require("services/brew_service")
local AddFlow = require("ui/recipe/add_flow")

local RecipeDetail = require("ui/recipe/detail")
local BrewAgain = require("ui/recipe/brew_again")
local Stopwatch = require("ui/recipe/stopwatch")
local History = require("ui/recipe/history")

local function draft_for(slug, ids)
  local _, method = MethodService.get_by_slug(slug)
  return {
    recipe = {
      method_slug = method.slug,
      title = "Test " .. slug,
      bean_id = ids.bean_id,
      grinder_id = ids.grinder_id,
      grind_value = 15,
      dose_g = 18,
      water_g = slug ~= "espresso" and 250 or nil,
      water_temp_c = 94,
      brew_time_sec = 165,
      output_weight_g = slug == "espresso" and 36 or 210,
      notes = "",
    },
    method = method,
    steps = {},
    spec = {},
    flavor_tag_ids = {},
  }
end

local function make_recipe(slug, ids)
  local ok, recipe = RecipeService.create(AddFlow.payload(draft_for(slug, ids)))
  assert(ok, recipe)
  return recipe
end

-- Find the first FormScreen row whose field has key `k`.
local function field_item(form, k)
  for _, item in ipairs(form.item_table) do
    if item._field and item._field.key == k then
      return item
    end
  end
end

local function tap_action(form, label)
  for _, item in ipairs(form.item_table) do
    if item._action and item.text == label then
      return item._action.callback(form)
    end
  end
  error("no action row: " .. label)
end

describe("ui brew history (Phase 7)", function()
  local ids

  before_each(function()
    ids = helper.recipe_ready()
    Nav:closeAll()
  end)

  after_each(function()
    Nav:closeAll()
    helper.teardown()
  end)

  describe("Brew Again dialog", function()
    it("records a session with rating + comment and re-derives the stats", function()
      local recipe = make_recipe("pour_over", ids)
      local refreshed = false
      local form = BrewAgain.open(recipe.id, {
        brew_count = 0,
        on_saved = function()
          refreshed = true
        end,
      })
      form:paintTo(Screen.bb, 0, 0)

      -- header row shows the projected brew count
      assert.are.equal("1", field_item(form, "_info").mandatory)

      -- set values straight on the draft the form reads
      form.values.session_rating = 4
      form.values.comment = "stronger agitation"
      tap_action(form, "Save")

      assert.is_true(refreshed)
      local _, sessions = BrewService.list_for_recipe(recipe.id)
      assert.are.equal(1, #sessions)
      assert.are.equal(4, tonumber(sessions[1].session_rating))
      assert.are.equal("stronger agitation", sessions[1].comment)

      local _, stats = BrewService.stats(recipe.id)
      assert.are.equal(1, tonumber(stats.brew_count))
      assert.are.equal(4, tonumber(stats.avg_session_rating))
    end)

    it("appends captured splits to the comment as plain text", function()
      local recipe = make_recipe("pour_over", ids)
      local form = BrewAgain.open(recipe.id, {})
      form.values.measured_brew_time_sec = 165
      form.values.splits_suffix = BrewAgain._splits_suffix { 32, 70, 165 }
      tap_action(form, "Save")

      local _, sessions = BrewService.list_for_recipe(recipe.id)
      assert.are.equal(165, tonumber(sessions[1].measured_brew_time_sec))
      assert.is_truthy(sessions[1].comment:find("splits: 0:32 / 1:10 / 2:45", 1, true))
    end)

    it("Cancel closes without recording", function()
      local recipe = make_recipe("pour_over", ids)
      local form = BrewAgain.open(recipe.id, {})
      assert.are.equal(1, Nav:depth())
      tap_action(form, "Cancel")
      assert.are.equal(0, Nav:depth())
      local _, sessions = BrewService.list_for_recipe(recipe.id)
      assert.are.equal(0, #sessions)
    end)
  end)

  describe("tap-to-capture stopwatch", function()
    it("runs the start / split / stop state machine and hands back the time", function()
      local captured
      local sw = Nav:push(Stopwatch:new {
        on_capture = function(elapsed, splits)
          captured = { elapsed = elapsed, splits = splits }
        end,
      })
      sw:paintTo(Screen.bb, 0, 0)

      local function tap(act)
        for _, item in ipairs(sw.item_table) do
          if item._act == act then
            sw:onMenuChoice(item)
            return
          end
        end
        error("no action row: " .. act)
      end

      assert.are.equal("idle", sw.state)
      tap("start")
      assert.are.equal("running", sw.state)
      -- fake two split marks (os.time() resolution is coarse for a unit test)
      sw.splits = { 32, 70 }
      sw.start_time = sw.start_time - 165
      tap("stop")
      assert.are.equal("stopped", sw.state)
      tap("use")

      assert.is_table(captured)
      assert.is_true(captured.elapsed >= 165)
      assert.are.same({ 32, 70 }, captured.splits)
      assert.are.equal(0, Nav:depth()) -- popped itself after "use"
    end)

    it("Restart clears elapsed and splits", function()
      local sw = Nav:push(Stopwatch:new {})
      sw.state = "stopped"
      sw.elapsed = 90
      sw.splits = { 10, 20 }
      for _, item in ipairs(sw:_items()) do
        if item._act == "restart" then
          sw:onMenuChoice(item)
        end
      end
      assert.are.equal("idle", sw.state)
      assert.are.equal(0, sw.elapsed)
      assert.are.equal(0, #sw.splits)
    end)
  end)

  describe("brew history sub-screen", function()
    it("lists sessions newest-first and deletes one, refreshing stats", function()
      local recipe = make_recipe("pour_over", ids)
      assert(BrewService.record { recipe_id = recipe.id, session_rating = 3, comment = "first" })
      assert(BrewService.record { recipe_id = recipe.id, session_rating = 5, comment = "second" })

      local changed = 0
      local screen = Nav:push(History:new {
        recipe_id = recipe.id,
        on_changed = function()
          changed = changed + 1
        end,
      })
      screen:paintTo(Screen.bb, 0, 0)
      assert.are.equal(2, #screen.sessions)

      -- delete the newest session directly through the service, then refresh
      local newest = screen.sessions[1]
      assert(BrewService.delete(newest.id))
      screen:_refresh()
      assert.are.equal(1, #screen.sessions)

      local _, stats = BrewService.stats(recipe.id)
      assert.are.equal(1, tonumber(stats.brew_count))
      assert.are.equal(3, tonumber(stats.avg_session_rating))
    end)

    it("shows an empty state with no sessions", function()
      local recipe = make_recipe("pour_over", ids)
      local screen = Nav:push(History:new { recipe_id = recipe.id })
      assert.are.equal(1, #screen.item_table)
      assert.is_truthy(screen.item_table[1]._inert)
      screen:paintTo(Screen.bb, 0, 0)
    end)
  end)

  describe("recipe detail wiring", function()
    local function card_titled(detail, title)
      for _, c in ipairs(detail.cards) do
        if c.title == title then
          return c
        end
      end
    end

    it("has a tappable History card that opens the sub-screen", function()
      local recipe = make_recipe("pour_over", ids)
      assert(BrewService.record { recipe_id = recipe.id, session_rating = 4 })
      local detail = Nav:push(RecipeDetail:new { recipe_id = recipe.id })

      local history = card_titled(detail, "History")
      assert.is_truthy(history)
      assert.is_function(history.on_tap)

      detail:_openHistory()
      assert.are.equal("koffeelab_recipe_history", Nav:top().name)
    end)

    it("Brew again from the navbar records a session and reloads", function()
      local recipe = make_recipe("pour_over", ids)
      local detail = Nav:push(RecipeDetail:new { recipe_id = recipe.id })
      detail:onNavAction("brew_again")

      local form = Nav:top()
      assert.are.equal("koffeelab_form", form.name)
      form.values.session_rating = 5
      tap_action(form, "Save")

      -- back on the detail, stats re-derived
      assert.are.equal("koffeelab_recipe_detail", Nav:top().name)
      local _, stats = BrewService.stats(recipe.id)
      assert.are.equal(1, tonumber(stats.brew_count))
    end)

    it("the favourite navbar cell toggles state", function()
      local recipe = make_recipe("pour_over", ids)
      local detail = Nav:push(RecipeDetail:new { recipe_id = recipe.id })
      assert.is_false(detail:_isFavourite())
      detail:onNavAction("favourite")
      assert.is_true(detail:_isFavourite())
    end)
  end)
end)
