#!/bin/sh
# Run the KoffeeLab busted specs inside the KOReader emulator's test environment.
#
# The specs need KOReader's runtime (lua-ljsqlite3, datastorage, logger), which a
# standalone `busted` cannot provide, so they run through `./kodev test`. This
# script wires the plugin's spec/ dir into the sibling koreader checkout and runs
# only the `koffeelab_*` tests.
#
#   Requires: ../koreader built once (`./kodev build`); see README "Dev environment".
#   Usage:    scripts/test.sh [extra kodev test args]

set -eu

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KOREADER_DIR="${KOREADER_DIR:-$(cd "$PLUGIN_DIR/../koreader" 2>/dev/null && pwd || true)}"

if [ -z "${KOREADER_DIR:-}" ] || [ ! -x "$KOREADER_DIR/kodev" ]; then
  echo "test.sh: KOReader checkout not found (expected at ../koreader)." >&2
  echo "         Set KOREADER_DIR=/path/to/koreader, or see README 'Dev environment setup'." >&2
  exit 1
fi

# shellcheck disable=SC1091
. "$PLUGIN_DIR/scripts/koenv.sh" >/dev/null

# Expose the plugin's specs to KOReader's front test suite (idempotent).
ln -sfn "$PLUGIN_DIR/spec" "$KOREADER_DIR/spec/unit/koffeelab"

cd "$KOREADER_DIR"
exec ./kodev test front "koffeelab_*" "$@"
