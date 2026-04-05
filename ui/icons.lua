local _, ns = ...
local addon = ns
local UI = ns.UI
local Tracker = ns.Tracker or {}
local API = (ns.Utils and ns.Utils.API) or {}
local uiShared = addon._ui or {}
local pixelSnap = uiShared.PixelSnap
local copyArrayInto = uiShared.CopyArrayInto or uiShared.CopyArray
local clearArray = uiShared.ClearArray or uiShared.ClearTable
local iconRowWidth = uiShared.IconRowWidth
local ICON_SIZE = uiShared.ICON_SIZE
local OLDEST_FADE_DUR = uiShared.OLDEST_FADE_DUR
local SCROLL_DUR = uiShared.SCROLL_DUR
local C = (ns.Utils and ns.Utils.Constants) or addon.Constants or {}
local FLOW_FADE_IN_DUR = 0.10
local FLOW_FADE_OUT_DUR = 0.12

local CLASS_SAMPLE_SPELL_IDS = {
  WARRIOR     = { 12294, 1464,   5308,  1680,  23922,  85288  }, -- Mortal Strike, Slam, Execute, Whirlwind, Shield Slam, Raging Blow
  PALADIN     = { 35395, 20271, 85256, 20473,  31935,  53600  }, -- Crusader Strike, Judgment, Templar's Verdict, Holy Shock, Avenger's Shield, Shield of the Righteous
  HUNTER      = { 34026,185358, 19434,217200, 257620, 259387  }, -- Kill Command, Arcane Shot, Aimed Shot, Barbed Shot, Multi-Shot, Mongoose Bite
  ROGUE       = {  1752,    53,196819,  2098,   1329,  51723  }, -- Sinister Strike, Backstab, Eviscerate, Dispatch, Mutilate, Fan of Knives
  PRIEST      = {   589,  8092,  2061,    17,    585,  34433  }, -- Shadow Word: Pain, Mind Blast, Flash Heal, Power Word: Shield, Smite, Dispel Magic
  DEATHKNIGHT = { 49998, 49020, 49143, 55090, 195182, 343294  }, -- Death Strike, Obliterate, Frost Strike, Scourge Strike, Marrowrend, Soul Reaper
  SHAMAN      = {188196, 17364, 51505, 61882, 188443,  73899  }, -- Lightning Bolt, Stormstrike, Lava Burst, Earthquake, Chain Lightning, Unleash Elements
  MAGE        = {   133,   116, 30451,108853,  30455,  84714  }, -- Fireball, Frostbolt, Arcane Blast, Fire Blast, Ice Lance, Frozen Orb
  WARLOCK     = { 29722,   686,   172,116858,    980,    348  }, -- Incinerate, Shadow Bolt, Corruption, Chaos Bolt, Agony, Immolate
  MONK        = {100780,100784,107428,113656, 101546, 152175, 123986, 322101}, -- Tiger Palm, Blackout Kick, Rising Sun Kick, Fists of Fury, Spinning Crane Kick, Whirling Dragon Punch, Chi Burst, Expel Harm
  DRUID       = { 78674,  5176,  1822,  1079,  33917,   8921  }, -- Starsurge, Wrath, Rake, Rip, Mangle, Moonfire
  DEMONHUNTER = {162794,195072,188499,204596, 258920, 198013  }, -- Chaos Strike, Fel Rush, Blade Dance, Sigil of Flame, Immolation Aura, Eye Beam
  EVOKER      = {356995,357211,357208,359073, 367226, 355913  }, -- Disintegrate, Pyre, Fire Breath, Eternity Surge, Spiritbloom, Emerald Blossom
}

local function GetEditModePreviewTexture(index)
  local _, classToken = UnitClass("player")
  local spellIDs = (classToken and CLASS_SAMPLE_SPELL_IDS[classToken])
               or CLASS_SAMPLE_SPELL_IDS.MONK
  local count = #spellIDs
  if count == 0 then
    return 134400 -- INV_Misc_QuestionMark fileID fallback
  end

  index = tonumber(index) or 1
  local spellID = spellIDs[((index - 1) % count) + 1]
  local texture = nil

  if API.GetSpellTexture then
    texture = API.GetSpellTexture(spellID)
  end

  if not texture and C_Spell and C_Spell.GetSpellTexture then
    texture = C_Spell.GetSpellTexture(spellID)
  end

  if not texture and _G.GetSpellTexture then
    texture = _G.GetSpellTexture(spellID)
  end

  return texture or 134400 -- INV_Misc_QuestionMark
