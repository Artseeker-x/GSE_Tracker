local _, ns = ...
local addon = ns
local UI = ns.UI
local API = (ns.Utils and ns.Utils.API) or {}
local uiShared = addon._ui or {}
local C = (ns.Utils and ns.Utils.Constants) or addon.Constants or {}

function UI:GetPressedIndicatorShape()
  if ns.Utils and ns.Utils.GetPressedIndicatorShape then
    return ns.Utils:GetPressedIndicatorShape()
  end
  uiShared.EnsureDB()
  return tostring(C.DEFAULT_PRESSED_INDICATOR_SHAPE or "dot")
end

function UI:GetPressedIndicatorSize()
  if ns.Utils and ns.Utils.GetPressedIndicatorSize then
    return ns.Utils:GetPressedIndicatorSize()
  end
  uiShared.EnsureDB()
  return uiShared.Clamp(tonumber(C.DEFAULT_PRESSED_INDICATOR_SIZE) or 10, C.PRESSED_INDICATOR_MIN_SIZE or 4, C.PRESSED_INDICATOR_MAX_SIZE or 24)
end

function UI:SetPressedIndicatorColor(frame, r, g, b, a)
  local target = frame or (self.ui and self.ui.pressedIndicator)
  if not target then return end
  local cr, cg, cb, ca = r or (C.COLOR_RED_R or 1), g or (C.COLOR_RED_G or 0.20), b or (C.COLOR_RED_B or 0.20), a or (C.ALPHA_DEFAULT or 0.90)
  target._piColorR, target._piColorG, target._piColorB, target._piColorA = cr, cg, cb, ca
  if target.tex then
    target.tex:SetTexture("Interface\\Buttons\\WHITE8x8")
    target.tex:SetVertexColor(cr, cg, cb, ca)
  end
  if target.crossH then
    target.crossH:SetColorTexture(cr, cg, cb, ca)
  end
  if target.crossV then
    target.crossV:SetColorTexture(cr, cg, cb, ca)
  end
end

