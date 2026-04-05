local _, ns = ...
local addon = ns
local UI = ns.UI
local API = (ns.Utils and ns.Utils.API) or {}
addon._ui = addon._ui or {}
local uiShared = addon._ui
local C = (ns.Utils and ns.Utils.Constants) or addon.Constants or {}
local SV = (ns.Utils and ns.Utils.SV) or nil

local function Clamp(v, lo, hi)
  return uiShared.Clamp(v, lo, hi)
end

local function EnsureDB()
  return uiShared.EnsureDB()
end

local function PixelSnap(v, frame)
  return uiShared.PixelSnap(v, frame)
end

local function IconRowWidth(count)
  return uiShared.IconRowWidth(count)
end

local function SetFramePointIfChanged(frame, point, anchor, relativePoint, x, y)
  return uiShared.SetPointIfChanged(frame, point, anchor, relativePoint, x, y)
end

local function IsCanonicalActionTrackerPoint(point, relName, relPoint)
  return point == (C.ANCHOR_CENTER or "CENTER")
    and relName == (C.UI_PARENT_NAME or "UIParent")
    and relPoint == (C.ANCHOR_CENTER or "CENTER")
end

local function GetCenteredOffsets(frame, parent)
  if uiShared.GetCenteredOffsets then
    return uiShared.GetCenteredOffsets(frame, parent)
  end
  return 0, 0
end

local function ApplyCenteredOffsets(frame, parent, x, y)
  if uiShared.ApplyCenteredOffsets then
    return uiShared.ApplyCenteredOffsets(frame, parent, x, y)
  end
  x = PixelSnap(x, parent)
  y = PixelSnap(y, parent)
  SetFramePointIfChanged(frame, "CENTER", parent, "CENTER", x, y)
  return x, y
end

local function ClampCenteredOffsetsToScreen(frame, parent, x, y)
  if uiShared.ClampCenteredOffsetsToScreen then
    return uiShared.ClampCenteredOffsetsToScreen(frame, parent, x, y)
  end
  return PixelSnap(x, parent), PixelSnap(y, parent)
end

local function ParentUnitsToCanonicalPixels(value, parent)
  if uiShared.ParentUnitsToCanonicalPixels then
    return uiShared.ParentUnitsToCanonicalPixels(value, parent)
  end
  return tonumber(value) or 0
end

local function SetTextureInsetsIfChanged(texture, owner, inset)
  if not (texture and owner) then return end
  if texture._gsetrackerInset == inset then return end
  texture._gsetrackerInset = inset
  texture:ClearAllPoints()
  texture:SetPoint("TOPLEFT", owner, "TOPLEFT", inset, -inset)
  texture:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", -inset, inset)
end

local function EnsureActionTrackerRowRelativeAnchorFrames(ui)
  if not (ui and ui.content) then return nil end
  ui.elementAnchors = ui.elementAnchors or {}
  local names = { "sequenceText", "modifiersText", "keybindText", "pressedIndicator" }
  for _, name in ipairs(names) do
    if not ui.elementAnchors[name] then
      local anchor = API.CreateFrame("Frame", nil, ui.content)
      anchor:SetSize(1, 1)
      ui.elementAnchors[name] = anchor
    end
  end
  return ui.elementAnchors
end

local function GetActionTrackerRowRelativeBaselineOffsets(ui)
  local pressedSize = tonumber(ui and ui.pressedIndicator and ui.pressedIndicator.GetWidth and ui.pressedIndicator:GetWidth()) or 0
  return {
    sequenceText = { x = 0, y = 17 },
    modifiersText = { x = 0, y = -15 },
    keybindText = { x = 0, y = 27 },
    pressedIndicator = { x = (pressedSize * 0.5) + 8, y = 0, point = "CENTER", relativePoint = "RIGHT" },
  }
end

local function UpdateActionTrackerRowRelativeAnchors(ui)
  if not (ui and ui.content and ui.iconHolder) then return end
  local anchors = EnsureActionTrackerRowRelativeAnchorFrames(ui)
  if not anchors then return end
  local baselines = GetActionTrackerRowRelativeBaselineOffsets(ui)
  for elementName, cfg in pairs(baselines) do
    local anchor = anchors[elementName]
    if anchor then
      local point = cfg.point or "CENTER"
      local relativePoint = cfg.relativePoint or "CENTER"
      SetFramePointIfChanged(anchor, point, ui.iconHolder, relativePoint, PixelSnap(cfg.x or 0, ui), PixelSnap(cfg.y or 0, ui))
    end
  end
end

