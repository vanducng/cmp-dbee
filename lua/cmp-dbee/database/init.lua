---@mod cmp-dbee.database Database Module
---@brief [[
---This module provides functions to interact with the database, including
---fetching the database structure, models, and column completions.
---
---Access it like this:
--->
---local Database = require("cmp-dbee.database")
---<
---@brief ]]

-- Lazy require dbee modules to avoid loading issues
local dbee_core = nil
local dbee_ui = nil

local function get_dbee_core()
  if not dbee_core then
    -- Only try to load if dbee is actually available
    if package.loaded["dbee"] or package.loaded["dbee.api.core"] then
      local ok, core = pcall(require, "dbee.api.core")
      if ok then
        dbee_core = core
      end
    end
  end
  return dbee_core
end

local function get_dbee_ui()
  if not dbee_ui then
    -- Only try to load if dbee is actually available
    if package.loaded["dbee"] or package.loaded["dbee.api.ui"] then
      local ok, ui = pcall(require, "dbee.api.ui")
      if ok then
        dbee_ui = ui
      end
    end
  end
  return dbee_ui
end

--- @class Database
local Database = {}
Database.cache = {} -- Cache for storing the current database structure
Database.column_cache = {} -- Cache for storing columns of specific tables
Database.cache_expiry_s = 10 -- seconds
Database.cache_last_updated = {}
Database._listeners_registered = false -- Track if event listeners are registered

--- Clear the cache for the current connection.
function Database.clear_cache()
  local connection_id = Database.get_current_connection()
  if connection_id then
    Database.cache[connection_id.id] = nil -- Clear the cache for this connection
    Database.column_cache[connection_id.id] = nil -- Clear the column cache for this connection
  end
end

--- Safely register event listeners for cache invalidation
function Database.ensure_event_listeners()
  if Database._listeners_registered then
    return
  end
  
  local core = get_dbee_core()
  if not core then
    return
  end
  
  local ok = pcall(function()
    core.register_event_listener("current_connection_changed", Database.clear_cache)
    core.register_event_listener("database_selected", Database.clear_cache)
  end)
  
  if ok then
    Database._listeners_registered = true
  end
end

--- Get the current connection ID.
--- @return ConnectionParams|nil connection_id The current connection ID or nil if not available.
function Database.get_current_connection()
  local core = get_dbee_core()
  if not core then
    return nil
  end
  
  local ok, connection_id = pcall(core.get_current_connection)
  if not ok then
    return nil
  end
  return connection_id
end

--- Check if the database is available (if dbee core and ui loaded)
--- @return boolean True if the database is available, false otherwise.
function Database.is_available()
  local core = get_dbee_core()
  local ui = get_dbee_ui()
  
  if not core or not ui then
    return false
  end
  
  local core_ok, core_loaded = pcall(core.is_loaded)
  local ui_ok, ui_loaded = pcall(ui.is_loaded)
  
  return core_ok and core_loaded and ui_ok and ui_loaded
end

--- Get the current database structure. The structure
--- is of type DBStructure[].
--- @param callback Callback Callback function to return the database structure (cached or not).
function Database.get_db_structure(callback)
  Database.ensure_event_listeners() -- Ensure event listeners are registered
  
  local connection_id = Database.get_current_connection()
  if connection_id == nil then
    callback {}
    return
  end
  
  -- Check if completion is enabled for this database type
  local filter = require("cmp-dbee.database.filter")
  if not filter.is_completion_enabled(connection_id) then
    callback {}
    return
  end

  if
    Database.cache[connection_id.id]
    and os.time() - (Database.cache_last_updated[connection_id.id] or 0) < Database.cache_expiry_s
  then
    callback(Database.cache[connection_id.id])
    return
  end

  -- async fetch and cache
  vim.defer_fn(function()
    local core = get_dbee_core()
    if not core then
      callback({})
      return
    end
    
    local ok, structure = pcall(core.connection_get_structure, connection_id.id)
    if not ok then
      callback({})
      return
    end
    
    Database.cache[connection_id.id] = structure
    Database.cache_last_updated[connection_id.id] = os.time()
    callback(structure)
  end, 0)
end

--- Get the models for a specific schema.
--- @param schema string The schema name.
--- @param callback Callback Callback function to return the models.
function Database.get_models(schema, callback)
  Database.ensure_event_listeners() -- Ensure event listeners are registered
  
  local connection_id = Database.get_current_connection()
  if not connection_id then
    callback {}
    return
  end
  
  -- Check if completion is enabled for this database type
  local filter = require("cmp-dbee.database.filter")
  if not filter.is_completion_enabled(connection_id) then
    callback {}
    return
  end

  -- Add error handling for database operations
  local ok, result = pcall(function()
    Database.get_db_structure(function(structure)
      if not structure then
        callback {}
        return
      end

      local models = {}
    for _, s in ipairs(structure) do
      if s.name == schema then
        for _, model in ipairs(s.children or {}) do
          table.insert(models, model)
        end
      end
    end

    callback(models)
    end)
  end)
  
  if not ok then
    -- Error occurred, return empty results
    print("cmp-dbee: Error getting models for schema '" .. schema .. "': " .. tostring(result))
    callback {}
  end
end

--- Get column completions for a specific schema and model.
--- @param schema string The schema name.
--- @param model string The model name.
--- @param callback Callback Callback function to return the columns.
function Database.get_column_completion(schema, model, callback)
  Database.ensure_event_listeners() -- Ensure event listeners are registered
  
  local connection_id = Database.get_current_connection()
  if not connection_id then
    callback {}
    return
  end
  
  -- Check if completion is enabled for this database type
  local filter = require("cmp-dbee.database.filter")
  if not filter.is_completion_enabled(connection_id) then
    callback {}
    return
  end
  
  -- Add error handling for column operations
  local ok, result = pcall(function()

  if
    Database.column_cache[connection_id.id]
    and Database.column_cache[connection_id.id][schema]
    and Database.column_cache[connection_id.id][schema][model]
  then
    callback(Database.column_cache[connection_id.id][schema][model]) -- Return cached columns
    return
  end

  -- If not cached, fetch the columns from the database asynchronously
  -- TODO: materialization hardcoded to be table for now
  local opts = { table = model, schema = schema, materialization = "table" }
  vim.defer_fn(function()
    local core = get_dbee_core()
    if not core then
      callback({})
      return
    end
    
    local ok, columns = pcall(core.connection_get_columns, connection_id.id, opts)
    if not ok then
      -- TODO: vim.notify("Failed to fetch columns for " .. schema .. "." .. model, vim.log.levels.ERROR)
      callback {}
      return
    end

    -- Ensure the cache structure exists
    if not Database.column_cache[connection_id.id] then
      Database.column_cache[connection_id.id] = {}
    end
    if not Database.column_cache[connection_id.id][schema] then
      Database.column_cache[connection_id.id][schema] = {}
    end

    Database.column_cache[connection_id.id][schema][model] = columns -- Cache the fetched columns
    callback(columns)
  end, 0)
  end)
  
  if not ok then
    -- Error occurred, return empty results
    print("cmp-dbee: Error getting columns for " .. schema .. "." .. model .. ": " .. tostring(result))
    callback {}
  end
end

return Database
