-- LibStub
-- Minimal, compatible implementation (public domain style).
-- Provides: LibStub:NewLibrary, LibStub:GetLibrary, LibStub:IterateLibraries

local LIBSTUB_MAJOR, LIBSTUB_MINOR = "LibStub", 2

local LibStub = _G[LIBSTUB_MAJOR]
if LibStub and LibStub.minor and LibStub.minor >= LIBSTUB_MINOR then
  return
end

LibStub = LibStub or { libs = {}, minors = {} }
LibStub.minor = LIBSTUB_MINOR

function LibStub:NewLibrary(major, minor)
  assert(type(major) == "string", "Bad argument #1 to `NewLibrary` (string expected)")
  minor = assert(tonumber(minor), "Bad argument #2 to `NewLibrary` (number expected)")

  local oldminor = self.minors[major]
  if oldminor and oldminor >= minor then
    return nil
  end

  self.minors[major] = minor
  local lib = self.libs[major]
  if not lib then
    lib = {}
    self.libs[major] = lib
  end
  return lib
end

function LibStub:GetLibrary(major, silent)
  assert(type(major) == "string", "Bad argument #1 to `GetLibrary` (string expected)")
  local lib = self.libs[major]
  if not lib and not silent then
    error("Cannot find a library instance of " .. major, 2)
  end
  return lib
end

function LibStub:IterateLibraries()
  return pairs(self.libs)
end

_G[LIBSTUB_MAJOR] = LibStub