local function UpdateActionTrackerIconRowAnchor(ui)
  if not (ui and ui.content and ui.iconHolder) then return end
  SetFramePointIfChanged(ui.iconHolder, "CENTER", ui.content, "CENTER", 0, 0)
  UpdateActionTrackerRowRelativeAnchors(ui)
end

local function UpdateActionTrackerContentFrame(ui)
  if not (ui and ui.content) then return end
  local innerW = math.max(1, (ui:GetWidth() or 0) - ((uiShared.PAD_X or 0) * 2))
  local innerH = math.max(1, (ui:GetHeight() or 0) - ((uiShared.PAD_TOP or 0) + (uiShared.PAD_BOTTOM or 0)))
  ui.content:ClearAllPoints()
  ui.content:SetSize(PixelSnap(innerW, ui), PixelSnap(innerH, ui))
  ui.content:SetPoint("CENTER", ui, "CENTER", 0, 0)
  UpdateActionTrackerIconRowAnchor(ui)
end

local function ActionTrackerDragOnUpdate(frame)
  if frame and frame._isDragging and addon.SyncActiveActionTrackerDragPosition then
    addon:SyncActiveActionTrackerDragPosition()
  end
end

function UI:GetClassColorRGB()
  return uiShared.GetPlayerClassColorRGB(C.CLASS_FALLBACK_R or 0.20, C.CLASS_FALLBACK_G or 0.60, C.CLASS_FALLBACK_B or 1.00)
end

function UI:EnsureActionTrackerMoveMarker()
  if self._actionTrackerMoveMarker then return self._actionTrackerMoveMarker end
  local marker = API.CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  marker:SetSize(C.ACTION_TRACKER_MARKER_BASE_SIZE or 48, C.ACTION_TRACKER_MARKER_BASE_SIZE or 48)
  marker:SetFrameStrata(C.STRATA_TOOLTIP or "TOOLTIP")
  marker:SetFrameLevel(C.ACTION_TRACKER_MARKER_FRAME_LEVEL or 50)
  marker:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 2,
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
  })
  local glow = marker:CreateTexture(nil, "BACKGROUND")
  glow:SetPoint("TOPLEFT", marker, "TOPLEFT", -6, 6)
  glow:SetPoint("BOTTOMRIGHT", marker, "BOTTOMRIGHT", 6, -6)
  glow:SetTexture("Interface\\Buttons\\WHITE8x8")
  marker.glow = glow
  local crossH = marker:CreateTexture(nil, "ARTWORK")
  crossH:SetTexture("Interface\\Buttons\\WHITE8x8")
  crossH:SetHeight(2)
  crossH:SetPoint("LEFT", marker, "LEFT", 6, 0)
  crossH:SetPoint("RIGHT", marker, "RIGHT", -6, 0)
  marker.crossH = crossH
  local crossV = marker:CreateTexture(nil, "ARTWORK")
  crossV:SetTexture("Interface\\Buttons\\WHITE8x8")
  crossV:SetWidth(2)
  crossV:SetPoint("TOP", marker, "TOP", 0, -6)
  crossV:SetPoint("BOTTOM", marker, "BOTTOM", 0, 6)
  marker.crossV = crossV
  marker:Hide()
  self._actionTrackerMoveMarker = marker
  return marker
end

function UI:UpdateActionTrackerMoveMarker()
  local marker = self:EnsureActionTrackerMoveMarker()
  EnsureDB()
  if not addon._editingOptions or self:IsLocked() then
    marker:Hide()
    return
  end

  local r, g, b = self:GetClassColorRGB()
  local ui = self.ui

  marker:ClearAllPoints()
  if ui then
    local markerTarget = ui.content or ui
    if marker:GetParent() ~= markerTarget then
      marker:SetParent(markerTarget)
    end
    marker:SetFrameStrata(ui:GetFrameStrata() or (C.STRATA_TOOLTIP or "TOOLTIP"))
    marker:SetFrameLevel((ui:GetFrameLevel() or 0) + 20)
    marker:SetAllPoints(markerTarget)
  else
    if marker:GetParent() ~= UIParent then
      marker:SetParent(UIParent)
    end
    marker:SetFrameStrata(C.STRATA_TOOLTIP or "TOOLTIP")
    marker:SetFrameLevel(C.ACTION_TRACKER_MARKER_FRAME_LEVEL or 50)
    local x, y = self:GetActionTrackerOffset()
    marker:SetSize(C.ACTION_TRACKER_MARKER_BASE_SIZE or 48, C.ACTION_TRACKER_MARKER_BASE_SIZE or 48)
    SetFramePointIfChanged(marker, "CENTER", UIParent, "CENTER", x, y)
  end
  marker:SetBackdropColor(r, g, b, C.ALPHA_SOFT or 0.10)
  marker:SetBackdropBorderColor(r, g, b, C.ALPHA_STRONG or 0.95)
  marker.glow:SetVertexColor(r, g, b, C.ALPHA_GLOW or 0.18)
  marker.crossH:SetVertexColor(r, g, b, C.ALPHA_STRONG or 0.95)
  marker.crossV:SetVertexColor(r, g, b, C.ALPHA_STRONG or 0.95)
  marker:Show()
