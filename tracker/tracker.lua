local _, ns = ...
local addon = ns
local Tracker = ns.Tracker
local API = (ns.Utils and ns.Utils.API) or {}

local frame = Tracker._eventFrame or API.CreateFrame("Frame")
Tracker._eventFrame = frame

local DUPLICATE_SPELL_WINDOW = 0.05
local TEXTURE_CACHE_MAX = 256

local function TrackerEventOnEvent(_, _, unitTarget, _, spellID)
  if not spellID then
    return
  end

  if frame._unitSpellcastFiltered then
    if unitTarget ~= "player" then
      return
    end
  elseif unitTarget and unitTarget ~= "player" then
    return
  end

  if not API.InCombatLockdown() then
    return
  end

  Tracker:HandleSpellcast(spellID)
end

addon._recentIcons = addon._recentIcons or {}
Tracker._recentIcons = addon._recentIcons
Tracker._recentIconCount = Tracker._recentIconCount or 0
Tracker._textureCache = Tracker._textureCache or {}
Tracker._textureCacheCount = Tracker._textureCacheCount or 0
Tracker._lastSpellID = Tracker._lastSpellID or false
Tracker._lastSpellAt = Tracker._lastSpellAt or 0

local function GetMaxIconCount()
  local count = (addon.GetIconCount and addon:GetIconCount()) or 4
  if count < 4 then
    return 4
  end
  return count
end

local function GetSpellTextureByID(spellID)
  if not spellID then
    return nil
  end

  local cache = Tracker._textureCache
  local cached = cache[spellID]
  if cached then
    return cached
  end

  local tex = API.GetSpellTexture(spellID)
  if tex then
    local count = Tracker._textureCacheCount or 0
    if count >= TEXTURE_CACHE_MAX then
      if API.wipe then
        API.wipe(cache)
      else
        for key in pairs(cache) do
          cache[key] = nil
        end
      end
      count = 0
    end
    cache[spellID] = tex
    Tracker._textureCacheCount = count + 1
  end
  return tex or nil
end

function Tracker:ResetIcons()
  local recent = self._recentIcons or addon._recentIcons or {}
  self._recentIcons = recent
  addon._recentIcons = recent

  local hadIcons = (self._recentIconCount or 0) > 0 or recent[1] ~= nil

  self._recentIconCount = 0
  addon._recentIconCount = 0
  self._lastSpellID = false
  self._lastSpellAt = 0

  if API.wipe then
    API.wipe(recent)
  else
    for i = #recent, 1, -1 do
      recent[i] = nil
    end
  end

  if not hadIcons then
    return
  end

  if addon.ClearSpellHistory then
    addon:ClearSpellHistory()
  elseif addon.SetIconRow then
    addon:SetIconRow(recent)
  end
end

function Tracker:PushRecentTexture(texture)
  if not texture then
    return false
  end

  local setIconRow = addon.SetIconRow
  if not setIconRow then
    return false
  end

  local recent = self._recentIcons or addon._recentIcons or {}
  self._recentIcons = recent
  addon._recentIcons = recent

  local maxCount = GetMaxIconCount()
  local currentCount = self._recentIconCount or #recent
  if currentCount > maxCount then
    currentCount = maxCount
  end

  for i = currentCount, 1, -1 do
    if i < maxCount then
      recent[i + 1] = recent[i]
    end
  end
  recent[1] = texture

  if currentCount < maxCount then
    currentCount = currentCount + 1
  end
  self._recentIconCount = currentCount
  addon._recentIconCount = currentCount

  for i = currentCount + 1, #recent do
    recent[i] = nil
  end

  setIconRow(addon, recent)
  return true
end

function Tracker:HandleSpellcast(spellID)
  if not spellID then
    return false
  end

  local now = API.GetTime()
  local lastSpellID = self._lastSpellID
  if lastSpellID == spellID and (now - (self._lastSpellAt or 0)) <= DUPLICATE_SPELL_WINDOW then
    return false
  end

  local texture = GetSpellTextureByID(spellID)
  if not texture then
    return false
  end

  self._lastSpellID = spellID
  self._lastSpellAt = now

  return self:PushRecentTexture(texture)
end

function Tracker:InitTracker()
  frame:UnregisterAllEvents()
  local registered, unitFiltered = API.SafeRegisterUnitEvent(frame, "UNIT_SPELLCAST_SUCCEEDED", "player")
  frame._unitSpellcastFiltered = unitFiltered and true or false

  if not registered then
    API.SafeSetScript(frame, "OnEvent", nil)
    return
  end

  API.SafeSetScript(frame, "OnEvent", TrackerEventOnEvent)
end
