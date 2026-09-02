-- util/format.lua
-- Render-time formatting helpers (TECH_SOLUTION §1.15 durations, §1.9 ratio,
-- §1.11 rating). Physical values are stored raw (REAL grams, integer seconds);
-- every human-readable string is produced here so the DB never stores a
-- formatted value and the rules live in one place.

local Constants = require("util/constants")

local Format = {}

local STAR_FULL = "\u{2605}" -- ★
local STAR_EMPTY = "\u{2606}" -- ☆
local STAR_HALF = "\u{00BD}" -- ½ (appended; e-ink has no reliable half-star glyph)

-- SQLite INTEGER columns arrive as int64 cdata, which fails a `type() == "number"`
-- test; coerce so the callers can pass raw DB values straight in.
local function to_num(v)
  if type(v) == "number" then
    return v
  end
  if type(v) == "cdata" then
    return tonumber(v)
  end
  return nil
end

--- Integer seconds -> a compact duration string (§1.15):
---   165   -> "2:45"      (sub-hour, not a whole minute)
---   900   -> "15 min"    (whole minutes, sub-hour)
---   7200  -> "2 h"       (whole hours)
---   3660  -> "1:01:00"   (hours + remainder)
--- Returns nil for nil / negative / non-number input.
function Format.duration(sec)
  sec = to_num(sec)
  if sec == nil or sec < 0 then
    return nil
  end
  sec = math.floor(sec + 0.5)
  if sec == 0 then
    return "0:00"
  end
  if sec >= 3600 then
    if sec % 3600 == 0 then
      return string.format("%d h", sec / 3600)
    end
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = sec % 60
    return string.format("%d:%02d:%02d", h, m, s)
  end
  if sec % 60 == 0 then
    return string.format("%d min", sec / 60)
  end
  return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

--- Brew ratio (§1.9). Returns `label, kind` where kind is "brew" (water/dose) or
--- "yield" (output/dose — the Espresso fallback when water_g is NULL). Returns
--- nil when dose is missing/zero and no usable numerator exists.
function Format.ratio(water_g, dose_g, output_weight_g)
  water_g, dose_g, output_weight_g = to_num(water_g), to_num(dose_g), to_num(output_weight_g)
  if dose_g == nil or dose_g <= 0 then
    return nil
  end
  if water_g ~= nil and water_g >= 0 then
    return string.format("1 : %.1f", water_g / dose_g), "brew"
  end
  if output_weight_g ~= nil and output_weight_g > 0 then
    return string.format("1 : %.1f", output_weight_g / dose_g), "yield"
  end
  return nil
end

--- Whole-number catalogue rating (§1.11): N filled + (5-N) empty stars.
--- Returns nil for nil; clamps out-of-range input into 0..5.
function Format.rating_stars(n)
  n = to_num(n)
  if n == nil then
    return nil
  end
  n = math.max(0, math.min(5, math.floor(n + 0.5)))
  return string.rep(STAR_FULL, n) .. string.rep(STAR_EMPTY, 5 - n)
end

--- Derived session average (§1.11) as one decimal, e.g. 4.6667 -> "4.7".
function Format.rating_decimal(x)
  x = to_num(x)
  if x == nil then
    return nil
  end
  return string.format("%.1f", x)
end

--- Derived session average rendered as stars with a trailing ½ when the
--- fractional part rounds to a half, e.g. 3.7 -> "★★★★" ... 3.4 -> "★★★½".
function Format.rating_avg_stars(x)
  x = to_num(x)
  if x == nil then
    return nil
  end
  x = math.max(0, math.min(5, x))
  local whole = math.floor(x)
  local frac = x - whole
  local half = ""
  if frac >= 0.75 then
    whole = whole + 1
  elseif frac >= 0.25 then
    half = STAR_HALF
  end
  local empty = 5 - whole - (half ~= "" and 1 or 0)
  return string.rep(STAR_FULL, whole) .. half .. string.rep(STAR_EMPTY, math.max(0, empty))
end

--- Roast level 1..5 -> label (§0.12); nil / out of range -> nil.
function Format.roast_label(level)
  level = to_num(level)
  if level == nil then
    return nil
  end
  return Constants.ROAST_LABELS[level]
end

--- Grind value rendered with the grinder's configured unit,
--- e.g. (15, "clicks") -> "15 clicks". Trailing ".0" is trimmed.
function Format.grind(value, unit_name)
  value = to_num(value)
  if value == nil then
    return nil
  end
  local num = string.format("%.2f", value):gsub("%.?0+$", "")
  if unit_name and unit_name ~= "" then
    return num .. " " .. unit_name
  end
  return num
end

--- Grams with up to one decimal, trimmed: 18 -> "18 g", 17.5 -> "17.5 g".
function Format.grams(value)
  value = to_num(value)
  if value == nil then
    return nil
  end
  local num = string.format("%.1f", value):gsub("%.0$", "")
  return num .. " g"
end

--- Temperature in °C, one decimal when needed: 93 -> "93°C", 93.5 -> "93.5°C".
function Format.temp_c(value)
  value = to_num(value)
  if value == nil then
    return nil
  end
  local num = string.format("%.1f", value):gsub("%.0$", "")
  return num .. "\u{00B0}C"
end

--- Best-effort local date + time for a stored `os.time()` value, e.g.
--- 1756819800 -> "2025-09-02 14:30". Display only — the device clock may be
--- wrong (§Conventions 11). Returns nil for nil / non-number input.
function Format.timestamp(ts)
  local n = tonumber(ts)
  if not n then
    return nil
  end
  return os.date("%Y-%m-%d %H:%M", n)
end

local function parse_number(s)
  return tonumber((s:gsub(",", ".")))
end

--- Parse free-text duration input into integer seconds (inverse of .duration).
--- Accepts: "2:45", "1:02:03", "90" (bare = seconds), "15 min" / "15m",
--- "2 h" / "1.5h", "45 s" / "45s". Returns nil on anything unparseable or
--- negative.
function Format.parse_duration(str)
  if type(str) ~= "string" then
    return nil
  end
  local s = str:gsub("%s+", ""):lower()
  if s == "" then
    return nil
  end

  -- clock form h:mm:ss or m:ss
  local parts = {}
  for chunk in (s .. ":"):gmatch("([^:]*):") do
    table.insert(parts, chunk)
  end
  if #parts >= 2 and #parts <= 3 then
    local total = 0
    for _, p in ipairs(parts) do
      local n = tonumber(p)
      if not n or n < 0 or n ~= math.floor(n) then
        return nil
      end
      total = total * 60 + n
    end
    return total
  end

  -- suffixed forms
  local num, suffix = s:match("^([%d%.,]+)([a-z]*)$")
  if not num then
    return nil
  end
  local n = parse_number(num)
  if not n or n < 0 then
    return nil
  end
  if suffix == "" or suffix == "s" or suffix == "sec" or suffix == "secs" then
    return math.floor(n + 0.5)
  elseif suffix == "m" or suffix == "min" or suffix == "mins" then
    return math.floor(n * 60 + 0.5)
  elseif suffix == "h" or suffix == "hr" or suffix == "hrs" then
    return math.floor(n * 3600 + 0.5)
  end
  return nil
end

return Format
