local Config = require("cmp-dbee.config")

-- Detect which completion engine is being used
local function detect_completion_engine()
  if package.loaded["blink.cmp"] then
    return "blink"
  elseif package.loaded["cmp"] then
    return "nvim-cmp"
  else
    -- Default to nvim-cmp if neither is detected yet
    return "nvim-cmp"
  end
end

local M = {}

M.setup = function(user_config)
  Config.setup(user_config)
end

-- Return appropriate interface based on completion engine
local engine = detect_completion_engine()

if engine == "blink" then
  -- For blink.cmp, return the blink provider but keep setup method
  local blink_provider = require("cmp-dbee.blink")
  -- Add setup method to blink provider
  blink_provider.setup = M.setup
  return blink_provider
else
  -- For nvim-cmp, return the traditional interface
  local source = require("cmp-dbee.source")
  M.new = source.new
  M.complete = source.complete
  M.get_debug_name = source.get_debug_name
  M.is_available = source.is_available
  M.get_trigger_characters = source.get_trigger_characters
  return M
end