end

function UI:HideActionTrackerMoveMarker()
  if self._actionTrackerMoveMarker then self._actionTrackerMoveMarker:Hide() end
end

function UI:UpdateActionTrackerIconRowAnchor()
  UpdateActionTrackerIconRowAnchor(self.ui)
end

function UI:UpdateActionTrackerRowRelativeAnchors()
  UpdateActionTrackerRowRelativeAnchors(self.ui)
end

local function ResolveActionTrackerCenteredOffsets(self)
  local ui = self.ui
  local point, relName, relPoint, rawX, rawY = self:GetActionTrackerPoint()
  rawX = tonumber(rawX) or 0
  rawY = tonumber(rawY) or 0

  if IsCanonicalActionTrackerPoint(point, relName, relPoint) then
    if ui then
      return ClampCenteredOffsetsToScreen(ui, UIParent, rawX, rawY)
    end
    return rawX, rawY
  end

  -- Legacy non-canonical anchor: convert to CENTER/UIParent/CENTER once.
  if not ui then
    return rawX, rawY
  end

  local anchor = (_G[relName] or UIParent)
  SetFramePointIfChanged(ui, point, anchor, relPoint, rawX, rawY)

  local nx, ny = GetCenteredOffsets(ui, UIParent)
  -- Persist the migration so it only happens once.
  self:SetActionTrackerPoint(C.ANCHOR_CENTER or "CENTER", C.UI_PARENT_NAME or "UIParent", C.ANCHOR_CENTER or "CENTER", nx, ny)
  return nx, ny
end

function UI:GetActionTrackerOffset()
  EnsureDB()
  -- Read-only: return saved canonical values without writing back.
  local point, relName, relPoint, rawX, rawY = self:GetActionTrackerPoint()
  rawX = tonumber(rawX) or 0
  rawY = tonumber(rawY) or 0
  if IsCanonicalActionTrackerPoint(point, relName, relPoint) then
    return rawX, rawY
  end
  -- Non-canonical legacy path: compute equivalent offset without persisting.
  if not self.ui then return rawX, rawY end
  local anchor = (_G[relName] or UIParent)
  SetFramePointIfChanged(self.ui, point, anchor, relPoint, rawX, rawY)
  return GetCenteredOffsets(self.ui, UIParent)
end

function UI:ApplyActionTrackerPosition()
  if not self.ui then return end
  EnsureDB()
  local x, y = ResolveActionTrackerCenteredOffsets(self)
  ApplyCenteredOffsets(self.ui, UIParent, x, y)
  self:UpdateActionTrackerMoveMarker()
end

function UI:SetActionTrackerOffset(x, y)
  EnsureDB()
  if self:IsLocked() then return end
  local nx, ny = self:GetActionTrackerOffset()
  if x ~= nil then nx = x end
  if y ~= nil then ny = y end
  self:SetActionTrackerPoint(C.ANCHOR_CENTER or "CENTER", C.UI_PARENT_NAME or "UIParent", C.ANCHOR_CENTER or "CENTER", nx, ny)
  self:ApplyActionTrackerPosition()
  self:RefreshSettingsPositionDisplay()
  self:UpdateActionTrackerMoveMarker()
end

function UI:ApplyStrata()
  local ui = self.ui
  if not ui then return end
  ui:SetFrameStrata(self:GetStrata())
  if self.ApplyCombatMarkerStrata then
    self:ApplyCombatMarkerStrata()
  end
end

