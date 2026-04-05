local _, ns = ...
local addon = ns
local Utils = ns.Utils
local C = Utils.Constants or addon.Constants or {}

-- LibSharedMedia font support. Users can extend the list through LSM packs,
-- but the addon keeps working with Blizzard defaults on its own.

local LSM = _G.LibStub and _G.LibStub:GetLibrary("LibSharedMedia-3.0", true)
addon.LSM = LSM
Utils.LSM = LSM

local FALLBACK_FONT_PATH = (type(_G.STANDARD_TEXT_FONT) == "string" and _G.STANDARD_TEXT_FONT ~= "" and _G.STANDARD_TEXT_FONT) or "Fonts\\FRIZQT__.TTF"
addon._fontRegistryVersion = addon._fontRegistryVersion or 0

addon.DEFAULT_SEQ_FONT = C.FONT_FRIZ or "Friz Quadrata TT"
addon.DEFAULT_MOD_FONT = C.FONT_FRIZ or "Friz Quadrata TT"
Utils.DEFAULT_SEQ_FONT = addon.DEFAULT_SEQ_FONT
Utils.DEFAULT_MOD_FONT = addon.DEFAULT_MOD_FONT

local LEGACY_KEY_TO_LSM_NAME = {
  STANDARD = C.FONT_FRIZ or "Friz Quadrata TT",
  FRIZQT__ = C.FONT_FRIZ or "Friz Quadrata TT",
  ARIALN   = C.FONT_ARIAL_NARROW or "Arial Narrow",
  MORPHEUS = C.FONT_MORPHEUS or "Morpheus",
  SKURRI   = C.FONT_SKURRI or "Skurri",
}

local function SafeFontPath(path)
  if type(path) ~= "string" then return nil end
  if path == "" then return nil end
  -- Normalize to backslashes. Some media packs use forward slashes,
  -- and WoW's SetFont can fail unless paths use backslashes.
  path = path:gsub("/", "\\")
  return path
end

function Utils:InitMedia()
  if not self.LSM then return end

  -- Ensure Blizzard fonts exist in the registry under predictable names.
  -- (LSM often registers defaults, but being explicit avoids edge cases.)
  self.LSM:Register("font", "Friz Quadrata TT", FALLBACK_FONT_PATH)
  self.LSM:Register("font", "Arial Narrow", "Fonts\\ARIALN.TTF")
  self.LSM:Register("font", "Morpheus", "Fonts\\MORPHEUS.TTF")
  self.LSM:Register("font", "Skurri", "Fonts\\SKURRI.TTF")

  -- Re-apply fonts if other addons register fonts after we load.
  -- This prevents the ActionTracker from sticking to the fallback font until next manual change.
  if self._lsmFontCallbackRegistered ~= true then
    self._lsmFontCallbackRegistered = true
    self.LSM.RegisterCallback(self, "LibSharedMedia_Registered", function(_, mediaType)
      if mediaType == "font" then
        addon._fontRegistryVersion = (addon._fontRegistryVersion or 0) + 1
        if addon.ApplyFontFaces then addon:ApplyFontFaces() end
        if addon.ApplyAssistedHighlightFont then addon:ApplyAssistedHighlightFont() end
        if addon.RefreshFontDropdowns then addon:RefreshFontDropdowns() end
      end
    end)
  end
end

local function IsLegacyKey(v)
  return type(v) == "string" and LEGACY_KEY_TO_LSM_NAME[v] ~= nil
end

function Utils:NormalizeFontName(fontName, fallbackName)
  -- Convert legacy key -> name
  if IsLegacyKey(fontName) then
    fontName = LEGACY_KEY_TO_LSM_NAME[fontName]
  end

  if type(fontName) ~= "string" or fontName == "" then
    fontName = nil
  end

  if IsLegacyKey(fallbackName) then
    fallbackName = LEGACY_KEY_TO_LSM_NAME[fallbackName]
  end

  if type(fallbackName) ~= "string" or fallbackName == "" then
    fallbackName = self.DEFAULT_SEQ_FONT
  end

  -- Do NOT validate against the current LSM registry here.
  -- Other addons may register fonts later in the load order; validating too early
  -- would incorrectly reset SavedVariables back to defaults on /reload.
  return fontName or fallbackName
end

function Utils:GetFontPathByName(fontName)
  -- Returns a file path suitable for SetFont.
  fontName = self:NormalizeFontName(fontName, self.DEFAULT_SEQ_FONT)

  if self.LSM and fontName then
    local p = self.LSM:Fetch("font", fontName, true)
    p = SafeFontPath(p)
    if p then return p end
  end

  return FALLBACK_FONT_PATH
end

function Utils:GetFontDropdownList()
  -- Returns a sorted array of font names.
  if self.LSM then
    local names = self.LSM:List("font")
    if type(names) == "table" and #names > 0 then
      table.sort(names)
      return names
    end
  end

  -- Fallback list (minimal)
  return {
    C.FONT_FRIZ or "Friz Quadrata TT",
    C.FONT_ARIAL_NARROW or "Arial Narrow",
    C.FONT_MORPHEUS or "Morpheus",
    C.FONT_SKURRI or "Skurri",
  }
end

function Utils:MaybeMigrateLegacyFontsInDB(db)
  if type(db) ~= "table" then return end

  if IsLegacyKey(db.seqFont) then
    db.seqFont = LEGACY_KEY_TO_LSM_NAME[db.seqFont] or self.DEFAULT_SEQ_FONT
  end
  if IsLegacyKey(db.modFont) then
    db.modFont = LEGACY_KEY_TO_LSM_NAME[db.modFont] or self.DEFAULT_MOD_FONT
  end
  if IsLegacyKey(db.keybindFont) then
    db.keybindFont = LEGACY_KEY_TO_LSM_NAME[db.keybindFont] or self.DEFAULT_MOD_FONT
  end

  local fonts = type(db.fonts) == "table" and db.fonts or nil
  local seq = fonts and type(fonts.sequence) == "table" and fonts.sequence or nil
  local mods = fonts and type(fonts.modifiers) == "table" and fonts.modifiers or nil
  local keybind = fonts and type(fonts.keybind) == "table" and fonts.keybind or nil

  if seq and IsLegacyKey(seq.face) then
    seq.face = LEGACY_KEY_TO_LSM_NAME[seq.face] or self.DEFAULT_SEQ_FONT
  end
  if mods and IsLegacyKey(mods.face) then
    mods.face = LEGACY_KEY_TO_LSM_NAME[mods.face] or self.DEFAULT_MOD_FONT
  end
  if keybind and IsLegacyKey(keybind.face) then
    keybind.face = LEGACY_KEY_TO_LSM_NAME[keybind.face] or self.DEFAULT_MOD_FONT
  end
end

if Utils and Utils.InitMedia then
  Utils:InitMedia()
end
