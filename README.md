# KoffeeLab

A local-first coffee recipe catalogue for [KOReader](https://github.com/koreader/koreader),
built as a `.koplugin`. Brew recipes, brew history, tasting notes, reusable coffee
bases, custom drinks, configurable brewing methods, a searchable index, and
backup/restore — all on-device, no network.

**This repository *is* the plugin.** Its root is the `KoffeeLab.koplugin/` directory
KOReader loads — `_meta.lua` and `main.lua` sit at the top level.

## Target runtime

| | |
|---|---|
| Host | KOReader plugin (repo root = `KoffeeLab.koplugin/`) |
| Lua | 5.1 / LuaJIT |
| KOReader version (pinned) | `v2026.07.2` |
| Storage | SQLite via KOReader's bundled `lua-ljsqlite3`, DB at `DataStorage:getSettingsDir() .. "/koffeelab.sqlite3"` |

## Layout

```
_meta.lua          plugin manifest (fullname + description)
main.lua           WidgetContainer entry + main-menu registration
db/                connection, migrations, query helpers, repositories (SQL lives ONLY here)
model/             plain data shapes
services/          validation + referential rules; the only layer the UI calls
ui/                screens and reusable widgets
util/              format / validation / constants
resources/icons/   assets
spec/              busted specs (in-memory SQLite, seeded per test)
scripts/koenv.sh   PATH shim for running ./kodev on macOS
scripts/test.sh    runs spec/ inside the KOReader emulator's busted env
.luacheckrc        lint config (LuaJIT std + KOReader globals)
stylua.toml        formatter config (2-space indent)
Makefile           make check / lint / test / format
```

Strict layering: **UI → Service → Repository → SQLite**. UI modules never `require` a
repository or run SQL.

The design/planning docs (`TECH_SOLUTION_KoffeeLab_KOReader.md`, `IMPLEMENTATION_PLAN.md`,
`PROGRESS.md`) are kept locally by the maintainer but are **git-ignored** — they are
not part of the shipped plugin.

## Dev environment setup

Most development runs in the **KOReader emulator** on the desktop. A jailbroken Kindle
is only needed for e-ink/touch validation and final acceptance.

### 1. Toolchain (macOS / Apple Silicon)

```sh
# KOReader build deps (from koreader/doc/Building.md, macOS section)
brew install autoconf automake bash binutils cmake coreutils findutils \
    gettext gnu-getopt libtool make meson nasm ninja pkgconf sdl3 util-linux wget

# Lint / test / format for this plugin
brew install luajit stylua
luarocks --lua-dir="$(brew --prefix luajit)" --lua-version=5.1 \
    --tree="$HOME/.luarocks-jit" install luacheck
luarocks --lua-dir="$(brew --prefix luajit)" --lua-version=5.1 \
    --tree="$HOME/.luarocks-jit" install busted
```

`luacheck`/`busted` are installed against **LuaJIT (Lua 5.1)** to match KOReader's
runtime; a Homebrew `lua` (5.4/5.5) rocktree fails to load luacheck. Put
`~/.luarocks-jit/bin` on `PATH`. `make check` scrubs `LUA_PATH`/`LUA_CPATH` so a
stray 5.4/5.5 tree can't shadow it.

Homebrew's GNU tools are keg-only. `scripts/koenv.sh` prepends the ones `./kodev`
needs (bash ≥ 4, GNU `getopt`, coreutils, findutils, GNU make) — source it before
any `kodev` command.

Linux: install the distro equivalents (see `koreader/doc/Building.md`) plus
`luajit`; `koenv.sh` is a no-op there but harmless.

### 2. Build & run the KOReader emulator

The emulator is a **separate** checkout next to this repo (`../koreader`):

```sh
cd ..
git clone https://github.com/koreader/koreader.git
cd koreader && git checkout v2026.07.2
./kodev fetch-thirdparty          # submodules + third-party sources

cd ../KoffeeLab.koplugin
. scripts/koenv.sh                # PATH for kodev (bash4, GNU getopt/make/coreutils)
cd ../koreader
./kodev build                     # first build is slow (SDL3/mupdf/crengine ~15–40 min)
./kodev run                       # opens KOReader in an SDL window
```

Emulator output tree (Apple Silicon): `koreader/koreader-emulator-arm64-*/koreader/`;
`./kodev run` prints the exact path.

### 3. Symlink the plugin into the emulator

From this repo root:

```sh
ln -sfn "$(pwd)" ../koreader/plugins/KoffeeLab.koplugin
```

`./kodev` copies the (symlinked) plugin into the build. Then, from the koreader
checkout, `./kodev run` and open the main menu → **Tools → KoffeeLab** →
"KoffeeLab — coming soon". There is no hot reload; re-run `./kodev build && ./kodev
run` (or restart) after Lua changes.

Tail logs while it runs: `./kodev log` (from the koreader checkout).

### 4. On-device deploy

Copy this directory to `<USB drive>/koreader/plugins/KoffeeLab.koplugin`, eject, fully
restart KOReader. On failure check `<USB drive>/koreader/crash.log`.

## Lint & test

Run from this repo root:

```sh
make check          # lint + test + format-check (recommended)
make lint           # luacheck .
make test           # specs, via the KOReader emulator (see below)
make format         # stylua . (rewrites)
```

`make lint` / `make format` scrub `LUA_PATH`/`LUA_CPATH` so a system Lua 5.4/5.5
rocktree can't shadow the LuaJIT rocks. Invoking directly: `env -u LUA_PATH -u
LUA_CPATH luacheck .`

### Running the specs

The specs use SQLite through KOReader's bundled `lua-ljsqlite3`, which a standalone
`busted` can't load, so they run inside the emulator's test environment:

```sh
make test                     # = scripts/test.sh
scripts/test.sh -v            # extra args pass through to `kodev test`
```

`scripts/test.sh` sources `scripts/koenv.sh`, symlinks `spec/` into the sibling
`../koreader` checkout as `spec/unit/koffeelab`, and runs `./kodev test front
'koffeelab_*'`. It needs `../koreader` built once (`./kodev build`, see above); set
`KOREADER_DIR` if the checkout lives elsewhere. Each spec starts with
`require("koffeelab.spec_helper")`, which loads KOReader's test globals and puts the
plugin's modules on the require path; specs open `Connection.open(":memory:")` and
seed per test.

No task is complete with a failing `luacheck` or spec — report the failure instead.