function UI:ApplyFontFaces()
  EnsureDB()
  if not (self.ui and self.ui.nameText and self.ui.modShift) then
    self._pendingFontApply = true
    return
  end

  if self.EnsureRowRelativeAnchorOffsetModel and self:EnsureRowRelativeAnchorOffsetModel() then
    if self.ApplyAllElementPositions then
      self:ApplyAllElementPositions()
    end
  end

  self._pendingFontApply = nil

  local seqName = self:GetSeqFontName()
  local modName = self:GetModFontName()
  local keybindName = self:GetKeybindFontName()
  local seqPath = (self.GetFontPathByName and self:GetFontPathByName(seqName)) or STANDARD_TEXT_FONT
  local modPath = (self.GetFontPathByName and self:GetFontPathByName(modName)) or STANDARD_TEXT_FONT
  local keybindPath = (self.GetFontPathByName and self:GetFontPathByName(keybindName)) or modPath or STANDARD_TEXT_FONT
  local seqSize = self:GetSeqFontSize()
  local modSize = self:GetModFontSize()
  local keybindSize = self:GetKeybindFontSize()

  local function SafeSet(fs, path, size, flags)
    if not (fs and fs.SetFont) then return end
    if not fs:SetFont(path, size, flags) then
      fs:SetFont(STANDARD_TEXT_FONT, size, flags)
    end
  end

  SafeSet(self.ui.nameText, seqPath, seqSize, "OUTLINE")
  SafeSet(self.ui.keybindText, keybindPath, keybindSize, "OUTLINE")
  SafeSet(self.ui.modShift, modPath, modSize, "OUTLINE")
  SafeSet(self.ui.modAlt,   modPath, modSize, "OUTLINE")
  SafeSet(self.ui.modCtrl,  modPath, modSize, "OUTLINE")
  if self._ResizeToContent then self:_ResizeToContent() end
end

function UI:GetBorderThickness()
  if ns.Utils and ns.Utils.GetBorderThickness then
    return ns.Utils:GetBorderThickness()
  end
  EnsureDB()
  return Clamp(tonumber(C.DEFAULT_BORDER_THICKNESS) or 1, 0, 5)
end

function UI:ApplyBorderThickness()
  if not self.ui then return end
  local thickness = self:GetBorderThickness()
  local showBorder = self:IsBorderEnabled()
  local edgeSize = math.max(1, thickness > 0 and thickness or 1)
  local borderR, borderG, borderB
  if self.GetActionTrackerUseClassColor and self:GetActionTrackerUseClassColor() then
    borderR, borderG, borderB = self:GetClassColorRGB()
  elseif self.GetActionTrackerBorderColor then
    borderR, borderG, borderB = self:GetActionTrackerBorderColor()
  else
    borderR, borderG, borderB = 0, 0, 0
  end

  if self.ui.SetBackdrop then
    self.ui:SetBackdrop({
      bgFile   = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = 1,
      insets   = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    self.ui:SetBackdropColor(0, 0, 0, 0)
    self.ui:SetBackdropBorderColor(0, 0, 0, 0)
  end

  local icons = self.ui.icons or {}
  for _, icon in ipairs(icons) do
    if icon and icon.SetBackdrop then
      icon:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = edgeSize,
        insets   = { left = edgeSize, right = edgeSize, top = edgeSize, bottom = edgeSize }
      })
      icon:SetBackdropColor(0, 0, 0, 0)
      if icon.tex then
        SetTextureInsetsIfChanged(icon.tex, icon, thickness)
      end
      if showBorder then
        icon:SetBackdropBorderColor(borderR or 0, borderG or 0, borderB or 0, 1)
      else
        icon:SetBackdropBorderColor(0, 0, 0, 0)
      end
    end
  end
end

function UI:ApplyScale()
  if not self.ui then return end
  self.ui:SetScale(self:GetDesiredScale())
  self:_ResizeToContent()
  self:_AlignModsToIcons()
  self:UpdateActionTrackerMoveMarker()
end

local function GetCursorPositionInParentSpace(parent)
  parent = parent or UIParent
  local scale = (parent.GetEffectiveScale and parent:GetEffectiveScale()) or 1
  if not scale or scale == 0 then scale = 1 end
  local cursorX, cursorY = API.GetCursorPosition()
  return (tonumber(cursorX) or 0) / scale, (tonumber(cursorY) or 0) / scale
end

local function SyncRuntimeActionTrackerPointCache(ui, x, y)
  if not ui then return end
  local appliedX = uiShared.CanonicalPixelsToParentUnits and uiShared.CanonicalPixelsToParentUnits(x, UIParent) or (tonumber(x) or 0)
  local appliedY = uiShared.CanonicalPixelsToParentUnits and uiShared.CanonicalPixelsToParentUnits(y, UIParent) or (tonumber(y) or 0)
  ui._gsetrackerPoint = C.ANCHOR_CENTER or "CENTER"
  ui._gsetrackerAnchor = UIParent
  ui._gsetrackerRelativePoint = C.ANCHOR_CENTER or "CENTER"
  ui._gsetrackerPointX = appliedX
  ui._gsetrackerPointY = appliedY
end

local function CopyActionTrackerPoint(point, relName, relPoint, x, y)
  return {
    type(point) == "string" and point or (C.ANCHOR_CENTER or "CENTER"),
    type(relName) == "string" and relName or (C.UI_PARENT_NAME or "UIParent"),
    type(relPoint) == "string" and relPoint or (C.ANCHOR_CENTER or "CENTER"),
    tonumber(x) or 0,
    tonumber(y) or 0,
  }
