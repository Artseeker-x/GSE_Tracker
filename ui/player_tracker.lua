local _, ns = ...
local addon = ns
local UI = ns.UI
local API = (ns.Utils and ns.Utils.API) or {}
local C = (ns.Utils and ns.Utils.Constants) or addon.Constants or {}
local uiShared = addon._ui or {}
local UIParent = (API.UIParent and API.UIParent()) or UIParent

local pi = math.pi
local TEXTURE_WHITE = C.TEXTURE_WHITE8X8 or "Interface\\Buttons\\WHITE8x8"
local MAX_BARS = 16
local COMBAT_MARKER_LEVEL_OFFSET = 20

local function Clamp(value, lo, hi)
  if uiShared.Clamp then
    return uiShared.Clamp(value, lo, hi)
  end
  if value < lo then return lo end
  if value > hi then return hi end
  return value
end

local function PixelSnap(value, frame)
  if uiShared.PixelSnap then
    return uiShared.PixelSnap(value, frame)
  end
  return tonumber(value) or 0
end

local function GetClassColorRGB()
  if uiShared.GetPlayerClassColorRGB then
    return uiShared.GetPlayerClassColorRGB(C.CLASS_FALLBACK_R or 0.20, C.CLASS_FALLBACK_G or 0.60, C.CLASS_FALLBACK_B or 1.00)
  end
  return C.CLASS_FALLBACK_R or 0.20, C.CLASS_FALLBACK_G or 0.60, C.CLASS_FALLBACK_B or 1.00
end

local function GetResolvedMarkerColor()
  if addon.GetCombatMarkerUseClassColor and addon:GetCombatMarkerUseClassColor() then
    return GetClassColorRGB()
  end
  if addon.GetCombatMarkerColor then
    return addon:GetCombatMarkerColor()
  end
  return 1.00, 0.82, 0.20
end

local function ParentUnitsFromCanonical(value, parent)
  if uiShared.CanonicalPixelsToParentUnits then
    return uiShared.CanonicalPixelsToParentUnits(value, parent)
  end
  return PixelSnap(value, parent)
end

local function ParentUnitsToCanonical(value, parent)
  if uiShared.ParentUnitsToCanonicalPixels then
    return uiShared.ParentUnitsToCanonicalPixels(value, parent)
  end
  return tonumber(value) or 0
end

local function GetCursorPositionInParentSpace(parent)
  parent = parent or UIParent
  local scale = (parent.GetEffectiveScale and parent:GetEffectiveScale()) or 1
  if not scale or scale == 0 then
    scale = 1
  end

  local cursorX, cursorY = API.GetCursorPosition()
  return (tonumber(cursorX) or 0) / scale, (tonumber(cursorY) or 0) / scale
end

local function ClampCanonicalOffsets(frame, parent, x, y)
  if uiShared.ClampCenteredOffsetsToScreen then
    return uiShared.ClampCenteredOffsetsToScreen(frame, parent, x, y)
  end
  local limit = tonumber(C.COMBAT_MARKER_POSITION_LIMIT) or tonumber(C.ACTION_TRACKER_POSITION_LIMIT) or 3000
  return Clamp(x, -limit, limit), Clamp(y, -limit, limit)
end

local function HideTexture(tex)
  if tex then tex:Hide() end
end

local function SetTextureBar(tex, parent, width, height, rotation, x, y, r, g, b, a, drawLayer, subLevel)
  if not tex then return end
  tex:ClearAllPoints()
  subLevel = Clamp(tonumber(subLevel) or 0, -8, 7)
  tex:SetDrawLayer(drawLayer or "OVERLAY", subLevel)
  tex:SetPoint("CENTER", parent, "CENTER", PixelSnap(x or 0, parent), PixelSnap(y or 0, parent))
  tex:SetTexture(TEXTURE_WHITE)
  tex:SetSize(PixelSnap(width, parent), PixelSnap(height, parent))
  tex:SetRotation(rotation or 0)
  tex:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
  tex:Show()
end

local function GetCenteredAnchorConfig()
  local defaultPoint = C.COMBAT_MARKER_DEFAULT_POINT or { "CENTER", "UIParent", "CENTER", 0, 120 }
  local point = addon.GetCombatMarkerAnchorPoint and addon:GetCombatMarkerAnchorPoint() or defaultPoint[1] or "CENTER"
  local x = tonumber(defaultPoint[4]) or 0
  local y = tonumber(defaultPoint[5]) or 120
  if addon.GetCombatMarkerOffset then
    x, y = addon:GetCombatMarkerOffset()
  elseif addon.GetCombatMarkerPoint then
    local _, _, _, px, py = addon:GetCombatMarkerPoint()
    x, y = px, py
  end
  return point, tonumber(x) or 0, tonumber(y) or 120
