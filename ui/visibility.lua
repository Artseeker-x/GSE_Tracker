local _, ns = ...
local addon = ns
local UI = ns.UI
local API = (ns.Utils and ns.Utils.API) or {}
local C = (ns.Utils and ns.Utils.Constants) or addon.Constants or {}
local uiShared = addon._ui or {}
local ensureDatabase = uiShared.EnsureDB

local function SetModifierStyle(fs, active, r, g, b)
  if not fs then return end
  if active then
    fs:SetTextColor(r, g, b, 1)
  else
    fs:SetTextColor(1, 1, 1, 0.50)
  end
end

local function ElementEnabled(elementName)
  local cfg, defaults = addon:GetElementLayout(elementName)
  if type(cfg) == "table" and cfg.enabled ~= nil then
    return cfg.enabled and true or false
  end
  if defaults and defaults.enabled ~= nil then
    return defaults.enabled and true or false
  end
  return true
end

local function GetPreviewSequenceText()
  return "Example Sequence"
end

local function GetPreviewKeybindText()
  return "F1"
end

local function HasRuntimeSequenceText(ui)
  local txt = ui and ui._lastSeqText
  return type(txt) == "string" and txt ~= ""
end

local function GetRuntimeSequenceKey(ui)
  local seqKey = (ui and ui._lastSeqKey) or addon._activeSeqKey
  if type(seqKey) == "string" and seqKey ~= "" then
    return seqKey
  end
  return nil
end

local function GetRuntimeSequenceText(ui)
  if HasRuntimeSequenceText(ui) then
    return ui._lastSeqText
  end
  local seqKey = GetRuntimeSequenceKey(ui)
  if seqKey and addon.GetActiveSequenceDisplayText then
    local displayText = addon:GetActiveSequenceDisplayText(seqKey)
    if type(displayText) == "string" and displayText ~= "" then
      return displayText
    end
  end
  return ""
end

local function GetRuntimeKeybindText(ui)
  local seqKey = GetRuntimeSequenceKey(ui)
  if not seqKey and not HasRuntimeSequenceText(ui) then
    return ""
  end

  if addon.GetActiveSequenceBindingText then
    local bindingText = addon:GetActiveSequenceBindingText(seqKey)
    if type(bindingText) == "string" and bindingText ~= "" then
      return bindingText
    end
  end

  local txt = ui and ui._lastKeybindText
  if type(txt) == "string" and txt ~= "" then
    return txt
  end

  return ""
end

local function ApplyRuntimeSequenceVisibility(self, show)
  local ui = self.ui
  if not ui then return end

  local seqText = show and GetRuntimeSequenceText(ui) or ""
  local keyText = show and GetRuntimeKeybindText(ui) or ""

  local seqVisible = seqText ~= "" and ElementEnabled("sequenceText")
  if ui.sequenceTextFrame then
    if seqVisible then ui.sequenceTextFrame:Show() else ui.sequenceTextFrame:Hide() end
  end
  if ui.nameText then
    ui.nameText:SetText(seqVisible and seqText or "")
    ui.nameText:SetTextColor(
      ui._accentR or 1,
      ui._accentG or 1,
      ui._accentB or 1,
      seqVisible and (ui._accentA or 1) or 0
    )
  end

  local keyVisible = keyText ~= "" and ElementEnabled("keybindText")
  if ui.keybindFrame then
    if keyVisible then ui.keybindFrame:Show() else ui.keybindFrame:Hide() end
  end
  if ui.keybindText then
    ui.keybindText:SetText(keyVisible and keyText or "")
    ui.keybindText:SetTextColor(1, 1, 1, keyVisible and 1 or 0)
  end
end

function UI:RefreshEditingPreviewState()
  local ui = self.ui
  if not (ui and addon._editingOptions) then return end

  local show = (ui._lastVisible ~= false)
  local seqVisible = show and ElementEnabled("sequenceText")
  local keyVisible = show and ElementEnabled("keybindText")
  local modsVisible = show and ElementEnabled("modifiersText")

  if ui.sequenceTextFrame then
    if seqVisible then ui.sequenceTextFrame:Show() else ui.sequenceTextFrame:Hide() end
  end
  if ui.nameText then
    ui.nameText:SetText(seqVisible and GetPreviewSequenceText() or "")
    ui.nameText:SetTextColor(1, 1, 1, seqVisible and 1 or 0)
  end

  if ui.keybindFrame then
    if keyVisible then ui.keybindFrame:Show() else ui.keybindFrame:Hide() end
  end
  if ui.keybindText then
    ui.keybindText:SetText(keyVisible and GetPreviewKeybindText() or "")
    ui.keybindText:SetTextColor(1, 1, 1, keyVisible and 1 or 0)
  end

  if ui.modifiersFrame then
    if modsVisible then ui.modifiersFrame:Show() else ui.modifiersFrame:Hide() end
  end
  if ui.modAlt then
    ui.modAlt:SetText(modsVisible and "ALT" or "")
    if modsVisible then ui.modAlt:Show() else ui.modAlt:Hide() end
  end
  if ui.modShift then
    ui.modShift:SetText(modsVisible and "SHIFT" or "")
    if modsVisible then ui.modShift:Show() else ui.modShift:Hide() end
  end
  if ui.modCtrl then
    ui.modCtrl:SetText(modsVisible and "CTRL" or "")
    if modsVisible then ui.modCtrl:Show() else ui.modCtrl:Hide() end
  end

  if self.ApplyFontFaces then self:ApplyFontFaces() end
  if self.ApplyAllElementPositions then self:ApplyAllElementPositions() end
  if self.UpdateModifiers then self:UpdateModifiers(true) end
  if self._ResizeToContent then self:_ResizeToContent() end
  if self.RefreshPressedIndicator then self:RefreshPressedIndicator(true) end
