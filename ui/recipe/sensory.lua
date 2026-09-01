-- ui/recipe/sensory.lua
-- Sensory & flavor screen for the recipe flow (TECH_SOLUTION §2.10). Recipe-level
-- only: the five fixed axes (acidity / sweetness / strength / body / brightness)
-- plus an overall rating, a flavor-tag multi-select (with inline "+ Add Tag"),
-- and free-text notes. Values are written straight into `draft.recipe` and
-- `draft.flavor_tag_ids`; `on_change` repaints the parent form's summary row.

local Constants = require("util/constants")
local FormScreen = require("ui/widgets/form_screen")
local ListPicker = require("ui/widgets/list_picker")
local Menu = require("ui/widget/menu")
local TextInput = require("ui/widgets/text_input")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local Sensory = {}

local RATING_ITEMS = {
  { text = _("Not set"), value = 0 },
  { text = "1", value = 1 },
  { text = "2", value = 2 },
  { text = "3", value = 3 },
  { text = "4", value = 4 },
  { text = "5", value = 5 },
}

-- ── flavor-tag multi-select ───────────────────────────────────────────────────

local TagPicker = Menu:extend {
  name = "koffeelab_recipe_tags",
  covers_fullscreen = true,
  is_borderless = true,
  is_popout = false,
  is_enable_shortcut = false,
  with_bottom_line = true,
  title_bar_left_icon = "chevron.left",
  title = _("Flavor Tags"),
  selected = nil, -- shared array of flavor_tag ids
  on_change = nil,
}

function TagPicker:init()
  self.item_table = self:_items()
  Menu.init(self)
end

function TagPicker:_has(id)
  for _idx, tid in ipairs(self.selected) do -- luacheck: ignore _idx
    if tid == id then
      return true
    end
  end
  return false
end

function TagPicker:_items()
  local ConfigService = require("services/config_service")
  local ok, tags = ConfigService.flavor_tags.list {}
  tags = ok and tags or {}
  local items = { { text = "+ " .. _("Add Tag"), _add = true } }
  for _idx, tag in ipairs(tags) do -- luacheck: ignore _idx
    items[#items + 1] = {
      text = (self:_has(tag.id) and "\u{2713} " or "   ") .. tag.name,
      _id = tag.id,
    }
  end
  return items
end

function TagPicker:_refresh()
  if self.on_change then
    self.on_change()
  end
  self:switchItemTable(nil, self:_items(), self.page or 1)
end

function TagPicker:onMenuChoice(item)
  if item._add then
    local ConfigService = require("services/config_service")
    TextInput.show {
      title = _("New flavor tag"),
      hint = _("e.g. Citrus"),
      on_ok = function(name)
        if name == "" then
          return
        end
        local ok, res = ConfigService.flavor_tags.create { name = name }
        if not ok then
          UIManager:show(require("ui/widget/infomessage"):new {
            text = tostring(res),
            icon = "notice-warning",
          })
          return
        end
        self.selected[#self.selected + 1] = res.id
        self:_refresh()
      end,
    }
    return true
  end
  if item._id then
    if self:_has(item._id) then
      for i, tid in ipairs(self.selected) do
        if tid == item._id then
          table.remove(self.selected, i)
          break
        end
      end
    else
      self.selected[#self.selected + 1] = item._id
    end
    self:_refresh()
  end
  return true
end

function TagPicker:_back()
  if self.nav then
    self.nav:pop()
  else
    UIManager:close(self)
  end
  return true
end

TagPicker.onClose = TagPicker._back
TagPicker.onLeftButtonTap = TagPicker._back

-- ── the screen ────────────────────────────────────────────────────────────────

local function rating_field(key, label, draft, notify)
  return {
    key = key,
    label = label,
    display = function()
      return draft.recipe[key] and tostring(draft.recipe[key]) or nil
    end,
    edit = function(form)
      ListPicker.show {
        title = label,
        items = RATING_ITEMS,
        current = draft.recipe[key] or 0,
        on_select = function(v)
          draft.recipe[key] = (v ~= 0) and v or nil
          form:refreshItems()
          notify()
        end,
      }
    end,
  }
end

--- Build the screen.
---   Sensory.build{ draft = draft, on_change = function() … end }  -> FormScreen
function Sensory.build(opts)
  local draft = opts.draft
  local function notify()
    if opts.on_change then
      opts.on_change()
    end
  end

  local fields = {}
  for _idx, axis in ipairs(Constants.SENSORY_AXES) do -- luacheck: ignore _idx
    fields[#fields + 1] = rating_field(axis.key, axis.label, draft, notify)
  end
  fields[#fields + 1] = rating_field("overall_rating", _("Overall rating"), draft, notify)

  fields[#fields + 1] = {
    key = "flavor_tag_ids",
    label = _("Flavor tags"),
    display = function()
      local n = #draft.flavor_tag_ids
      return n > 0 and tostring(n) or nil
    end,
    edit = function(form)
      form.nav:push(TagPicker:new {
        selected = draft.flavor_tag_ids,
        on_change = function()
          form:refreshItems()
          notify()
        end,
      })
    end,
  }

  fields[#fields + 1] = {
    key = "notes",
    label = _("Notes"),
    display = function()
      return (draft.recipe.notes and draft.recipe.notes ~= "") and draft.recipe.notes or nil
    end,
    edit = function(form)
      TextInput.show {
        title = _("Notes"),
        value = draft.recipe.notes,
        on_ok = function(t)
          draft.recipe.notes = t
          form:refreshItems()
          notify()
        end,
      }
    end,
  }

  return FormScreen:new {
    title = _("Flavor & Sensory"),
    values = draft.recipe,
    fields = fields,
    actions = {
      {
        text = _("Done"),
        callback = function(form)
          if form.nav then
            form.nav:pop()
          else
            UIManager:close(form)
          end
        end,
      },
    },
  }
end

Sensory._TagPicker = TagPicker

return Sensory