end

function UI:RefreshSettingsPositionDisplay()
  local settingsWindow = addon.settingsWindow
  if not (settingsWindow and settingsWindow.IsShown and settingsWindow:IsShown()) then return end
  if settingsWindow.RefreshActionTrackerPositionControls then
    settingsWindow:RefreshActionTrackerPositionControls()
    return
  end
  if settingsWindow.Refresh then
    settingsWindow:Refresh()
  end
end

function UI:SyncActiveActionTrackerDragPosition()
  local frame = self.ui
  if not (frame and frame._isDragging) then return false end

  local origin = self._actionTrackerDragOrigin
  local startCursorX = self._actionTrackerDragCursorOriginX
  local startCursorY = self._actionTrackerDragCursorOriginY

  local x, y
  if origin and startCursorX ~= nil and startCursorY ~= nil then
    local cursorX, cursorY = GetCursorPositionInParentSpace(UIParent)
    x = (tonumber(origin[4]) or 0) + ParentUnitsToCanonicalPixels(cursorX - startCursorX, UIParent)
    y = (tonumber(origin[5]) or 0) + ParentUnitsToCanonicalPixels(cursorY - startCursorY, UIParent)
  else
    x, y = GetCenteredOffsets(frame, UIParent)
  end

  x, y = ClampCenteredOffsetsToScreen(frame, UIParent, x, y)
  self:SetActionTrackerPoint(C.ANCHOR_CENTER or "CENTER", C.UI_PARENT_NAME or "UIParent", C.ANCHOR_CENTER or "CENTER", x, y)
  ApplyCenteredOffsets(frame, UIParent, x, y)
  SyncRuntimeActionTrackerPointCache(frame, x, y)
  self:RefreshSettingsPositionDisplay()
  self:UpdateActionTrackerMoveMarker()
  return true
end

function UI:BeginActionTrackerDrag(frame)
  frame = frame or self.ui
  if not frame then return false end
  if frame._isDragging then return true end

  local x, y = self:GetActionTrackerOffset()
  self._actionTrackerDragOrigin = CopyActionTrackerPoint(C.ANCHOR_CENTER or "CENTER", C.UI_PARENT_NAME or "UIParent", C.ANCHOR_CENTER or "CENTER", x, y)
  self._actionTrackerDragCursorOriginX, self._actionTrackerDragCursorOriginY = GetCursorPositionInParentSpace(UIParent)
  frame._isDragging = true
  frame:SetScript("OnUpdate", ActionTrackerDragOnUpdate)
  ApplyCenteredOffsets(frame, UIParent, x, y)
  SyncRuntimeActionTrackerPointCache(frame, x, y)
  self:SyncActiveActionTrackerDragPosition()
  self:UpdateActionTrackerMoveMarker()
  return true
end

function UI:EndActionTrackerDrag(commitPosition)
  local frame = self.ui
  if not (frame and frame._isDragging) then return false end

  if frame.StopMovingOrSizing then
    frame:StopMovingOrSizing()
  end

  if commitPosition then
    self:SyncActiveActionTrackerDragPosition()
    local x, y = self:GetActionTrackerOffset()
    ApplyCenteredOffsets(frame, UIParent, x, y)
    SyncRuntimeActionTrackerPointCache(frame, x, y)
    self:RefreshSettingsPositionDisplay()
  else
    local origin = self._actionTrackerDragOrigin
    if origin then
      self:SetActionTrackerPoint(origin[1], origin[2], origin[3], origin[4], origin[5])
    end
    self:ApplyActionTrackerPosition()
  end

  frame._isDragging = false
  frame:SetScript("OnUpdate", nil)
  self._actionTrackerDragOrigin = nil
  self._actionTrackerDragCursorOriginX = nil
  self._actionTrackerDragCursorOriginY = nil
  self:RefreshDragMouseState()
  self:UpdateActionTrackerMoveMarker()
  return true
end

function UI:CanDragActionTracker()
  local ui = self.ui
  if not ui then return false end
  if not ui:IsShown() then return false end
  if self:IsLocked() then return false end
  if API.InCombatLockdown and API.InCombatLockdown() then return false end
  return true
end

function UI:RefreshDragMouseState()
  local ui = self.ui
  if not ui then return end
  EnsureDB()

  local canDrag = self:CanDragActionTracker()

  if (not canDrag) and ui._isDragging then
    self:EndActionTrackerDrag(true)
    return
  end

  ui:SetMovable(canDrag)
  ui:EnableMouse(canDrag)
  if ui.RegisterForDrag then
    if canDrag then
      ui:RegisterForDrag("LeftButton")
    else
      ui:RegisterForDrag()
    end
  end
