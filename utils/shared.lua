local _, ns = ...
local addon = ns
local Utils = ns.Utils or {}
ns.Utils = Utils
addon.Utils = Utils
local API = (ns.Utils and ns.Utils.API) or {}
local SV = (ns.Utils and ns.Utils.SV) or nil
local C = (ns.Utils and ns.Utils.Constants) or addon.Constants or {}
local uiShared = addon._ui or {}
addon._ui = uiShared

local PAD_X = 10
local PAD_TOP = 1
local PAD_BOTTOM = 7

local NAME_FONT_SIZE = 12
local MOD_FONT_SIZE = 8

local NAME_H = 24
local MODS_H = 14

local ICON_SIZE = 24
local DEFAULT_ICON_GAP = C.DEFAULT_ICON_GAP or 3

local TEXT_W = 140

local GAP_NAME_ICONS = 8
local GAP_ICONS_MODS = 6

local MIN_W = 180
local MAX_W = 480

local SCROLL_DUR = 0.55
local OLDEST_FADE_DUR = 0.50

local MOD_ALT_X_NUDGE = 2
local MOD_SHIFT_X_NUDGE = 2
local MOD_CTRL_X_NUDGE = 3

local MOD_FIXED_X_SPACING = (ICON_SIZE + DEFAULT_ICON_GAP)

local ADDON_DISPLAY_NAME = C.ADDON_DISPLAY_NAME or "|cFFFFFFFFGS|r|cFF00FFFFE:|r|cFFFFFF00 Tracker|r"

local function GetRootDefaults()
  if SV and SV.GetRootDefaults then
    local defaults = SV:GetRootDefaults()
    if type(defaults) == "table" then
      return defaults
    end
  end
  return nil
end


local ELEMENT_DEFAULTS = {
  sequenceText = { enabled = true,  point = "CENTER", relativeTo = "content", relativePoint = "CENTER", x = 0, y = 0 },
  modifiersText = { enabled = true, point = "CENTER", relativeTo = "content", relativePoint = "CENTER", x = 0, y = 0 },
  keybindText = { enabled = true,  point = "CENTER", relativeTo = "content", relativePoint = "CENTER", x = 0, y = 0 },
  pressedIndicator = { enabled = false, point = "CENTER", relativeTo = "content", relativePoint = "CENTER", x = 0, y = 0 },
}

local function Clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function EnsureDB()
  if SV and SV.EnsureDB then
    GSETrackerDB = SV:EnsureDB()
    return GSETrackerDB
  end

  GSETrackerDB = GSETrackerDB or {}
  return GSETrackerDB
end

local function RoundNearest(v)
  v = tonumber(v) or 0
  if v >= 0 then
    return math.floor(v + 0.5)
  end
  return math.ceil(v - 0.5)
end

local function GetPixelScale(frame)
  local f = frame or UIParent
  local scale = (f and f.GetEffectiveScale and f:GetEffectiveScale()) or 1
  if not scale or scale <= 0 then
    scale = 1
  end
  return scale
end

local function PixelSnap(v, frame)
  if v == nil then return 0 end
  local scale = GetPixelScale(frame)
  return math.floor((v * scale) + 0.5) / scale
end

local function IconRowWidth(count)
  count = Clamp(count or 4, 4, 8)
  local gap = addon:GetIconGap()
  return (count * ICON_SIZE) + ((count - 1) * gap)
end

local function GetPlayerClassColorRGB(fallbackR, fallbackG, fallbackB)
  local localizedClass, classFile
  if API.UnitClass then
    localizedClass, classFile = API.UnitClass("player")
  end

  local class = classFile or localizedClass
  local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
  local c = class and colors and colors[class]
  if c then
    return c.r, c.g, c.b
  end

  return fallbackR or 1, fallbackG or 1, fallbackB or 1
end

local function SetPointIfChanged(frame, point, anchor, relativePoint, x, y)
  if not frame then return end
  if frame._gsetrackerPoint == point
    and frame._gsetrackerAnchor == anchor
    and frame._gsetrackerRelativePoint == relativePoint
    and frame._gsetrackerPointX == x
    and frame._gsetrackerPointY == y then
    return
  end
  frame._gsetrackerPoint = point
  frame._gsetrackerAnchor = anchor
  frame._gsetrackerRelativePoint = relativePoint
  frame._gsetrackerPointX = x
  frame._gsetrackerPointY = y
  frame:ClearAllPoints()
  frame:SetPoint(point, anchor, relativePoint, x, y)
