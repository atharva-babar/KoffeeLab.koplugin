#!/bin/sh
# Source this before running ./kodev in the sibling koreader/ checkout:
#   . scripts/koenv.sh && (cd ../koreader && ./kodev run)
#
# Current KOReader (>= v2026.x) needs GNU coreutils/findutils/getopt/make ahead of
# the macOS BSD versions, plus a bash >= 4. Homebrew keeps them keg-only.

BREW_PREFIX="$(brew --prefix 2>/dev/null || echo /opt/homebrew)"

export PATH="\
$BREW_PREFIX/opt/gnu-getopt/bin:\
$BREW_PREFIX/opt/coreutils/libexec/gnubin:\
$BREW_PREFIX/opt/findutils/libexec/gnubin:\
$BREW_PREFIX/opt/make/libexec/gnubin:\
$BREW_PREFIX/opt/util-linux/bin:\
$BREW_PREFIX/bin:\
$PATH"

# Keep a stray system Lua 5.4/5.5 rocktree from shadowing the LuaJIT (5.1) rocks.
unset LUA_PATH LUA_CPATH

echo "koenv: PATH primed for kodev (bash $(bash --version | sed -n '1s/.*version \([0-9.]*\).*/\1/p'), $(getopt --version 2>&1 | head -1))"
