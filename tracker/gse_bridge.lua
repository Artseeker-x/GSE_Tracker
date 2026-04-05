local _, ns = ...
local addon = ns
local Tracker = ns.Tracker
local API = (ns.Utils and ns.Utils.API) or {}
local Compat = (ns.Utils and ns.Utils.Compat) or {}

local SafeHooksecurefunc = API.SafeHooksecurefunc or function() return false, nil end
local next = next
local pairs = pairs
local ipairs = ipairs
local pcall = pcall
local rawget = rawget
local type = type

local hookedButtons = {}
local pendingButtons = {}
local buttonActions = {}
local bindingTextBuffer = { false, false }

local seqObjCache = {}
local cacheLib = nil
local function EnsureSeqCache(lib)
  if lib ~= cacheLib then
    cacheLib = lib
    seqObjCache = {}
  end
end

local lateProbeStarted = false
local lateProbeFrame = nil
local bindingEventFrame = Tracker._bindingEventFrame or API.CreateFrame("Frame")
Tracker._bindingEventFrame = bindingEventFrame
local StartLateProbe
local StopLateProbe
local GetSortedStringKeys
local LATE_PROBE_INTERVAL = 0.25
local LATE_PROBE_MAX_TRIES = 40
local lateProbeElapsed = 0
local lateProbeTries = 0

local function GetLibrary()
  local GSE = _G.GSE
  local lib = GSE and rawget(GSE, "Library")
  return (type(lib) == "table") and lib or nil
end

local function GetUsedSequences()
  local GSE = _G.GSE
  local used = GSE and rawget(GSE, "UsedSequences")
  return (type(used) == "table") and used or nil
end

local function FindSequenceObject(seqKey)
  if type(seqKey) ~= "string" or seqKey == "" then return nil end

  local lib = GetLibrary()
  if not lib then return nil end
  EnsureSeqCache(lib)

  local cached = seqObjCache[seqKey]
  if cached then return cached end

  for _, bucket in pairs(lib) do
    if type(bucket) == "table" then
      local seq = rawget(bucket, seqKey)
      if type(seq) == "table" then
        seqObjCache[seqKey] = seq
        return seq
      end
    end
  end

  local direct = rawget(lib, seqKey)
  if type(direct) == "table" then
    seqObjCache[seqKey] = direct
    return direct
  end

  return nil
end

local function IsValidSequenceKey(seqKey)
  return FindSequenceObject(seqKey) ~= nil
end

local function GetPrettyName(seqKey)
  local seq = FindSequenceObject(seqKey)
  if not seq then return seqKey end

  local md = rawget(seq, "MetaData") or rawget(seq, "metadata")
  if type(md) == "table" then
    local name = rawget(md, "Name") or rawget(md, "name")
    if type(name) == "string" and name ~= "" then
      return name
    end
  end

  return seqKey
end

local function RegisterButtonAction(buttonName, clickButton)
  if type(buttonName) ~= "string" or buttonName == "" then return end
  clickButton = (type(clickButton) == "string" and clickButton ~= "") and clickButton or "LeftButton"
  local action = "CLICK " .. buttonName .. ":" .. clickButton
  local actions = buttonActions[buttonName]
  if not actions then
    actions = {}
    buttonActions[buttonName] = actions
  end
  actions[action] = true
end

local function RefreshActiveSequenceBindingText(seqKey)
  if not (addon.SetKeybindText and addon.GetActiveSequenceBindingText) then
    return
  end

  seqKey = seqKey or addon._activeSeqKey
  if type(seqKey) ~= "string" or seqKey == "" then
    return
  end

  addon:SetKeybindText(addon:GetActiveSequenceBindingText(seqKey) or "")
end

