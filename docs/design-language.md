# KoffeeLab — design language

The single source of truth for how every KoffeeLab screen looks and behaves.
Code lives in `ui/design.lua` (tokens) + `ui/widgets/` (components); this file is
the *why*. If a screen disagrees with this doc, the screen is wrong.

Target device: e-ink (Kindle / Kobo), 6", ~300 ppi, greyscale, slow refresh,
touch only. Everything below is shaped by that.

---

## 1. Principles

1. **Cards, not rows.** Content is grouped into rounded, borderless, light-grey
   cards on a white page. A screen is a short stack of cards, not a long list of
   text lines.
2. **The navbar owns all actions.** Add, Index, Configurator, Filter, Sort,
   Search, Back, Edit, Delete, Save, Favourite, Brew-again — every verb lives in
   the bottom navigation bar, and *only* there. No action rows in lists, no
   titlebar overflow menu, no inline buttons scattered through a form. The navbar
   is **contextual**: its icons change per screen.
3. **Centered.** Layout gravitates to the horizontal centre. Cards are centred in
   the page with a comfortable outer margin; a card's own content is centred
   unless it is genuinely a list. Deviate only with a reason.
4. **Icons carry meaning.** Brew methods always show their icon (in the picker,
   on the recipe card, on the detail header). Navbar actions are icon + tiny
   label. A screen should be legible at a glance from its shapes, not only its
   text.
5. **Minimal separators.** Whitespace and the card edge do the grouping. A hairline
   is a last resort, never the default row divider.
6. **Interactive feel.** Tappable things look tappable — a card with a chevron, a
   tile with an icon, a segmented control. Avoid walls of `Label …… value` text.
7. **One repaint per action** (unchanged from the e-ink rules): no animation, no
   `scheduleIn`, no polling; modal pickers over dropdowns; hardware Back + swipe
   + navbar Back all reach the same place.

---

## 2. Tokens (`ui/design.lua`)

### 2.1 Colour (8-bit greyscale)