end

function UI:Lock(locked)
  EnsureDB()
  self:SetLocked(locked)
  if self.ui then
    self:RefreshDragMouseState()
  end
  if self.ApplyEditModeIconPreview then
    self:ApplyEditModeIconPreview(true)
  end
  self:UpdateActionTrackerMoveMarker()
end

function UI:SetBorder(on)
  EnsureDB()
  self:SetBorderEnabled(on)
  if self.ApplyBorderThickness then
    self:ApplyBorderThickness()
  end
  if self.RequestUIRebuild then
    self:RequestUIRebuild("settings")
  elseif self.RebuildIcons then
    self:RebuildIcons(true)
  end
end

function UI:SetBackground(on)
  return self:SetBorder(on)
end

local STRUCTURAL_REBUILD_REASONS = {
  init = true,
  settings = true,
  iconCount = true,
}

function UI:_GetRenderSettingsSignature()
  EnsureDB()
  return table.concat({
    tostring((self.GetEditModePreviewIconCount and self:GetEditModePreviewIconCount()) or self:GetIconCount()),
    tostring(self:GetIconGap()),
    tostring(self:GetBorderThickness()),
    tostring(self:IsBorderEnabled() and 1 or 0),
    tostring(string.format("%.2f", self:GetDesiredScale() or 1)),
    tostring(self:GetShowWhen()),
  }, "|")
end

function UI:_GetDeterministicRenderSignature()
  local ui = self.ui
  if not ui then return nil end
  return table.concat({
    self:_GetRenderSettingsSignature(),
    tostring(ui._lastVisible == true),
  }, "|")
end

function UI:_CanRunStructuralRebuild(reason)
  reason = reason or self._pendingUIRebuildReason or "settings"
  if not STRUCTURAL_REBUILD_REASONS[reason] then
    return false
  end

  return true
end

function UI:RequestUIRebuild(reason)
  reason = reason or "settings"
  if not STRUCTURAL_REBUILD_REASONS[reason] then
    return false
  end

  self._pendingUIRebuild = true
  self._pendingUIRebuildReason = reason

  if self.ui and self.ApplyDeterministicRenderPipeline then
    return self:ApplyDeterministicRenderPipeline(reason)
  end

  return false
end

function UI:ApplyDeterministicRenderPipeline(reason)
  local ui = self.ui
  if not ui then return false end

  reason = reason or self._pendingUIRebuildReason or "settings"
  if not self:_CanRunStructuralRebuild(reason) then
    return false
  end

  local renderSig = self:_GetDeterministicRenderSignature()
  if (not self._pendingUIRebuild) and ui._lastRenderPipelineSig == renderSig then
    return false
  end

  ui._lastRenderPipelineSig = renderSig
  self._pendingUIRebuild = nil
  self._pendingUIRebuildReason = nil

  if self.RebuildIcons then
    return self:RebuildIcons(true)
  end

  return false
end

function UI:ResetToDefaults()
  if SV and SV.ResetToDefaults then
    GSETrackerDB = SV:ResetToDefaults({ colors = true })
  else
    GSETrackerDB = EnsureDB()
  end

  EnsureDB()

  local ui = self.ui
  if not ui then return end

  if ui._isDragging then
    self:EndActionTrackerDrag(false)
  end

  self._pendingUIRebuild = nil
  self._pendingUIRebuildReason = nil
  ui._lastRenderPipelineSig = nil

  self:ApplyScale()
  self:ApplyStrata()
  self:ApplyFontFaces()
  self:ApplyBorderThickness()
  self:ApplyActionTrackerPosition()
  self:Lock(self:IsLocked())

  self:RequestUIRebuild("settings")
  if self.ApplyDeterministicRenderPipeline then
    self:ApplyDeterministicRenderPipeline("settings")
  end

  self:ApplyAllElementPositions()
  self:ApplyVisibility()
  self:ClearSpellHistory()
  self:RefreshDragMouseState()
  self:UpdateActionTrackerMoveMarker()
  if self.RefreshMinimapButton then
    self:RefreshMinimapButton()
  end
end

