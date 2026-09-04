-- ui/widgets/wizard.lua
-- Wizard — a multi-page card form (design-language §4.6). Replaces the flat
-- ui/widgets/form_screen for the Add / Edit flows. Each page is a few field
-- cards; a field card shows `label` over its current value and opens a modal
-- editor on tap (the same ListPicker / NumberInput / … the old form used). The
-- navbar is `back · (next | save) · exit`: `next` validates the page first,
-- `save` runs on the last page, `exit` abandons the draft (with a confirm), and
-- hardware Back / swipe step to the previous page.
--
--   local W = Wizard:extend{ name = "koffeelab_recipe_form" }
--   function W:init()
--     self.wizard_title = _("New Recipe")
--     self.values = draft.recipe
--     self.draft = draft
--     self.pages = {
--       { title = _("Basics"), fields = { <field>, ... },
--         validate = function(values, draft) return err_or_nil end },
--       ...
--     }
--     Wizard.init(self)
--   end
--   function W:on_save() ... end   -- persist; navigate away
--
-- A `field` is `{ key, label, display = function(values) -> str|nil,
--                 edit = function(wizard) ... end }` — identical to the old
-- FormScreen field, so existing sub-editors work unchanged.

local ConfirmDialog = require("ui/widgets/confirm_dialog")
local Design = require("ui/design")
local Device = require("device")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local IconWidget = require("ui/widget/iconwidget")
local InfoMessage = require("ui/widget/infomessage")
local Paths = require("ui/paths")
local ScreenCard = require("ui/screen_card")
local SectionCard = require("ui/widgets/section_card")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Card = require("ui/widgets/card")
local _ = require("gettext")
local Screen = Device.screen

local Wizard = ScreenCard:extend {
  name = "koffeelab_wizard",
  navbar = "wizard",
  wizard_title = "",
  pages = nil,
  values = nil,
  draft = nil,
  page_index = 1,
}

function Wizard:init()
  self.pages = self.pages or {}
  self.values = self.values or {}
  self.page_index = 1
  -- a flat list of every field across all pages, for callers / specs
  self.all_fields = {}
  for _, p in ipairs(self.pages) do
    for _, f in ipairs(p.fields or {}) do
      self.all_fields[#self.all_fields + 1] = f
    end
  end
  self.navbar = self:_navItems()
  ScreenCard.init(self)
  self:_syncTitle()
end

function Wizard:_isLast()
  return self.page_index >= #self.pages
end

function Wizard:_navItems()
  return { "back", self:_isLast() and "save" or "next", "exit" }
end

function Wizard:_syncTitle()
  local page = self.pages[self.page_index]
  local suffix = page and page.title and ("  \u{00B7}  " .. page.title) or ""
  self.title = (self.wizard_title or "") .. suffix
  if self.title_bar and self.title_bar.setTitle then
    self.title_bar:setTitle(self.title, true) -- our own refresh() repaints
  end
end

local function warn(msg)
  UIManager:show(InfoMessage:new { text = tostring(msg), icon = "notice-warning" })
end

-- One tappable field card: label over its current value, chevron on the right.
function Wizard:_fieldCard(field)
  local inner = self.card_w - 2 * Design.pad.card
  local chevron = IconWidget:new {
    file = Paths.icon("next"),
    width = Screen:scaleBySize(18),
    height = Screen:scaleBySize(18),
    is_icon = true,
    alpha = true,
  }
  local value_str = field.display and field.display(self.values)
  local text_w = inner - chevron:getSize().w - Design.gap
  local col = VerticalGroup:new {
    align = "left",
    TextWidget:new { text = tostring(field.label), face = Design.face("title"), max_width = text_w },
    VerticalSpan:new { width = Design.gap_tight },
    TextWidget:new {
      text = value_str and tostring(value_str) or _("\u{2014}"),
      face = Design.face("body"),
      fgcolor = value_str and Design.color.fg or Design.color.muted,
      max_width = text_w,
    },
  }
  return Card:new {
    width = self.card_w,
    show_parent = self,
    on_tap = field.edit and function()
      field.edit(self)
    end or nil,
    HorizontalGroup:new {
      align = "center",
      col,
      HorizontalSpan:new { width = math.max(Design.gap, text_w - col:getSize().w) },
      chevron,
    },
  }
end

function Wizard:buildCards()
  local page = self.pages[self.page_index] or { fields = {} }
  self:_syncTitle()
  self.item_table = {} -- mirror for specs / callers that inspect fields
  local cards = {}

  if #self.pages > 1 then
    cards[#cards + 1] = SectionCard:new {
      width = self.card_w,
      show_parent = self,
      body = TextWidget:new {
        text = string.format(_("Step %d of %d"), self.page_index, #self.pages),
        face = Design.face("label"),
        fgcolor = Design.color.muted,
      },
    }
  end

  for _fi, field in ipairs(page.fields or {}) do -- luacheck: ignore _fi
    local value_str = field.display and field.display(self.values)
    self.item_table[#self.item_table + 1] = {
      text = field.label,
      mandatory = value_str and tostring(value_str) or _("\u{2014}"),
      _field = field,
    }
    cards[#cards + 1] = self:_fieldCard(field)
  end
  return cards
end

--- Update one value and rebuild the page (sub-editors call this).
function Wizard:set(key, value)
  self.values[key] = value
  self:refresh()
end

Wizard.refreshItems = Wizard.refresh

function Wizard:_validatePage(idx)
  local page = self.pages[idx]
  if page and page.validate then
    return page.validate(self.values, self.draft)
  end
end

function Wizard:_next()
  local err = self:_validatePage(self.page_index)
  if err then
    warn(err)
    return
  end
  if self.page_index < #self.pages then
    self.page_index = self.page_index + 1
    self:setNavbarItems(self:_navItems())
    self:refresh()
  end
end

--- Validate every page, then hand off to the subclass `on_save`.
function Wizard:_save()
  for i = 1, #self.pages do
    local err = self:_validatePage(i)
    if err then
      warn(err)
      return
    end
  end
  if self.on_save then
    self:on_save()
  end
end

function Wizard:_exit()
  if self.on_exit then
    self:on_exit()
    return
  end
  ConfirmDialog.destructive {
    text = _("Discard this draft?\n\nNothing will be saved."),
    ok_text = _("Discard"),
    on_confirm = function()
      ScreenCard._goBack(self)
    end,
  }
end

--- Navbar verbs (design-language §3.7 `wizard` preset).
function Wizard:onNavAction(key)
  if key == "next" then
    self:_next()
  elseif key == "save" then
    self:_save()
  elseif key == "exit" then
    self:_exit()
  end
end

--- Back (navbar / hardware / swipe) steps to the previous page, then pops.
function Wizard:_goBack()
  if self.page_index > 1 then
    self.page_index = self.page_index - 1
    self:setNavbarItems(self:_navItems())
    self:refresh()
    return true
  end
  return ScreenCard._goBack(self)
end

return Wizard
