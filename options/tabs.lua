local _, ns = ...
local API = (ns.Utils and ns.Utils.API) or {}
local Options = ns.Options
local optionsModule = Options

local TAB_HEIGHT = optionsModule.TAB_HEIGHT or 34
local TAB_GAP = optionsModule.TAB_GAP or 2

local function SetTabVisual(button, selected)
  if not button then return end
  local r, g, b = optionsModule.GetClassColor()

  if button._gseBg then
    if selected then
      button._gseBg:SetVertexColor(0.036, 0.040, 0.045, 0.98)
    else
      button._gseBg:SetVertexColor(0.020, 0.023, 0.027, 0.94)
    end
  end

  if button._gseInner then
    if selected then
      button._gseInner:SetVertexColor(0.06, 0.065, 0.070, 0.05)
    else
      button._gseInner:SetVertexColor(0.028, 0.032, 0.036, 0.03)
    end
  end

  if button._gseGlow then
    button._gseGlow:SetVertexColor(r, g, b, selected and 0.03 or 0)
  end

  if button._gseAccent then
    button._gseAccent:SetVertexColor(r, g, b, selected and 0.92 or 0)
  end

  if button._gseLabel then
    if selected then
      button._gseLabel:SetTextColor(0.97, 0.97, 0.97)
    else
      button._gseLabel:SetTextColor(0.62, 0.62, 0.64)
    end
  end

  if button._gseSubtitle then
    button._gseSubtitle:SetShown(false)
  end

  if button._gsePill then
    button._gsePill:SetShown(false)
  end

  if button._gseBorder then
    for _, tex in ipairs(button._gseBorder) do
      if selected then
        tex:SetVertexColor(r, g, b, 0.42)
      else
        tex:SetVertexColor(0.15, 0.15, 0.16, 1)
      end
    end
  end
end

function optionsModule.CreateTopTab(parent, key, text, subtitle)
  local button = API.CreateFrame("Button", nil, parent)
  button:SetHeight(TAB_HEIGHT)
  button.tabKey = key

  local bg = button:CreateTexture(nil, "BACKGROUND")
  bg:SetTexture("Interface\\Buttons\\WHITE8x8")
  bg:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
  bg:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
  button._gseBg = bg

  local inner = button:CreateTexture(nil, "BORDER")
  inner:SetTexture("Interface\\Buttons\\WHITE8x8")
  inner:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
  inner:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
  button._gseInner = inner

  local glow = button:CreateTexture(nil, "BORDER")
  glow:SetTexture("Interface\\Buttons\\WHITE8x8")
  glow:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
  glow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
  button._gseGlow = glow

  local accent = button:CreateTexture(nil, "ARTWORK")
  accent:SetTexture("Interface\\Buttons\\WHITE8x8")
  accent:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
  accent:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
  accent:SetWidth(3)
  button._gseAccent = accent

  local pill = button:CreateTexture(nil, "ARTWORK")
  pill:SetTexture("Interface\\Buttons\\WHITE8x8")
  pill:SetPoint("TOPRIGHT", button, "TOPRIGHT", -12, -10)
  pill:SetSize(6, 6)
  button._gsePill = pill

  local borderTop = button:CreateTexture(nil, "ARTWORK")
  borderTop:SetTexture("Interface\\Buttons\\WHITE8x8")
  borderTop:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
  borderTop:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
  borderTop:SetHeight(1)
  local borderBottom = button:CreateTexture(nil, "ARTWORK")
  borderBottom:SetTexture("Interface\\Buttons\\WHITE8x8")
  borderBottom:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
  borderBottom:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
  borderBottom:SetHeight(1)
  local borderLeft = button:CreateTexture(nil, "ARTWORK")
  borderLeft:SetTexture("Interface\\Buttons\\WHITE8x8")
  borderLeft:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
  borderLeft:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
  borderLeft:SetWidth(1)
  local borderRight = button:CreateTexture(nil, "ARTWORK")
  borderRight:SetTexture("Interface\\Buttons\\WHITE8x8")
  borderRight:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
  borderRight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
  borderRight:SetWidth(1)
  button._gseBorder = { borderTop, borderBottom, borderLeft, borderRight }

  local label = button:CreateFontString(nil, "ARTWORK")
  label:SetFont(STANDARD_TEXT_FONT, 11, "")
  label:SetShadowOffset(1, -1)
  label:SetShadowColor(0, 0, 0, 0.85)
  label:SetPoint("LEFT", button, "LEFT", 14, 0)
  label:SetPoint("RIGHT", button, "RIGHT", -12, 0)
  label:SetJustifyH("CENTER")
  label:SetJustifyV("MIDDLE")
  label:SetWordWrap(false)
  label:SetText(text)
  button._gseLabel = label

  local subtitleText = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  subtitleText:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
  subtitleText:SetPoint("RIGHT", button, "RIGHT", -18, 0)
  subtitleText:SetJustifyH("LEFT")
  subtitleText:SetText(subtitle or "")
  button._gseSubtitle = subtitleText
  subtitleText:Hide()

  button:HookScript("OnEnter", function(self)
    if self._gseSelected then return end
    local r, g, b = optionsModule.GetClassColor()
    if self._gseBg then self._gseBg:SetVertexColor(0.028, 0.032, 0.036, 0.98) end
    if self._gseInner then self._gseInner:SetVertexColor(0.05, 0.055, 0.06, 0.05) end
    if self._gseGlow then self._gseGlow:SetVertexColor(r, g, b, 0.02) end
    if self._gseLabel then self._gseLabel:SetTextColor(0.90, 0.90, 0.92) end
    if self._gseAccent then self._gseAccent:SetVertexColor(optionsModule.GetClassColor()) end
    if self._gseAccent then self._gseAccent:SetAlpha(0.42) end
    if self._gseBorder then
      for _, tex in ipairs(self._gseBorder) do
        tex:SetVertexColor(r, g, b, 0.24)
      end
    end
  end)
  button:HookScript("OnLeave", function(self)
    SetTabVisual(self, self._gseSelected == true)
  end)

  SetTabVisual(button, false)
  return button
end

function optionsModule.ApplyTopTabSelection(frame, selectedKey)
  if not (frame and frame.topTabs) then return end
  frame.selectedTopTab = selectedKey

  for key, button in pairs(frame.topTabs) do
    local isSelected = key == selectedKey
    button._gseSelected = isSelected
    SetTabVisual(button, isSelected)
  end

  if frame.tabContents then
    for key, content in pairs(frame.tabContents) do
      if content then
        if key == selectedKey then
          content:Show()
        else
          content:Hide()
        end
      end
    end
  end
end

function optionsModule.BuildTopTabs(frame, parent, tabs, onSelected)
  frame.topTabs = frame.topTabs or {}

  local anchor = nil
  for index, tabInfo in ipairs(tabs) do
    local button = optionsModule.CreateTopTab(parent, tabInfo.key, tabInfo.text, tabInfo.subtitle)
    button:SetPoint("LEFT", parent, "LEFT", 0, 0)
    button:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    if index == 1 then
      button:SetPoint("TOP", parent, "TOP", 0, 0)
    else
      button:SetPoint("TOP", anchor, "BOTTOM", 0, -TAB_GAP)
    end
    button:SetScript("OnClick", function()
      optionsModule.ApplyTopTabSelection(frame, tabInfo.key)
      if onSelected then onSelected(tabInfo.key) end
      if frame.Refresh then frame:Refresh() end
    end)
    frame.topTabs[tabInfo.key] = button
    anchor = button
  end
end
