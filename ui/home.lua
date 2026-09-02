-- ui/home.lua
-- KoffeeLab root screen: a 2x2 grid of stat cards (Recent, Most Brewed, Top
-- Rated, Favourites) over two big action tiles (Add Recipe, Add Custom Drink),
-- with the bottom navbar. Stats refresh whenever the screen is shown again.

local ButtonDialog = require("ui/widget/buttondialog")
local Card = require("ui/widgets/card")
local TopContainer = require("ui/widget/container/topcontainer")
local Design = require("ui/design")
local Device = require("device")
local Format = require("util/format")
local Geom = require("ui/geometry")
local HomeService = require("services/home_service")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InfoMessage = require("ui/widget/infomessage")
local Nav = require("ui/nav")
local ScreenBase = require("ui/screen_base")
local TextWidget = require("ui/widget/textwidget")
local Tile = require("ui/widgets/tile")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Version = require("version")
local _ = require("gettext")
local Screen = Device.screen

local HomeScreen = ScreenBase:extend {
  name = "koffeelab_home",
  title = _("KoffeeLab"),
  no_back_button = false, -- Back from Home closes the plugin (stack empties)
  right_icon = "appbar.menu",
  navbar = "home",
  scroll = true,
}

local function safe(fn)
  local ok, res = pcall(fn)
  return ok and res or nil
end

function HomeScreen:getContentWidget()
  self.content_wrap = TopContainer:new {
    dimen = Geom:new { w = self.screen_w, h = self.content_height },
    self:_buildBody(),
  }
  return self.content_wrap
end

function HomeScreen:_buildBody()
  local pad = Design.pad.lg
  local gap = Design.pad.md
  local avail = self.screen_w - 2 * pad
  local card_w = math.floor((avail - gap) / 2)
  local card_h = Screen:scaleBySize(96)
  local tile_h = Screen:scaleBySize(92)

  local recent = safe(HomeService.recent)
  local most = safe(HomeService.most_brewed)
  local top = safe(HomeService.top_rated)
  local fav_n = safe(HomeService.favourites_count) or 0

  -- `self.cards` / `self.tiles` keep the built widgets in a flat, ordered list so
  -- the screen (and specs) can read what is on screen without walking the tree.
  self.cards = {
    self:_statCard(_("Recent"), recent, "recent", card_w, card_h),
    self:_statCard(_("Most Brewed"), most, "brews", card_w, card_h),
    self:_statCard(_("Top Rated"), top, "rating", card_w, card_h),
    self:_favCard(fav_n, card_w, card_h),
  }
  self.tiles = {
    Tile:new {
      width = card_w,
      height = tile_h,
      icon = "add",
      label = _("Add Recipe"),
      show_parent = self,
      on_tap = function()
        require("ui/recipe/add_flow").start {}
      end,
    },
    Tile:new {
      width = card_w,
      height = tile_h,
      icon = "custom_drink",
      label = _("Custom Drink"),
      show_parent = self,
      on_tap = function()
        require("ui/drink/add_flow").start {}
      end,
    },
  }

  local grid = VerticalGroup:new {
    align = "left",
    self:_cardRow(gap, { self.cards[1], self.cards[2] }),
    VerticalSpan:new { width = gap },
    self:_cardRow(gap, { self.cards[3], self.cards[4] }),
    VerticalSpan:new { width = Design.pad.lg },
    self:_cardRow(gap, { self.tiles[1], self.tiles[2] }),
  }

  return VerticalGroup:new {
    align = "left",
    VerticalSpan:new { width = pad },
    HorizontalGroup:new {
      HorizontalSpan:new { width = pad },
      grid,
    },
  }
end

function HomeScreen:_cardRow(gap, cards)
  return HorizontalGroup:new {
    align = "top",
    cards[1],
    HorizontalSpan:new { width = gap },
    cards[2],
  }
end

local function label_widget(text, w)
  return TextWidget:new {
    text = text,
    face = Design.face("label"),
    fgcolor = Design.color.muted,
    max_width = w,
  }
end

local function title_widget(text, w)
  return TextWidget:new {
    text = text,
    face = Design.face("title"),
    max_width = w,
  }