end

function UI:RefreshCombatOnlyElements(show, inCombat)
  local ui = self.ui
  if not ui then return end

  if addon._editingOptions then
    self:RefreshEditingPreviewState()
    return
  end

  local combatVisible = show and inCombat

  ApplyRuntimeSequenceVisibility(self, show)

  local modsVisible = show and ElementEnabled("modifiersText")
  if ui.modifiersFrame and ui._modsShown ~= modsVisible then
    ui._modsShown = modsVisible
    if modsVisible then
      ui.modifiersFrame:Show()
      ui.modAlt:Show(); ui.modShift:Show(); ui.modCtrl:Show()
      self:UpdateModifiers(true)
    else
      ui.modifiersFrame:Hide()
      ui.modAlt:Hide(); ui.modShift:Hide(); ui.modCtrl:Hide()
    end
  elseif ui.modifiersFrame then
    if modsVisible then
      ui.modifiersFrame:Show()
    else
      ui.modifiersFrame:Hide()
    end
  end

  local pressedVisible = combatVisible and ElementEnabled("pressedIndicator")
  if not pressedVisible and ui.pressedIndicator then
    ui._pressedIndicatorActive = false
    ui.pressedIndicator:Hide()
  elseif pressedVisible and self.RefreshPressedIndicator then
    self:RefreshPressedIndicator(true)
  end
end

function UI:ApplyVisibility()
  local ui = self.ui
  if not ui then return end
  ensureDatabase()

  if self.UpdateEventSubscriptions then
    self:UpdateEventSubscriptions(ui)
  end

  local mode = (addon.GetShowWhen and addon:GetShowWhen()) or (C.MODE_ALWAYS or "Always")
  local inCombat = (ui._combatState ~= nil and ui._combatState) or API.InCombatLockdown()
  local hasTarget = API.UnitExists("target") or false

  local show
  local editingOverride = addon._editingOptions and true or false
  local actionTrackerEnabled = not (self.IsEnabled and not self:IsEnabled())
  if not actionTrackerEnabled and not editingOverride then
    show = false
  elseif self.EvaluateVisibilityMode then
    show = self:EvaluateVisibilityMode(mode, inCombat, hasTarget, editingOverride)
  else
    show = true
    if not editingOverride then
      if mode == "Never" then
        show = false
      elseif mode == "InCombat" then
        show = inCombat
      elseif mode == "HasTarget" then
        show = hasTarget
      end
    end
  end

  local visibilityChanged = (ui._lastVisible ~= show)
  if visibilityChanged then
    ui._lastVisible = show
    if show then ui:Show() else ui:Hide() end
  end

  if self._pendingFontApply and self.ApplyFontFaces then
    self:ApplyFontFaces()
  end

  if self.ApplyEditModeIconPreview then
    self:ApplyEditModeIconPreview(false)
  end

  self:RefreshCombatOnlyElements(show, inCombat)
end

function UI:UpdateModifiers(force)
  local ui = self.ui
  if not ui then return end

  local alt = ui._modAlt or false
  local shift = ui._modShift or false
  local ctrl = ui._modCtrl or false

  if not force and ui._modsRenderedAlt == alt and ui._modsRenderedShift == shift and ui._modsRenderedCtrl == ctrl then
    return
  end

  SetModifierStyle(ui.modAlt, alt, 1, 1, 1)
  SetModifierStyle(ui.modShift, shift, 1, 1, 1)
  SetModifierStyle(ui.modCtrl, ctrl, 1, 1, 1)

  ui._modsRenderedAlt = alt
  ui._modsRenderedShift = shift
  ui._modsRenderedCtrl = ctrl
end

function uiShared.SyncModifiers(ui)
  local alt = API.IsAltKeyDown() or false
  local shift = API.IsShiftKeyDown() or false
  local ctrl = API.IsControlKeyDown() or false
  local changed = (ui._modAlt ~= alt) or (ui._modShift ~= shift) or (ui._modCtrl ~= ctrl)
  ui._modAlt = alt
  ui._modShift = shift
  ui._modCtrl = ctrl
  return changed
end

function uiShared.ApplyModifierEvent(ui, key, state)
  local down = (state == 1)
  if key == "LALT" or key == "RALT" then
    if ui._modAlt == down then return false end
    ui._modAlt = down
    return true
  elseif key == "LSHIFT" or key == "RSHIFT" then
    if ui._modShift == down then return false end
    ui._modShift = down
    return true
  elseif key == "LCTRL" or key == "RCTRL" then
    if ui._modCtrl == down then return false end
    ui._modCtrl = down
    return true
  end
  return uiShared.SyncModifiers(ui)
end

function uiShared.VisibilityDependsOnTarget()
  return addon.VisibilityDependsOnTarget and addon:VisibilityDependsOnTarget() or false
end