end

local function GetClassColor()
  return uiShared.GetPlayerClassColorRGB(1, 1, 1)
end

local function GetSequenceColor(seqKey)
  if ns.Utils and ns.Utils.GetSequenceColorRGB then
    return ns.Utils:GetSequenceColorRGB(seqKey, GetClassColor())
  end
  return GetClassColor()
end

local function EnsureOldestFade(icon)
  if icon._oldestFade then return end
  local ag = icon:CreateAnimationGroup()
  ag:SetToFinalAlpha(true)
  local a = ag:CreateAnimation("Alpha")
  a:SetFromAlpha(1)
  a:SetToAlpha(0)
  a:SetDuration(OLDEST_FADE_DUR)
  a:SetOrder(1)
  icon._oldestFade = ag
end

local function PlayOldestFade(icon)
  if not icon then return end
  EnsureOldestFade(icon)
  icon._oldestFade:Stop()
  icon:SetAlpha(1)
  icon._oldestFade:Play()
end
uiShared.PlayOldestFade = PlayOldestFade

local function EnsureFlowFadeIn(icon)
  if icon._flowFadeInAG then return end
  local ag = icon:CreateAnimationGroup()
  ag:SetToFinalAlpha(true)
  local a = ag:CreateAnimation("Alpha")
  a:SetFromAlpha(0)
  a:SetToAlpha(1)
  a:SetDuration(FLOW_FADE_IN_DUR)
  a:SetOrder(1)
  icon._flowFadeInAG = ag
end

local function PlayFlowFadeIn(icon)
  if not icon then return end
  EnsureFlowFadeIn(icon)
  icon._flowFadeInAG:Stop()
  icon:SetAlpha(0)
  icon._flowFadeInAG:Play()
end

local function EnsureFadeGhost(ui)
  if ui._fadeGhost then return ui._fadeGhost end
  local ghost = API.CreateFrame("Frame", nil, ui.iconHolder, "BackdropTemplate")
  ghost:SetSize(pixelSnap(ICON_SIZE, ui), pixelSnap(ICON_SIZE, ui))
  ghost:SetFrameLevel((ui.iconHolder:GetFrameLevel() or 0) + 10)
  ghost:SetAlpha(0)
  ghost:Hide()

  local tex = ghost:CreateTexture(nil, "ARTWORK")
  tex:SetPoint("TOPLEFT", ghost, "TOPLEFT", 0, 0)
  tex:SetPoint("BOTTOMRIGHT", ghost, "BOTTOMRIGHT", 0, 0)
  tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  ghost.tex = tex

  local ag = ghost:CreateAnimationGroup()
  ag:SetToFinalAlpha(true)
  local a = ag:CreateAnimation("Alpha")
  a:SetFromAlpha(1)
  a:SetToAlpha(0)
  a:SetDuration(FLOW_FADE_OUT_DUR)
  a:SetOrder(1)
  ag:SetScript("OnFinished", function()
    ghost:Hide()
  end)
  ghost._fadeOutAG = ag

  ui._fadeGhost = ghost
  return ghost
end

local function PlayFlowFadeOutGhost(ui, texture, baseX)
  if not (ui and texture and texture ~= "") then return end
  if addon.IsPerformanceModeEnabled and addon:IsPerformanceModeEnabled() then return end
  local ghost = EnsureFadeGhost(ui)
  ghost._fadeOutAG:Stop()
  ghost:ClearAllPoints()
  ghost:SetPoint("LEFT", ui.iconHolder, "LEFT", pixelSnap(baseX or 0, ui), 0)
  ghost.tex:SetTexture(texture)
  ghost:Show()
  ghost:SetAlpha(1)
  ghost._fadeOutAG:Play()
end

local function StopManualSlideDriver(ui)
  if ui and ui.iconHolder then
    ui.iconHolder:SetScript("OnUpdate", nil)
  end
  if ui then
    ui._slidePending = nil
    ui._slideDriver = nil
  end