function UI:ApplyPressedIndicatorStyle(frame)
  local ui = self.ui
  local target = frame or (ui and ui.pressedIndicator)
  if not target or not target.tex then return end

  local shape = self:GetPressedIndicatorShape()
  local configuredSize = self:GetPressedIndicatorSize()
  local baseSize = uiShared.PixelSnap(configuredSize, ui or target)
  local dotSize = uiShared.PixelSnap(math.max(2, math.floor((configuredSize * 0.4) + 0.5)), ui or target)
  local texPath = "Interface\\Buttons\\WHITE8x8"
  local circleMaskPath = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

  target:SetSize(baseSize, baseSize)
  if self.UpdateActionTrackerRowRelativeAnchors then
    self:UpdateActionTrackerRowRelativeAnchors()
  end
  target.tex:SetTexture(texPath)
  target.tex:ClearAllPoints()
  target.tex:SetAllPoints(target)
  target.tex:Show()

  if not target.crossH then
    target.crossH = target:CreateTexture(nil, "OVERLAY")
    target.crossH:SetTexture(texPath)
  end
  if not target.crossV then
    target.crossV = target:CreateTexture(nil, "OVERLAY")
    target.crossV:SetTexture(texPath)
  end
  if not target.mask then
    target.mask = target:CreateMaskTexture(nil, "OVERLAY")
  end

  target.crossH:Hide()
  target.crossV:Hide()
  if target.tex.RemoveMaskTexture then
    target.tex:RemoveMaskTexture(target.mask)
  end
  target.mask:Hide()
  target.mask:ClearAllPoints()

  self:SetPressedIndicatorColor(
    target,
    target._piColorR or (C.COLOR_RED_R or 1),
    target._piColorG or (C.COLOR_RED_G or 0.20),
    target._piColorB or (C.COLOR_RED_B or 0.20),
    target._piColorA or (C.ALPHA_DEFAULT or 0.90)
  )

  if shape == "cross" then
    target.tex:Hide()
    local bar = uiShared.PixelSnap(2, ui or target)
    target.crossH:ClearAllPoints()
    target.crossH:SetPoint("CENTER", target, "CENTER", 0, 0)
    target.crossH:SetSize(baseSize, bar)
    target.crossH:Show()
    target.crossV:ClearAllPoints()
    target.crossV:SetPoint("CENTER", target, "CENTER", 0, 0)
    target.crossV:SetSize(bar, baseSize)
    target.crossV:Show()
    return
  end

  if shape == "square" then
    return
  end

  if shape == "dot" then
    target.tex:ClearAllPoints()
    target.tex:SetPoint("CENTER", target, "CENTER", 0, 0)
    target.tex:SetSize(dotSize, dotSize)
  else
    target.tex:ClearAllPoints()
    target.tex:SetAllPoints(target)
  end

  target.mask:SetTexture(circleMaskPath, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  target.mask:ClearAllPoints()
  target.mask:SetAllPoints(target.tex)
  target.mask:Show()
  if target.tex.AddMaskTexture then
    target.tex:AddMaskTexture(target.mask)
  end
end

local function PressedIndicatorOnUpdate(driverFrame, elapsed)
  driverFrame._tick = (driverFrame._tick or 0) + (elapsed or 0)
  if driverFrame._tick < 0.05 then return end
  driverFrame._tick = 0

  if not (addon and addon.RefreshPressedIndicator) then
    driverFrame._driverActive = false
    driverFrame:SetScript("OnUpdate", nil)
    return
  end

  addon:RefreshPressedIndicator()
  if not driverFrame:IsShown() or not driverFrame._indicatorDriverNeeded then
    driverFrame._driverActive = false
    driverFrame:SetScript("OnUpdate", nil)
  end
end

function UI:StopPressedIndicatorDriver(frame)
  local target = frame or (self.ui and self.ui.pressedIndicator)
  if not target then return end
  target._tick = 0
  target._driverActive = false
  target:SetScript("OnUpdate", nil)
end

function UI:StartPressedIndicatorDriver(frame)
  local target = frame or (self.ui and self.ui.pressedIndicator)
  if not target then return end
  if target._driverActive then return end
  target._driverActive = true
  target._tick = 0
  target:SetScript("OnUpdate", PressedIndicatorOnUpdate)
end

function UI:SetupPressedIndicator(ui)
  if not ui then return end
  local pressedSize = self:GetPressedIndicatorSize()
  ui.pressedIndicator = API.CreateFrame("Frame", nil, ui.content)
  ui.pressedIndicator:SetSize(uiShared.PixelSnap(pressedSize, ui), uiShared.PixelSnap(pressedSize, ui))
  ui.elements.pressedIndicator = ui.pressedIndicator
  ui.pressedIndicator.tex = ui.pressedIndicator:CreateTexture(nil, "OVERLAY")
  ui.pressedIndicator.tex:SetAllPoints()
  ui.pressedIndicator.tex:SetTexture("Interface\\Buttons\\WHITE8x8")
  self:SetPressedIndicatorColor(ui.pressedIndicator, C.COLOR_RED_R or 1, C.COLOR_RED_G or 0.20, C.COLOR_RED_B or 0.20, C.ALPHA_DEFAULT or 0.90)
  ui.pressedIndicator.mask = ui.pressedIndicator:CreateMaskTexture(nil, "OVERLAY")
  ui.pressedIndicator.mask:SetAllPoints(ui.pressedIndicator.tex)
  ui.pressedIndicator:Hide()
  ui.pressedIndicator._driverActive = false
  ui.pressedIndicator._indicatorDriverNeeded = false
  ui.pressedIndicator._styleSig = nil
  self:ApplyPressedIndicatorStyle(ui.pressedIndicator)
end

function UI:RefreshPressedIndicator(force)
  local ui = self.ui
  if not (ui and ui.pressedIndicator and ui.pressedIndicator.tex) then return end

  local cfg, defaults = self:GetElementLayout("pressedIndicator")
  local enabled = true
  if type(cfg) == "table" and cfg.enabled ~= nil then
    enabled = cfg.enabled and true or false
  elseif defaults and defaults.enabled ~= nil then
    enabled = defaults.enabled and true or false
  end

  local shouldShow = enabled and ((API.InCombatLockdown and API.InCombatLockdown()) or addon._editingOptions)
  local active = false
  if type(self._lastGSEPressTime) == "number" then
    active = (API.GetTime() - self._lastGSEPressTime) <= (C.PRESSED_INDICATOR_ACTIVE_WINDOW or 0.20)
  end

  local shape = self.GetPressedIndicatorShape and self:GetPressedIndicatorShape() or (C.DEFAULT_PRESSED_INDICATOR_SHAPE or "dot")
  local size = self.GetPressedIndicatorSize and self:GetPressedIndicatorSize() or (C.DEFAULT_PRESSED_INDICATOR_SIZE or 10)
  local styleSig = tostring(shape) .. "|" .. tostring(size)

  if not shouldShow then
    ui._pressedIndicatorActive = false
    ui.pressedIndicator._indicatorDriverNeeded = false
    if self.StopPressedIndicatorDriver then self:StopPressedIndicatorDriver(ui.pressedIndicator) end
    ui.pressedIndicator:Hide()
    return
  end

  ui.pressedIndicator:Show()
  ui.pressedIndicator._indicatorDriverNeeded = active and true or false

  if ui.pressedIndicator._styleSig ~= styleSig and self.ApplyPressedIndicatorStyle then
    ui.pressedIndicator._styleSig = styleSig
    self:ApplyPressedIndicatorStyle(ui.pressedIndicator)
    force = true
  end

  if active then
    if self.StartPressedIndicatorDriver then self:StartPressedIndicatorDriver(ui.pressedIndicator) end
  elseif self.StopPressedIndicatorDriver then
    self:StopPressedIndicatorDriver(ui.pressedIndicator)
  end

  if not force and ui._pressedIndicatorActive == active then return end
  ui._pressedIndicatorActive = active
  if active then
    self:SetPressedIndicatorColor(ui.pressedIndicator, C.COLOR_GREEN_R or 0.20, C.COLOR_GREEN_G or 1, C.COLOR_GREEN_B or 0.20, C.ALPHA_STRONG or 0.95)
  else
    self:SetPressedIndicatorColor(ui.pressedIndicator, C.COLOR_RED_R or 1, C.COLOR_RED_G or 0.20, C.COLOR_RED_B or 0.20, C.ALPHA_DIM or 0.60)
  end
end
