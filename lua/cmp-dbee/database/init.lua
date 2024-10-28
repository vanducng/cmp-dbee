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

local dbee_core = require("dbee.api.core")
local dbee_ui = require("dbee.api.ui")

--- @class Database
local Database = {}
Database.cache = {} -- Cache for storing the current database structure
Database.column_cache = {} -- Cache for storing columns of specific tables
Database.cache_expiry_s = 10 -- seconds
Database.cache_last_updated = {}

--- Get the current connection ID.
--- @return ConnectionID|nil connection_id The current connection ID or nil if not available.
function Database.get_current_connection()
  local ok, connection_id = pcall(dbee_core.get_current_connection)
  if not ok then
    return nil
  end
  return connection_id
end

--- Check if the database is available (if dbee core and ui loaded)
--- @return boolean True if the database is available, false otherwise.
function Database.is_available()
  return dbee_core.is_loaded() and dbee_ui.is_loaded()
end

--- Get the current database structure. The structure
--- is of type DBStructure[].
--- @param callback Callback Callback function to return the database structure (cached or not).
function Database.get_db_structure(callback)
  local connection_id = Database.get_current_connection()
  if not connection_id then
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
    local structure = dbee_core.connection_get_structure(connection_id.id)
    Database.cache[connection_id.id] = structure
    Database.cache_last_updated[connection_id.id] = os.time()
    callback(structure)
  end, 0)
end

--- Get the models for a specific schema.
--- @param schema string The schema name.
--- @param callback Callback Callback function to return the models.
function Database.get_models(schema, callback)
  local connection_id = Database.get_current_connection()
  if not connection_id then
    callback {}
    return
  end

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
end

--- Get column completions for a specific schema and model.
--- @param schema string The schema name.
--- @param model string The model name.
--- @param callback Callback Callback function to return the columns.
function Database.get_column_completion(schema, model, callback)
  local connection_id = dbee_core.get_current_connection()
  if not connection_id then
    callback {}
    return
  end

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
    local ok, columns = pcall(dbee_core.connection_get_columns, connection_id.id, opts)
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
end

--- Clear the cache for the current connection.
local function clear_cache()
  local connection_id = dbee_core.get_current_connection()
  if connection_id then
    Database.cache[connection_id.id] = nil -- Clear the cache for this connection
    Database.column_cache[connection_id.id] = nil -- Clear the column cache for this connection
  end
end

-- Register event listeners to invalidate the cache
dbee_core.register_event_listener("current_connection_changed", clear_cache)
dbee_core.register_event_listener("database_selected", clear_cache)

return Database