end

local function BuildCircleBars(size, thickness)
  local bars = {}
  local segments = 12
  local radius = math.max((size * 0.5) - (thickness * 0.85), thickness * 1.2)
  local length = math.max(thickness * 1.25, size * 0.20)
  for i = 1, segments do
    local angle = ((i - 1) / segments) * (2 * pi)
    bars[#bars + 1] = {
      length = length,
      thick = thickness,
      rotation = angle + (pi * 0.5),
      x = math.cos(angle) * radius,
      y = math.sin(angle) * radius,
    }
  end
  return bars
end

local function GetLayoutBars(symbol, size, thickness)
  local half = size * 0.5
  local diagLength = math.max(thickness, size * 0.90)
  local diamondLength = math.max(thickness, size * 0.34)
  local squareOffset = math.max(0, half - (thickness * 0.5))

  if symbol == "plus" then
    return {
      { length = size, thick = thickness, rotation = 0, x = 0, y = 0 },
      { length = size, thick = thickness, rotation = pi * 0.5, x = 0, y = 0 },
    }
  elseif symbol == "diamond" then
    local edgeInset = math.max(thickness * 0.9, size * 0.16)
    return {
      { length = diamondLength, thick = thickness, rotation = pi * 0.25, x = 0, y = half - edgeInset },
      { length = diamondLength, thick = thickness, rotation = -pi * 0.25, x = half - edgeInset, y = 0 },
      { length = diamondLength, thick = thickness, rotation = pi * 0.25, x = 0, y = -(half - edgeInset) },
      { length = diamondLength, thick = thickness, rotation = -pi * 0.25, x = -(half - edgeInset), y = 0 },
    }
  elseif symbol == "square" then
    return {
      { length = size, thick = thickness, rotation = 0, x = 0, y = squareOffset },
      { length = size, thick = thickness, rotation = 0, x = 0, y = -squareOffset },
      { length = size, thick = thickness, rotation = pi * 0.5, x = -squareOffset, y = 0 },
      { length = size, thick = thickness, rotation = pi * 0.5, x = squareOffset, y = 0 },
    }
  elseif symbol == "circle" then
    return BuildCircleBars(size, thickness)
  end

  return {
    { length = diagLength, thick = thickness, rotation = pi * 0.25, x = 0, y = 0 },
    { length = diagLength, thick = thickness, rotation = -pi * 0.25, x = 0, y = 0 },
  }
end

local function EnsureMarkerBars(frame)
  frame.borderBars = frame.borderBars or {}
  frame.fillBars = frame.fillBars or {}
  for i = 1, MAX_BARS do
    if not frame.borderBars[i] then
      frame.borderBars[i] = frame:CreateTexture(nil, "BACKGROUND")
      frame.borderBars[i]:Hide()
    end
    if not frame.fillBars[i] then
      frame.fillBars[i] = frame:CreateTexture(nil, "OVERLAY")
      frame.fillBars[i]:Hide()
    end
  end
end

local function EnsureMarkerFrame(frame, parent, strata, level)
  if frame then
    EnsureMarkerBars(frame)
    return frame
  end

  frame = API.CreateFrame("Frame", nil, parent or UIParent)
  frame:SetSize(C.COMBAT_MARKER_DEFAULT_SIZE or 40, C.COMBAT_MARKER_DEFAULT_SIZE or 40)
  frame:SetFrameStrata(strata or (C.STRATA_TOOLTIP or "TOOLTIP"))
  frame:SetFrameLevel(level or ((C.ACTION_TRACKER_MARKER_FRAME_LEVEL or 50) + COMBAT_MARKER_LEVEL_OFFSET))
  frame:SetIgnoreParentScale(true)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(false)
  frame:Hide()
  EnsureMarkerBars(frame)
  return frame
end

local function CombatMarkerDragOnUpdate(selfFrame)
  if selfFrame and selfFrame._isDragging and addon.SyncActiveCombatMarkerDragPosition then
    addon:SyncActiveCombatMarkerDragPosition()
  end
end

