# KoffeeLab — dev tasks
#
# The repo root IS the plugin (KoffeeLab.koplugin/). Run these from here.
# Requires: luacheck, stylua on PATH (see README "Toolchain"); the specs run
# through the KOReader emulator (see README "Dev environment setup") because they
# need KOReader's SQLite runtime.
# LUA_PATH/LUA_CPATH are scrubbed so a system Lua 5.4/5.5 rocktree cannot shadow
# the LuaJIT (5.1) rocks that match KOReader's runtime.

# LuaJIT (5.1) rocks tree used for luacheck/busted (see README). Override if yours
# lives elsewhere:  make check LUAROCKS_BIN=/path/to/bin
LUAROCKS_BIN ?= $(HOME)/.luarocks-jit/bin
CLEANENV     := env -u LUA_PATH -u LUA_CPATH PATH="$(LUAROCKS_BIN):$(PATH)"

.PHONY: all check lint test format format-check clean

all: check

check: lint test format-check

lint:
	$(CLEANENV) luacheck .

test:
	scripts/test.sh

format:
	stylua .

format-check:
	stylua --check .

clean:
	rm -f spec/*.sqlite3 luacov.stats.out luacov.report.out