local function SetActiveSequence(seqKey, buttonName)
  if not IsValidSequenceKey(seqKey) then return end

  if type(buttonName) == "string" and buttonName ~= "" then
    addon._activeButtonName = buttonName
  end

  if addon._activeSeqKey ~= seqKey then
    addon._activeSeqKey = seqKey
    addon._gseActive = true
    addon._lastGSEPressTime = API.GetTime()

    if addon.ResetIcons then
      addon:ResetIcons()
    end

    if addon.SetSequenceText then
      addon:SetSequenceText(GetPrettyName(seqKey), nil, nil, seqKey)
    end
    if addon.RefreshPressedIndicator then
      addon:RefreshPressedIndicator(true)
    end
  else
    addon._lastGSEPressTime = API.GetTime()
    local sequenceTextRefreshed = false

    if addon.SetSequenceText and addon.ui and addon.ui.nameText and addon._activeSeqKey == seqKey then
      local cur = addon.ui.nameText:GetText()
      local alpha = addon.ui.nameText.GetAlpha and addon.ui.nameText:GetAlpha() or 1
      if not cur or cur == "" or alpha == 0 then
        addon:SetSequenceText(GetPrettyName(seqKey), nil, nil, seqKey)
        sequenceTextRefreshed = true
      end
    end
    if not sequenceTextRefreshed then
      RefreshActiveSequenceBindingText(seqKey)
    end
    if addon.RefreshPressedIndicator then
      addon:RefreshPressedIndicator(true)
    end
  end
end

local FIELD_KEYS = {
  "GSESequence",
  "Sequence",
  "name",
}

local ATTR_KEYS = {
  "GSESequence",
  "Sequence",
  "name",
}

local function TryGetField(btn, key)
  local v = rawget(btn, key)
  if type(v) == "string" and v ~= "" then
    return v
  end
end

local function TryGetAttribute(btn, attr)
  if not (btn and btn.GetAttribute) then return nil end
  local ok, v = pcall(btn.GetAttribute, btn, attr)
  if ok and type(v) == "string" and v ~= "" then
    return v
  end
end

local function TryResolveUsedSequence(buttonName)
  if type(buttonName) ~= "string" or buttonName == "" then return nil end

  local used = GetUsedSequences()
  local entry = used and rawget(used, buttonName) or nil
  if type(entry) == "string" and IsValidSequenceKey(entry) then
    return entry
  end

  if type(entry) == "table" then
    local candidates = {
      rawget(entry, "Sequence"),
      rawget(entry, "sequence"),
      rawget(entry, "GSESequence"),
      rawget(entry, "Name"),
      rawget(entry, "name"),
      rawget(entry, "Macro"),
      rawget(entry, "macro"),
      rawget(entry, 1),
    }
    for i = 1, #candidates do
      local candidate = candidates[i]
      if type(candidate) == "string" and candidate ~= "" and IsValidSequenceKey(candidate) then
        return candidate
      end
    end
  end

  return nil
end

local function ResolveSequenceKey(btn)
  if not btn then return nil end

  for _, key in ipairs(FIELD_KEYS) do
    local v = TryGetField(btn, key)
    if v and IsValidSequenceKey(v) then
      return v
    end
  end

  for _, attr in ipairs(ATTR_KEYS) do
    local v = TryGetAttribute(btn, attr)
    if v and IsValidSequenceKey(v) then
      return v
    end
  end

  local buttonName = btn and btn.GetName and btn:GetName() or nil
  local usedSeq = TryResolveUsedSequence(buttonName)
  if usedSeq then
    return usedSeq
  end

  return nil
end

local function HookButton(buttonName)
  if hookedButtons[buttonName] then return end

  local btn = _G[buttonName]
  if not btn or not btn.HookScript then return end

  btn:HookScript("PostClick", function(self)
    local seqKey = ResolveSequenceKey(self)
    if seqKey then
      SetActiveSequence(seqKey, self and self.GetName and self:GetName() or nil)
    end
  end)

  hookedButtons[buttonName] = true
  pendingButtons[buttonName] = nil
end

local function RememberButton(buttonName, clickButton)
  if type(buttonName) ~= "string" or buttonName == "" then return end
  RegisterButtonAction(buttonName, clickButton)
  if hookedButtons[buttonName] then return end

  HookButton(buttonName)
  if hookedButtons[buttonName] then
    pendingButtons[buttonName] = nil
    return
  end

  pendingButtons[buttonName] = true
  if not lateProbeStarted then
    StartLateProbe()
  end
