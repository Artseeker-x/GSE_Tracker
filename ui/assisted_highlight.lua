local _, ns = ...
local addon = ns
local UI = ns.UI
local API = (ns.Utils and ns.Utils.API) or {}
local C = (ns.Utils and ns.Utils.Constants) or addon.Constants or {}
local uiShared = addon._ui or {}
local UIParent = (API.UIParent and API.UIParent()) or UIParent

local GetCursorPositionInParentSpace

local AssistedHighlight = addon.AssistedHighlight or {}
addon.AssistedHighlight = AssistedHighlight
AssistedHighlight.Provider = AssistedHighlight.Provider or {}
AssistedHighlight.Display = AssistedHighlight.Display or {}

local Provider = AssistedHighlight.Provider
local Display = AssistedHighlight.Display

local function PixelSnap(v, frame)
  if uiShared.PixelSnap then
    return uiShared.PixelSnap(v, frame)
  end
  return tonumber(v) or 0
end

local function SetPointIfChanged(frame, point, anchor, relativePoint, x, y)
  if uiShared.SetPointIfChanged then
    return uiShared.SetPointIfChanged(frame, point, anchor, relativePoint, x, y)
  end
  frame:ClearAllPoints()
  frame:SetPoint(point, anchor, relativePoint, x, y)
  return true
end

local function CanonicalPixelsToParentUnits(value, parent)
  if uiShared.CanonicalPixelsToParentUnits then
    return uiShared.CanonicalPixelsToParentUnits(value, parent)
  end
  return tonumber(value) or 0
end

local function ClampCenteredOffsetsToScreen(frame, parent, x, y)
  if uiShared.ClampCenteredOffsetsToScreen then
    return uiShared.ClampCenteredOffsetsToScreen(frame, parent, x, y)
  end
  return tonumber(x) or 0, tonumber(y) or 0
end

local function ParentUnitsToCanonicalPixels(value, parent)
  if uiShared.ParentUnitsToCanonicalPixels then
    return uiShared.ParentUnitsToCanonicalPixels(value, parent)
  end
  return tonumber(value) or 0
end

local function GetClassColorRGB()
  if uiShared.GetPlayerClassColorRGB then
    return uiShared.GetPlayerClassColorRGB(C.CLASS_FALLBACK_R or 0.20, C.CLASS_FALLBACK_G or 0.60, C.CLASS_FALLBACK_B or 1.00)
  end
  return C.CLASS_FALLBACK_R or 0.20, C.CLASS_FALLBACK_G or 0.60, C.CLASS_FALLBACK_B or 1.00
end

local function GetResolvedBorderColor()
  if addon.GetAssistedHighlightUseClassColor and addon:GetAssistedHighlightUseClassColor() then
    return GetClassColorRGB()
  end
  if addon.GetAssistedHighlightColor then
    return addon:GetAssistedHighlightColor()
  end
  return GetClassColorRGB()
end

local function GetAssistedHighlightLockState()
  if addon.GetAssistedHighlightLocked then
    return addon:GetAssistedHighlightLocked()
  end
  return addon.IsLocked and addon:IsLocked() or false
end

local function ResolvePointName(value)
  value = tostring(value or C.ANCHOR_CENTER or "CENTER")
  local compact = value:gsub("%s+", ""):upper()
  if compact == "TOPCENTER" then compact = "TOP" end
  if compact == "BOTTOMCENTER" then compact = "BOTTOM" end
  return compact
end

local function IsRenderableAnchorFrame(frame)
  return frame ~= nil
    and frame ~= UIParent
    and frame.IsObjectType
    and frame:IsObjectType("Frame")
    and not (frame.IsForbidden and frame:IsForbidden())
end

local function ResolveTargetNameplateFrame()
  if API.UnitExists and not API.UnitExists("target") then
    return nil
  end
  if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
    local plate = C_NamePlate.GetNamePlateForUnit("target", false)
    if IsRenderableAnchorFrame(plate) and ((not plate.IsShown) or plate:IsShown()) then
      return plate
    end
  end
  return nil
end

local function GetLiveAnchorTargetInfo()
  local target = addon.GetAssistedHighlightAnchorTarget and addon:GetAssistedHighlightAnchorTarget() or "Screen"
  if target == "Target Nameplate" then
    return ResolveTargetNameplateFrame(), "Target Nameplate", false, true
  elseif target == "Mouse Cursor" then
    return UIParent, "Mouse Cursor", true, true
  end
  return UIParent, C.UI_PARENT_NAME or "UIParent", false, true
end

local function GetAnchorPointConfig()
  local point, relName, relPoint, x, y = addon:GetAssistedHighlightPoint()
  return ResolvePointName(point), tostring(relName or C.UI_PARENT_NAME or "UIParent"), ResolvePointName(relPoint), tonumber(x) or 0, tonumber(y) or 0
end

local function ApplyResolvedAnchor(frame, parent, point, relativePoint, x, y)
  local appliedX = CanonicalPixelsToParentUnits(x, parent)
  local appliedY = CanonicalPixelsToParentUnits(y, parent)
  appliedX = PixelSnap(appliedX, parent)
  appliedY = PixelSnap(appliedY, parent)
  SetPointIfChanged(frame, point, parent or UIParent, relativePoint, appliedX, appliedY)
  return appliedX, appliedY
end

local function ResolveAppliedAnchorPoints(point, relativePoint)
  point = ResolvePointName(point)
  relativePoint = ResolvePointName(relativePoint)
  return point, relativePoint
end

local function ApplyCursorAnchor(frame, point, relativePoint, x, y)
  local parent = UIParent
  local cursorX, cursorY = GetCursorPositionInParentSpace(parent)
  local width = (parent.GetWidth and parent:GetWidth()) or 0
  local height = (parent.GetHeight and parent:GetHeight()) or 0
  local centerX = width * 0.5
  local centerY = height * 0.5
  local appliedX = ParentUnitsToCanonicalPixels((cursorX - centerX), parent) + (tonumber(x) or 0)
  local appliedY = ParentUnitsToCanonicalPixels((cursorY - centerY), parent) + (tonumber(y) or 0)
  appliedX, appliedY = ClampCenteredOffsetsToScreen(frame, parent, appliedX, appliedY)
  ApplyResolvedAnchor(frame, parent, point, relativePoint, appliedX, appliedY)
  return appliedX, appliedY
end

local function CreateFont(parent, size, outline)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(C.FONT_PATH_FRIZ or "Fonts\\FRIZQT__.TTF", size, outline or "OUTLINE")
  fs:SetJustifyH("RIGHT")
  fs:SetJustifyV("MIDDLE")
  fs:SetShadowOffset(1, -1)
  fs:SetShadowColor(0, 0, 0, 0.85)
  return fs
end

local function GetSpellTexture(spellID)
  if API.GetSpellTexture then
    local tex = API.GetSpellTexture(spellID)
    if tex then return tex end
  end
  if C_Spell and C_Spell.GetSpellTexture then
    return C_Spell.GetSpellTexture(spellID)
  end
  if _G.GetSpellTexture then
    return _G.GetSpellTexture(spellID)
  end
  return nil
end

local function GetRangeState(actionSlot)
  actionSlot = tonumber(actionSlot)
  if actionSlot and actionSlot > 0 and HasAction and HasAction(actionSlot) and IsActionInRange then
    -- Mirror the same slot-oriented flow Blizzard action buttons use:
    -- 1) verify the slot really exists, 2) verify that the action supports range,
    -- 3) read the in-range bit from the slot itself.
    if ActionHasRange and not ActionHasRange(actionSlot) then
      return nil
    end

    local result = IsActionInRange(actionSlot)
    if result == 1 or result == true then
      return true
    elseif result == 0 or result == false then
      return false
    end
    return nil
  end

  -- Do not approximate live action-bar range from spell-only checks when no real slot
  -- is available. Returning nil keeps the mirror visually neutral instead of stale/wrong.
  return nil
end