end

local function ClearTable(t)
  if type(t) ~= "table" then return end
  if API.wipe then
    API.wipe(t)
    return
  end
  for k in pairs(t) do
    t[k] = nil
  end
end

local function ClearArray(t, fromIndex)
  if type(t) ~= "table" then return end
  local startIndex = tonumber(fromIndex) or 1
  for i = #t, startIndex, -1 do
    t[i] = nil
  end
end

local function CopyArrayInto(dst, src, maxN)
  dst = dst or {}
  if type(dst) ~= "table" then dst = {} end
  local n = 0
  if type(src) == "table" then
    n = maxN or #src
    for i = 1, n do
      dst[i] = src[i]
    end
  end
  ClearArray(dst, n + 1)
  return dst
end

local function CopyArray(src, maxN, dst)
  return CopyArrayInto(dst, src, maxN)
end

uiShared.PAD_X = PAD_X
uiShared.PAD_TOP = PAD_TOP
uiShared.PAD_BOTTOM = PAD_BOTTOM
uiShared.NAME_FONT_SIZE = NAME_FONT_SIZE
uiShared.MOD_FONT_SIZE = MOD_FONT_SIZE
uiShared.NAME_H = NAME_H
uiShared.MODS_H = MODS_H
uiShared.ICON_SIZE = ICON_SIZE
uiShared.DEFAULT_ICON_GAP = DEFAULT_ICON_GAP
uiShared.TEXT_W = TEXT_W
uiShared.GAP_NAME_ICONS = GAP_NAME_ICONS
uiShared.GAP_ICONS_MODS = GAP_ICONS_MODS
uiShared.MIN_W = MIN_W
uiShared.MAX_W = MAX_W
uiShared.SCROLL_DUR = SCROLL_DUR
uiShared.OLDEST_FADE_DUR = OLDEST_FADE_DUR
uiShared.MOD_ALT_X_NUDGE = MOD_ALT_X_NUDGE
uiShared.MOD_SHIFT_X_NUDGE = MOD_SHIFT_X_NUDGE
uiShared.MOD_CTRL_X_NUDGE = MOD_CTRL_X_NUDGE
uiShared.MOD_FIXED_X_SPACING = MOD_FIXED_X_SPACING
uiShared.ADDON_DISPLAY_NAME = ADDON_DISPLAY_NAME
uiShared.GetRootDefaults = GetRootDefaults
uiShared.ELEMENT_DEFAULTS = ELEMENT_DEFAULTS
uiShared.Clamp = Clamp
uiShared.RoundNearest = RoundNearest
uiShared.EnsureDB = EnsureDB
uiShared.GetPixelScale = GetPixelScale
uiShared.PixelSnap = PixelSnap
uiShared.IconRowWidth = IconRowWidth
uiShared.GetPlayerClassColorRGB = GetPlayerClassColorRGB
uiShared.SetPointIfChanged = SetPointIfChanged
uiShared.ClearTable = ClearTable
uiShared.ClearArray = ClearArray
uiShared.CopyArrayInto = CopyArrayInto
uiShared.CopyArray = CopyArray

function Utils:IsPerformanceModeEnabled()
  if Utils.GetPerformanceModeEnabled then
    return Utils:GetPerformanceModeEnabled()
  end
  EnsureDB()
  local db = GSETrackerDB or {}
  local flags = type(db.flags) == "table" and db.flags or {}
  return flags.performanceMode and true or false
end

function Utils:SetPerformanceModeEnabled(enabled)
  if Utils.SetPerformanceModeEnabledCanonical then
    return Utils:SetPerformanceModeEnabledCanonical(enabled)
  end
  EnsureDB()
  GSETrackerDB = GSETrackerDB or {}
  GSETrackerDB.flags = GSETrackerDB.flags or {}
  GSETrackerDB.flags.performanceMode = not not enabled
end
