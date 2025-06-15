---@mod cmp-dbee.blink-wrapper Blink.cmp Wrapper Module
---@brief [[
---This module provides a wrapper for blink.cmp that can dynamically disable
---the provider based on the current database connection.
---@brief ]]

local M = {}

--- Create a disabled provider that returns nothing
local function create_disabled_provider()
  return {
    get_completions = function(self, context, callback)
      callback({
        items = {},
        is_incomplete_forward = false,
        is_incomplete_backward = false,
      })
    end,
    is_available = function(self, context)
      return false
    end,
    get_trigger_characters = function(self)
      return {}
    end,
  }
end

--- Create a new blink.cmp provider instance
--- @return table The provider instance (real or disabled)
function M.new()
  -- Check if completion should be enabled
  local database_ok, database = pcall(require, "cmp-dbee.database")
  if not database_ok then
    return create_disabled_provider()
  end
  
  local current_connection = database.get_current_connection()
  if not current_connection then
    -- No connection, return regular provider (it will handle this case)
    local blink_provider = require("cmp-dbee.blink")
    return blink_provider.new()
  end
  
  local filter_ok, filter = pcall(require, "cmp-dbee.database.filter")
  if filter_ok and not filter.is_completion_enabled(current_connection) then
    return create_disabled_provider()
  end
  
  -- Return the real provider
  local blink_provider = require("cmp-dbee.blink")
  return blink_provider.new()
end

return M