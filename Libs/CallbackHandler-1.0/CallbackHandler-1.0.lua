-- CallbackHandler-1.0 (minimal, compatible)
-- A small subset of the Ace3 CallbackHandler API.
-- Sufficient for LibSharedMedia-3.0 (uses :New() and :Fire()).

local MAJOR, MINOR = "CallbackHandler-1.0", 7

local LibStub = _G.LibStub
if not LibStub then
  error("CallbackHandler-1.0 requires LibStub")
end

local CallbackHandler = LibStub:NewLibrary(MAJOR, MINOR)
if not CallbackHandler then return end

local type, pairs, error = type, pairs, error

local function safecall(func, ...)
  if type(func) ~= "function" then return end
  local ok, err = pcall(func, ...)
  if not ok then
    -- Swallow errors to avoid breaking the caller; this mirrors typical handler behavior.
  end
end

-- Creates (or returns) a callback handler table bound to `target`.
-- If registerName/unregisterName are provided, the target gets methods with those names.
function CallbackHandler:New(target, registerName, unregisterName, unregisterAllName)
  if type(target) ~= "table" then
    error("CallbackHandler:New() - target must be a table", 2)
  end

  local handler = target.callbacks
  if type(handler) ~= "table" then
    handler = { _events = {} }
    target.callbacks = handler
  end

  -- Register
  function handler:RegisterCallback(event, funcOrMethod, arg)
    if type(event) ~= "string" then
      error("RegisterCallback: event must be a string", 2)
    end

    local fn
    if type(funcOrMethod) == "function" then
      fn = funcOrMethod
    elseif type(funcOrMethod) == "string" and type(arg) == "table" and type(arg[funcOrMethod]) == "function" then
      -- arg is the object, funcOrMethod is the method name
      local obj = arg
      fn = function(...)
        return obj[funcOrMethod](obj, ...)
      end
    elseif type(funcOrMethod) == "string" and type(target[funcOrMethod]) == "function" then
      -- method on the original target
      fn = function(...)
        return target[funcOrMethod](target, ...)
      end
    else
      error("RegisterCallback: funcOrMethod must be a function or method name", 2)
    end

    local bucket = self._events[event]
    if not bucket then
      bucket = {}
      self._events[event] = bucket
    end

    bucket[funcOrMethod] = { fn = fn }
    return true
  end

  function handler:UnregisterCallback(event, funcOrMethod)
    local bucket = self._events[event]
    if not bucket then return end
    bucket[funcOrMethod] = nil
  end

  function handler:UnregisterAllCallbacks()
    for k in pairs(self._events) do
      self._events[k] = nil
    end
  end

  function handler:Fire(event, ...)
    local bucket = self._events[event]
    if not bucket then return end
    for _, rec in pairs(bucket) do
      if rec and rec.fn then
        safecall(rec.fn, event, ...)
      end
    end
  end

  -- Optional convenience methods on the target
  if registerName and type(registerName) == "string" then
    target[registerName] = function(_, ...) return handler:RegisterCallback(...) end
  end
  if unregisterName and type(unregisterName) == "string" then
    target[unregisterName] = function(_, ...) return handler:UnregisterCallback(...) end
  end
  if unregisterAllName and type(unregisterAllName) == "string" then
    target[unregisterAllName] = function(_) return handler:UnregisterAllCallbacks() end
  end

  return handler
end
