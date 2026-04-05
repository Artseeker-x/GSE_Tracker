local _, ns = ...
local addon = ns
local UI = ns.UI
local C = (ns.Utils and ns.Utils.Constants) or addon.Constants or {}

function UI:EvaluateVisibilityMode(mode, inCombat, hasTarget, editingOverride)
  local resolvedMode = tostring(mode or (C.MODE_ALWAYS or "Always"))
  if editingOverride then return true end
  if resolvedMode == "Never" then return false end
  if resolvedMode == "InCombat" then return inCombat and true or false end
  if resolvedMode == "HasTarget" then return hasTarget and true or false end
  return true
end

function UI:VisibilityDependsOnTarget()
  if self:GetShowWhen() == (C.MODE_HAS_TARGET or "HasTarget") then return true end
  if addon.GetCombatMarkerShowWhen and addon:GetCombatMarkerShowWhen() == (C.MODE_HAS_TARGET or "HasTarget") then return true end
  if addon.GetAssistedHighlightShowWhen and addon:GetAssistedHighlightShowWhen() == (C.MODE_HAS_TARGET or "HasTarget") then return true end
  return false
end