local function FormatBindingKey(key)
  if not key or key == "" then return nil end
  if API.GetBindingText then
    local text = API.GetBindingText(key, "KEY_")
    if text and text ~= "" then
      -- GetBindingText returns the full localized string for mouse buttons:
      -- "Mouse Button 1", "Mouse Button 4", etc.  Collapse all to MB<N>.
      text = text:gsub("Mouse Button (%d+)", "MB%1")
      return text
    end
  end
  key = tostring(key)
  key = key:gsub("ALT%-", "A-")
  key = key:gsub("CTRL%-", "C-")
  key = key:gsub("SHIFT%-", "S-")
  key = key:gsub("NUMPAD", "N")
  key = key:gsub("MOUSEWHEELUP", "MWU")
  key = key:gsub("MOUSEWHEELDOWN", "MWD")
  -- Raw BUTTON<N> tokens (when GetBindingText is unavailable): collapse all to MB<N>.
  key = key:gsub("BUTTON(%d+)", "MB%1")
  return key
end

local SLOT_BINDINGS = {
  [1] = "ACTIONBUTTON1", [2] = "ACTIONBUTTON2", [3] = "ACTIONBUTTON3", [4] = "ACTIONBUTTON4", [5] = "ACTIONBUTTON5", [6] = "ACTIONBUTTON6",
  [7] = "ACTIONBUTTON7", [8] = "ACTIONBUTTON8", [9] = "ACTIONBUTTON9", [10] = "ACTIONBUTTON10", [11] = "ACTIONBUTTON11", [12] = "ACTIONBUTTON12",
  [13] = "MULTIACTIONBAR3BUTTON1", [14] = "MULTIACTIONBAR3BUTTON2", [15] = "MULTIACTIONBAR3BUTTON3", [16] = "MULTIACTIONBAR3BUTTON4", [17] = "MULTIACTIONBAR3BUTTON5", [18] = "MULTIACTIONBAR3BUTTON6",
  [19] = "MULTIACTIONBAR3BUTTON7", [20] = "MULTIACTIONBAR3BUTTON8", [21] = "MULTIACTIONBAR3BUTTON9", [22] = "MULTIACTIONBAR3BUTTON10", [23] = "MULTIACTIONBAR3BUTTON11", [24] = "MULTIACTIONBAR3BUTTON12",
  [25] = "MULTIACTIONBAR4BUTTON1", [26] = "MULTIACTIONBAR4BUTTON2", [27] = "MULTIACTIONBAR4BUTTON3", [28] = "MULTIACTIONBAR4BUTTON4", [29] = "MULTIACTIONBAR4BUTTON5", [30] = "MULTIACTIONBAR4BUTTON6",
  [31] = "MULTIACTIONBAR4BUTTON7", [32] = "MULTIACTIONBAR4BUTTON8", [33] = "MULTIACTIONBAR4BUTTON9", [34] = "MULTIACTIONBAR4BUTTON10", [35] = "MULTIACTIONBAR4BUTTON11", [36] = "MULTIACTIONBAR4BUTTON12",
  [37] = "MULTIACTIONBAR2BUTTON1", [38] = "MULTIACTIONBAR2BUTTON2", [39] = "MULTIACTIONBAR2BUTTON3", [40] = "MULTIACTIONBAR2BUTTON4", [41] = "MULTIACTIONBAR2BUTTON5", [42] = "MULTIACTIONBAR2BUTTON6",
  [43] = "MULTIACTIONBAR2BUTTON7", [44] = "MULTIACTIONBAR2BUTTON8", [45] = "MULTIACTIONBAR2BUTTON9", [46] = "MULTIACTIONBAR2BUTTON10", [47] = "MULTIACTIONBAR2BUTTON11", [48] = "MULTIACTIONBAR2BUTTON12",
  [49] = "MULTIACTIONBAR1BUTTON1", [50] = "MULTIACTIONBAR1BUTTON2", [51] = "MULTIACTIONBAR1BUTTON3", [52] = "MULTIACTIONBAR1BUTTON4", [53] = "MULTIACTIONBAR1BUTTON5", [54] = "MULTIACTIONBAR1BUTTON6",
  [55] = "MULTIACTIONBAR1BUTTON7", [56] = "MULTIACTIONBAR1BUTTON8", [57] = "MULTIACTIONBAR1BUTTON9", [58] = "MULTIACTIONBAR1BUTTON10", [59] = "MULTIACTIONBAR1BUTTON11", [60] = "MULTIACTIONBAR1BUTTON12",
  [61] = "MULTIACTIONBAR5BUTTON1", [62] = "MULTIACTIONBAR5BUTTON2", [63] = "MULTIACTIONBAR5BUTTON3", [64] = "MULTIACTIONBAR5BUTTON4", [65] = "MULTIACTIONBAR5BUTTON5", [66] = "MULTIACTIONBAR5BUTTON6",
  [67] = "MULTIACTIONBAR5BUTTON7", [68] = "MULTIACTIONBAR5BUTTON8", [69] = "MULTIACTIONBAR5BUTTON9", [70] = "MULTIACTIONBAR5BUTTON10", [71] = "MULTIACTIONBAR5BUTTON11", [72] = "MULTIACTIONBAR5BUTTON12",
  [73] = "MULTIACTIONBAR6BUTTON1", [74] = "MULTIACTIONBAR6BUTTON2", [75] = "MULTIACTIONBAR6BUTTON3", [76] = "MULTIACTIONBAR6BUTTON4", [77] = "MULTIACTIONBAR6BUTTON5", [78] = "MULTIACTIONBAR6BUTTON6",
  [79] = "MULTIACTIONBAR6BUTTON7", [80] = "MULTIACTIONBAR6BUTTON8", [81] = "MULTIACTIONBAR6BUTTON9", [82] = "MULTIACTIONBAR6BUTTON10", [83] = "MULTIACTIONBAR6BUTTON11", [84] = "MULTIACTIONBAR6BUTTON12",
  [85] = "MULTIACTIONBAR7BUTTON1", [86] = "MULTIACTIONBAR7BUTTON2", [87] = "MULTIACTIONBAR7BUTTON3", [88] = "MULTIACTIONBAR7BUTTON4", [89] = "MULTIACTIONBAR7BUTTON5", [90] = "MULTIACTIONBAR7BUTTON6",
  [91] = "MULTIACTIONBAR7BUTTON7", [92] = "MULTIACTIONBAR7BUTTON8", [93] = "MULTIACTIONBAR7BUTTON9", [94] = "MULTIACTIONBAR7BUTTON10", [95] = "MULTIACTIONBAR7BUTTON11", [96] = "MULTIACTIONBAR7BUTTON12",
  [97] = "MULTIACTIONBAR8BUTTON1", [98] = "MULTIACTIONBAR8BUTTON2", [99] = "MULTIACTIONBAR8BUTTON3", [100] = "MULTIACTIONBAR8BUTTON4", [101] = "MULTIACTIONBAR8BUTTON5", [102] = "MULTIACTIONBAR8BUTTON6",
  [103] = "MULTIACTIONBAR8BUTTON7", [104] = "MULTIACTIONBAR8BUTTON8", [105] = "MULTIACTIONBAR8BUTTON9", [106] = "MULTIACTIONBAR8BUTTON10", [107] = "MULTIACTIONBAR8BUTTON11", [108] = "MULTIACTIONBAR8BUTTON12",
}

-- Maps Blizzard default action button frame names to their binding command names.
-- Unlike SLOT_BINDINGS (slot→command), this mapping is keyed on the FRAME NAME and is
-- stable regardless of action bar paging, stances, or bar visibility.
-- Slot 13 may be shown by ActionButton1 (main bar page 2) OR MultiBarRightButton1
-- (fixed right bar).  SLOT_BINDINGS[13] = MULTIACTIONBAR3BUTTON1, which is wrong for
-- the paged case.  Frame-name lookup is always right: ActionButton1 → ACTIONBUTTON1.
local BUTTON_NAME_TO_BINDING = {}
do
  local function _reg(prefix, bindPrefix, count)
    for i = 1, count do
      BUTTON_NAME_TO_BINDING[prefix .. i] = bindPrefix .. i
    end
  end
  _reg("ActionButton",               "ACTIONBUTTON",          12)
  _reg("MultiBarBottomLeftButton",   "MULTIACTIONBAR1BUTTON", 12)
  _reg("MultiBarBottomRightButton",  "MULTIACTIONBAR2BUTTON", 12)
  _reg("MultiBarRightButton",        "MULTIACTIONBAR3BUTTON", 12)
  _reg("MultiBarLeftButton",         "MULTIACTIONBAR4BUTTON", 12)
  -- Override Action Bar shares ACTIONBUTTON bindings (vehicle / possess bar).
  _reg("OverrideActionBarButton",    "ACTIONBUTTON",           6)
