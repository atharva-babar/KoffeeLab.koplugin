-- services/sample_data.lua
-- Loads a spread of sample beans / grinders / recipes / brew sessions / custom
-- drinks so the UI has realistic content to browse (dev + first-run demo). All
-- writes go through the normal services. Config entities are matched by name so a
-- second load does not duplicate them; recipes and drinks are always added.

local ConfigService = require("services/config_service")
local RecipeService = require("services/recipe_service")
local DrinkService = require("services/drink_service")
local BrewService = require("services/brew_service")
local SearchService = require("services/search_service")

local SampleData = {}

local GRINDERS = {
  { name = "Timemore C3S", unit_name = "clicks", min_value = 1, max_value = 30, step_value = 1 },
  { name = "Comandante C40", unit_name = "clicks", min_value = 0, max_value = 40, step_value = 1 },
  { name = "Niche Zero", unit_name = "dial", min_value = 0, max_value = 50, step_value = 1 },
  { name = "1Zpresso J-Max", unit_name = "clicks", min_value = 0, max_value = 90, step_value = 1 },
}

local BEANS = {
  { name = "Ethiopia Guji Natural", roaster_name = "Blue Tokai", roast_level = 2 },
  { name = "Colombia Huila Pink Bourbon", roaster_name = "Corvus", roast_level = 2 },
  { name = "Kenya Nyeri AA", roaster_name = "Onyx", roast_level = 3 },
  { name = "Brazil Cerrado", roaster_name = "Sey", roast_level = 4 },
  { name = "Guatemala Antigua", roaster_name = "Tim Wendelboe", roast_level = 3 },
  { name = "Sumatra Mandheling", roaster_name = "Verve", roast_level = 5 },
}

local INGREDIENTS = {
  "Whole milk",
  "Oat milk",
  "Tonic water",
  "Sparkling water",
  "Simple syrup",
  "Ice",
  "Orange peel",
}

local TAGS =
  { "Floral", "Berry", "Chocolate", "Citrus", "Nutty", "Stone fruit", "Tea-like", "Caramel" }

