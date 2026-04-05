local _, ns = ...
local addon = ns
local UI = ns.UI
local API = (ns.Utils and ns.Utils.API) or {}
local C = (ns.Utils and ns.Utils.Constants) or addon.Constants or {}
local GameTooltip = _G.GameTooltip
local ICON_TEXTURE = "Interface\\AddOns\\GSE_Tracker\\media\\GSE_Tracker.png"
local BUTTON_NAME = "GSE_TrackerMinimapButton"
local BUTTON_SIZE = 32
local ICON_SIZE = 20
local BACKGROUND_SIZE = 20
local BORDER_SIZE = 53
local DEFAULT_ANGLE = 225
local DRAG_BUTTON = "RightButton"
local TOOLTIP_TITLE_FALLBACK = (C.ADDON_DISPLAY_NAME or "|cFFFFFFFFGS|r|cFF00FFFFE:|r|cFFFFFF00 Tracker|r")
local ICON_MASK = C.MASK_CIRCLE or "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local MINIMAP_SHAPES = {
  ROUND = { true, true, true, true },
  SQUARE = { false, false, false, false },
  ["CORNER-TOPLEFT"] = { false, false, false, true },
  ["CORNER-TOPRIGHT"] = { false, false, true, false },
  ["CORNER-BOTTOMLEFT"] = { false, true, false, false },
  ["CORNER-BOTTOMRIGHT"] = { true, false, false, false },
  ["SIDE-LEFT"] = { false, true, false, true },
  ["SIDE-RIGHT"] = { true, false, true, false },
  ["SIDE-TOP"] = { false, false, true, true },
  ["SIDE-BOTTOM"] = { true, true, false, false },
  ["TRICORNER-TOPLEFT"] = { false, true, true, true },
  ["TRICORNER-TOPRIGHT"] = { true, false, true, true },
  ["TRICORNER-BOTTOMLEFT"] = { true, true, false, true },
  ["TRICORNER-BOTTOMRIGHT"] = { true, true, true, false },
}

local function NormalizeAngle(value)
  local angle = tonumber(value)
  if angle == nil then
    angle = DEFAULT_ANGLE
  end
  angle = angle % 360
  if angle < 0 then
    angle = angle + 360
  end
  return angle
end

local function Atan2(y, x)
  if x > 0 then
    return math.atan(y / x)
  elseif x < 0 and y >= 0 then
    return math.atan(y / x) + math.pi
  elseif x < 0 and y < 0 then
    return math.atan(y / x) - math.pi
  elseif x == 0 and y > 0 then
    return math.pi * 0.5
  elseif x == 0 and y < 0 then
    return -(math.pi * 0.5)
  end
  return 0
end

local function GetMinimapFrame()
  return _G.Minimap
end

local function GetSavedAngle()
  if addon.GetMinimapAngle then
    return NormalizeAngle(addon:GetMinimapAngle())
  end
  return DEFAULT_ANGLE
end

local function SaveAngle(value)
  if addon.SetMinimapAngle then
    addon:SetMinimapAngle(NormalizeAngle(value))
  end
end

local function GetRadius(minimap)
  local width = minimap and minimap.GetWidth and minimap:GetWidth() or 140
  local size = tonumber(width) or 140
  return math.max(45, math.floor((size * 0.5) - 10))
end

local function ApplyPosition(button, angle)
  local minimap = button and button:GetParent()
  if not minimap then return end
  angle = NormalizeAngle(angle)
  local radians = math.rad(angle)
  local unitX = math.cos(radians)
  local unitY = math.sin(radians)
  local quadrant = 1
  if unitX < 0 then quadrant = quadrant + 1 end
  if unitY > 0 then quadrant = quadrant + 2 end

  local getMinimapShape = _G.GetMinimapShape
  local shape = (type(getMinimapShape) == "function" and tostring(getMinimapShape() or "ROUND")) or "ROUND"
  local quadTable = MINIMAP_SHAPES[shape] or MINIMAP_SHAPES.ROUND
  local width = (minimap.GetWidth and minimap:GetWidth()) or 140
  local height = (minimap.GetHeight and minimap:GetHeight()) or 140
  local halfWidth = (tonumber(width) or 140) * 0.5
  local halfHeight = (tonumber(height) or 140) * 0.5
  local radius = GetRadius(minimap)
  local x, y

  if quadTable[quadrant] then
    x = unitX * radius
    y = unitY * radius
  else
    local squareRadius = math.sqrt(2 * (radius ^ 2)) - 10
    x = math.max(-halfWidth, math.min(unitX * squareRadius, halfWidth))
    y = math.max(-halfHeight, math.min(unitY * squareRadius, halfHeight))
  end

  button:ClearAllPoints()
  button:SetPoint("CENTER", minimap, "CENTER", x, y)
  button._angle = angle