local function ApplyMarkerStyleToFrame(frame)
  if not frame then return end

  local size = addon.GetCombatMarkerSize and addon:GetCombatMarkerSize() or (C.COMBAT_MARKER_DEFAULT_SIZE or 40)
  local thickness = addon.GetCombatMarkerThickness and addon:GetCombatMarkerThickness() or (C.COMBAT_MARKER_DEFAULT_THICKNESS or 4)
  local borderSize = addon.GetCombatMarkerBorderSize and addon:GetCombatMarkerBorderSize() or (C.COMBAT_MARKER_DEFAULT_BORDER_SIZE or 2)
  local alpha = addon.GetCombatMarkerAlpha and addon:GetCombatMarkerAlpha() or (C.COMBAT_MARKER_DEFAULT_ALPHA or 0.85)
  local symbol = addon.GetCombatMarkerSymbol and addon:GetCombatMarkerSymbol() or (C.COMBAT_MARKER_DEFAULT_SYMBOL or "x")
  local r, g, b = GetResolvedMarkerColor()

  size = Clamp(tonumber(size) or 40, C.COMBAT_MARKER_MIN_SIZE or 16, C.COMBAT_MARKER_MAX_SIZE or 128)
  thickness = Clamp(tonumber(thickness) or 4, C.COMBAT_MARKER_MIN_THICKNESS or 1, C.COMBAT_MARKER_MAX_THICKNESS or 12)
  borderSize = Clamp(tonumber(borderSize) or 2, C.COMBAT_MARKER_MIN_BORDER_SIZE or 0, C.COMBAT_MARKER_MAX_BORDER_SIZE or 8)
  alpha = Clamp(tonumber(alpha) or 0.85, 0.05, 1.00)

  local styleSig = table.concat({
    tostring(symbol), tostring(size), tostring(thickness), tostring(borderSize),
    string.format("%.3f", alpha),
    string.format("%.3f", r or 1), string.format("%.3f", g or 1), string.format("%.3f", b or 1),
  }, "|")
  if frame._combatMarkerStyleSig == styleSig then
    return
  end
  frame._combatMarkerStyleSig = styleSig

  frame:SetSize(PixelSnap(size, frame), PixelSnap(size, frame))
  frame:SetAlpha(1)

  local bars = GetLayoutBars(symbol, size, thickness)
  for i = 1, MAX_BARS do
    local fill = frame.fillBars[i]
    local border = frame.borderBars[i]
    local bar = bars[i]
    if bar then
      local borderThick = math.max(bar.thick, bar.thick + (borderSize * 2))
      local borderLength = bar.length + (borderSize * 2)
      if borderSize > 0 then
        SetTextureBar(border, frame, borderLength, borderThick, bar.rotation, bar.x, bar.y, 0, 0, 0, math.min(1, alpha * 0.95), "BACKGROUND", i)
      else
        HideTexture(border)
      end
      SetTextureBar(fill, frame, bar.length, bar.thick, bar.rotation, bar.x, bar.y, r, g, b, alpha, "OVERLAY", i)
    else
      HideTexture(fill)
      HideTexture(border)
    end
  end
end

local function ApplyMarkerPointToFrame(frame, parent, point, x, y)
  if not frame then return end
  parent = parent or UIParent
  x, y = ClampCanonicalOffsets(frame, parent, x, y)
  local px = ParentUnitsFromCanonical(x, parent)
  local py = ParentUnitsFromCanonical(y, parent)

  if uiShared.SetPointIfChanged then
    uiShared.SetPointIfChanged(frame, point, parent, "CENTER", px, py)
  else
    frame:ClearAllPoints()
    frame:SetPoint(point, parent, "CENTER", px, py)
  end
end


local function IsEditingPlayerTrackerTab()
  if not addon._editingOptions then return false end
  local settingsWindow = addon.settingsWindow
  if not (settingsWindow and settingsWindow.GetSelectedTopTab) then return true end
  return settingsWindow:GetSelectedTopTab() == "PlayerTracker"
end

local function GetLiveActionTrackerStrataAndLevel(self)
  local ui = self and self.ui
  if ui and ui.GetFrameStrata then
    local strata = ui:GetFrameStrata()
    if strata and strata ~= "" then
      return strata, math.max(0, (ui:GetFrameLevel() or 0) + COMBAT_MARKER_LEVEL_OFFSET)
    end
  end

  local strata = (self and self.GetStrata and self:GetStrata()) or (C.DEFAULT_COMBAT_TRACKER_STRATA or C.STRATA_MEDIUM or "MEDIUM")
  return strata, (C.ACTION_TRACKER_MARKER_FRAME_LEVEL or 50) + COMBAT_MARKER_LEVEL_OFFSET
end

function UI:ApplyCombatMarkerStrata(frame)
  frame = frame or addon.combatMarkerFrame
  if not frame then return end

  local strata, level = GetLiveActionTrackerStrataAndLevel(self)
  frame:SetFrameStrata(strata)
  frame:SetFrameLevel(level)
