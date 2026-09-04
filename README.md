# KoffeeLab

A coffee brewing companion for [KOReader](https://github.com/koreader/koreader).
Store brew recipes, log brews with tasting notes and a stopwatch, build custom
drinks from a base recipe, and search the catalogue.

## Features

- **Recipes** for five brew methods — Pour Over, AeroPress, French Press,
  Espresso, Cold Brew. Each method asks only for the fields that apply to it
  (dose, water, temperature, total time, grind) plus method-specific options like
  dripper or AeroPress orientation.
- **Step-by-step brew guides.** Add pours, stirs and waits; elapsed time and
  running water total are worked out for you.
- **Brew history.** "Brew Again" logs a rating, comment and brew time; a built-in
  stopwatch with splits helps you time the brew. Brew count and average rating
  show on the recipe.
- **Custom drinks.** Build a drink from a base recipe plus an amount used, extra
  ingredients and extra steps.
- **Tasting notes & flavour tags.** Rate 1–5, leave a comment, tag with a
  reusable flavour list, and note the expected result.
- **Favourites** and a searchable index of recipes and drinks, filterable by
  method, temperature or ingredient and sortable by recent, brew count or rating.
- **Configurator** for your beans, grinders, ingredients and flavour tags.
- **Backup & restore** to JSON or a database file.
- **Sample data** on first launch so there is something to browse right away.

Everything is stored on the device. The plugin makes no network requests.

## Installation

1. Download the plugin — clone the repo or download the ZIP from GitHub. The
   folder must be named **`KoffeeLab.koplugin`** (rename it if the ZIP unpacks as
   `KoffeeLab.koplugin-main`).
2. Connect your e-reader by USB and copy the folder to
   `koreader/plugins/KoffeeLab.koplugin` on the device.
3. Eject the drive and **fully restart KOReader** (exit completely and relaunch,
   or reboot) — not just going back to the file browser.
4. Open it from the KOReader menu: **Tools → KoffeeLab**.

Repeat the copy and restart to update. If KOReader won't start after installing,
delete the plugin folder and check `koreader/crash.log`.

## Using it

Open **Tools → KoffeeLab**. The home screen shows Recently Saved, Most Brewed, Top
Rated and Favourites — tap a recipe to open it, or a card's heading to see the
full list.

Actions live on the bar at the bottom of each screen:

- Home / Index / Configurator: `Home · Index · Add · Configurator · Exit`
- Lists: `Home · Filter · Sort · Search · Back`
- A recipe: `Home · Edit · Delete · Brew Again · Favourite`
- A drink: `Home · Edit · Delete`
- Add / Edit: `Back · Save · Exit`

Tap **Add** to create a recipe (pick a method, then fill the wizard pages) or a
custom drink (pick a base recipe). On a recipe, **Brew Again** logs a brew and the
stopwatch is available from that flow.

## Backup

**Configurator → Backup & Restore** exports your configuration, your recipes and
history, or the whole database — as JSON or a raw database file — and restores
from either.

Backups are saved to `koffeelab/backups/` at the root of the device's user
storage. The database itself lives in KOReader's settings folder as
`koffeelab.sqlite3`.

The first launch (or any launch with an empty catalogue) loads the built-in
sample recipes and drinks. You can reload them any time from
**Configurator → Developer → Load sample data**.

## Credits

Some UI icons are from [Lucide](https://lucide.dev) (ISC) — see
[`resources/icons/LICENSE-lucide`](resources/icons/LICENSE-lucide). The brew-method
icons are original to KoffeeLab.
