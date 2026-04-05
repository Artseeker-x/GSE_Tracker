local _, ns = ...
local Utils = ns.Utils or {}
ns.Utils = Utils
local C = Utils.Constants or ns.Constants or {}

local DebugModule = Utils.DebugModule or {}
Utils.DebugModule = DebugModule

local PREFIX = C.ADDON_DISPLAY_NAME or "|cFFFFFFFFGS|r|cFF00FFFFE:|r|cFFFFFF00 Tracker|r"
local noop = function() end

local function GetDB()
  local SV = Utils.SV
  if SV and SV.EnsureDB then
    return SV:EnsureDB()
  end
  _G.GSETrackerDB = _G.GSETrackerDB or {}
  return _G.GSETrackerDB
end

local function PrintChat(message)
  if not message or message == "" then
    return
  end

  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. " " .. message)
  elseif print then
    print("GSE Tracker", message)
  end
end

local function BuildMessage(...)
  local n = select("#", ...)
  if n == 0 then return "" end

  local out = DebugModule._scratch or {}
  DebugModule._scratch = out

  for i = 1, n do
    out[i] = tostring(select(i, ...))
  end
  for i = n + 1, #out do
    out[i] = nil
  end

  return table.concat(out, " ", 1, n)
end

function DebugModule:Print(...)
  local msg = BuildMessage(...)
  if msg == "" then return end
  PrintChat(msg)
end

local function activeLogger(...)
  DebugModule:Print(...)
end

function DebugModule:ApplyRuntimeState(enabled)
  enabled = not not enabled
  self.enabled = enabled
  ns.Debug = enabled and activeLogger or noop
  Utils.Debug = ns.Debug

  local API = Utils.API
  if API and API.SetDebug then
    API.SetDebug(enabled, enabled and function(methodName, ...)
      DebugModule:Print("[API]", methodName, ...)
    end or nil)
  end
end

function DebugModule:IsEnabled()
  return self.enabled == true
end

function DebugModule:SetEnabled(enabled)
  local db = GetDB()
  db.flags = type(db.flags) == "table" and db.flags or {}
  db.flags.debug = not not enabled
  self:ApplyRuntimeState(db.flags.debug)
  return db.flags.debug
end

function DebugModule:HandleSlashCommand(msg)
  msg = type(msg) == "string" and msg:lower():match("^%s*(.-)%s*$") or ""

  if msg == "debug" then
    local enabled = not self:IsEnabled()
    self:SetEnabled(enabled)
    PrintChat(enabled and "Debug mode enabled." or "Debug mode disabled.")
    return
  end

  if msg == "debug on" then
    self:SetEnabled(true)
    PrintChat("Debug mode enabled.")
    return
  end

  if msg == "debug off" then
    self:SetEnabled(false)
    PrintChat("Debug mode disabled.")
    return
  end

  if ns.ToggleSettingsWindow then
    ns:ToggleSettingsWindow()
  end
end

function DebugModule:RegisterSlashCommands()
  if self._slashRegistered then
    return
  end

  SLASH_GSETRACKER1 = "/gsetracker"
  SLASH_GSETRACKER2 = "/gsetrackersettings"
  SlashCmdList.GSETRACKER = function(msg)
    self:HandleSlashCommand(msg)
  end

  self._slashRegistered = true
end

function DebugModule:Init()
  local db = GetDB()
  self:RegisterSlashCommands()
  self:ApplyRuntimeState(type(db.flags) == "table" and db.flags.debug == true)
end

ns.IsDebugEnabled = function()
  return DebugModule:IsEnabled()
end

ns.SetDebugEnabled = function(_, enabled)
  return DebugModule:SetEnabled(enabled)
end

Utils.IsDebugEnabled = ns.IsDebugEnabled
Utils.SetDebugEnabled = ns.SetDebugEnabled

if ns.Debug == nil then
  ns.Debug = noop
end
if Utils.Debug == nil then
  Utils.Debug = ns.Debug
end