end

function UI:EnsureCombatMarker()
  local strata, level = GetLiveActionTrackerStrataAndLevel(self)
  addon.combatMarkerFrame = EnsureMarkerFrame(addon.combatMarkerFrame, UIParent, strata, level)
  addon.playerTrackerFrame = addon.combatMarkerFrame
  if addon.combatMarkerFrame and not addon.combatMarkerFrame._gseMarkerDragScripts then
    local frame = addon.combatMarkerFrame
    frame._gseMarkerDragScripts = true
    frame:SetScript("OnMouseDown", function(selfFrame, button)
      if button ~= "LeftButton" then return end
      if not (addon.CanDragCombatMarker and addon:CanDragCombatMarker()) then return end
      addon:BeginCombatMarkerDrag(selfFrame)
    end)
    frame:SetScript("OnMouseUp", function(selfFrame, button)
      if button ~= "LeftButton" then return end
      if selfFrame._isDragging and addon.EndCombatMarkerDrag then
        addon:EndCombatMarkerDrag(true)
      end
    end)
    frame:SetScript("OnHide", function(selfFrame)
      if selfFrame._isDragging and addon.EndCombatMarkerDrag then
        addon:EndCombatMarkerDrag(false)
      end
    end)
  end
  self:ApplyCombatMarkerStrata(addon.combatMarkerFrame)
  return addon.combatMarkerFrame
end

function UI:ApplyCombatMarkerStyle(frame)
  ApplyMarkerStyleToFrame(frame or self:EnsureCombatMarker())
end

function UI:ApplyCombatMarkerPosition(frame, parent, point, x, y)
  frame = frame or self:EnsureCombatMarker()
  if not frame then return end
  if point == nil then
    point, x, y = GetCenteredAnchorConfig()
  end
  ApplyMarkerPointToFrame(frame, parent or UIParent, point, x, y)
end

function UI:LayoutCombatMarkerPreview()
  self:RefreshCombatMarker(true)
end

function UI:HideCombatMarkerPreview()
end

function UI:BeginCombatMarkerDrag(frame)
  frame = frame or addon.combatMarkerFrame
  if not frame then return false end
  if frame._isDragging then return true end
  if not self:CanDragCombatMarker() then return false end

  local point = addon.GetCombatMarkerAnchorPoint and addon:GetCombatMarkerAnchorPoint() or ((C.COMBAT_MARKER_DEFAULT_POINT and C.COMBAT_MARKER_DEFAULT_POINT[1]) or "CENTER")
  local x, y = addon:GetCombatMarkerOffset()
  self._combatMarkerDragOrigin = { point, x, y }
  self._combatMarkerDragCursorOriginX, self._combatMarkerDragCursorOriginY = GetCursorPositionInParentSpace(UIParent)
  frame._isDragging = true
  frame:SetScript("OnUpdate", CombatMarkerDragOnUpdate)
  self:SyncActiveCombatMarkerDragPosition()
  return true
end

function UI:EndCombatMarkerDrag(commit)
  local frame = addon.combatMarkerFrame
  if not (frame and frame._isDragging) then return false end

  if commit then
    self:SyncActiveCombatMarkerDragPosition()
  else
    local origin = self._combatMarkerDragOrigin
    if origin then
      addon:SetCombatMarkerPoint(origin[1], C.UI_PARENT_NAME or "UIParent", C.ANCHOR_CENTER or "CENTER", origin[2], origin[3])
      self:ApplyCombatMarkerPosition(frame, UIParent, origin[1], origin[2], origin[3])
    end
  end

  frame._isDragging = false
  frame:SetScript("OnUpdate", nil)
  self._combatMarkerDragOrigin = nil
  self._combatMarkerDragCursorOriginX = nil
  self._combatMarkerDragCursorOriginY = nil

  local settingsWindow = addon.settingsWindow
  if settingsWindow and settingsWindow.RefreshCombatMarkerControls then
    settingsWindow:RefreshCombatMarkerControls()
  end
  self:RefreshCombatMarkerDragMouseState()
  return true
end

function UI:CanDragCombatMarker()
  local frame = addon and addon.combatMarkerFrame
  if not frame then return false end
  if not (addon.IsCombatMarkerEnabled and addon:IsCombatMarkerEnabled()) then return false end
  if addon.GetCombatMarkerLocked and addon:GetCombatMarkerLocked() then return false end
  if not IsEditingPlayerTrackerTab() then return false end
  if API.InCombatLockdown and API.InCombatLockdown() then return false end
  return frame:IsShown() and true or false