end

local function HookBindingAPIs()
  if addon.__BridgeBindingHooks then return end
  addon.__BridgeBindingHooks = true

  local ok1 = SafeHooksecurefunc("SetOverrideBindingClick", function(_, _, _, buttonName, clickButton)
    RememberButton(buttonName, clickButton)
  end)

  local ok2 = SafeHooksecurefunc("SetBindingClick", function(_, buttonName, clickButton)
    RememberButton(buttonName, clickButton)
  end)

  if Compat and Compat.IsCompatibilityMode and Compat:IsCompatibilityMode() and (not ok1 or not ok2) and addon.Debug then
    addon:Debug("Compatibility: one or more binding hooks were unavailable; late button detection remains enabled.")
  end
end

local function LateProbeOnUpdate(_, dt)
  lateProbeElapsed = lateProbeElapsed + dt
  if lateProbeElapsed < LATE_PROBE_INTERVAL then return end
  lateProbeElapsed = 0
  lateProbeTries = lateProbeTries + 1

  if next(pendingButtons) == nil then
    StopLateProbe(false)
    return
  end

  for buttonName in pairs(pendingButtons) do
    HookButton(buttonName)
  end

  if next(pendingButtons) == nil then
    StopLateProbe(false)
    return
  end

  if lateProbeTries >= LATE_PROBE_MAX_TRIES then
    StopLateProbe(true)
  end
end

StopLateProbe = function(clearPending)
  if lateProbeFrame then
    lateProbeFrame:SetScript("OnUpdate", nil)
  end
  lateProbeStarted = false

  if clearPending then
    for buttonName in pairs(pendingButtons) do
      pendingButtons[buttonName] = nil
    end
  end
end

StartLateProbe = function()
  if lateProbeStarted or next(pendingButtons) == nil then return end
  lateProbeStarted = true
  lateProbeElapsed = 0
  lateProbeTries = 0
  lateProbeFrame = lateProbeFrame or API.CreateFrame("Frame")
  lateProbeFrame:SetScript("OnUpdate", LateProbeOnUpdate)
end

