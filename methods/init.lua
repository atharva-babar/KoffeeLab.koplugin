-- methods/init.lua
-- Static registry of the built-in brew methods. Each method (methods/<slug>.lua)
-- is its own hand-written schema: the shared brew_recipes columns it surfaces,
-- its typed parameters, and its step shape. No user-defined methods, no DB rows.

local Constants = require("util/constants")

local ORDER = { "pour_over", "aeropress", "french_press", "espresso", "cold_brew" }

local Methods = { _by_slug = {} }

for _, slug in ipairs(ORDER) do
  Methods._by_slug[slug] = require("methods/" .. slug)
end

function Methods.list()
  local out = {}
  for _, slug in ipairs(ORDER) do
    out[#out + 1] = Methods._by_slug[slug]
  end
  return out
end

function Methods.get(slug)
  return Methods._by_slug[slug]
end

function Methods.step_label(step_type)
  return Constants.STEP_TYPE_LABELS[step_type] or step_type
end

return Methods
