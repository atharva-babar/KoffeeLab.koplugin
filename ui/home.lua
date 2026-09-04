-- ui/home.lua
-- KoffeeLab root screen (design-language §4.1): a 2x2 grid of StatCards —
-- Recently Saved, Most Brewed, Top Rated, Favourites — each listing up to three
-- recipes. Tapping a line opens that recipe; tapping a card header opens the
-- matching index. Every verb (Add / Index / Configurator / Exit) is on the
-- navbar. The cards refresh whenever the screen is shown again.

local Design = require("ui/design")
local Device = require("device")
local HomeService = require("services/home_service")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local Nav = require("ui/nav")
local ScreenBase = require("ui/screen_base")
local StatCard = require("ui/widgets/stat_card")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local _ = require("gettext")
local Screen = Device.screen

local MAX_PAGE_W = 600

local HomeScreen = ScreenBase:extend {
  name = "koffeelab_home",
  title = _("KoffeeLab"),
  no_back_button = true, -- no chevron; hardware/gesture Back still closes the plugin
  navbar = "home",
  scroll = true,
}

local function safe(fn, ...)
  local ok, res = pcall(fn, ...)
  return ok and res or nil
end

function HomeScreen:getContentWidget()
  -- width-pinned + centred; a plain VerticalGroup so the ScrollableContainer sees
  -- the real content height (a fixed-dimen wrapper would make it think it fits).
  self.content_wrap = VerticalGroup:new {
    align = "center",
    HorizontalSpan:new { width = self.screen_w },
  }
  self.content_wrap[2] = self:_buildBody()
  return self.content_wrap
end

-- One StatCard. `rows` is a list of index rows; `open_index` opens the full list.
function HomeScreen:_card(header, rows, open_index, empty_text, card_w)
  local items = {}
  for _, r in ipairs(rows or {}) do
    items[#items + 1] = {
      text = r.title,
      on_tap = function()
        Nav:push(require("ui/recipe/detail"):new {
          recipe_id = r.id,
          on_changed = function()
            self:_reload()
          end,
        })
      end,
    }
  end
  local card = StatCard:new {
    width = card_w,
    show_parent = self,
    header = header,
    empty_text = empty_text,
    items = items,
    on_header = open_index,
  }
  card.header = header
  return card
end

function HomeScreen:_buildBody()
  local pad = Design.pad.page
  local gap = Design.gap
  local page_w = math.min(self.screen_w, Screen:scaleBySize(MAX_PAGE_W))
  local avail = page_w - 2 * pad
  local card_w = math.floor((avail - gap) / 2)

  local function open_recipe_index(opts)
    return function()
      Nav:push(require("ui/recipe/index"):new(opts or {}))
    end
  end

  self.cards = {
    self:_card(
      _("Recently Saved"),
      safe(HomeService.recently_saved_list, 3),
      open_recipe_index { sort = "updated" },
      _("No recipes yet"),
      card_w
    ),
    self:_card(
      _("Most Brewed"),
      safe(HomeService.most_brewed_list, 3),
      open_recipe_index { sort = "brew_count" },
      _("No brews yet"),
      card_w
    ),
    self:_card(
      _("Top Rated"),
      safe(HomeService.top_rated_list, 3),
      open_recipe_index { sort = "rating" },
      _("No ratings yet"),
      card_w
    ),
    self:_card(
      _("Favourites"),
      safe(HomeService.favourites_list, 3),
      open_recipe_index { favourites = true },
      _("None yet"),
      card_w
    ),
  }

  local grid = VerticalGroup:new {
    align = "left",
    HorizontalGroup:new {
      align = "top",
      self.cards[1],
      HorizontalSpan:new { width = gap },
      self.cards[2],
    },
    VerticalSpan:new { width = gap },
    HorizontalGroup:new {
      align = "top",
      self.cards[3],
      HorizontalSpan:new { width = gap },
      self.cards[4],
    },
  }

  return VerticalGroup:new {
    align = "center",
    VerticalSpan:new { width = pad },
    grid,
    VerticalSpan:new { width = pad },
  }
end

--- Rebuild the card area and repaint once (called after nav returns / on show).
function HomeScreen:_reload()
  if not self.content_wrap then
    return
  end
  self.content_wrap[2] = self:_buildBody()
  self.content_wrap:resetLayout()
  if self.scroll_container and self.scroll_container.reset then
    self.scroll_container:reset()
  end
  UIManager:setDirty(self, "ui")
end

function HomeScreen:onShow()
  self:_reload()
  return ScreenBase.onShow(self)
end

return HomeScreen