| token | value | use |
|---|---|---|
| `color.fg` | `COLOR_BLACK` | primary text, icons |
| `color.muted` | `COLOR_GRAY_5` (#555) | captions, secondary text, inactive navbar |
| `color.card` | `COLOR_GRAY_E` (#EEE) | card fill |
| `color.card_active` | `COLOR_LIGHT_GRAY` (#CCC) | pressed / selected card |
| `color.bg` | `COLOR_WHITE` | page |
| `color.hairline` | `COLOR_GRAY_B` (#BBB) | the rare separator |

No pure-black fills except icons/text. Cards are always the grey, never white,
never bordered.

### 2.2 Type

Bundled faces only (KOReader has no clean custom-`.ttf` path). NotoSerif for
headings gives the app a distinct voice; NotoSans for everything else.

| role | face | ~px | use |
|---|---|---|---|
| `display` | NotoSerif-Bold | 24 | screen title, hero number |
| `title` | NotoSerif-Bold | 19 | card header |
| `body` | NotoSans (`cfont`) | 17 | card content, values |
| `label` | NotoSans (`cfont`) | 13 | captions, navbar labels, units |

Fallback: if `NotoSerif-Bold.ttf` fails to resolve, headings drop to `tfont`
(NotoSans-Bold) — verified at runtime, not assumed.

### 2.3 Space & shape

| token | value (pre-scale) | use |
|---|---|---|
| `radius` | 10 | every card corner |
| `pad.card` | 14 | inside a card |
| `pad.page` | 16 | page edge → card |
| `gap` | 10 | between cards / tiles |
| `gap.tight` | 6 | icon → label, within a tile |

All through `Screen:scaleBySize`. `border` is effectively unused now (cards have
none); keep the token for the one hairline case.

### 2.4 Navbar metric

`Navbar.HEIGHT` = pad + icon(22) + gap.tight + label line + pad. Computed once at
module load. Every scrolling screen subtracts it from the content height.

---

## 3. Components (`ui/widgets/`)

### 3.1 `Card`

Rounded, borderless, grey. `Card:new{ width, height?, on_tap?, show_parent, <child> }`.

- fill `color.card`, `radius`, `bordersize = 0`, `padding = pad.card`
- `on_tap` set ⇒ tappable (lazy `GestureRange` over `self.frame.dimen`), one
  `setDirty(show_parent, "ui")` per tap, brief `color.card_active` flash optional
- no `on_tap` ⇒ inert (an empty-state card)
- height omitted ⇒ hugs its content

### 3.2 `Tile`

A `Card` whose content is centred `Icon → gap.tight → label`. For method pickers,
Home actions, the Index chooser. `Tile:new{ width, height, icon, label, on_tap }`.

### 3.3 `CardRow`

Lays 2–3 child cards/tiles in a centred horizontal group with `gap` between and
`pad.page` on the outside. Equal widths by default; pass explicit widths for a
title+method split.

### 3.4 `StatCard`

Home's Recent / Most-Brewed / Top-Rated / Favourites. Header (`label`, muted) +
a short **list** of up to 3 lines (`body`), each a recipe/drink title. Tapping a
line opens that item; tapping the card header opens the full list. Empty ⇒ one
muted "Nothing yet" line, card inert.

### 3.5 `SectionCard`

A titled block on a detail/form screen: `title` (NotoSerif) + body content
(rows, a tile strip, or wrapped text). Used for "Brew Details", "Steps",
"Output / Result", "Flavour profile". Replaces the old `head`/`text`/normal row
kinds of `scroll_list`.

### 3.6 `TileStrip`

A horizontal run of small labelled value tiles inside a `SectionCard`
(`Beans 18 g` · `Water 200 mL / 93°` · `Output 200 mL · 1:15`). Wraps to a second
line when it doesn't fit; never scrolls sideways.

### 3.7 `Navbar` (contextual)

`Navbar:new{ items = { {icon, label, key}, ... }, active?, on_select }`.
2–5 equal cells, top hairline, white fill, pinned bottom via `BottomContainer`.
Active cell: bolder label + light-grey cell fill. Tap → `on_select(key)`.

Standard item sets (keys):

| screen kind | navbar items |
|---|---|
| Home | `home` · `add_recipe` · `add_drink` · `index` · `configurator` |
| Index root | `home` · `index` · `add` · `configurator` |
| List (recipe/drink index, history, config lists) | `home` · `filter` · `sort` · `search` · `back` |
| Detail (recipe/drink) | `home` · `edit` · `delete` · `brew_again`* · `favourite`* |
| Form / wizard step | `back` · `save` (or `next`) · `exit` |
| Configurator | `home` · `index` · `add` · `configurator` |

\* `brew_again` / `favourite` are recipe-only; drink detail shows `edit` ·
`delete` only. A screen with <5 verbs just has fewer cells, still centred.

`home` is on every screen that isn't itself Home or a wizard step — it resets the
stack to Home (§2.6 of the nav rules).

### 3.8 Pickers & inputs (unchanged in spirit)

- selection → full-screen modal list (`ListPicker`) or a `Tile` grid (methods)
- number → `SpinWidget` via `NumberInput` (has −/+, hold-to-jump, tap-to-type)
- grind → `GrindDial` (segmented `ButtonProgressWidget`, −/+, ⌥ keyboard)
- text / duration → existing modal widgets
- Every field editor is a **popup over the card**, never an inline expansion.

---

## 4. Screen recipes

### 4.1 Home
Title "KoffeeLab" + `home` glyph. 2×2 `StatCard` grid (Recent, Most Brewed, Top
Rated, Favourites), each showing up to 3 items. Navbar: home·add-recipe·add-drink
·index·configurator. Cards refresh on `onShow`.

### 4.2 Index root
Title "Index". Two big `Tile`s stacked & centred: **Coffee Recipes** (dripper
icon), **Custom Drinks** (tumbler icon). Navbar: home·index·add·configurator.

### 4.3 Recipe / Drink list
Title = "Coffee Recipes" / "Custom Drinks" / "Favourite Recipes". A scrolling
column of **recipe cards**: method icon + title on the left, `rating · N brews`
on the right, method name as a caption. No control rows — Filter / Sort / Search
are navbar actions that open modals. Navbar: home·filter·sort·search·back.

### 4.4 Recipe detail
Title = recipe name + method icon. Stack of `SectionCard`s:
- **Brew Details** — `TileStrip`: Beans (name · dose), Water (g / °C), Grind
  (grinder · setting), Output / Ratio
- **Steps** — 2-column numbered grid inside the card
- **Sensory** — the 5 axes as compact star rows, centred
- **Output / Result** — Taste / Expected note (wrapped), Rating (stars)
- **History** — brew count + session average as two value tiles; tap → history
- **Notes** — wrapped text, only if present

Navbar: home·edit·delete·brew-again·favourite. Favourite cell reflects state
(filled ★ / outline ☆).

### 4.5 Drink detail
Same card treatment: **Base** (recipe + amount + remaining-of-batch tiles),
**Ingredients** (name · amount rows), **Steps** (numbered), **Rating / Comment**.
Navbar: home·edit·delete.

### 4.6 Recipe / Drink wizard (Add / Edit)
`ui/widgets/wizard.lua` — multi-page, each page a short stack of **field cards**
(label over current value + chevron; tap opens the same modal editor the old form
used). A "Step N of M" card heads each page. Navbar per page: `back · (next |
save) · exit` — `next` runs the page's `validate(values, draft)`, `save` (last
page) validates every page then persists, `exit` confirms then abandons the
draft; hardware Back / swipe step to the previous page.

Recipe pages: **Basics** (Title, Method — read-only) · **Brew** (Bean, Grind,
the method's dose/water/temp/time/output fields, method params) · **Steps** (a
card that pushes the step sub-editor) · **Output** (Expected result, Flavour &
sensory). Drink pages: **Basics** (Title, Temperature, Base recipe, Amount) ·
**Extras** (Ingredients, Steps, Rating, Comment).

The leaf editors reached from a field card — one brew step, one ingredient, the
sensory screen, the grind dial, Brew Again — stay on `ui/widgets/form_screen`
(now card-styled rows via `scroll_list`); they are small modal-ish forms, not
wizards.

### 4.7 Configurator & config lists
Configurator: a card list of categories, an "About KoffeeLab" row, and a
"Developer › Load sample data" row; navbar `home·index·add·configurator`. Each
config list: entity cards + a "+ Add" card row, navbar `home·back`.

### 4.8 Stopwatch
`ui/recipe/stopwatch.lua` — a big centred `display`-face elapsed readout in a
card, over a `CardRow` of action tiles (Start / Split·Stop / Use·Restart), with
captured splits in a `KvList` card. Static: repainted only on a tap, never on a
timer. Navbar `home·back`.

---

## 5. What this replaces

- `ui/screen_base.lua` right-icon overflow menu → gone (verbs move to navbar)
- `ui/screen_list.lua` normal rows → grey `Card` rows (icon + title + caption +
  value); `head` / `text` kinds survive for list counts / empty-state text
- detail screens' `head` / `text` / row lists → `ui/screen_card` + `SectionCard`
  / `TileStrip` / `KvList`
- `ui/widgets/form_screen.lua` as the *main* Add/Edit surface → `ui/widgets/
  wizard.lua` card pages (form_screen kept for the leaf editors, §4.6)
- per-screen "control rows" (method filter / search / sort) → navbar modals
- titlebar chevron as the only Back → still there, but navbar `back` is primary
- hairline under every row → whitespace + card edges

Kept: `Nav` stack, `ListPicker`, `NumberInput`, `GrindDial`, `ConfirmDialog`,
`Rating`, `ui/widgets/form_screen` (leaf editors only), the services layer, the
e-ink one-repaint rules.

---

## 6. Icons

**Nav / action icons — vendor from [Lucide](https://lucide.dev)** (ISC / MIT,
24×24, `stroke` line art — matches our style). Copy the LICENSE into
`resources/icons/LICENSE-lucide`. Replace `currentColor` → `#000000` on import
(KOReader's SVG rasteriser treats unknown colours as black, but be explicit).

| purpose | Lucide slug | file |
|---|---|---|
| home | `house` | `home.svg` |
| index / list | `list` | `index.svg` |
| add | `plus` / `circle-plus` | `add.svg` |
| add recipe | `plus` | `add_recipe.svg` |
| add drink | `glass-water` + `plus` (compose) | `add_drink.svg` |
| configurator | `sliders-horizontal` | `configurator.svg` |
| filter | `funnel` | `filter.svg` |
| sort | `arrow-up-down` | `sort.svg` |
| search | `search` | `search.svg` |
| back | `chevron-left` | `back.svg` |
| exit | `log-out` | `exit.svg` |
| edit | `pencil` | `edit.svg` |
| delete | `trash-2` | `delete.svg` |
| brew again | `refresh-cw` / `rotate-cw` | `brew_again.svg` |
| favourite (outline) | `star` | `favorite.svg` |
| favourite (filled) | `star` + `fill` | `favorite_filled.svg` |
| save | `save` | `save.svg` |
| next | `chevron-right` | `next.svg` |
| rating star | `star` | reuse `favorite*` |

**Brew-method icons — original line art** (no permissive set has pour-over /
AeroPress / cold-brew). Keep the 5 hand-drawn 24×24 SVGs from Phase 12.2, but
redraw to match Lucide's weight (`stroke-width="2"`, round caps/joins) and make
them unmistakable at 22 px:

| method | slug | motif |
|---|---|---|
| Pour Over | `pour_over` | V60 cone + carafe + one drip |
| AeroPress | `aeropress` | cylinder + plunger cap + down arrow |
| French Press | `french_press` | beaker + plunger rod + knob |
| Espresso | `espresso` | portafilter + double spout + cup |
| Cold Brew | `cold_brew` | mason jar + lid band + droplet |

All method icons live in `methods/<slug>.lua` as `icon = "<slug>"` already; the
detail header and list rows read that.

Sanity-check every icon: paint it to a BB at 22 px and 48 px in
`koffeelab_widgets_spec` and eyeball the render.

---

## 7. Non-negotiables checklist (per screen)

- [ ] Cards are grey, rounded, borderless — never white, never outlined
- [ ] The only buttons/verbs on screen are in the navbar
- [ ] Content reads as centred
- [ ] Brew method shows its icon wherever a method is named
- [ ] ≤ 1 hairline; grouping is by card + whitespace
- [ ] Every tappable target ≥ ~44 px and visibly tappable
- [ ] One repaint per action; no animation/scheduleIn
- [ ] `home` in the navbar (except on Home / wizard steps); hardware Back + swipe
      still reach `Nav:pop`
- [ ] No horizontal scroll
