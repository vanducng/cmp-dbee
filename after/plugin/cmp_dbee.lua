-- Only register cmp-dbee source for nvim-cmp (not blink.cmp)
-- Blink.cmp handles provider registration differently through its configuration

-- Check if we're using nvim-cmp (not blink.cmp)
if package.loaded["blink.cmp"] then
  -- Skip registration for blink.cmp
  return
end

-- Only register if nvim-cmp is available
local cmp_ok, cmp = pcall(require, "cmp")
if not cmp_ok then
  return
end

-- Check if dbee is available before registering the source
local dbee_available = package.loaded["dbee"] or package.loaded["dbee.api.core"]
if not dbee_available then
  return
end

-- Try to register the source safely for nvim-cmp
local source_ok, source = pcall(require, "cmp-dbee.source")
if source_ok then
  cmp.register_source("dbee", source.new())
end