end

local LIVE_REFRESH_INTERVAL = 0.12
local HASHLESS_REFRESH_INTERVAL = 0.25
local ACTION_SLOT_CACHE_MAX = 64

local function IsEditingAssistedHighlightTab()
  if not addon._editingOptions then return false end
  local settingsWindow = addon.settingsWindow
  if not (settingsWindow and settingsWindow.GetSelectedTopTab) then return true end
  return settingsWindow:GetSelectedTopTab() == "AssistedHighlight"
end

local function SetMirrorShown(frame, shouldShow)
  if not frame then return end
  shouldShow = shouldShow and true or false

  local shownChanged = frame._assistedHighlightShown ~= shouldShow
  local actualMismatch = (shouldShow and (not frame:IsShown())) or ((not shouldShow) and frame:IsShown())
  if not shownChanged and not actualMismatch then
    return
  end

  frame._assistedHighlightShown = shouldShow
  if shouldShow then
    frame:Show()
  else
    frame:Hide()
  end
end

local function MarkAssistedHighlightDirty(reason)
  addon._assistedHighlightDirty = true
  if reason ~= nil then
    addon._assistedHighlightDirtyReason = reason
  end
end

local function MarkAssistedHighlightPositionDirty()
  addon._assistedHighlightPositionDirty = true
end

local function CacheActionSlot(self, spellID, slot)
  if not spellID then return end
  self._actionSlotCache = self._actionSlotCache or {}
  local cache = self._actionSlotCache

  if cache[spellID] == nil then
    local count = self._actionSlotCacheCount or 0
    if count >= ACTION_SLOT_CACHE_MAX then
      if API.wipe then
        API.wipe(cache)
      else
        for key in pairs(cache) do
          cache[key] = nil
        end
      end
      count = 0
    end
    self._actionSlotCacheCount = count + 1
  end

  cache[spellID] = slot
end

local function GetBindingForActionSlot(slot)
  slot = tonumber(slot) or 0
  if slot <= 0 then return nil end
  Provider._bindingCache = Provider._bindingCache or {}
  local cached = Provider._bindingCache[slot]
  if cached ~= nil then
    return cached ~= false and cached or nil
  end

  local command = SLOT_BINDINGS[slot]
  if not command or not GetBindingKey then
    Provider._bindingCache[slot] = false
    return nil
  end

  local key1, key2 = GetBindingKey(command)
  key1 = key1 and FormatBindingKey(key1) or nil
  key2 = key2 and FormatBindingKey(key2) or nil
  local value = key1 or key2
  if key1 and key2 then
    value = key1 .. " / " .. key2
  end
  Provider._bindingCache[slot] = value or false
  return value
end

-- Resolve the keybind for an action button by its FRAME NAME, not its slot number.
-- This is always correct regardless of action bar paging:
--   ActionButton1.action may be 1 (page 1) or 13 (page 2), but its binding command
--   is always ACTIONBUTTON1.  SLOT_BINDINGS[13] would return MULTIACTIONBAR3BUTTON1,
--   which is wrong for a paged main bar.  Frame-name lookup has no such ambiguity.
local function GetBindingForButton(button)
  if not button then return nil end
  local name = button.GetName and button:GetName()
  if not name then return nil end
  Provider._buttonBindingCache = Provider._buttonBindingCache or {}
  local cached = Provider._buttonBindingCache[name]
  if cached ~= nil then
    return cached ~= false and cached or nil
  end
  local cmd = BUTTON_NAME_TO_BINDING[name]
  if not cmd or not GetBindingKey then
    Provider._buttonBindingCache[name] = false
    return nil
  end
  local k1, k2 = GetBindingKey(cmd)
  k1 = k1 and FormatBindingKey(k1) or nil
  k2 = k2 and FormatBindingKey(k2) or nil
  local value = k1 or k2
  if k1 and k2 then value = k1 .. " / " .. k2 end
  Provider._buttonBindingCache[name] = value or false
  return value
end

local function SpellMatchesActionSlot(slot, spellID, slotType, id, subType)
  if not slot or not spellID then return false end
  if slotType == nil and GetActionInfo then
    slotType, id, subType = GetActionInfo(slot)
  end
  -- Assisted-combat slots are found by FindAssistedCombatSlot, not by spell-ID search.
  -- Matching them here causes a tautology: GetActionSpell() always equals the spell we
  -- are searching for, so every assistedcombat slot unconditionally matches, and the
  -- first one in slot-number order (which may belong to a visually-stacked wrong bar)
  -- is returned instead of the slot the player actually presses.
  if subType == "assistedcombat" then return false end
  if slotType == "spell" then
    if tonumber(id) == tonumber(spellID) then
      return true
    end
  end
  if C_ActionBar and C_ActionBar.GetSpell then
    local actionSpell = C_ActionBar.GetSpell(slot)
    if tonumber(actionSpell) == tonumber(spellID) then
      return true
    end
  end
  return false
end

-- ── Assisted-combat slot discovery ────────────────────────────────────────────
-- Find the slot that holds the Blizzard Rotation Helper (assisted-combat) action.
-- This is the EXACT slot Blizzard highlights; its binding is always the correct
-- keybind regardless of which spell is currently recommended.
--
-- Design notes:
--   • Do NOT gate on HasAction().  HasAction returns false when the action is
--     currently unusable (OOM, on cooldown, no target).  That would cause the
--     scan to skip the correct slot and fall through to a wrong one.  GetActionInfo
--     alone is authoritative for slot-identity purposes.
--   • Do NOT require slotType == "spell".  The subType field alone uniquely
--     identifies the Rotation Helper action; guarding on slotType makes the check
--     brittle against future API shape changes.
--   • false  = scanned the full bar, not found
--   • nil    = not yet scanned (triggers scan on next call)
local function FindAssistedCombatSlot(self)
  if self._assistedCombatSlot ~= nil then
    return self._assistedCombatSlot ~= false and self._assistedCombatSlot or nil
  end

  if not GetActionInfo then
    self._assistedCombatSlot = false
    return nil
  end

  for slot = 1, 120 do
    local _, _, subType = GetActionInfo(slot)
    if subType == "assistedcombat" then
      self._assistedCombatSlot = slot
      return slot
    end
  end

  self._assistedCombatSlot = false
  return nil
end

-- ── Glow hook (authoritative keybind signal) ──────────────────────────────────
-- Hook Blizzard's ActionButton_ShowOverlayGlow / ActionButton_HideOverlayGlow to
-- track which action button frames Blizzard is currently highlighting.
--
-- This is more reliable than slot-number ordering or frame-level sorting because:
--  • Blizzard calls ShowOverlayGlow on the EXACT button it wants the player to press.
--  • button.action gives the real action slot, regardless of bar name or position.
--  • No guesswork about frame names, prefix lists, or visual stacking order.
--
-- Provider._glowedButtonList : { {slot=N, button=F}, … } for each currently-glowing button.
-- Cleared on PLAYER_ENTERING_WORLD (bar layout reset) and ACTIONBAR_SLOT_CHANGED.