end

local function GetCursorAngle(button)
  local minimap = button and button:GetParent()
  if not minimap then return nil end
  local centerX, centerY = minimap:GetCenter()
  if not (centerX and centerY) then return nil end

  local cursorX, cursorY = API.GetCursorPosition()
  local scale = API.GetEffectiveScale(minimap)
  if scale and scale > 0 then
    cursorX = cursorX / scale
    cursorY = cursorY / scale
  end

  local deltaX = cursorX - centerX
  local deltaY = cursorY - centerY
  if deltaX == 0 and deltaY == 0 then
    return nil
  end

  return NormalizeAngle(math.deg(Atan2(deltaY, deltaX)))
end

local function UpdateTooltip(button)
  if not GameTooltip then return end
  local title = TOOLTIP_TITLE_FALLBACK
  if API.GetAddOnMetadata then
    title = API.GetAddOnMetadata(addon.name, "Title") or title
  end
  GameTooltip:SetOwner(button, "ANCHOR_LEFT")
  GameTooltip:SetText(title)
  GameTooltip:AddLine("Left Click: |cffffff00Open settings|r", 0.85, 0.85, 0.85)
  GameTooltip:AddLine("Right Drag: |cffffff00Move button|r", 0.85, 0.85, 0.85)
  GameTooltip:Show()
end

local function MinimapDragOnUpdate(button)
  local angle = GetCursorAngle(button)
  if angle == nil then return end
  button._pendingAngle = angle
  ApplyPosition(button, angle)
end

function UI:BeginMinimapButtonDrag(button)
  if not button then return end
  button._pendingAngle = button._angle or GetSavedAngle()
  button:SetScript("OnUpdate", MinimapDragOnUpdate)
end

function UI:EndMinimapButtonDrag(button)
  if not button then return end
  button:SetScript("OnUpdate", nil)
  local angle = NormalizeAngle(button._pendingAngle or button._angle or GetSavedAngle())
  button._pendingAngle = nil
  SaveAngle(angle)
  ApplyPosition(button, angle)
end

function UI:RefreshMinimapButton()
  local button = self.minimapButton
  if not button then
    self:EnsureMinimapButton()
    button = self.minimapButton
  end
  if not button then return end
  ApplyPosition(button, GetSavedAngle())
  button:Show()
end

function UI:EnsureMinimapButton()
  if self.minimapButton then
    self:RefreshMinimapButton()
    return self.minimapButton
  end

  local minimap = GetMinimapFrame()
  if not minimap then return nil end

  local button = _G[BUTTON_NAME]
  if not button then
    button = API.CreateFrame("Button", BUTTON_NAME, minimap)
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetFrameStrata(minimap:GetFrameStrata() or "MEDIUM")
    button:SetFrameLevel((minimap:GetFrameLevel() or 0) + 8)
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag(DRAG_BUTTON)

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(BACKGROUND_SIZE, BACKGROUND_SIZE)
    background:SetPoint("CENTER", button, "CENTER", 0, 0)
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetTexCoord(0, 1, 0, 1)
    button.background = background

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    icon:SetTexture(ICON_TEXTURE)
    icon:SetTexCoord(0.10, 0.90, 0.10, 0.90)
    if button.CreateMaskTexture then
      local mask = button:CreateMaskTexture(nil, "ARTWORK")
      mask:SetTexture(ICON_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
      mask:SetPoint("CENTER", icon, "CENTER", 0, 0)
      mask:SetSize(ICON_SIZE, ICON_SIZE)
      if icon.AddMaskTexture then
        icon:AddMaskTexture(mask)
      end
      button.iconMask = mask
    end
    button.icon = icon

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(BORDER_SIZE, BORDER_SIZE)
    border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button.border = border

    button:SetScript("OnClick", function(_, mouseButton)
      if mouseButton ~= "LeftButton" then return end
      if addon.OpenSettingsWindow then
        addon:OpenSettingsWindow()
      elseif addon.ToggleSettingsWindow then
        addon:ToggleSettingsWindow()
      end
    end)

    button:SetScript("OnDragStart", function(selfButton)
      addon:BeginMinimapButtonDrag(selfButton)
    end)

    button:SetScript("OnDragStop", function(selfButton)
      addon:EndMinimapButtonDrag(selfButton)
    end)

    button:SetScript("OnEnter", function(selfButton)
      UpdateTooltip(selfButton)
    end)

    button:SetScript("OnLeave", function()
      if GameTooltip then
        GameTooltip:Hide()
      end
    end)
  end

  self.minimapButton = button
  self:RefreshMinimapButton()
  return button
end