-- recipe, tag names, and 0-3 canned sessions each
local RECIPES = {
  {
    method = "pour_over",
    title = "Guji V60 \u{2014} bright morning",
    dose_g = 15,
    water_g = 250,
    water_temp_c = 94,
    brew_time_sec = 165,
    grind_value = 18,
    spec = { dripper = "V60" },
    overall_rating = 5,
    acidity = 5,
    sweetness = 4,
    body = 2,
    brightness = 5,
    strength = 3,
    notes = "Jasmine and lemon, very clean. 45s bloom.",
    output_note = "Drawdown finishes ~2:45, tea-like body.",
    fav = true,
    tags = { "Floral", "Citrus", "Tea-like" },
    steps = {
      { step_type = "bloom", start_time = 0, water = 45, note = "Swirl gently" },
      { step_type = "pour", start_time = 45, water = 150, note = "Spiral to 150 g" },
      { step_type = "pour", start_time = 90, water = 250, note = "Top up to 250 g" },
      { step_type = "drawdown", start_time = 150 },
    },
    sessions = {
      { rating = 5, comment = "Best one yet." },
      { rating = 4, comment = "Bloom looked even." },
    },
  },
  {
    method = "pour_over",
    title = "Kenya Kalita \u{2014} juicy",
    dose_g = 20,
    water_g = 320,
    water_temp_c = 92,
    brew_time_sec = 200,
    grind_value = 20,
    spec = { dripper = "Kalita Wave" },
    overall_rating = 4,
    acidity = 4,
    sweetness = 4,
    body = 3,
    notes = "Blackcurrant, tomato. Flat bed helps.",
    tags = { "Berry" },
    sessions = {
      { rating = 4 },
      { rating = 3, comment = "A touch sour \u{2014} grind finer." },
      {},
    },
  },
  {
    method = "pour_over",
    title = "Chemex \u{2014} Sunday batch",
    dose_g = 42,
    water_g = 700,
    water_temp_c = 95,
    brew_time_sec = 300,
    grind_value = 24,
    spec = { dripper = "Chemex" },
    overall_rating = 4,
    notes = "Scaled up for two. Coarser than a single V60.",
    tags = { "Chocolate", "Nutty" },
    sessions = { { rating = 4 } },
  },
  {
    method = "aeropress",
    title = "AeroPress inverted \u{2014} chocolate",
    dose_g = 16,
    water_g = 220,
    water_temp_c = 85,
    brew_time_sec = 90,
    output_weight_g = 200,
    grind_value = 12,
    spec = { orientation = "Inverted", filter_type = "Paper", bypass_water = 30 },
    overall_rating = 4,
    sweetness = 5,
    body = 4,
    notes = "1:00 steep, gentle press. Dilute after.",
    tags = { "Chocolate", "Caramel" },
    steps = {
      { step_type = "setup", start_time = 0, note = "Rinse filter" },
      { step_type = "pour", start_time = 0, water = 190, note = "All in, stir 3x" },
      { step_type = "wait", start_time = 15 },
      { step_type = "press", start_time = 75, note = "~20s press" },
      { step_type = "bypass", start_time = 90, water = 30 },
    },
    sessions = { { rating = 4 }, { rating = 4, comment = "Channelled slightly." } },
  },
  {
    method = "aeropress",
    title = "AeroPress standard \u{2014} quick cup",
    dose_g = 14,
    water_g = 200,
    water_temp_c = 90,
    brew_time_sec = 75,
    output_weight_g = 180,
    grind_value = 10,
    spec = { orientation = "Standard", filter_type = "Metal" },
    overall_rating = 3,
    notes = "Metal filter, a bit more body and sediment.",
    tags = { "Nutty" },
    sessions = { { rating = 3 } },
  },
  {
    method = "french_press",
    title = "French Press \u{2014} full immersion",
    dose_g = 30,
    water_g = 500,
    water_temp_c = 96,
    brew_time_sec = 480,
    grind_value = 30,
    spec = { steep_time = 240, crust_break = true },
    overall_rating = 4,
    body = 5,
    strength = 4,
    notes = "Break crust at 4:00, skim, plunge at 8:00.",
    fav = true,
    tags = { "Chocolate", "Nutty" },
    steps = {
      { step_type = "pour", start_time = 0, note = "Saturate grounds" },
      { step_type = "wait", start_time = 0 },
      { step_type = "stir", start_time = 240, note = "Break the crust" },
      { step_type = "plunge", start_time = 480 },
      { step_type = "decant", start_time = 490 },
    },
    sessions = { { rating = 4 }, { rating = 4 }, {} },
  },
  {
    method = "french_press",
    title = "French Press \u{2014} clean method",
    dose_g = 28,
    water_g = 450,
    water_temp_c = 94,
    brew_time_sec = 600,
    grind_value = 34,
    spec = { steep_time = 480, crust_break = false },
    overall_rating = 4,
    notes = "No stir, no plunge \u{2014} decant off the top.",
    tags = { "Caramel" },
    sessions = {},
  },
  {
    method = "espresso",
    title = "House espresso \u{2014} Brazil",
    dose_g = 18,
    water_temp_c = 93,
    brew_time_sec = 28,
    output_weight_g = 38,
    grind_value = 12,
    spec = { preinfusion = 6, basket = "Double" },
    overall_rating = 4,
    body = 4,
    sweetness = 4,
    notes = "1:2.1 ratio, hazelnut and cocoa.",
    output_note = "Thick, syrupy. Bitter past 40 g.",
    fav = true,
    tags = { "Chocolate", "Nutty", "Caramel" },
    steps = {
      { step_type = "preinfuse", start_time = 0, note = "6s at low pressure" },
      { step_type = "extract", start_time = 6, note = "Full pressure to 38 g" },
    },
    sessions = { { rating = 4 }, { rating = 3, comment = "Ran a little fast." } },
  },
  {
    method = "espresso",
    title = "Light roast shot \u{2014} Ethiopia",
    dose_g = 18,
    water_temp_c = 95,
    brew_time_sec = 32,
    output_weight_g = 45,
    grind_value = 8,
    spec = { preinfusion = 10, basket = "Double" },
    overall_rating = 5,
    acidity = 5,
    brightness = 5,
    notes = "1:2.5, longer ratio for the acidity. Peach, bergamot.",
    tags = { "Stone fruit", "Citrus", "Floral" },
    sessions = { { rating = 5 }, { rating = 5 } },
  },
  {
    method = "cold_brew",
    title = "Cold brew concentrate \u{2014} 16h",
    dose_g = 100,
    water_g = 1000,
    brew_time_sec = 57600,
    grind_value = 38,
    spec = { dilution_ratio = "1:1 with water", vessel = "Toddy" },
    overall_rating = 4,
    sweetness = 4,
    body = 4,
    notes = "Fridge, 16 hours. Dilute 1:1 over ice.",
    output_note = "Smooth, low acidity. Keeps ~1 week.",
    tags = { "Chocolate", "Caramel" },
    steps = {
      { step_type = "pour", start_time = 0, water = 1000, note = "Saturate fully" },
      { step_type = "immerse", start_time = 0 },
      { step_type = "wait", start_time = 0, note = "16 h in the fridge" },
      { step_type = "decant", start_time = 57600, note = "Filter through paper" },
    },
    sessions = { { rating = 4 } },
  },
  {
    method = "cold_brew",
    title = "Cold brew \u{2014} jar, ready to drink",
    dose_g = 60,
    water_g = 900,
    brew_time_sec = 43200,
    grind_value = 40,
    spec = { dilution_ratio = "none", vessel = "Jar" },
    overall_rating = 3,
    notes = "1:15, 12h, drink straight. Weaker but easy.",
    tags = { "Nutty" },
    sessions = { { rating = 3 }, {} },
  },
}

