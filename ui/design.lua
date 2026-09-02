-- ui/design.lua
-- The KoffeeLab design system: one place for the type scale, greys, spacing and
-- border metrics so every screen looks like the same app. Custom .ttf fonts are
-- not cleanly supported by KOReader's font API, so headings use the bundled
-- NotoSerif and body text the default sans (cfont / NotoSans).

local Blitbuffer = require("ffi/blitbuffer")
local Font = require("ui/font")
local Size = require("ui/size")

local Design = {}

Design.color = {
  fg = Blitbuffer.COLOR_BLACK,
  muted = Blitbuffer.COLOR_GRAY_5, -- secondary text / captions
  hairline = Blitbuffer.COLOR_GRAY_7, -- separators / card borders
  bg = Blitbuffer.COLOR_WHITE,
}

-- role -> { face name, pre-scale px }. Font:getFace scales the number itself.
local FACES = {
  display = { "NotoSerif-Bold.ttf", 26 },
  title = { "NotoSerif-Bold.ttf", 20 },
  body = { "cfont", 18 },
  label = { "cfont", 14 },
}

-- NotoSerif is not always resolvable by filename in every build; fall back to the
-- bundled bold sans face so headings still render (verified on first run).
local FALLBACK = {
  display = { "tfont", 26 },
  title = { "tfont", 20 },
  body = { "cfont", 18 },
  label = { "cfont", 14 },
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
  lg = Size.padding.large,
  md = Size.padding.default,
  sm = Size.padding.small,
}
Design.border = Size.border.thin
Design.radius = 0 -- flat by default

return Design
