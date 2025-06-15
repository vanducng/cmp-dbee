---@mod cmp-dbee.database.filter Database Filter Module
---@brief [[
---This module provides centralized filtering logic for database connections.
---It determines whether completion should be enabled for a given database type
---based on configuration settings.
---
---Usage:
--->
---local filter = require("cmp-dbee.database.filter")
---if not filter.is_completion_enabled(connection) then
---  return {}
---end
---<
---@brief ]]

local M = {}

--- Check if completion is enabled for a database connection
---@param connection table|nil Database connection info
---@return boolean enabled True if completion is enabled, false otherwise
function M.is_completion_enabled(connection)
  if not connection or not connection.type then
    return true -- Enable by default if no connection info
  end
  
  local config = require("cmp-dbee.config").get()
  if not config then
    return true -- Enable by default if no config
  end
  
  -- Check if database type is in disabled list
  local disabled_databases = config.disabled_databases or {}
  local db_type = string.lower(connection.type)
  
  for _, disabled_db in ipairs(disabled_databases) do
    if db_type == string.lower(disabled_db) then
      -- Log that completion is disabled for this database
      if config.debug and config.debug.enabled then
        print(string.format("cmp-dbee: Completion disabled for %s connection", connection.type))
      end
      return false
    end
  end
  
  -- Check database-specific overrides
  if config.database_overrides and config.database_overrides[db_type] then
    local override = config.database_overrides[db_type]
    if override.completion_enabled ~= nil then
      return override.completion_enabled
    end
  end
  
  return true -- Enable by default
end

--- Check if query execution is enabled for a database connection
---@param connection table|nil Database connection info
---@return boolean enabled True if execution is enabled, false otherwise
function M.is_execution_enabled(connection)
  if not connection or not connection.type then
    return true -- Enable by default if no connection info
  end
  
  local config = require("cmp-dbee.config").get()
  if not config then
    return true -- Enable by default if no config
  end
  
  -- Check database-specific overrides
  local db_type = string.lower(connection.type)
  if config.database_overrides and config.database_overrides[db_type] then
    local override = config.database_overrides[db_type]
    if override.execution_enabled ~= nil then
      return override.execution_enabled
    end
  end
  
  return true -- Enable by default
end

--- Get a human-readable reason why completion is disabled
---@param connection table|nil Database connection info
---@return string|nil reason Reason for disabling, or nil if enabled
function M.get_disabled_reason(connection)
  if not connection or not connection.type then
    return nil
  end
  
  if not M.is_completion_enabled(connection) then
    return string.format("Completion is disabled for %s connections", connection.type)
  end
  
  return nil
end

return M