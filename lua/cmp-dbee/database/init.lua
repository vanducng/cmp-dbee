local dbee_core = require("dbee.api.core")

local Database = {}
Database.cache = {} -- Cache for storing the current database structure
Database.column_cache = {} -- Cache for storing columns of specific tables

-- Function to get the current database structure
Database.get_db_structure = function()
  local connection_id = dbee_core.get_current_connection()
  if not connection_id then
    return {}
  end

  -- Check if the cache is already populated
  if Database.cache[connection_id.id] then
    return Database.cache[connection_id.id] -- Return cached structure
  end

  -- If not cached, fetch the structure and store it
  local structure = dbee_core.connection_get_structure(connection_id.id)
  Database.cache[connection_id.id] = structure

  return structure
end

-- Function to get column completions for a specific schema and model
Database.get_column_completion = function(schema, model)
  local connection_id = dbee_core.get_current_connection()
  if not connection_id then
    return {}
  end

  -- Check if columns for the specified model are cached
  if
    Database.column_cache[connection_id.id]
    and Database.column_cache[connection_id.id][schema]
    and Database.column_cache[connection_id.id][schema][model]
  then
    return Database.column_cache[connection_id.id][schema][model] -- Return cached columns
  end

  -- If not cached, fetch the columns from the database
  -- TODO: materialization hardcoded to be table for now
  local opts = { table = model, schema = schema, materialization = "table" }
  local ok, columns = pcall(dbee_core.connection_get_columns, connection_id.id, opts)
  if not ok then
    vim.notify("Failed to fetch columns for " .. schema .. "." .. model, vim.log.levels.ERROR)
    return {}
  end

  -- Ensure the cache structure exists
  if not Database.column_cache[connection_id.id] then
    Database.column_cache[connection_id.id] = {}
  end
  if not Database.column_cache[connection_id.id][schema] then
    Database.column_cache[connection_id.id][schema] = {}
  end

  Database.column_cache[connection_id.id][schema][model] = columns -- Cache the fetched columns
  return columns
end

-- Function to manually clear the cache for the current connection
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
