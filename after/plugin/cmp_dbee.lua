-- Only register cmp-dbee source if cmp is available and dbee is loaded
local cmp_ok, cmp = pcall(require, "cmp")
if not cmp_ok then
  return
end

-- Check if dbee is available before registering the source
local dbee_available = package.loaded["dbee"] or package.loaded["dbee.api.core"]
if not dbee_available then
  return
end

-- Try to register the source safely
local source_ok, source = pcall(require, "cmp-dbee.source")
if source_ok then
  cmp.register_source("dbee", source.new())
end