end
local function ReleaseIconFrame(icon)
  if not icon then return end
  if icon._oldestFade then icon._oldestFade:Stop() end
  if icon._flowFadeInAG then icon._flowFadeInAG:Stop() end
  icon._animStartX = nil
  icon._animTargetX = nil
  icon._animElapsed = nil
  icon._animating = nil
  icon:Hide()
  icon:SetAlpha(0)
  if icon.tex then
    icon.tex:SetTexture(nil)
    icon.tex:Hide()
  end
  icon:ClearAllPoints()
  icon:SetParent(nil)
end

local function AcquireIconFrame(owner, ui, index, showBorder, thickness)
  ui._iconPool = ui._iconPool or {}
  ui._iconBackdropCache = ui._iconBackdropCache or {}
  local backdrop = ui._iconBackdropCache[thickness]
  if not backdrop then
    backdrop = { bgFile = C.TEXTURE_WHITE8X8 or "Interface/Buttons/WHITE8x8", edgeFile = C.TEXTURE_WHITE8X8 or "Interface/Buttons/WHITE8x8", edgeSize = thickness, insets = { left = thickness, right = thickness, top = thickness, bottom = thickness } }
    ui._iconBackdropCache[thickness] = backdrop
  end
  local b = ui._iconPool[index]
  if not b then
    b = API.CreateFrame("Frame", nil, ui.iconHolder, "BackdropTemplate")
    local tex = b:CreateTexture(nil, "ARTWORK")
    tex:ClearAllPoints()
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.tex = tex
    ui._iconPool[index] = b
  else
    b:SetParent(ui.iconHolder)
  end

  b:SetSize(pixelSnap(ICON_SIZE, ui), pixelSnap(ICON_SIZE, ui))
  b:SetBackdrop(backdrop)
  b:SetBackdropColor(0, 0, 0, 0)

  local borderR, borderG, borderB = 0, 0, 0
  if owner and owner.GetActionTrackerUseClassColor and owner:GetActionTrackerUseClassColor() then
    borderR, borderG, borderB = owner:GetClassColorRGB()
  elseif owner and owner.GetActionTrackerBorderColor then
    borderR, borderG, borderB = owner:GetActionTrackerBorderColor()
  end

  if showBorder then
    b:SetBackdropBorderColor(borderR or 0, borderG or 0, borderB or 0, 1)
  else
    b:SetBackdropBorderColor(0, 0, 0, 0)
  end
  b.tex:ClearAllPoints()
  b.tex:SetPoint("TOPLEFT", b, "TOPLEFT", thickness, -thickness)
  b.tex:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -thickness, thickness)
  b:SetAlpha(0)
  b:Hide()
  b.tex:SetTexture(nil)
  b.tex:Hide()
  return b
end

local function HideUnusedIconPool(ui, keepCount)
  if not (ui and ui._iconPool) then return end
  for i = keepCount + 1, #ui._iconPool do
    ReleaseIconFrame(ui._iconPool[i])
  end
end

local function BorrowScratch(ui, key)
  ui._scratch = ui._scratch or {}
  local t = ui._scratch[key]
  if not t then
    t = {}
    ui._scratch[key] = t
  end
  if API.wipe then
    API.wipe(t)
  else
    for k in pairs(t) do t[k] = nil end
  end
  return t
end

local function BorrowArray(ui, key, count)
  local t = BorrowScratch(ui, key)
  if count and count > 0 then
    clearArray(t, count + 1)
  end
  return t
end

local function TexturesMatch(ui, textures, count)
  local last = ui and ui._lastTextures
  if not last then return false end
  for i = 1, count do
    if last[i] ~= (textures and textures[i] or nil) then
      return false
    end
  end
  return last[count + 1] == nil
end

