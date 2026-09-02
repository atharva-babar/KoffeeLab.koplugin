-- ui/drink/detail.lua
-- Custom-drink detail page (TECH_SOLUTION §2.15; design-language §4.5). A
-- scrolling stack of SectionCards — Base (recipe + amount + derived remaining),
-- Ingredients, Steps, Result — with Edit / Delete on the `detail_drink` navbar.
-- The remaining-of-batch value is derived here, never stored (§3.13).

local AddFlow = require("ui/drink/add_flow")
local ConfirmDialog = require("ui/widgets/confirm_dialog")
local Constants = require("util/constants")
local Design = require("ui/design")
local DrinkService = require("services/drink_service")
local Format = require("util/format")
local KvList = require("ui/widgets/kv_list")
local ScreenCard = require("ui/screen_card")
local SectionCard = require("ui/widgets/section_card")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TileStrip = require("ui/widgets/tile_strip")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local _ = require("gettext")

local DrinkDetail = ScreenCard:extend {
  name = "koffeelab_drink_detail",
  navbar = "detail_drink",
  drink_id = nil, -- required
  on_changed = nil, -- optional: called after edit / delete
}

function DrinkDetail:init()
  self:_fetch()
  self.title = self.drink and self.drink.title or _("Drink")
  ScreenCard.init(self)
end

function DrinkDetail:_fetch()
  local ok, drink = DrinkService.get(self.drink_id)
  self.drink = ok and drink or nil
end

local function amount_str(amount, unit)
  local n = tonumber(amount)
  if n == nil then
    return nil
  end
  if unit and unit ~= "" then
    return (string.format("%.2f", n):gsub("%.?0+$", "")) .. " " .. unit
  end
  return Format.grams(n)
end

function DrinkDetail:_wrapped(text)
  return TextBoxWidget:new {
    text = tostring(text),
    face = Design.face("body"),
    width = self.card_w - 2 * Design.pad.card,
  }
end

function DrinkDetail:buildCards()
  local d = self.drink
  if not d then
    self.not_found = true
    return {
      SectionCard:new {
        width = self.card_w,
        show_parent = self,
        body = self:_wrapped(_("Drink not found. It may have been deleted.")),
      },
    }
  end
  self.not_found = false
  local inner = self.card_w - 2 * Design.pad.card
  local cards = {}

  -- Base ------------------------------------------------------------------
  local base = d.base_recipe
  local tiles = {
    {
      label = _("Temperature"),
      value = Constants.TEMPERATURE_MODE_LABELS[d.temperature_mode] or d.temperature_mode,
    },
    { label = _("Base recipe"), value = base and base.title or _("\u{2014}") },
  }
  local amt = amount_str(d.base_amount, d.base_unit)
  if amt then
    tiles[#tiles + 1] = { label = _("Amount used"), value = amt }
  end
  local out = base and tonumber(base.output_weight_g) or nil
  local used = tonumber(d.base_amount)
  self.remaining_g = nil
  if out and used then
    self.remaining_g = math.max(0, out - used)
    tiles[#tiles + 1] = { label = _("Remaining of batch"), value = Format.grams(self.remaining_g) }
  end
  cards[#cards + 1] = SectionCard:new {
    width = self.card_w,
    title = _("Base"),
    show_parent = self,
    body = TileStrip:new { width = inner, items = tiles },
  }

  -- Ingredients ---------------------------------------------------------
  if #(d.ingredients or {}) > 0 then
    local rows = {}
    for _idx, ing in ipairs(d.ingredients) do -- luacheck: ignore _idx
      rows[#rows + 1] = {
        ing.ingredient_name or _("?"),
        amount_str(ing.amount, ing.unit) or _("\u{2014}"),
      }
    end
    cards[#cards + 1] = SectionCard:new {
      width = self.card_w,
      title = _("Ingredients"),
      show_parent = self,
      body = KvList.new(inner, rows),
    }
  end

  -- Steps -------------------------------------------------------------
  if #(d.steps or {}) > 0 then
    local body = VerticalGroup:new { align = "left" }
    for i, step in ipairs(d.steps) do
      if i > 1 then
        body[#body + 1] = VerticalSpan:new { width = Design.gap }
      end
      body[#body + 1] = self:_wrapped(string.format("#%d  %s", i, step.instruction or ""))
      if step.note and step.note ~= "" then
        body[#body + 1] = VerticalSpan:new { width = Design.gap_tight }
        body[#body + 1] = self:_wrapped(step.note)
      end
    end
    cards[#cards + 1] = SectionCard:new {
      width = self.card_w,
      title = _("Steps"),
      show_parent = self,
      body = body,
    }
  end

  -- Result ----------------------------------------------------------
  local result_rows = {}
  if d.rating ~= nil then
    result_rows[#result_rows + 1] = { _("Rating"), Format.rating_stars(tonumber(d.rating)) }
  end
  if #result_rows > 0 or (d.comment and d.comment ~= "") then
    local body
    if d.comment and d.comment ~= "" and #result_rows > 0 then
      body = VerticalGroup:new {
        align = "left",
        KvList.new(inner, result_rows),
        VerticalSpan:new { width = Design.gap },
        self:_wrapped(d.comment),
      }
    elseif d.comment and d.comment ~= "" then
      body = self:_wrapped(d.comment)
    else
      body = KvList.new(inner, result_rows)
    end
    cards[#cards + 1] = SectionCard:new {
      width = self.card_w,
      title = _("Result"),
      show_parent = self,
      body = body,
    }
  end

  return cards
end

--- Navbar verbs (design-language §3.7 `detail_drink` preset).
function DrinkDetail:onNavAction(key)
  if key == "edit" then
    self:_edit()
  elseif key == "delete" then
    self:_delete()
  end
end

function DrinkDetail:_reload()
  self:_fetch()
  self.title = self.drink and self.drink.title or _("Drink")
  self:refresh()
end

function DrinkDetail:_edit()
  ConfirmDialog.confirm {
    text = _("Edit drink?\n\nExisting drink data will be changed."),
    ok_text = _("Continue"),
    on_confirm = function()
      AddFlow.edit(self.drink_id, {
        on_saved = function()
          if self.on_changed then
            self.on_changed()
          end
          self:_reload()
        end,
      })
    end,
  }
end

function DrinkDetail:_delete()
  ConfirmDialog.destructive {
    text = _("Delete drink?\n\nThis removes the drink, its ingredients and its steps."),
    ok_text = _("Delete"),
    on_confirm = function()
      local ok, err = DrinkService.delete(self.drink_id)
      if not ok then
        ConfirmDialog.blocked { text = tostring(err) }
        return
      end
      if self.on_changed then
        self.on_changed()
      end
      if self.nav then
        self.nav:pop()
      else
        UIManager:close(self)
      end
    end,
  }
end

return DrinkDetail