function UI:_AlignModsToIcons()
  local ui = self.ui
  if not (ui and ui.modifiersFrame) then return end
  local function PS(v) return PixelSnap(v, ui) end
  local xAlt   = PS(-(uiShared.MOD_FIXED_X_SPACING) + (uiShared.MOD_ALT_X_NUDGE or 0))
  local xShift = PS(0 + (uiShared.MOD_SHIFT_X_NUDGE or 0))
  local xCtrl  = PS((uiShared.MOD_FIXED_X_SPACING) + (uiShared.MOD_CTRL_X_NUDGE or 0))
  ui.modifiersFrame:SetSize(PS(uiShared.TEXT_W), PS(uiShared.MODS_H))
  ui.modAlt:ClearAllPoints(); ui.modAlt:SetPoint("CENTER", ui.modifiersFrame, "CENTER", xAlt, 0)
  ui.modShift:ClearAllPoints(); ui.modShift:SetPoint("CENTER", ui.modifiersFrame, "CENTER", xShift, 0)
  ui.modCtrl:ClearAllPoints(); ui.modCtrl:SetPoint("CENTER", ui.modifiersFrame, "CENTER", xCtrl, 0)
end

function UI:_ResizeToContent()
  local ui = self.ui
  if not ui then return end
  local function PS(v) return PixelSnap(v, ui) end
  local count = (self.GetEditModePreviewIconCount and self:GetEditModePreviewIconCount()) or self:GetIconCount()
  local nameW = (ui.nameText:GetStringWidth() or 0) + uiShared.PAD_X * 2
  local keybindW = (ui.keybindText and ui.keybindText:GetStringWidth() or 0) + uiShared.PAD_X * 2
  local iconW = IconRowWidth(count) + uiShared.PAD_X * 2
  local stableTextW = math.max(nameW, keybindW, uiShared.TEXT_W + uiShared.PAD_X * 2)
  ui._stableTextWidth = math.max(ui._stableTextWidth or 0, stableTextW)
  local w = Clamp(math.max(ui._stableTextWidth or stableTextW, iconW, uiShared.MIN_W), uiShared.MIN_W, uiShared.MAX_W)
  local innerW = PS(w - (uiShared.PAD_X * 2))
  local frameW = PS(w)
  local h = uiShared.PAD_TOP + uiShared.NAME_H + uiShared.GAP_NAME_ICONS + uiShared.ICON_SIZE + uiShared.GAP_ICONS_MODS + uiShared.MODS_H + uiShared.PAD_BOTTOM
  local frameH = PS(h)

  local sizeSig = table.concat({ tostring(innerW), tostring(frameW), tostring(frameH), tostring(count), tostring(ui._stableTextWidth or stableTextW) }, "|")
  local changed = ui._lastResizeSig ~= sizeSig
  ui._lastResizeSig = sizeSig

  if changed then
    if ui.sequenceTextFrame then ui.sequenceTextFrame:SetSize(innerW, PS(uiShared.NAME_H)) end
    if ui.keybindFrame then ui.keybindFrame:SetSize(innerW, PS(uiShared.NAME_H)) end
    if ui.modifiersFrame then ui.modifiersFrame:SetSize(innerW, PS(uiShared.MODS_H)) end
    ui:SetSize(frameW, frameH)
    UpdateActionTrackerContentFrame(ui)
  end

  UpdateActionTrackerIconRowAnchor(ui)

  if changed then
    self:ApplyAllElementPositions()
    self:UpdateActionTrackerMoveMarker()
  end
end