local function RebuildBaseSlots(ui)
  local count = (ui.icons and #ui.icons) or 0
  local gap = addon:GetIconGap()
  local step = (ICON_SIZE + gap)
  ui._iconBaseX = ui._iconBaseX or {}
  for slot = 1, count do
    ui._iconBaseX[slot] = (slot - 1) * step
  end
end

local function SyncIconLayout(ui)
  if not (ui and ui.icons) then return end
  for slot = 1, #ui.icons do
    local icon = ui.icons[slot]
    if icon then
      local baseX = icon._baseX
      if baseX == nil then baseX = (ui._iconBaseX and ui._iconBaseX[slot]) or 0 end
      icon._animStartX = nil
      icon._animTargetX = nil
      icon._animElapsed = nil
      icon._animating = nil
      icon:ClearAllPoints()
      icon:SetPoint("LEFT", ui.iconHolder, "LEFT", pixelSnap(baseX, ui), 0)
    end
  end
end

local RevealPendingSequenceTextIfReady

local function PostSlideResyncOnUpdate(holder)
  local ui = holder and holder._gsetrackerOwnerUI
  if not ui or not ui._postSlideResyncFrames then
    if holder then holder:SetScript("OnUpdate", nil) end
    return
  end
  ui._postSlideResyncFrames = ui._postSlideResyncFrames - 1
  SyncIconLayout(ui)
  if ui._postSlideResyncFrames <= 0 then
    ui._postSlideResyncFrames = nil
    holder:SetScript("OnUpdate", nil)
    RevealPendingSequenceTextIfReady(ui)
  end
end

local function QueuePostSlideResync(ui)
  if not (ui and ui.iconHolder and ui.icons and #ui.icons > 0) then return end
  ui._postSlideResyncFrames = 2
  ui.iconHolder._gsetrackerOwnerUI = ui
  ui.iconHolder:SetScript("OnUpdate", PostSlideResyncOnUpdate)
end

RevealPendingSequenceTextIfReady = function(ui)
  if not ui then return end
  if ui._slidePending and ui._slidePending > 0 then return end
  if addon and addon.RevealPendingSequenceText then
    addon:RevealPendingSequenceText()
  end
end

local function ManualSlideOnUpdate(holder, elapsed)
  local ui = holder and holder._gsetrackerOwnerUI
  if not ui then
    if holder then holder:SetScript("OnUpdate", nil) end
    return
  end

  local anyAnimating = false
  for i = 1, #(ui.icons or {}) do
    local icon = ui.icons[i]
    if icon and icon._animating then
      anyAnimating = true
      local dur = SCROLL_DUR
      local t = (icon._animElapsed or 0) + elapsed
      icon._animElapsed = t
      local p = dur > 0 and math.min(t / dur, 1) or 1
      local eased = 1 - ((1 - p) * (1 - p))
      local x = (icon._animStartX or 0) + (((icon._animTargetX or 0) - (icon._animStartX or 0)) * eased)
      icon:ClearAllPoints()
      icon:SetPoint("LEFT", ui.iconHolder, "LEFT", pixelSnap(x, ui), 0)
      if p >= 1 then
        icon._animating = nil
        icon._animElapsed = nil
        icon._baseX = icon._animTargetX or icon._baseX or 0
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", ui.iconHolder, "LEFT", pixelSnap(icon._baseX, ui), 0)
        if ui._slidePending and ui._slidePending > 0 then
          ui._slidePending = ui._slidePending - 1
        end
      end
    end
  end

  if not anyAnimating then
    StopManualSlideDriver(ui)
    SyncIconLayout(ui)
    QueuePostSlideResync(ui)
  end
end

local function StartManualSlideDriver(ui)
  if not (ui and ui.iconHolder) then return end
  ui.iconHolder._gsetrackerOwnerUI = ui
  ui.iconHolder:SetScript("OnUpdate", ManualSlideOnUpdate)
end

local function SetIconBaseX(ui, icon, newBaseX, animate)
  animate = animate and not (addon.IsPerformanceModeEnabled and addon:IsPerformanceModeEnabled())
  local oldBaseX = icon._baseX
  if oldBaseX == nil then
    icon._baseX = newBaseX
    icon:ClearAllPoints()
    icon:SetPoint("LEFT", ui.iconHolder, "LEFT", pixelSnap(newBaseX, ui), 0)
    return false
  end
  if not animate or newBaseX == oldBaseX then
    icon._animating = nil
    icon._animElapsed = nil
    icon._baseX = newBaseX
    icon:ClearAllPoints()
    icon:SetPoint("LEFT", ui.iconHolder, "LEFT", pixelSnap(newBaseX, ui), 0)
    return false
  end

  icon._animStartX = oldBaseX
  icon._animTargetX = newBaseX
  icon._animElapsed = 0
  icon._animating = true
  icon:ClearAllPoints()
  icon:SetPoint("LEFT", ui.iconHolder, "LEFT", pixelSnap(oldBaseX, ui), 0)
  return true
end

local function AnimateIconsToSlots(ui)
  if not ui.icons then return end
  RebuildBaseSlots(ui)
  local pending = 0
  for slot = 1, #ui.icons do
    local icon = ui.icons[slot]
    local baseX = ui._iconBaseX[slot] or 0
    if SetIconBaseX(ui, icon, baseX, true) then pending = pending + 1 end
  end
  if pending > 0 then
    ui._slidePending = pending
    StartManualSlideDriver(ui)
  else
    SyncIconLayout(ui)
    QueuePostSlideResync(ui)
  end
end
uiShared.AnimateIconsToSlots = AnimateIconsToSlots

function UI:RevealPendingSequenceText()
  local ui = self.ui
  if not ui then return end
  if ui._pendingSeqText == nil then return end
  local txt = ui._pendingSeqText
  local key = ui._pendingSeqKey
  ui._pendingSeqText = nil
  ui._pendingSeqKey = nil
  self:SetSequenceText(txt, nil, nil, key)
end

function UI:SetKeybindText(text)
  local ui = self.ui
  if not (ui and ui.keybindText) then return end
  local txt = type(text) == "string" and text or ""
  local rendered = (ui.keybindText.GetText and ui.keybindText:GetText()) or ""
  if ui._lastKeybindText == txt and rendered == txt then return end
  ui._lastKeybindText = txt
  ui.keybindText:SetText(txt)

  if ui.keybindFrame then
    local cfg = (self.GetElementLayout and self:GetElementLayout("keybindText")) or nil
    local enabled = cfg and cfg.enabled ~= false
    local shouldShow = txt ~= "" and enabled and (ui._lastVisible ~= false)
    if shouldShow then
      ui.keybindFrame:Show()
    else
      ui.keybindFrame:Hide()
    end
  end

  self:_ResizeToContent()
end

function UI:SetSequenceText(displayName, _, _, seqKey)
  local ui = self.ui
  if not ui then return end
  local txt = (type(displayName) == "string") and displayName or ""
  if txt == "-" or txt == "Sequence Standing By" then txt = "" end

  if ui._slidePending and ui._slidePending > 0 then
    ui._pendingSeqText = txt
    ui._pendingSeqKey = seqKey
    return
  end

  ui._pendingSeqText = nil
  ui._pendingSeqKey = nil

  if txt == "" then
    local renderedName = (ui.nameText and ui.nameText.GetText and ui.nameText:GetText()) or ""
    local renderedKeybind = (ui.keybindText and ui.keybindText.GetText and ui.keybindText:GetText()) or ""
    if ui._lastSeqText == "" and ui._lastSeqKey == nil and ui._accentA == 0 and renderedName == "" and renderedKeybind == "" then return end
    ui._lastSeqText = ""
    ui._lastSeqKey = nil
    ui._accentR, ui._accentG, ui._accentB, ui._accentA = 1, 1, 1, 0
    ui.nameText:SetText("")
    ui.nameText:SetTextColor(1, 1, 1, 0)
    if ui.sequenceTextFrame then ui.sequenceTextFrame:Hide() end
    self:SetKeybindText("")
    self:_ResizeToContent()
    return
  end

  local r, g, b = GetSequenceColor(seqKey)
  local liveKeybindText = nil
  if self.GetActiveSequenceBindingText then
    liveKeybindText = self:GetActiveSequenceBindingText(seqKey) or ""
  end

  local renderedName = (ui.nameText and ui.nameText.GetText and ui.nameText:GetText()) or ""
  local renderedNameAlpha = (ui.nameText and ui.nameText.GetAlpha and ui.nameText:GetAlpha()) or 1
  local renderedKeybind = (ui.keybindText and ui.keybindText.GetText and ui.keybindText:GetText()) or ""
  local keybindInSync = (liveKeybindText == nil) or (renderedKeybind == liveKeybindText)

  if ui._lastSeqText == txt
    and ui._lastSeqKey == seqKey
    and ui._accentR == r
    and ui._accentG == g
    and ui._accentB == b
    and ui._accentA == 1
    and renderedName == txt
    and renderedNameAlpha > 0
    and keybindInSync then
    return
  end

  ui._lastSeqText = txt
  ui._lastSeqKey = seqKey
  ui._accentR, ui._accentG, ui._accentB, ui._accentA = r, g, b, 1
  ui.nameText:SetText(txt)
  if liveKeybindText ~= nil then
    self:SetKeybindText(liveKeybindText)
  end
  ui.nameText:SetTextColor(r, g, b, 1)

  if ui.sequenceTextFrame and ui._lastVisible ~= false then
    local seqCfg = (self.GetElementLayout and self:GetElementLayout("sequenceText")) or nil
    local seqEnabled = seqCfg and seqCfg.enabled ~= false
    if seqEnabled then
      ui.sequenceTextFrame:Show()
    end
  end

  self:UpdateModifiers(true)
  self:_ResizeToContent()
end

function UI:_GetIconLayoutSignature()
  local ui = self.ui
  if not ui then return nil end

  return table.concat({
    tostring((self.GetEditModePreviewIconCount and self:GetEditModePreviewIconCount()) or self:GetIconCount()),
    tostring(self:GetIconGap()),
    tostring(self:GetBorderThickness()),
    tostring(self:IsBorderEnabled() and 1 or 0),
    tostring(string.format("%.2f", self:GetDesiredScale() or 1)),
    tostring(ui._lastVisible == true),
  }, "|")
end

function UI:IsEditModePreviewActive()
  return not not (addon._editingOptions and self.IsLocked and not self:IsLocked())
end

function UI:GetEditModePreviewIconCount()
  local count = (self.GetIconCount and self:GetIconCount()) or 4
  if self:IsEditModePreviewActive() and count < 4 then
    return 4
  end
  return count
end

function UI:ApplyEditModeIconPreview(force)
  local ui = self.ui
  if not (ui and ui.icons) then return false end

  local active = self:IsEditModePreviewActive()
  local targetCount = (self.GetEditModePreviewIconCount and self:GetEditModePreviewIconCount()) or #ui.icons

  if #ui.icons ~= targetCount and self.RebuildIcons then
    return self:RebuildIcons(true)
  end

  if not active then
    if not ui._editModePreviewIconsActive and not force then
      return false
    end

    ui._editModePreviewIconsActive = false
    local restored = false
    local lastTextures = ui._lastTextures
    if lastTextures then
      for i = 1, #ui.icons do
        local tex = lastTextures[i]
        if tex and tex ~= "" then
          restored = true
          break
        end
      end
    end

    if restored and self.SetIconRow then
      local restoreTextures = BorrowArray(ui, "restoreTextures", #ui.icons)
      copyArrayInto(restoreTextures, lastTextures, #ui.icons)
      clearArray(ui._lastTextures, 1)
      self:SetIconRow(restoreTextures)
    else
      for i = 1, #ui.icons do
        local btn = ui.icons[i]
        if btn then
          btn:SetAlpha(0)
          btn:Hide()
          if btn.tex then
            btn.tex:SetTexture(nil)
            btn.tex:Hide()
          end
        end
      end
    end

    return true
  end

  if self.ApplyBorderThickness then
    self:ApplyBorderThickness()
  end

  local changed = force or not ui._editModePreviewIconsActive
  ui._editModePreviewIconsActive = true
  for i = 1, #ui.icons do
    local btn = ui.icons[i]
    if btn then
      local texture = GetEditModePreviewTexture(i)
      if btn.tex then
        if btn.tex:GetTexture() ~= texture then
          btn.tex:SetTexture(texture)
          changed = true
        end
        btn.tex:Show()
      end
      if not btn:IsShown() or (btn.GetAlpha and math.abs((btn:GetAlpha() or 0) - 1) > 0.001) then
        changed = true
      end
      btn:SetAlpha(1)
      btn:Show()
    end
  end

  return changed
end

function UI:RebuildIcons(force)
  local ui = self.ui
  if not ui then return false end

  local layoutSig = self._GetIconLayoutSignature and self:_GetIconLayoutSignature() or nil
  if not force and ui._lastIconRebuildSig and layoutSig == ui._lastIconRebuildSig then
    return false
  end
  ui._lastIconRebuildSig = layoutSig

  ui:SetScale(self:GetDesiredScale())
  local function PS(v) return pixelSnap(v, ui) end
  ui._lastTextures = ui._lastTextures or {}
  ui._preservedTextures = copyArrayInto(ui._preservedTextures or {}, ui._lastTextures, #ui._lastTextures)
  local preserved = ui._preservedTextures

  StopManualSlideDriver(ui)
  ui.icons = ui.icons or {}
  ui._iconBaseX = ui._iconBaseX or {}
  clearArray(ui.icons, 1)
  clearArray(ui._iconBaseX, 1)

  local count = (self.GetEditModePreviewIconCount and self:GetEditModePreviewIconCount()) or self:GetIconCount()
  local gap = self:GetIconGap()
  local step = (ICON_SIZE + gap)

  ui.iconHolder:SetSize(PS(iconRowWidth(count)), PS(ICON_SIZE))
  if self.UpdateActionTrackerIconRowAnchor then
    self:UpdateActionTrackerIconRowAnchor()
  end

  local showBorder = self:IsBorderEnabled()
  local thickness = self:GetBorderThickness()

  for i = 1, count do
    local b = AcquireIconFrame(self, ui, i, showBorder, thickness)
    ui._iconBaseX[i] = (i - 1) * step
    b._baseX = ui._iconBaseX[i]
    b:ClearAllPoints()
    b:SetPoint("LEFT", ui.iconHolder, "LEFT", PS(b._baseX), 0)
    ui.icons[i] = b
  end
  HideUnusedIconPool(ui, count)

  RebuildBaseSlots(ui)
  self:_AlignModsToIcons()
  self:_ResizeToContent()

  local hasAny = false
  for i = 1, count do if preserved[i] then hasAny = true; break end end
  clearArray(ui._lastTextures, 1)

  if hasAny then
    local reapplied = BorrowArray(ui, "reappliedTextures", count)
    copyArrayInto(reapplied, preserved, count)
    copyArrayInto(ui._lastTextures, preserved, count)
    self:SetIconRow(reapplied)
  else
    for i = 1, count do
      local btn = ui.icons[i]
      btn:Hide(); btn:SetAlpha(0)
      if btn.tex then btn.tex:SetTexture(nil) end
    end
  end

  if self.ApplyBorderThickness then
    self:ApplyBorderThickness()
  end

  if self.ApplyEditModeIconPreview and self:ApplyEditModeIconPreview(true) then
    return true
  end

  return true
end

function UI:SetIconRow(textures)
  local ui = self.ui
  if not ui or not ui.icons then return end

  local count = #ui.icons
  ui._lastTextures = ui._lastTextures or {}
  if TexturesMatch(ui, textures, count) then
    self:RefreshPressedIndicator()
    return false
  end
  local prevTextures = BorrowArray(ui, "prevTextures", count)
  copyArrayInto(prevTextures, ui._lastTextures, count)
  local hadVisibleBefore = false
  local hasVisibleNow = false
  for i = 1, count do
    if prevTextures[i] and prevTextures[i] ~= "" then hadVisibleBefore = true; break end
  end

  local sourceSlotForTarget = BorrowArray(ui, "sourceSlotForTarget", count)
  local isFrontQueueShift = true
  for i = 1, count do
    local tex = textures and textures[i] or nil
    if tex and tex ~= "" then hasVisibleNow = true end
  end

  if hadVisibleBefore and hasVisibleNow then
    for i = 2, count do
      local tex = textures and textures[i] or nil
      local prev = prevTextures[i - 1]
      if tex ~= prev then
        isFrontQueueShift = false
        break
      end
    end
  else
    isFrontQueueShift = false
  end

  if isFrontQueueShift then
    for i = 2, count do
      local tex = textures and textures[i] or nil
      local prev = prevTextures[i - 1]
      if tex and tex ~= "" and prev and prev ~= "" then
        sourceSlotForTarget[i] = i - 1
      end
    end
  else
    local oldSlotsByTexture = BorrowScratch(ui, "oldSlotsByTexture")
    ui._oldSlotBuckets = ui._oldSlotBuckets or {}
    local oldSlotBuckets = ui._oldSlotBuckets
    local oldSlotBucketCount = 0
    for i = 1, count do
      local prev = prevTextures[i]
      if prev and prev ~= "" then
        local bucket = oldSlotsByTexture[prev]
        if not bucket then
          oldSlotBucketCount = oldSlotBucketCount + 1
          bucket = oldSlotBuckets[oldSlotBucketCount]
          if bucket then
            clearArray(bucket, 1)
          else
            bucket = {}
            oldSlotBuckets[oldSlotBucketCount] = bucket
          end
          bucket.first = 1
          oldSlotsByTexture[prev] = bucket
        end
        bucket[#bucket + 1] = i
      end
    end

    for i = 1, count do
      local tex = textures and textures[i] or nil
      if tex and tex ~= "" then
        local bucket = oldSlotsByTexture[tex]
        local first = bucket and bucket.first
        if first and first <= #bucket then
          sourceSlotForTarget[i] = bucket[first]
          bucket[first] = nil
          bucket.first = first + 1
        end
      end
    end

    for i = 1, oldSlotBucketCount do
      local bucket = oldSlotBuckets[i]
      if bucket then
        bucket.first = nil
        clearArray(bucket, 1)
      end
    end
  end

  for i = 1, count do
    local btn = ui.icons[i]
    local tex = textures and textures[i] or nil

    if tex and tex ~= "" then
      btn.tex:SetTexture(tex)
      btn.tex:Show()
      btn:SetAlpha(1)
      btn:Show()
    else
      btn.tex:SetTexture(nil)
      btn.tex:Hide()
      btn:SetAlpha(0)
      btn:Hide()
    end
    ui._lastTextures[i] = tex
  end
  clearArray(ui._lastTextures, count + 1)

  RebuildBaseSlots(ui)
  local removedTexture = nil
  if isFrontQueueShift then
    removedTexture = prevTextures[count]
  end
  local shouldAnimate = hadVisibleBefore and hasVisibleNow and not (addon.IsPerformanceModeEnabled and addon:IsPerformanceModeEnabled())
  local pending = 0
  for i = 1, count do
    local btn = ui.icons[i]
    local tex = textures and textures[i] or nil
    local targetBaseX = ui._iconBaseX[i] or 0
    local sourceSlot = sourceSlotForTarget[i]

    if tex and tex ~= "" and shouldAnimate and sourceSlot and sourceSlot ~= i then
      btn._baseX = ui._iconBaseX[sourceSlot] or btn._baseX or targetBaseX
      if SetIconBaseX(ui, btn, targetBaseX, true) then
        pending = pending + 1
      end
    elseif tex and tex ~= "" and shouldAnimate and isFrontQueueShift and i == 1 and hadVisibleBefore then
      btn._baseX = -(ICON_SIZE + self:GetIconGap())
      if SetIconBaseX(ui, btn, targetBaseX, true) then
        pending = pending + 1
      end
      PlayFlowFadeIn(btn)
    else
      SetIconBaseX(ui, btn, targetBaseX, false)
    end
  end

  if removedTexture and removedTexture ~= "" then
    PlayFlowFadeOutGhost(ui, removedTexture, ui._iconBaseX[count] or 0)
  end

  if pending > 0 then
    ui._slidePending = pending
    StartManualSlideDriver(ui)
  else
    ui._slidePending = nil
    SyncIconLayout(ui)
    RevealPendingSequenceTextIfReady(ui)
  end

  self:RefreshPressedIndicator()
end

local function ResetRuntimeSpellHistoryState(ui)
  if not ui then return end

  ui._castsInCombat = 0
  ui._lastTextures = ui._lastTextures or {}
  clearArray(ui._lastTextures, 1)

  local recent = Tracker._recentIcons or addon._recentIcons or {}
  if API.wipe then
    API.wipe(recent)
  else
    clearArray(recent, 1)
  end

  Tracker._recentIcons = recent
  addon._recentIcons = recent
  Tracker._recentIconCount = 0
  addon._recentIconCount = 0
  Tracker._lastSpellID = false
  Tracker._lastSpellAt = 0
end

function UI:ClearSpellHistory()
  local ui = self.ui
  if not (ui and ui.icons) then return end
  ResetRuntimeSpellHistoryState(ui)
  if self.ApplyEditModeIconPreview and self:IsEditModePreviewActive() then
    StopManualSlideDriver(ui)
    ui._postSlideResyncFrames = nil
    if ui.iconHolder then
      ui.iconHolder:SetScript("OnUpdate", nil)
    end
    self:ApplyEditModeIconPreview(true)
    self:RefreshPressedIndicator(true)
    return
  end
  StopManualSlideDriver(ui)
  ui._postSlideResyncFrames = nil
  if ui.iconHolder then
    ui.iconHolder:SetScript("OnUpdate", nil)
  end
  for i = 1, #ui.icons do
    local btn = ui.icons[i]
    if btn and btn.tex then
      btn.tex:SetTexture("")
      btn.tex:SetColorTexture(0, 0, 0, 0)
      btn.tex:Hide()
    end
    if btn then btn:SetAlpha(0); btn:Hide() end
  end
  self:RefreshPressedIndicator(true)
end