end

function HomeScreen:_statCardBody(header, primary, secondary, inner_w)
  return VerticalGroup:new {
    align = "left",
    label_widget(header, inner_w),
    VerticalSpan:new { width = Design.pad.sm },
    title_widget(primary, inner_w),
    VerticalSpan:new { width = Design.pad.sm },
    label_widget(secondary or "", inner_w),
  }
end

local EMPTY_PRIMARY = {
  recent = _("No brews yet"),
  brews = _("No brews yet"),
  rating = _("No ratings yet"),
}

-- A Recent / Most Brewed / Top Rated card. `row` is a search index row or nil;
-- `kind` is "recent" | "brews" | "rating" and picks the secondary line.
function HomeScreen:_statCard(header, row, kind, card_w, card_h)
  local inner_w = card_w - 2 * Design.pad.md
  local primary, secondary, on_tap
  if row then
    primary = row.title
    local bits = { row.method_name or "" }
    local avg = tonumber(row.avg_session_rating)
    local overall = tonumber(row.overall_rating)
    if kind == "brews" then
      local n = tonumber(row.brew_count) or 0
      bits[#bits + 1] = string.format(n == 1 and "%d brew" or "%d brews", n)
    elseif avg then
      bits[#bits + 1] = Format.rating_decimal(avg)
    elseif overall then
      bits[#bits + 1] = Format.rating_stars(overall)
    end
    secondary = table.concat(bits, "  \u{00B7}  ")
    on_tap = function()
      Nav:push(require("ui/recipe/detail"):new {
        recipe_id = row.id,
        on_changed = function()
          self:_reload()
        end,
      })
    end
  else
    primary = EMPTY_PRIMARY[kind] or _("Nothing yet")
    secondary = _("\u{2014}")
  end
  local card = Card:new {
    width = card_w,
    height = card_h,
    show_parent = self,
    on_tap = on_tap,
    self:_statCardBody(header, primary, secondary, inner_w),
  }
  card.header, card.primary, card.secondary = header, primary, secondary
  return card
end

function HomeScreen:_favCard(n, card_w, card_h)
  local inner_w = card_w - 2 * Design.pad.md
  local primary, secondary
  if n > 0 then
    primary = string.format(n == 1 and _("%d recipe") or _("%d recipes"), n)
    secondary = _("Tap to browse")
  else
    primary = _("None yet")
    secondary = _("Tap to browse")
  end
  local card = Card:new {
    width = card_w,
    height = card_h,
    show_parent = self,
    on_tap = function()
      Nav:push(require("ui/recipe/index"):new { favourites = true })
    end,
    self:_statCardBody(_("Favourites"), primary, secondary, inner_w),
  }
  card.header, card.primary, card.secondary = _("Favourites"), primary, secondary
  return card
end

--- Rebuild the card area and repaint once (called after nav returns / on show).
function HomeScreen:_reload()
  if not self.content_wrap then
    return
  end
  self.content_wrap[1] = self:_buildBody()
  if self.scroll_container and self.scroll_container.reset then
    self.scroll_container:reset()
  end
  UIManager:setDirty(self, "ui")
end

function HomeScreen:onShow()
  self:_reload()
  return ScreenBase.onShow(self)
end

function HomeScreen:onRightButton()
  local dialog
  dialog = ButtonDialog:new {
    title = _("KoffeeLab"),
    title_align = "center",
    buttons = {
      {
        {
          text = _("Backup & Restore"),
          callback = function()
            UIManager:close(dialog)
            Nav:push(require("ui/backup"):new {})
          end,
        },
      },
      {
        {
          text = _("About"),
          callback = function()
            UIManager:close(dialog)
            self:_showAbout()
          end,
        },
      },
    },
  }
  UIManager:show(dialog)
end

function HomeScreen:_showAbout()
  UIManager:show(InfoMessage:new {
    text = _("KoffeeLab")
      .. "\n"
      .. _(
        "Local-first coffee recipe catalogue with brew history, tasting notes and custom drinks."
      )
      .. "\n\n"
      .. _("KOReader")
      .. " "
      .. tostring(Version:getCurrentRevision()),
  })
end

return HomeScreen