end

function UI:RefreshCombatMarkerDragMouseState()
  local frame = addon and addon.combatMarkerFrame
  if frame then
    local canDrag = self:CanDragCombatMarker()
    if (not canDrag) and frame._isDragging then
      self:EndCombatMarkerDrag(true)
      return
    end
    frame._canDragCombatMarker = canDrag
    frame:EnableMouse(canDrag)
  end
end

function UI:SyncActiveCombatMarkerDragPosition()
  local frame = addon and addon.combatMarkerFrame
  if not (frame and frame._isDragging) then return false end

  local origin = self._combatMarkerDragOrigin
  local startCursorX = self._combatMarkerDragCursorOriginX
  local startCursorY = self._combatMarkerDragCursorOriginY

  local point = addon.GetCombatMarkerAnchorPoint and addon:GetCombatMarkerAnchorPoint() or ((C.COMBAT_MARKER_DEFAULT_POINT and C.COMBAT_MARKER_DEFAULT_POINT[1]) or "CENTER")
  local x, y
  if origin and startCursorX ~= nil and startCursorY ~= nil then
    local cursorX, cursorY = GetCursorPositionInParentSpace(UIParent)
    x = (tonumber(origin[2]) or 0) + ParentUnitsToCanonical(cursorX - startCursorX, UIParent)
    y = (tonumber(origin[3]) or 0) + ParentUnitsToCanonical(cursorY - startCursorY, UIParent)
  else
    x, y = addon:GetCombatMarkerOffset()
  end

  x, y = ClampCanonicalOffsets(frame, UIParent, x, y)
  addon:SetCombatMarkerPoint(point, C.UI_PARENT_NAME or "UIParent", C.ANCHOR_CENTER or "CENTER", x, y)
  self:ApplyCombatMarkerPosition(frame, UIParent, point, x, y)

  local settingsWindow = addon.settingsWindow
  if settingsWindow and settingsWindow.RefreshCombatMarkerControls then
    settingsWindow:RefreshCombatMarkerControls()
  end
  return true
end

function UI:ShouldShowCombatMarker(forceOverride)
  if not (addon.IsCombatMarkerEnabled and addon:IsCombatMarkerEnabled()) then
    return false
  end

  local editingOverride = (forceOverride == true)
    or IsEditingPlayerTrackerTab()

  local showWhen = (addon.GetCombatMarkerShowWhen and addon:GetCombatMarkerShowWhen())
    or (C.COMBAT_MARKER_DEFAULT_SHOW_WHEN or (C.MODE_IN_COMBAT or "InCombat"))

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

function UI:RefreshCombatMarker(force)
  local frame = self:EnsureCombatMarker()
  if not frame then return end

  self:ApplyCombatMarkerStyle(frame)
  self:ApplyCombatMarkerPosition(frame)

  if self:ShouldShowCombatMarker(force) then
    frame:Show()
  else
    frame:Hide()
  end
  self:RefreshCombatMarkerDragMouseState()
end

function UI:ApplyPlayerTrackerStrata(frame)
  return self:ApplyCombatMarkerStrata(frame)
end

function UI:EnsurePlayerTracker()
  return self:EnsureCombatMarker()
end

function UI:ApplyPlayerTrackerStyle(frame)
  return self:ApplyCombatMarkerStyle(frame)
end

function UI:ApplyPlayerTrackerPosition(frame, parent, point, x, y)
  return self:ApplyCombatMarkerPosition(frame, parent, point, x, y)
end

function UI:LayoutPlayerTrackerPreview()
  return self:LayoutCombatMarkerPreview()
end

function UI:HidePlayerTrackerPreview()
  return self:HideCombatMarkerPreview()
end

function UI:BeginPlayerTrackerDrag(frame)
  return self:BeginCombatMarkerDrag(frame)
end

function UI:EndPlayerTrackerDrag(commit)
  return self:EndCombatMarkerDrag(commit)
end

function UI:CanDragPlayerTracker()
  return self:CanDragCombatMarker()
end

function UI:RefreshPlayerTrackerDragMouseState()
  return self:RefreshCombatMarkerDragMouseState()
end

function UI:SyncActivePlayerTrackerDragPosition()
  return self:SyncActiveCombatMarkerDragPosition()
end

function UI:ShouldShowPlayerTracker(forceOverride)
  return self:ShouldShowCombatMarker(forceOverride)
end

function UI:RefreshPlayerTracker(force)
  return self:RefreshCombatMarker(force)
end
