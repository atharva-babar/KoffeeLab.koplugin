-- ui/design.lua
-- The KoffeeLab design system: one place for the type scale, greys, spacing and
-- shape metrics so every screen looks like the same app. See docs/design-language.md
-- for the intent. Custom .ttf fonts are not cleanly supported by KOReader's font
-- API, so headings use the bundled NotoSerif and body text the default sans
-- (cfont / NotoSans).

local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Font = require("ui/font")
local Size = require("ui/size")
local Screen = Device.screen

local Design = {}

local function scale(n)
  return Screen:scaleBySize(n)
end

-- 8-bit greyscale. No pure-black fills except icons/text; cards are always the
-- grey, never white, never bordered.
Design.color = {
  fg = Blitbuffer.COLOR_BLACK, -- primary text, icons
  muted = Blitbuffer.COLOR_GRAY_5, -- captions, secondary text, inactive navbar
  card = Blitbuffer.COLOR_GRAY_E, -- card fill
  card_active = Blitbuffer.COLOR_LIGHT_GRAY, -- pressed / selected card
  bg = Blitbuffer.COLOR_WHITE, -- page
  hairline = Blitbuffer.COLOR_GRAY_B, -- the rare separator
}

-- role -> { face name, pre-scale px }. Font:getFace scales the number itself.
local FACES = {
  display = { "NotoSerif-Bold.ttf", 24 }, -- screen title, hero number
  title = { "NotoSerif-Bold.ttf", 19 }, -- card header
  body = { "cfont", 17 }, -- card content, values
  label = { "cfont", 13 }, -- captions, navbar labels, units
}

-- NotoSerif is not always resolvable by filename in every build; fall back to the
-- bundled bold sans face so headings still render (verified on first run).
local FALLBACK = {
  display = { "tfont", 24 },
  title = { "tfont", 19 },
  body = { "cfont", 17 },
  label = { "cfont", 13 },
}

local _face_cache = {}
function Design.face(role)
  if _face_cache[role] then
    return _face_cache[role]
  end
  local spec = FACES[role] or FACES.body
  local ok, face = pcall(Font.getFace, Font, spec[1], spec[2])
  if not ok or not face then
    spec = FALLBACK[role] or FALLBACK.body
    face = Font:getFace(spec[1], spec[2])
  end
  _face_cache[role] = face
  return face
end

Design.pad = {
  card = scale(14), -- inside a card
  page = scale(16), -- page edge -> card
  -- Legacy aliases: still referenced by screens not yet migrated to the v2 card
  -- language (home, method_select, grind_dial, scroll_list). Removed in Phase D.
  lg = Size.padding.large,
  md = Size.padding.default,
  sm = Size.padding.small,
}
Design.gap = scale(10) -- between cards / tiles
Design.gap_tight = scale(6) -- icon -> label, within a tile
Design.radius = scale(10) -- every card corner
Design.border = Size.border.thin -- effectively unused (cards have none); kept for the one hairline case

return Design