local function SetupGlowHook(provider)
  if provider._glowHookDone then return end
  provider._glowHookDone = true

  -- Track {slot, button} pairs rather than bare slot numbers.
  -- Blizzard fires ShowOverlayGlow on EVERY button that shows the recommended spell,
  -- including buttons on hidden/disabled bars.  Storing the button frame lets
  -- GetState filter by visibility and pick the topmost visible button, rather than
  -- selecting randomly from all glowed slots via pairs() with undefined order.
  local function OnGlowShow(button)
    local slot = button and tonumber(
      button.action or (button.GetAttribute and button:GetAttribute("action")))
    if not (slot and slot >= 1 and slot <= 120) then return end
    provider._glowedButtonList = provider._glowedButtonList or {}
    local list = provider._glowedButtonList
    for _, entry in ipairs(list) do
      if entry.button == button then return end  -- already tracked
    end
    list[#list + 1] = { slot = slot, button = button }
    provider:MarkDirty()
    MarkAssistedHighlightDirty("GlowShow")
  end

  local function OnGlowHide(button)
    local list = provider._glowedButtonList
    if not list then return end
    for i = #list, 1, -1 do
      if list[i].button == button then
        table.remove(list, i)
        break
      end
    end
    provider:MarkDirty()
    MarkAssistedHighlightDirty("GlowHide")
  end

  API.SafeHooksecurefunc("ActionButton_ShowOverlayGlow", OnGlowShow)
  API.SafeHooksecurefunc("ActionButton_HideOverlayGlow", OnGlowHide)
end

-- ── Frame-priority slot lookup ─────────────────────────────────────────────────
-- When the same spell exists on multiple bars (stacked / overlapping layout), the
-- slot-number scan (1→120) is wrong: it returns the lowest slot regardless of which
-- bar is visually on top and which key the player actually presses.
--
-- The correct answer is the button with the highest effective frame level — that is
-- the button "on top" in the visual stack, the one that intercepts mouse input, and
-- the one whose keybind the player uses.
--
-- We build this registry once per session from standard Blizzard action bar frame
-- names and sort it by GetEffectiveFrameLevel() descending.  It is invalidated on
-- ACTIONBAR_SLOT_CHANGED, PLAYER_ENTERING_WORLD, and PLAYER_SPECIALIZATION_CHANGED.
--
-- AddOn-created bars (Bartender4, Dominos, etc.) are not in the registry; if no
-- frame-priority match is found, FindActionSlotForSpell provides the slot-scan
-- fallback that covers them.

local _buttonRegistry        = nil   -- { {slot=N, frame=F}, … } sorted desc by level
local _buttonRegistryValid   = false

-- Standard Blizzard action bar button name prefixes (Retail / TWW / Midnight).
-- Count is always 12 per bar.  Names are part of the shipped UI and are stable.
local BUTTON_PREFIXES = {
  "ActionButton",
  "MultiBarBottomLeftButton",
  "MultiBarBottomRightButton",
  "MultiBarRightButton",
  "MultiBarLeftButton",
}
local BUTTONS_PER_BAR = 12

local function InvalidateButtonRegistry()
  _buttonRegistryValid = false
end

local function GetButtonRegistry()
  if _buttonRegistryValid and _buttonRegistry then
    return _buttonRegistry
  end

  local reg = _buttonRegistry or {}
  _buttonRegistry = reg
  for i = #reg, 1, -1 do reg[i] = nil end   -- wipe in-place, reuse table

  for _, prefix in ipairs(BUTTON_PREFIXES) do
    for i = 1, BUTTONS_PER_BAR do
      local btn = _G[prefix .. i]
      if btn and type(btn) == "table" then
        -- btn.action is set by Blizzard's ActionButton_Update; GetAttribute is the
        -- secure-frame fallback for buttons created by some addon bars.
        local slot = btn.action
        if slot == nil and btn.GetAttribute then
          slot = tonumber(btn:GetAttribute("action"))
        end
        slot = tonumber(slot)
        if slot and slot >= 1 and slot <= 120 then
          reg[#reg + 1] = { slot = slot, frame = btn }
        end
      end
    end
  end

  -- Sort: highest effective frame level first (visually topmost button).
  -- GetEffectiveFrameLevel sums the frame's own level plus all parent levels,
  -- giving the true draw order.  Tiebreak by slot ascending so the result is
  -- deterministic when levels are equal (common on same-strata bars).
  table.sort(reg, function(a, b)
    local la = (a.frame.GetEffectiveFrameLevel and a.frame:GetEffectiveFrameLevel())
            or (a.frame.GetFrameLevel          and a.frame:GetFrameLevel()) or 0
    local lb = (b.frame.GetEffectiveFrameLevel and b.frame:GetEffectiveFrameLevel())
            or (b.frame.GetFrameLevel          and b.frame:GetFrameLevel()) or 0
    if la ~= lb then return la > lb end
    return (a.slot or 999) < (b.slot or 999)
  end)

  _buttonRegistryValid = true
  return reg
end

-- Find the action slot for spellID by iterating known button frames in visual
-- priority order (topmost bar first).  Returns slot, frame for the first match;
-- nil, nil if none found.
local function FindSlotByFramePriority(spellID)
  local reg = GetButtonRegistry()
  for _, entry in ipairs(reg) do
    if SpellMatchesActionSlot(entry.slot, spellID) then
      return entry.slot, entry.frame
    end
  end
  return nil, nil
end

-- Return the first registered button frame whose current .action == slot.
-- Used to attach a button frame to an assistedcombat or raw-scan slot result so
-- GetBindingForButton can be used instead of the SLOT_BINDINGS fallback.
local function FindButtonForSlot(slot)
  if not slot then return nil end
  local reg = GetButtonRegistry()
  for _, entry in ipairs(reg) do
    if entry.slot == slot then
      return entry.frame
    end
  end
  return nil
end

function Provider:FindActionSlotForSpell(spellID)
  if not spellID then return nil end
  self._actionSlotCache = self._actionSlotCache or {}

  local cachedSlot = self._actionSlotCache[spellID]
  if cachedSlot and SpellMatchesActionSlot(cachedSlot, spellID) then
    return cachedSlot
  end
  self._actionSlotCache[spellID] = nil

  -- Single pass: find the slot containing the spell.
  -- Assisted-combat slots are excluded by SpellMatchesActionSlot; they are resolved
  -- separately by FindAssistedCombatSlot and used for the keybind in GetState.
  if GetActionInfo then
    for slot = 1, 120 do
      if (not HasAction) or HasAction(slot) then  ---@diagnostic disable-line: undefined-global
        local slotType, id, subType = GetActionInfo(slot)
        if SpellMatchesActionSlot(slot, spellID, slotType, id, subType) then
          CacheActionSlot(self, spellID, slot)
          return slot
        end
      end
    end
  end
  return nil
end

function Provider:MarkDirty()
  self._stateDirty = true
end

function Provider:IsAvailable()
  return C_AssistedCombat and C_AssistedCombat.IsAvailable and C_AssistedCombat.IsAvailable() or false
end

function Provider:GetRecommendedSpellID()
  if not self:IsAvailable() then return nil end
  if not (C_AssistedCombat and C_AssistedCombat.GetNextCastSpell) then return nil end

  local spellID = C_AssistedCombat.GetNextCastSpell(true)
  if not spellID then
    spellID = C_AssistedCombat.GetNextCastSpell()
  end
  return tonumber(spellID) or nil
end

function Provider:GetState(force)
  local spellID = self:GetRecommendedSpellID()
  if not spellID then
    self._lastState = nil
    self._stateDirty = false
    return nil
  end

  -- ── Binding resolution priority chain ────────────────────────────────────────
  --
  --  1. Glow hook (authoritative) — select the best button from _glowedButtonList
  --     whose slot contains the recommended spell.
  --       • Prefer buttons where IsVisible() is true (bar is actually shown on screen).
  --         This prevents hidden/disabled bars from winning over the visible one.
  --       • Among equally-visible candidates, prefer highest GetEffectiveFrameLevel.
  --     Keybind is derived from the button FRAME NAME via BUTTON_NAME_TO_BINDING,
  --     NOT from SLOT_BINDINGS[slot].  Frame-name lookup is paging-safe:
  --     ActionButton1 → ACTIONBUTTON1 always, regardless of which slot it shows.
  --
  --  2. FindSlotByFramePriority — returns slot + frame for the topmost registered
  --     Blizzard bar button containing the spell.  Keybind via frame name.
  --
  --  3. FindAssistedCombatSlot — the Rotation Helper action button.  Keybind via
  --     frame name if the button is in the registry; SLOT_BINDINGS fallback otherwise.
  --
  --  4. FindActionSlotForSpell — raw slot scan (1→120).  Last resort for addon bars
  --     not in the standard frame registry.  Keybind via SLOT_BINDINGS fallback.
  local bindSlot   -- action slot used for range check and state identity
  local bindButton -- button frame, when known — used for accurate keybind lookup
  local glowSrc = "scan"

  -- Phase 1: glow hook — pick best visible, highest-level glowed button for the spell
  local glowList = self._glowedButtonList
  if glowList and #glowList > 0 then
    local bestLevel   = -1
    local bestVisible = false
    for _, entry in ipairs(glowList) do
      if SpellMatchesActionSlot(entry.slot, spellID) then
        local btn = entry.button
        -- IsVisible checks the full parent-chain (bar frame hidden → false).
        local isVisible = btn and btn.IsVisible and btn:IsVisible() or false
        local level     = (btn and btn.GetEffectiveFrameLevel and btn:GetEffectiveFrameLevel())
                       or (btn and btn.GetFrameLevel          and btn:GetFrameLevel()) or 0
        local isBetter  = (isVisible and not bestVisible)
                       or (isVisible == bestVisible and level > bestLevel)
        if isBetter then
          bindSlot   = entry.slot
          bindButton = btn
          bestLevel  = level
          bestVisible = isVisible
        end
      end
    end
    if bindSlot then glowSrc = "glow" end
  end

  -- Phase 2: frame-priority scan (returns slot + frame, already sorted by level)
  if not bindSlot then
    bindSlot, bindButton = FindSlotByFramePriority(spellID)
  end

  -- Phase 3: Rotation Helper action button (assistedcombat subType)
  if not bindSlot then
    bindSlot = FindAssistedCombatSlot(self)
    if bindSlot then
      bindButton = FindButtonForSlot(bindSlot)
    end
  end

  -- Phase 4: raw slot scan — last resort for addon bars not in the registry
  if not bindSlot then
    bindSlot = self:FindActionSlotForSpell(spellID)
    if bindSlot then
      bindButton = FindButtonForSlot(bindSlot)
    end
  end

  -- Derive keybind: button frame name is authoritative (paging-safe).
  -- Fall back to SLOT_BINDINGS only when no frame is available (pure addon bar).
  local keybind
  if bindButton then
    keybind = GetBindingForButton(bindButton)
  end
  if not keybind and bindSlot then
    keybind = GetBindingForActionSlot(bindSlot)
  end

  local texture = GetSpellTexture(spellID)
  local inRange = GetRangeState(bindSlot)

  local Debug = ns.Debug
  if Debug then
    local btnName = bindButton and (bindButton.GetName and bindButton:GetName()) or "nil"
    Debug("[AH]", "spellID=" .. tostring(spellID),
      "bindSlot=" .. tostring(bindSlot),
      "src=" .. glowSrc,
      "btn=" .. tostring(btnName),
      "keybind=" .. tostring(keybind),
      "inRange=" .. tostring(inRange))
  end

  local lastState = self._lastState
  if not force and (not self._stateDirty) and lastState
    and lastState.spellID == spellID
    and lastState.bindSlot == bindSlot
    and lastState.texture == texture
    and lastState.keybind == keybind
    and lastState.inRange == inRange then
    return lastState
  end

  local state = lastState or {}
  state.spellID = spellID
  state.texture = texture
  state.bindSlot = bindSlot
  -- Keep actionSlot populated for any consumers that may reference it externally.
  state.actionSlot = bindSlot
  state.keybind = keybind
  state.inRange = inRange
  self._lastState = state
  self._stateDirty = false
  return state
end

function Display:ApplyFont(frame)
  frame = frame or addon.assistedHighlightFrame
  if not (frame and frame.keybindText) then return end
  local fontName = (addon.GetAssistedHighlightFontName and addon:GetAssistedHighlightFontName()) or (addon.GetKeybindFontName and addon:GetKeybindFontName()) or (addon.GetModFontName and addon:GetModFontName()) or (addon.DEFAULT_MOD_FONT or C.FONT_FRIZ or "Friz Quadrata TT")
  local fontSize = tonumber((addon.GetAssistedHighlightFontSize and addon:GetAssistedHighlightFontSize()) or (addon.GetKeybindFontSize and addon:GetKeybindFontSize()) or 8) or 8
  local fontVersion = addon._fontRegistryVersion or 0
  if frame._assistedHighlightFontName == fontName
    and frame._assistedHighlightFontSize == fontSize
    and frame._assistedHighlightFontVersion == fontVersion then
    return
  end
  local fontPath = (addon.GetFontPathByName and addon:GetFontPathByName(fontName)) or C.FONT_PATH_FRIZ or STANDARD_TEXT_FONT
  frame._assistedHighlightFontName = fontName
  frame._assistedHighlightFontPath = fontPath
  frame._assistedHighlightFontSize = fontSize
  frame._assistedHighlightFontVersion = fontVersion
  if not frame.keybindText:SetFont(fontPath, fontSize, "OUTLINE") then
    frame.keybindText:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
  end
end

function Display:ApplyKeybindPosition(frame)
  frame = frame or addon.assistedHighlightFrame
  if not (frame and frame.keybindText) then return end
  local x, y = addon:GetAssistedHighlightKeybindOffset()
  local px = PixelSnap(x, frame)
  local py = PixelSnap(y, frame)
  if frame._assistedHighlightKeybindX == px and frame._assistedHighlightKeybindY == py then return end
  frame._assistedHighlightKeybindX = px
  frame._assistedHighlightKeybindY = py
  frame.keybindText:ClearAllPoints()
  frame.keybindText:SetPoint("CENTER", frame, "CENTER", px, py)
end

function Display:ApplyBorder(frame)
  frame = frame or addon.assistedHighlightFrame
  if not frame then return end
  local borderSize = addon:GetAssistedHighlightBorderSize()
  local r, g, b = GetResolvedBorderColor()

  if frame.border then
    local alpha = borderSize <= 0 and 0 or 1
    local edgeSize = borderSize > 0 and borderSize or 0
    local needsBorderColorApply = false
    if frame._assistedHighlightBorderEdgeSize ~= edgeSize then
      frame._assistedHighlightBorderEdgeSize = edgeSize
      if edgeSize > 0 then
        frame.border:SetBackdrop({
          bgFile = C.TEXTURE_WHITE8X8 or "Interface\\Buttons\\WHITE8x8",
          edgeFile = C.TEXTURE_WHITE8X8 or "Interface\\Buttons\\WHITE8x8",
          edgeSize = edgeSize,
          insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        frame.border:SetBackdropColor(0, 0, 0, 0)
      else
        frame.border:SetBackdrop(nil)
      end
      needsBorderColorApply = true
    end

    if needsBorderColorApply or frame._assistedHighlightBorderR ~= r or frame._assistedHighlightBorderG ~= g or frame._assistedHighlightBorderB ~= b or frame._assistedHighlightBorderA ~= alpha then
      frame._assistedHighlightBorderR = r
      frame._assistedHighlightBorderG = g
      frame._assistedHighlightBorderB = b
      frame._assistedHighlightBorderA = alpha
      if edgeSize > 0 then
        frame.border:SetBackdropBorderColor(r, g, b, alpha)
      end
    end
  end

  if frame._dragBorder then
    local showDragBorder = false
    if (not frame.isPreview) and IsEditingAssistedHighlightTab() and (not GetAssistedHighlightLockState()) and addon:IsAssistedHighlightMirrorEnabled() then
      showDragBorder = true
      if frame._assistedHighlightDragBorderR ~= r or frame._assistedHighlightDragBorderG ~= g or frame._assistedHighlightDragBorderB ~= b then
        frame._assistedHighlightDragBorderR = r
        frame._assistedHighlightDragBorderG = g
        frame._assistedHighlightDragBorderB = b
        frame._dragBorder:SetBackdropBorderColor(r, g, b, 0.85)
        frame._dragBorder:SetBackdropColor(r, g, b, 0.10)
      end
    end

    if frame._assistedHighlightDragBorderShown ~= showDragBorder then
      frame._assistedHighlightDragBorderShown = showDragBorder
      if showDragBorder then
        frame._dragBorder:Show()
      else
        frame._dragBorder:Hide()
      end
    end
  end
end

function Display:ApplyPosition(force)
  local frame = addon.assistedHighlightFrame
  if not frame then return false end
  local point, _, relativePoint, x, y = GetAnchorPointConfig()
  local parent, relName, followsCursor, anchorAvailable = GetLiveAnchorTargetInfo()
  local targetMode = addon.GetAssistedHighlightAnchorTarget and addon:GetAssistedHighlightAnchorTarget() or "Screen"
  local appliedPoint, appliedRelativePoint = ResolveAppliedAnchorPoints(point, relativePoint)
  local resolvedAnchorAvailable = anchorAvailable and parent ~= nil

  if force or frame._assistedHighlightAnchorMode ~= targetMode or frame._assistedHighlightAnchorAvailable ~= resolvedAnchorAvailable then
    frame._gsetrackerPoint = nil
    frame._gsetrackerAnchor = nil
    frame._gsetrackerRelativePoint = nil
    frame._gsetrackerPointX = nil
    frame._gsetrackerPointY = nil
    frame:ClearAllPoints()
  end

  frame._assistedHighlightAnchorMode = targetMode
  frame._assistedHighlightAnchorName = relName
  frame._assistedHighlightAnchorAvailable = resolvedAnchorAvailable

  if not frame._assistedHighlightAnchorAvailable then
    frame._assistedHighlightResolvedX = nil
    frame._assistedHighlightResolvedY = nil
    return false
  end

  if followsCursor then
    local ax, ay = ApplyCursorAnchor(frame, appliedPoint, appliedRelativePoint, x, y)
    frame._assistedHighlightResolvedX = ax
    frame._assistedHighlightResolvedY = ay
  else
    ApplyResolvedAnchor(frame, parent, appliedPoint, appliedRelativePoint, x, y)
    frame._assistedHighlightResolvedX = x
    frame._assistedHighlightResolvedY = y
  end

  return true
end

function Display:UpdateMovableState()
  local frame = addon.assistedHighlightFrame
  if not frame then return end

  local canDrag = not not (
    IsEditingAssistedHighlightTab()
    and (not GetAssistedHighlightLockState())
    and (not (API.InCombatLockdown and API.InCombatLockdown()))
    and addon:IsAssistedHighlightMirrorEnabled()
  )

  if not canDrag and frame._isDragging and addon.EndAssistedHighlightDrag then
    addon:EndAssistedHighlightDrag(false)
  end

  if frame._canDragAssistedHighlight ~= canDrag then
    frame._canDragAssistedHighlight = canDrag
    frame:EnableMouse(canDrag)
  end

  self:ApplyBorder(frame)
end

GetCursorPositionInParentSpace = function(parent)
  parent = parent or UIParent
  local scale = (parent.GetEffectiveScale and parent:GetEffectiveScale()) or 1
  if not scale or scale == 0 then scale = 1 end
  local cursorX, cursorY = API.GetCursorPosition()
  return (tonumber(cursorX) or 0) / scale, (tonumber(cursorY) or 0) / scale
end

function UI:SyncActiveAssistedHighlightDragPosition()
  local frame = addon.assistedHighlightFrame
  if not (frame and frame._isDragging) then return false end

  local origin = self._assistedHighlightDragOrigin
  local startCursorX = self._assistedHighlightDragCursorOriginX
  local startCursorY = self._assistedHighlightDragCursorOriginY

  local point, relName, relativePoint = addon:GetAssistedHighlightPoint()
  local parent, _, followsCursor, anchorAvailable = GetLiveAnchorTargetInfo()
  local x, y
  if origin and startCursorX ~= nil and startCursorY ~= nil then
    local cursorX, cursorY = GetCursorPositionInParentSpace(UIParent)
    x = (tonumber(origin[4]) or 0) + ParentUnitsToCanonicalPixels(cursorX - startCursorX, UIParent)
    y = (tonumber(origin[5]) or 0) + ParentUnitsToCanonicalPixels(cursorY - startCursorY, UIParent)
  else
    x, y = addon:GetAssistedHighlightOffset()
  end

  x, y = ClampCenteredOffsetsToScreen(frame, UIParent, x, y)
  self:SetAssistedHighlightPoint(point, relName, relativePoint, x, y)
  local appliedPoint = ResolvePointName(point)
  local appliedRelativePoint = ResolvePointName(relativePoint)
  if followsCursor then
    local ax, ay = ApplyCursorAnchor(frame, appliedPoint, appliedRelativePoint, x, y)
    frame._assistedHighlightResolvedX = ax
    frame._assistedHighlightResolvedY = ay
  elseif anchorAvailable and parent then
    ApplyResolvedAnchor(frame, parent, appliedPoint, appliedRelativePoint, x, y)
    frame._assistedHighlightResolvedX = x
    frame._assistedHighlightResolvedY = y
  else
    frame._assistedHighlightResolvedX = nil
    frame._assistedHighlightResolvedY = nil
    return false
  end
  self:RefreshAssistedHighlightPositionControls()
  return true
end

function UI:BeginAssistedHighlightDrag(frame)
  frame = frame or addon.assistedHighlightFrame
  if not frame then return false end
  if frame._isDragging then return true end

  local point, relName, relativePoint, x, y = self:GetAssistedHighlightPoint()
  self._assistedHighlightDragOrigin = { point, relName, relativePoint, x, y }
  self._assistedHighlightDragCursorOriginX, self._assistedHighlightDragCursorOriginY = GetCursorPositionInParentSpace(UIParent)
  frame._isDragging = true
  self:SyncActiveAssistedHighlightDragPosition()
  return true
end

function UI:EndAssistedHighlightDrag(commitPosition)
  local frame = addon.assistedHighlightFrame
  if not (frame and frame._isDragging) then return false end

  if commitPosition then
    self:SyncActiveAssistedHighlightDragPosition()
  else
    local origin = self._assistedHighlightDragOrigin
    if origin then
      self:SetAssistedHighlightPoint(origin[1], origin[2], origin[3], origin[4], origin[5])
    end
    self:ApplyAssistedHighlightPosition(true)
  end

  frame._isDragging = false
  MarkAssistedHighlightPositionDirty()
  self._assistedHighlightDragOrigin = nil
  self._assistedHighlightDragCursorOriginX = nil
  self._assistedHighlightDragCursorOriginY = nil
  self:RefreshAssistedHighlightPositionControls()
  return true
end

function Display:ApplyLiveStrata(frame)
  frame = frame or addon.assistedHighlightFrame
  if not frame or frame.isPreview then return end
  local strata = (addon.ui and addon.ui.GetFrameStrata and addon.ui:GetFrameStrata()) or (addon.GetStrata and addon:GetStrata()) or (C.DEFAULT_COMBAT_TRACKER_STRATA or C.STRATA_MEDIUM or "MEDIUM")
  local level = (addon.ui and addon.ui.GetFrameLevel and addon.ui:GetFrameLevel()) or 0
  if frame._assistedHighlightFrameStrata ~= strata then
    frame._assistedHighlightFrameStrata = strata
    frame:SetFrameStrata(strata)
  end
  if frame._assistedHighlightFrameLevel ~= level then
    frame._assistedHighlightFrameLevel = level
    frame:SetFrameLevel(level)
  end
end

local function CreateMirrorFrame(parent, isPreview)
  local frame = API.CreateFrame("Frame", nil, parent or UIParent, "BackdropTemplate")
  frame.isPreview = isPreview and true or false
  if frame.isPreview then
    frame:SetFrameStrata(C.STRATA_DIALOG or "DIALOG")
    frame:SetFrameLevel(80)
  else
    local strata = (addon.ui and addon.ui.GetFrameStrata and addon.ui:GetFrameStrata()) or (addon.GetStrata and addon:GetStrata()) or (C.DEFAULT_COMBAT_TRACKER_STRATA or C.STRATA_MEDIUM or "MEDIUM")
    local level = (addon.ui and addon.ui.GetFrameLevel and addon.ui:GetFrameLevel()) or 0
    frame:SetFrameStrata(strata)
    frame:SetFrameLevel(level)
  end
  frame:SetClampedToScreen(true)
  frame:SetIgnoreParentScale(false)
  frame:Hide()

  local bg = frame:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(frame)
  bg:SetTexture(C.TEXTURE_WHITE8X8 or "Interface\\Buttons\\WHITE8x8")
  bg:SetVertexColor(0.02, 0.02, 0.02, frame.isPreview and 0.84 or 0.72)
  frame.bg = bg

  local icon = frame:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints(frame)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  frame.icon = icon

  local border = API.CreateFrame("Frame", nil, frame, "BackdropTemplate")
  border:SetAllPoints(frame)
  frame.border = border

  local dragBorder = API.CreateFrame("Frame", nil, frame, "BackdropTemplate")
  dragBorder:SetAllPoints(frame)
  dragBorder:SetBackdrop({ bgFile = C.TEXTURE_WHITE8X8 or "Interface\\Buttons\\WHITE8x8", edgeFile = C.TEXTURE_WHITE8X8 or "Interface\\Buttons\\WHITE8x8", edgeSize = 2, insets = { left = 0, right = 0, top = 0, bottom = 0 } })
  dragBorder:SetBackdropColor(0, 0, 0, 0)
  dragBorder:Hide()
  frame._dragBorder = dragBorder

  local keybind = CreateFont(frame, 11)
  keybind:SetDrawLayer("OVERLAY", 7)
  frame.keybindText = keybind

  local rangeTint = frame:CreateTexture(nil, "OVERLAY")
  rangeTint:SetAllPoints(frame)
  rangeTint:SetTexture(C.TEXTURE_WHITE8X8 or "Interface\\Buttons\\WHITE8x8")
  rangeTint:SetVertexColor(1, 0.1, 0.1, 0)
  frame.rangeOverlay = rangeTint

  Display:ApplyFont(frame)
  Display:ApplyKeybindPosition(frame)
  Display:ApplyBorder(frame)

  if not frame.isPreview then
    frame:SetScript("OnMouseDown", function(self, button)
      if button ~= "LeftButton" then return end
      if not self._canDragAssistedHighlight then return end
      if not addon:IsAssistedHighlightMirrorEnabled() or GetAssistedHighlightLockState() then return end
      addon:BeginAssistedHighlightDrag(self)
    end)

    frame:SetScript("OnMouseUp", function(self, button)
      if button ~= "LeftButton" then return end
      if self._isDragging then
        addon:EndAssistedHighlightDrag(true)
      end
    end)

    frame:SetScript("OnHide", function(self)
      if self._isDragging then
        addon:EndAssistedHighlightDrag(false)
      end
    end)

    frame:SetScript("OnUpdate", function(self, elapsed)
      if self._isDragging and addon.SyncActiveAssistedHighlightDragPosition then
        addon:SyncActiveAssistedHighlightDragPosition()
        return
      end

      local mirrorEnabled = addon.IsAssistedHighlightMirrorEnabled and addon:IsAssistedHighlightMirrorEnabled()
      if IsEditingAssistedHighlightTab() or not mirrorEnabled then
        return
      end

      -- Hidden mirrors should not keep doing cursor-follow or provider work.
      -- Event-driven refreshes wake the frame back up when visibility changes.
      if not self:IsShown() then
        return
      end

      local followsCursor = addon.GetAssistedHighlightAnchorTarget and addon:GetAssistedHighlightAnchorTarget() == "Mouse Cursor"
      if followsCursor then
        Display:ApplyPosition()
      end

      self._elapsed = (self._elapsed or 0) + (elapsed or 0)
      local refreshInterval = (API.InCombatLockdown and API.InCombatLockdown()) and LIVE_REFRESH_INTERVAL or HASHLESS_REFRESH_INTERVAL
      local dirty = addon._assistedHighlightDirty == true

      if self._elapsed < refreshInterval then
        return
      end

      self._elapsed = 0
      addon._assistedHighlightDirty = nil
      addon._assistedHighlightDirtyReason = nil
      if addon.RefreshAssistedHighlight then
        addon:RefreshAssistedHighlight(dirty)
      end
    end)
  end

  return frame
end

function Display:ApplySize(frame)
  frame = frame or addon.assistedHighlightFrame or self:Create()
  local size = addon:GetAssistedHighlightSize()
  local snappedW = PixelSnap(size, frame)
  local snappedH = PixelSnap(size, frame)
  if frame._assistedHighlightWidth == snappedW and frame._assistedHighlightHeight == snappedH then return end
  frame._assistedHighlightWidth = snappedW
  frame._assistedHighlightHeight = snappedH
  frame:SetSize(snappedW, snappedH)
end

function Display:ApplyAlpha(frame)
  frame = frame or addon.assistedHighlightFrame or self:Create()
  if not frame then return end
  local alpha = addon.GetAssistedHighlightAlpha and addon:GetAssistedHighlightAlpha() or (C.ASSISTED_HIGHLIGHT_DEFAULT_ALPHA or 0.85)
  alpha = math.max(0.05, math.min(1.00, tonumber(alpha) or (C.ASSISTED_HIGHLIGHT_DEFAULT_ALPHA or 0.85)))
  if frame._assistedHighlightAlpha == alpha then return end
  frame._assistedHighlightAlpha = alpha
  frame:SetAlpha(alpha)
end

function Display:RenderToFrame(frame, state)
  if not frame then return end
  self:ApplySize(frame)
  self:ApplyAlpha(frame)
  self:ApplyFont(frame)
  self:ApplyKeybindPosition(frame)
  self:ApplyBorder(frame)

  if not state or not state.texture then
    if frame._assistedHighlightTexture ~= false then
      frame._assistedHighlightTexture = false
      frame.icon:SetTexture(nil)
    end
    if frame._assistedHighlightIconR ~= 1 or frame._assistedHighlightIconG ~= 1 or frame._assistedHighlightIconB ~= 1 then
      frame._assistedHighlightIconR, frame._assistedHighlightIconG, frame._assistedHighlightIconB = 1, 1, 1
      frame.icon:SetVertexColor(1, 1, 1, 1)
    end
    if frame._assistedHighlightRangeAlpha ~= 0 then
      frame._assistedHighlightRangeAlpha = 0
      frame.rangeOverlay:SetAlpha(0)
    end
    if frame._assistedHighlightKeybindText ~= "" then
      frame._assistedHighlightKeybindText = ""
      frame.keybindText:SetText("")
    end
    if frame._assistedHighlightKeybindVisible ~= false then
      frame._assistedHighlightKeybindVisible = false
      frame.keybindText:Hide()
    end

    local shouldShow = false
    if (not frame.isPreview) and IsEditingAssistedHighlightTab() and addon:IsAssistedHighlightMirrorEnabled() and (not GetAssistedHighlightLockState()) then
      shouldShow = true
    end
    SetMirrorShown(frame, shouldShow)
    return
  end

  if frame._assistedHighlightTexture ~= state.texture then
    frame._assistedHighlightTexture = state.texture
    frame.icon:SetTexture(state.texture)
  end
  if frame._assistedHighlightDesaturated ~= false then
    frame._assistedHighlightDesaturated = false
    frame.icon:SetDesaturated(false)
  end

  local showKeybind = addon:GetAssistedHighlightShowKeybind() and state.keybind and true or false
  local keybindText = showKeybind and state.keybind or ""
  if frame._assistedHighlightKeybindText ~= keybindText then
    frame._assistedHighlightKeybindText = keybindText
    frame.keybindText:SetText(keybindText)
  end
  if frame._assistedHighlightKeybindVisible ~= showKeybind then
    frame._assistedHighlightKeybindVisible = showKeybind
    if showKeybind then frame.keybindText:Show() else frame.keybindText:Hide() end
  end

  local outOfRange = addon:GetAssistedHighlightRangeCheckerEnabled() and state.inRange == false
  local iconR, iconG, iconB = 1, 1, 1
  local rangeAlpha = 0
  if outOfRange then
    iconR, iconG, iconB = 0.82, 0.18, 0.18
    rangeAlpha = frame.isPreview and 0.10 or 0.16
  end
  if frame._assistedHighlightIconR ~= iconR or frame._assistedHighlightIconG ~= iconG or frame._assistedHighlightIconB ~= iconB then
    frame._assistedHighlightIconR, frame._assistedHighlightIconG, frame._assistedHighlightIconB = iconR, iconG, iconB
    frame.icon:SetVertexColor(iconR, iconG, iconB, 1)
  end
  if frame._assistedHighlightRangeAlpha ~= rangeAlpha then
    frame._assistedHighlightRangeAlpha = rangeAlpha
    frame.rangeOverlay:SetAlpha(rangeAlpha)
  end

  SetMirrorShown(frame, true)
end

function Display:Render(state)
  local frame = addon.assistedHighlightFrame or self:Create()
  self:ApplyLiveStrata(frame)
  local followsCursor = addon.GetAssistedHighlightAnchorTarget and addon:GetAssistedHighlightAnchorTarget() == "Mouse Cursor"
  local anchorApplied = true
  if followsCursor or addon._assistedHighlightPositionDirty or frame._assistedHighlightAnchorAvailable == nil then
    anchorApplied = self:ApplyPosition(addon._assistedHighlightPositionDirty)
    addon._assistedHighlightPositionDirty = nil
  end
  self:UpdateMovableState()
  if not anchorApplied then
    SetMirrorShown(frame, false)
    return
  end
  self:RenderToFrame(frame, state)
end

function Display:Create()
  if addon.assistedHighlightFrame then return addon.assistedHighlightFrame end
  addon.assistedHighlightFrame = CreateMirrorFrame(UIParent, false)
  return addon.assistedHighlightFrame
end

function UI:EnsureAssistedHighlightEvents()
  if self.assistedHighlightEvents then return self.assistedHighlightEvents end
  local frame = API.CreateFrame("Frame")
  self.assistedHighlightEvents = frame
  local events = {
    "PLAYER_ENTERING_WORLD",
    "PLAYER_TARGET_CHANGED",
    "UNIT_TARGET",
    "NAME_PLATE_UNIT_ADDED",
    "NAME_PLATE_UNIT_REMOVED",
    "ACTIONBAR_SLOT_CHANGED",
    "ACTIONBAR_UPDATE_STATE",
    "ACTIONBAR_UPDATE_USABLE",
    "SPELL_UPDATE_USABLE",
    "PLAYER_SPECIALIZATION_CHANGED",
    "UPDATE_BINDINGS",
    "UNIT_AURA",
    "CURRENT_SPELL_CAST_CHANGED",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
    "ASSISTED_COMBAT_ACTION_SPELL_CAST",
  }
  for _, event in ipairs(events) do
    API.SafeRegisterEvent(frame, event)
  end
  frame:SetScript("OnEvent", function(_, event, unit)
    local mirrorEnabled = addon.IsAssistedHighlightMirrorEnabled and addon:IsAssistedHighlightMirrorEnabled()

    if event == "UNIT_AURA" or event == "UNIT_TARGET" then
      if unit and unit ~= "player" and unit ~= "target" then return end
    elseif event == "NAME_PLATE_UNIT_ADDED" or event == "NAME_PLATE_UNIT_REMOVED" then
      if not (unit and UnitIsUnit and UnitIsUnit(unit, "target")) then return end
    end

    if event == "UPDATE_BINDINGS" then
      Provider._bindingCache = nil
      Provider._buttonBindingCache = nil  -- frame-name based cache, also keybind data
    end

    if event == "PLAYER_ENTERING_WORLD"
      or event == "ACTIONBAR_SLOT_CHANGED"
      or event == "PLAYER_SPECIALIZATION_CHANGED" then
      Provider._actionSlotCache = nil
      Provider._actionSlotCacheCount = nil
      -- The Rotation Helper slot, frame-priority registry, and glow tracking all
      -- reflect bar layout; invalidate them whenever the bar layout may have changed.
      Provider._assistedCombatSlot = nil
      Provider._glowedButtonList = nil
      InvalidateButtonRegistry()
    end

    if (not mirrorEnabled) and (not IsEditingAssistedHighlightTab()) then
      return
    end

    if event == "PLAYER_ENTERING_WORLD"
      or event == "PLAYER_TARGET_CHANGED"
      or event == "UNIT_TARGET"
      or event == "NAME_PLATE_UNIT_ADDED"
      or event == "NAME_PLATE_UNIT_REMOVED"
      or event == "PLAYER_REGEN_DISABLED"
      or event == "PLAYER_REGEN_ENABLED" then
      MarkAssistedHighlightPositionDirty()
    end

    Provider:MarkDirty()
    MarkAssistedHighlightDirty(event)

    local immediate = (
      event == "PLAYER_ENTERING_WORLD"
      or event == "PLAYER_TARGET_CHANGED"
      or event == "UNIT_TARGET"
      or event == "NAME_PLATE_UNIT_ADDED"
      or event == "NAME_PLATE_UNIT_REMOVED"
      or event == "ACTIONBAR_SLOT_CHANGED"
      or event == "PLAYER_SPECIALIZATION_CHANGED"
      or event == "UPDATE_BINDINGS"
      or event == "PLAYER_REGEN_DISABLED"
      or event == "PLAYER_REGEN_ENABLED"
      or event == "ASSISTED_COMBAT_ACTION_SPELL_CAST"
    )

    if immediate and addon.RefreshAssistedHighlight then
      addon:RefreshAssistedHighlight(true)
    end
  end)

  -- Install the overlay-glow hook so we know exactly which button Blizzard
  -- is highlighting.  Called once; SetupGlowHook guards against re-entry.
  SetupGlowHook(Provider)

  return frame
end

function UI:EnsureAssistedHighlight()
  self:EnsureAssistedHighlightEvents()
  return Display:Create()
end

function UI:ApplyAssistedHighlightPosition(force)
  MarkAssistedHighlightPositionDirty()
  local applied = Display:ApplyPosition(force)
  if applied == false and addon.assistedHighlightFrame then
    SetMirrorShown(addon.assistedHighlightFrame, false)
  end
  return applied
end

function UI:ApplyAssistedHighlightSize()
  Display:ApplySize(addon.assistedHighlightFrame)
  Display:ApplyBorder(addon.assistedHighlightFrame)
  Display:ApplyFont(addon.assistedHighlightFrame)
  Display:ApplyKeybindPosition(addon.assistedHighlightFrame)
end

function UI:ApplyAssistedHighlightAlpha()
  Display:ApplyAlpha(addon.assistedHighlightFrame)
end

function UI:ApplyAssistedHighlightFont()
  Display:ApplyFont(addon.assistedHighlightFrame)
end

function UI:ApplyAssistedHighlightKeybindPosition()
  Display:ApplyKeybindPosition(addon.assistedHighlightFrame)
end

function UI:ApplyAssistedHighlightBorder()
  Display:ApplyBorder(addon.assistedHighlightFrame)
end

function UI:ApplyAssistedHighlightLayout(force)
  local applied = self:ApplyAssistedHighlightPosition(force)
  self:ApplyAssistedHighlightKeybindPosition()
  return applied
end

function UI:RefreshAssistedHighlightPositionControls()
  local settingsWindow = addon.settingsWindow
  if not (settingsWindow and settingsWindow.RefreshAssistedHighlightPositionControls) then return end
  settingsWindow:RefreshAssistedHighlightPositionControls()
end

function UI:HideAssistedHighlightPreview()
end

function UI:ShouldShowAssistedHighlight()
  if not (addon.IsAssistedHighlightMirrorEnabled and addon:IsAssistedHighlightMirrorEnabled()) then
    return false
  end

  local editingOverride = IsEditingAssistedHighlightTab()

  local showWhen = (addon.GetAssistedHighlightShowWhen and addon:GetAssistedHighlightShowWhen())
    or (C.MODE_ALWAYS or "Always")

  local ui = addon and addon.ui
  local inCombat
  if ui and ui._combatState ~= nil then
    inCombat = (ui._combatState == true)
  else
    inCombat = (API.InCombatLockdown and API.InCombatLockdown()) and true or false
  end
  local hasTarget = (API.UnitExists and API.UnitExists("target")) and true or false

  if self.EvaluateVisibilityMode then
    return self:EvaluateVisibilityMode(showWhen, inCombat, hasTarget, editingOverride)
  end

  if editingOverride then return true end
  if showWhen == (C.MODE_NEVER or "Never") then return false end
  if showWhen == (C.MODE_IN_COMBAT or "InCombat") then return inCombat end
  if showWhen == (C.MODE_HAS_TARGET or "HasTarget") then return hasTarget end
  return true
end

function UI:RefreshAssistedHighlight(force)
  local frame = self:EnsureAssistedHighlight()
  if not addon:IsAssistedHighlightMirrorEnabled() then
    SetMirrorShown(frame, false)
    self:HideAssistedHighlightPreview()
    return
  end

  local shouldShow = self:ShouldShowAssistedHighlight()
  if not shouldShow then
    SetMirrorShown(frame, false)
  else
    local providerAvailable = Provider:IsAvailable()
    local state = providerAvailable and Provider:GetState(force) or nil
    Display:Render(state)
  end

end
