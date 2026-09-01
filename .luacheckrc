-- Luacheck configuration for the KoffeeLab KOReader plugin.
-- KOReader runs on LuaJIT (Lua 5.1 semantics). Module resolution (`require`) and
-- widget base classes are provided by the KOReader `frontend/` runtime at load time,
-- so KOReader-injected globals are declared here rather than resolved on disk.
-- The repo root IS the plugin (KoffeeLab.koplugin/). Run from here: `luacheck .`

std = "luajit"
cache = true
codes = true

-- KOReader's own frontend keeps `self` on registered callbacks even when a given
-- method does not use it; match that so plugin code reads the same.
unused_args = false

-- Generated DDL and long localized strings in db/ would otherwise trip the
-- line-length check; KOReader's own .luacheckrc disables it too.
max_line_length = false
max_code_line_length = false
max_string_line_length = false
max_comment_line_length = false

read_globals = {
  -- KOReader i18n helpers
  "_",
  "C_",
  "N_",
  "T",
  -- KOReader runtime singletons
  "Device",
  "Screen",
  "Input",
  "G_reader_settings",
  "G_defaults",
  "lfs",
}

globals = {
  "G_reader_settings",
}

-- Busted spec files get the busted DSL globals.
files["spec/"] = {
  std = "+busted",
}

exclude_files = {
  "spec/fixtures/",
  "scripts/",
}
