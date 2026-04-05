local ADDON_NAME, ns = ...
local addon = ns
local Core = ns.Core
local API = (ns.Utils and ns.Utils.API) or {}
local Compat = (ns.Utils and ns.Utils.Compat) or nil
local SV = (ns.Utils and ns.Utils.SV) or nil

local function EnsureDatabase()
  if SV and SV.EnsureDB then
    GSETrackerDB = SV:EnsureDB()
    return GSETrackerDB
  end
  GSETrackerDB = GSETrackerDB or {}
  return GSETrackerDB
end

local function InitializeAddonUI()
  if addon.InitUI then
    addon:InitUI()
  end
end

function Core:ApplyDB()
  EnsureDatabase()
  if not self.ui then return end

  if self.ApplyScale then
    self:ApplyScale()
  else
    local desiredScale = (self.GetDesiredScale and self:GetDesiredScale()) or 1.0
    self.ui:SetScale(desiredScale)
  end

  if self.ApplyStrata then
    self:ApplyStrata()
  end
  if self.ApplyFontFaces then
    self:ApplyFontFaces()
  end
  if self.ApplyBorderThickness then
    self:ApplyBorderThickness()
  end
  if self.ApplyActionTrackerPosition then
    self:ApplyActionTrackerPosition()
  end
  if self.ApplyAllElementPositions then
    self:ApplyAllElementPositions()
  end
  if self.Lock then
    self:Lock((self.IsLocked and self:IsLocked()) or false)
  end
  if self.RequestUIRebuild then
    self:RequestUIRebuild("settings")
  end
  if self.ApplyDeterministicRenderPipeline then
    self:ApplyDeterministicRenderPipeline("settings")
  end
  if self.ApplyVisibility then
    self:ApplyVisibility()
  elseif self.IsEnabled and self:IsEnabled() then
    self.ui:Show()
  else
    self.ui:Hide()
  end
  if self.RefreshDragMouseState then
    self:RefreshDragMouseState()
  end
  if self.UpdateActionTrackerMoveMarker then
    self:UpdateActionTrackerMoveMarker()
  end
  if self.RefreshPlayerTracker then
    self:RefreshPlayerTracker()
  elseif self.RefreshCombatMarker then
    self:RefreshCombatMarker()
  end
  if self.RefreshAssistedHighlight then
    self:RefreshAssistedHighlight(true)
  end
  if self.RefreshMinimapButton then
    self:RefreshMinimapButton()
  end
end

local lifecycleEventFrame = API.CreateFrame("Frame")
API.SafeRegisterEvent(lifecycleEventFrame, "ADDON_LOADED")
API.SafeRegisterEvent(lifecycleEventFrame, "PLAYER_LOGIN")
API.SafeRegisterEvent(lifecycleEventFrame, "PLAYER_LOGOUT")

lifecycleEventFrame:SetScript("OnEvent", function(self, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
    API.SafeUnregisterEvent(self, "ADDON_LOADED")

    EnsureDatabase()
    if ns.FinalizeAPI then
      ns:FinalizeAPI()
    end
    if ns.Utils and ns.Utils.DebugModule and ns.Utils.DebugModule.Init then
      ns.Utils.DebugModule:Init()
    end
    if Compat and Compat.CheckRuntime then
      Compat:CheckRuntime()
    end
    InitializeAddonUI()

  elseif event == "PLAYER_LOGIN" then
    API.SafeUnregisterEvent(self, "PLAYER_LOGIN")

    if addon.InitTracker then
      addon:InitTracker()
    end
    if addon.InitGSEBridge then
      addon:InitGSEBridge()
    end

    if addon.ApplyDB then
      addon:ApplyDB()
    elseif Core and Core.ApplyDB then
      Core:ApplyDB()
    end
    if addon.Debug then addon:Debug("Initialized.") end
    if Compat and Compat.PrintLoadedMessage then
      Compat:PrintLoadedMessage()
    end

  elseif event == "PLAYER_LOGOUT" then
    API.SafeUnregisterEvent(self, "PLAYER_LOGOUT")
    if SV and SV.FlushRuntimeToCanonical then
      SV:FlushRuntimeToCanonical()
    end

    API.SafeSetScript(self, "OnEvent", nil)
  end
end)
