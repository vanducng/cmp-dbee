local Config = require("cmp-dbee.config")

local M = {}

M.setup = function(user_config)
  Config.setup(user_config)
end

-- For blink.cmp compatibility, we need to export the provider creation function
M.new = function()
  -- Detect which completion engine is being used at runtime
  if package.loaded["blink.cmp"] then
    -- Return blink.cmp provider
    local blink_provider = require("cmp-dbee.blink")
    return blink_provider.new()
  else
    -- Return nvim-cmp source
    local source = require("cmp-dbee.source")
    return source.new()
  end
end

-- Export other functions for nvim-cmp compatibility
local source = require("cmp-dbee.source")
M.complete = source.complete
M.get_debug_name = source.get_debug_name
M.is_available = source.is_available
M.get_trigger_characters = source.get_trigger_characters

return M