function UI:BuildMainFrame()
  if self.ui then return end
  EnsureDB()

  local ui = _G.GSE_TrackerFrame
  if ui then
    self.ui = ui
    return
  end

  ui = API.CreateFrame("Frame", "GSE_TrackerFrame", UIParent, "BackdropTemplate")
  self.ui = ui

  ui:SetScale(self:GetDesiredScale())
  ui:SetFrameStrata(self:GetStrata())
  ui:SetClampedToScreen(true)
  ui:SetMovable(true)
  ui:EnableMouse(true)

  ui._combatState = false

  ui:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = math.max(1, (addon:GetBorderThickness() or 0) > 0 and addon:GetBorderThickness() or 1),
    insets   = { left = 0, right = 0, top = 0, bottom = 0 }
  })

  ui:SetBackdropColor(0, 0, 0, 0)
  ui:SetBackdropBorderColor(0, 0, 0, 0)

  local function PS(v) return PixelSnap(v, ui) end

  ui.content = API.CreateFrame("Frame", nil, ui)
  UpdateActionTrackerContentFrame(ui)

  ui.elements = ui.elements or {}
  EnsureActionTrackerRowRelativeAnchorFrames(ui)

  ui.sequenceTextFrame = API.CreateFrame("Frame", nil, ui.content)
  ui.sequenceTextFrame:SetSize(PS(uiShared.TEXT_W), PS(uiShared.NAME_H))
  ui.elements.sequenceText = ui.sequenceTextFrame

  ui.nameText = ui.sequenceTextFrame:CreateFontString(nil, "OVERLAY")
  ui.nameText:SetPoint(C.ANCHOR_CENTER or "CENTER", ui.sequenceTextFrame, C.ANCHOR_CENTER or "CENTER", 0, 0)
  ui.nameText:SetJustifyH("CENTER")
  ui.nameText:SetFont(STANDARD_TEXT_FONT, uiShared.NAME_FONT_SIZE, "OUTLINE")
  ui.nameText:SetText("")


  ui.modifiersFrame = API.CreateFrame("Frame", nil, ui.content)
  ui.modifiersFrame:SetSize(PS(uiShared.TEXT_W), PS(uiShared.MODS_H))
  ui.elements.modifiersText = ui.modifiersFrame

  ui.modShift = ui.modifiersFrame:CreateFontString(nil, "OVERLAY")
  ui.modShift:SetFont(STANDARD_TEXT_FONT, uiShared.MOD_FONT_SIZE, "OUTLINE")
  ui.modShift:SetJustifyH("CENTER")
  ui.modShift:SetText("SHIFT")

  ui.modAlt = ui.modifiersFrame:CreateFontString(nil, "OVERLAY")
  ui.modAlt:SetFont(STANDARD_TEXT_FONT, uiShared.MOD_FONT_SIZE, "OUTLINE")
  ui.modAlt:SetJustifyH("CENTER")
  ui.modAlt:SetText("ALT")

  ui.modCtrl = ui.modifiersFrame:CreateFontString(nil, "OVERLAY")
  ui.modCtrl:SetFont(STANDARD_TEXT_FONT, uiShared.MOD_FONT_SIZE, "OUTLINE")
  ui.modCtrl:SetJustifyH("CENTER")
  ui.modCtrl:SetText("CTRL")

  ui.modShift:SetWidth(PS(uiShared.ICON_SIZE + 18))
  ui.modAlt:SetWidth(PS(uiShared.ICON_SIZE + 10))
  ui.modCtrl:SetWidth(PS(uiShared.ICON_SIZE + 10))

  if addon and addon.ApplyFontFaces then addon:ApplyFontFaces() end

  ui.iconHolder = API.CreateFrame("Frame", nil, ui.content)
  UpdateActionTrackerIconRowAnchor(ui)

  ui.keybindFrame = API.CreateFrame("Frame", nil, ui.content)
  ui.keybindFrame:SetSize(PS(uiShared.TEXT_W), PS(uiShared.NAME_H))
  ui.elements.keybindText = ui.keybindFrame
  ui.keybindText = ui.keybindFrame:CreateFontString(nil, "OVERLAY")
  ui.keybindText:SetPoint("CENTER", ui.keybindFrame, "CENTER", 0, 0)
  ui.keybindText:SetJustifyH("CENTER")
  ui.keybindText:SetFont(STANDARD_TEXT_FONT, uiShared.MOD_FONT_SIZE, "OUTLINE")
  ui.keybindText:SetText("")
  if self.SetupPressedIndicator then
    self:SetupPressedIndicator(ui)
  end

  if addon and addon.ApplyFontFaces then
    addon:ApplyFontFaces()
  end

  ui.icons = {}
  ui._iconBaseX = {}
  ui._lastTextures = {}
  ui._castsInCombat = 0
  if self.RegisterModifierEvents then
    self:RegisterModifierEvents(ui)
  else
    uiShared.SyncModifiers(ui)
    if addon.RefreshDragMouseState then addon:RefreshDragMouseState() end
  end

  if self.RegisterCombatEvents then
    self:RegisterCombatEvents(ui)
  end

  ui:SetScript("OnDragStart", function(frame)
    if not addon:CanDragActionTracker() then return end
    addon:BeginActionTrackerDrag(frame)
  end)

  ui:SetScript("OnDragStop", function()
    addon:EndActionTrackerDrag(true)
  end)

  self:RequestUIRebuild("init")
  self:_AlignModsToIcons()
  self:ClearSpellHistory()

  -- Show and size the frame BEFORE applying position so that
  -- ClampCenteredOffsetsToScreen sees the final frame dimensions.
  ui:Show()
  self:_ResizeToContent()
  if self.EnsureCenteredElementOffsetModel then
    self:EnsureCenteredElementOffsetModel()
  end
  self:ApplyAllElementPositions()
  if self.RefreshPressedIndicator then self:RefreshPressedIndicator() end

  -- Position is applied after the frame has its final size to prevent
  -- incorrect clamping from overwriting saved offsets.
  self:ApplyActionTrackerPosition()

  self:UpdateModifiers()
  self:Lock(self:IsLocked())
  self:ApplyVisibility()
  self:UpdateActionTrackerMoveMarker()
end
