-- ui/recipe/history.lua
-- Brew history sub-screen for a recipe (TECH_SOLUTION §2.15). Lists the recipe's
-- brew_sessions newest-first (date, rating, measured time); tapping a row offers
-- "View comment" and "Delete session". Deleting confirms first and then re-reads,
-- so the recipe's derived brew count / session average refresh via `on_changed`.

local BrewService = require("services/brew_service")
local ButtonDialog = require("ui/widget/buttondialog")
local ConfirmDialog = require("ui/widgets/confirm_dialog")
local Format = require("util/format")
local InfoMessage = require("ui/widget/infomessage")
local ScreenList = require("ui/screen_list")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local History = ScreenList:extend {
  name = "koffeelab_recipe_history",
  title = _("Brew History"),
  navbar = { "home", "back" }, -- nothing to filter / sort here
  recipe_id = nil, -- required
  on_changed = nil, -- optional: called after a session is deleted
}

function History:buildItems()
  local ok, sessions = BrewService.list_for_recipe(self.recipe_id)
  self.sessions = ok and sessions or {}
  if #self.sessions == 0 then
    return { { text = _("No brew sessions yet."), kind = "text", _inert = true } }
  end
  local items = {}
  for _idx, s in ipairs(self.sessions) do -- luacheck: ignore _idx
    local note = {}
    if s.session_rating ~= nil then
      note[#note + 1] = Format.rating_stars(tonumber(s.session_rating))
    end
    if s.measured_brew_time_sec ~= nil then
      note[#note + 1] = Format.duration(tonumber(s.measured_brew_time_sec))
    end
    items[#items + 1] = {
      text = Format.timestamp(s.brewed_at) or _("(undated)"),
      mandatory = table.concat(note, "  \u{00B7}  "),
      _session = s,
      callback = function()
        self:_rowMenu(s)
      end,
    }
  end
  return items
end

History._refresh = ScreenList.refresh

function History:_confirmDelete(session)
  ConfirmDialog.destructive {
    text = _(
      "Delete this brew session?\n\nThe recipe's brew count and session average will be recalculated."
    ),
    ok_text = _("Delete"),
    on_confirm = function()
      local ok, err = BrewService.delete(session.id)
      if not ok then
        ConfirmDialog.blocked { text = tostring(err) }
        return
      end
      if self.on_changed then
        self.on_changed()
      end
      self:refresh()
    end,
  }
end

function History:_rowMenu(s)
  local dialog
  dialog = ButtonDialog:new {
    title = Format.timestamp(s.brewed_at) or _("Brew session"),
    title_align = "center",
    buttons = {
      {
        {
          text = _("View comment"),
          callback = function()
            UIManager:close(dialog)
            UIManager:show(InfoMessage:new {
              text = (s.comment and s.comment ~= "") and s.comment or _("No comment."),
            })
          end,
        },
      },
      {
        {
          text = _("Delete session"),
          callback = function()
            UIManager:close(dialog)
            self:_confirmDelete(s)
          end,
        },
      },
    },
  }
  UIManager:show(dialog)
end

return History