local function ScanExistingBindings()
  if type(GetNumBindings) == "function" and type(GetBinding) == "function" then
    local numBindings = GetNumBindings() or 0
    for i = 1, numBindings do
      local command = GetBinding(i)
      if type(command) == "string" then
        local buttonName, clickButton = command:match("^CLICK%s+([^:]+):(.+)$")
        if buttonName and buttonName ~= "" then
          RememberButton(buttonName, clickButton)
        end
      end
    end
  end

  local used = GetUsedSequences()
  if used then
    local buttonNames = {}
    for buttonName in pairs(used) do
      if type(buttonName) == "string" and buttonName ~= "" then
        buttonNames[#buttonNames + 1] = buttonName
      end
    end
    table.sort(buttonNames)

    for i = 1, #buttonNames do
      RememberButton(buttonNames[i])
    end
  end
end

local function ResolveButtonNameForSequence(seqKey, currentButtonName)
  if type(seqKey) ~= "string" or seqKey == "" then
    return nil
  end

  local used = GetUsedSequences()
  local hasUsedSequences = type(used) == "table" and next(used) ~= nil
  if not hasUsedSequences then
    return currentButtonName
  end

  if type(currentButtonName) == "string" and currentButtonName ~= "" and TryResolveUsedSequence(currentButtonName) == seqKey then
    RememberButton(currentButtonName)
    return currentButtonName
  end

  local buttonNames = GetSortedStringKeys(used)
  for i = 1, #buttonNames do
    local buttonName = buttonNames[i]
    if TryResolveUsedSequence(buttonName) == seqKey then
      RememberButton(buttonName)
      return buttonName
    end
  end

  if type(currentButtonName) == "string" and currentButtonName ~= "" then
    -- Keep the last known active button when GSE's UsedSequences table does not
    -- expose a resolvable mapping yet. A stale keybind is better than blanking
    -- the ActionTracker in combat, and the next successful resolution will still resync it.
    RememberButton(currentButtonName)
    return currentButtonName
  end

  return nil
end

local function BindingEventOnEvent(_, event, arg1)
  if event == "UPDATE_BINDINGS" then
    -- Rebuild the current binding-action map from live bindings so stale commands
    -- do not accumulate across repeated rebinding during long sessions.
    buttonActions = {}
    ScanExistingBindings()
    RefreshActiveSequenceBindingText()
    return
  end

  if event == "ADDON_LOADED" and arg1 == "GSE" then
    -- Without an OptionalDeps ordering guarantee, rescan as soon as GSE finishes
    -- loading so existing buttons and UsedSequences are picked up immediately.
    ScanExistingBindings()
    RefreshActiveSequenceBindingText()
  end
end

local function NormalizeBindingKey(key)
  if type(key) ~= "string" then return nil end
  key = key:gsub("ALT%-", "A-")
  key = key:gsub("CTRL%-", "C-")
  key = key:gsub("SHIFT%-", "S-")
  key = key:gsub("NUMPAD", "NP")
  key = key:gsub("BUTTON(%d+)", "MB%1")
  key = key:gsub("MOUSEWHEELUP", "MWU")
  key = key:gsub("MOUSEWHEELDOWN", "MWD")
  key = key:gsub("SPACE", "SPC")
  return key
end

GetSortedStringKeys = function(map)
  if type(map) ~= "table" then
    return {}
  end

  local keys = {}
  for key in pairs(map) do
    if type(key) == "string" and key ~= "" then
      keys[#keys + 1] = key
    end
  end
  table.sort(keys)
  return keys
end

function Tracker:GetButtonBindingText(buttonName)
  if type(buttonName) ~= "string" or buttonName == "" then return nil end

  local actions = buttonActions[buttonName]
  local action = nil
  if actions and type(GetBindingKey) == "function" then
    local candidates = GetSortedStringKeys(actions)
    for i = 1, #candidates do
      local candidate = candidates[i]
      local key1, key2 = GetBindingKey(candidate)
      if key1 or key2 then
        action = candidate
        break
      end
    end

    if not action then
      action = candidates[1]
    end
  end

  if not action then
    action = "CLICK " .. buttonName .. ":LeftButton"
  end

  if type(GetBindingKey) ~= "function" then
    return nil
  end

  local key1, key2 = GetBindingKey(action)
  key1 = (key1 and key1 ~= "") and (NormalizeBindingKey(key1) or key1) or nil
  key2 = (key2 and key2 ~= "") and (NormalizeBindingKey(key2) or key2) or nil
  if not key1 then return key2 end
  if not key2 then return key1 end
  bindingTextBuffer[1] = key1
  bindingTextBuffer[2] = key2
  return table.concat(bindingTextBuffer, " / ", 1, 2)
end

function Tracker:GetActiveSequenceBindingText(seqKey)
  if seqKey and seqKey ~= self._activeSeqKey then return nil end

  if self._activeSeqKey then
    self._activeButtonName = ResolveButtonNameForSequence(self._activeSeqKey, self._activeButtonName)
  end

  return self:GetButtonBindingText(self._activeButtonName)
end

function Tracker:GetActiveSequenceDisplayText(seqKey)
  seqKey = seqKey or self._activeSeqKey
  if type(seqKey) ~= "string" or seqKey == "" then
    return nil
  end
  if not IsValidSequenceKey(seqKey) then
    return nil
  end
  local displayName = GetPrettyName(seqKey)
  if type(displayName) == "string" and displayName ~= "" then
    return displayName
  end
  return nil
end

function Tracker:InitGSEBridge()
  HookBindingAPIs()
  ScanExistingBindings()
  if bindingEventFrame then
    bindingEventFrame:UnregisterAllEvents()
    API.SafeRegisterEvent(bindingEventFrame, "UPDATE_BINDINGS")
    API.SafeRegisterEvent(bindingEventFrame, "ADDON_LOADED")
    API.SafeSetScript(bindingEventFrame, "OnEvent", BindingEventOnEvent)
  end
end