local function find_or_create(svc, name, fields)
  local ok, rows = svc.list { include_inactive = true }
  if ok then
    for _, row in ipairs(rows) do
      if row.name == name then
        return row
      end
    end
  end
  local cok, row = svc.create(fields)
  assert(cok, tostring(row))
  return row
end

--- True when the catalogue already has recipes (so the caller can warn).
function SampleData.loaded()
  local _, rows = SearchService.recipes {}
  return rows and #rows > 0
end

--- Load the sample set. Returns `ok, summary_table_or_err`.
function SampleData.load()
  local ok, err = pcall(function()
    local grinders, beans, ings, tags = {}, {}, {}, {}
    for _, g in ipairs(GRINDERS) do
      grinders[#grinders + 1] = find_or_create(ConfigService.grinders, g.name, g)
    end
    for _, b in ipairs(BEANS) do
      beans[#beans + 1] = find_or_create(ConfigService.beans, b.name, b)
    end
    for _, name in ipairs(INGREDIENTS) do
      ings[name] = find_or_create(ConfigService.ingredients, name, { name = name })
    end
    for _, name in ipairs(TAGS) do
      tags[name] = find_or_create(ConfigService.flavor_tags, name, { name = name })
    end

    local summary = { recipes = 0, sessions = 0, drinks = 0 }
    local by_method = {}
    for i, r in ipairs(RECIPES) do
      local tag_ids = {}
      for _, tname in ipairs(r.tags or {}) do
        tag_ids[#tag_ids + 1] = tags[tname].id
      end
      local recipe = {
        method_slug = r.method,
        title = r.title,
        bean_id = beans[(i % #beans) + 1].id,
        grinder_id = grinders[(i % #grinders) + 1].id,
        grind_value = r.grind_value,
        dose_g = r.dose_g,
        water_g = r.water_g,
        water_temp_c = r.water_temp_c,
        brew_time_sec = r.brew_time_sec,
        output_weight_g = r.output_weight_g,
        output_note = r.output_note or "",
        acidity = r.acidity,
        sweetness = r.sweetness,
        strength = r.strength,
        body = r.body,
        brightness = r.brightness,
        overall_rating = r.overall_rating,
        notes = r.notes or "",
        is_favorite = r.fav and 1 or 0,
      }
      local rok, row = RecipeService.create(recipe, r.steps or {}, r.spec or {}, tag_ids)
      assert(rok, tostring(row))
      summary.recipes = summary.recipes + 1
      by_method[r.method] = by_method[r.method] or row

      for _, s in ipairs(r.sessions or {}) do
        assert(BrewService.record {
          recipe_id = row.id,
          session_rating = s.rating,
          measured_brew_time_sec = r.brew_time_sec,
          comment = s.comment or "",
        })
        summary.sessions = summary.sessions + 1
      end
    end

    local esp = by_method.espresso
    local cold = by_method.cold_brew
    local DRINKS = {
      {
        d = {
          title = "Flat white",
          temperature_mode = "hot",
          base_recipe_id = esp.id,
          base_amount = 38,
          base_unit = "g",
          rating = 5,
          comment = "6 oz, silky microfoam.",
        },
        ings = { { name = "Whole milk", amount = 120, unit = "ml" } },
        steps = {
          { instruction = "Pull the shot into the cup" },
          { instruction = "Steam milk to ~60 C", note = "Stretch briefly, then spin" },
          { instruction = "Pour to a small dot" },
        },
      },
      {
        d = {
          title = "Iced oat latte",
          temperature_mode = "cold",
          base_recipe_id = esp.id,
          base_amount = 38,
          base_unit = "g",
          rating = 4,
          comment = "Long, refreshing.",
        },
        ings = {
          { name = "Oat milk", amount = 180, unit = "ml" },
          { name = "Ice", amount = 120, unit = "g" },
          { name = "Simple syrup", amount = 10, unit = "ml" },
        },
        steps = {
          { instruction = "Fill glass with ice" },
          { instruction = "Add oat milk and syrup" },
          { instruction = "Pour shot over the back of a spoon", note = "Keep the layers" },
        },
      },
      {
        d = {
          title = "Espresso tonic",
          temperature_mode = "cold",
          base_recipe_id = esp.id,
          base_amount = 38,
          base_unit = "g",
          rating = 4,
          comment = "Bittersweet, citrusy.",
        },
        ings = {
          { name = "Tonic water", amount = 150, unit = "ml" },
          { name = "Ice", amount = 100, unit = "g" },
          { name = "Orange peel", amount = 1, unit = "parts" },
        },
        steps = {
          { instruction = "Ice + tonic in a highball" },
          { instruction = "Rest 30s so it doesn't foam over" },
          { instruction = "Slowly add the shot" },
          { instruction = "Express an orange peel over the top" },
        },
      },
      {
        d = {
          title = "Cold brew + milk",
          temperature_mode = "cold",
          base_recipe_id = cold.id,
          base_amount = 150,
          base_unit = "ml",
          rating = 3,
          comment = "Easy weekday drink.",
        },
        ings = {
          { name = "Whole milk", amount = 100, unit = "ml" },
          { name = "Ice", amount = 120, unit = "g" },
        },
        steps = {},
      },
    }
    for _, entry in ipairs(DRINKS) do
      local ing_rows = {}
      for _, ig in ipairs(entry.ings) do
        ing_rows[#ing_rows + 1] =
          { ingredient_id = ings[ig.name].id, amount = ig.amount, unit = ig.unit }
      end
      assert(DrinkService.create(entry.d, ing_rows, entry.steps))
      summary.drinks = summary.drinks + 1
    end

    return summary
  end)

  if not ok then
    return false, tostring(err)
  end
  return true, err
end

return SampleData
