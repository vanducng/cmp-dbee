---@mod cmp-dbee.database.snowflake_queries Snowflake-specific query helpers
---@brief [[
---This module provides Snowflake-specific queries to get schema and table information
---across databases using INFORMATION_SCHEMA queries.
---@brief ]]

local M = {}

--- Get schemas from current database (since cross-database queries fail)
---@param callback function Callback with schema results
function M.get_current_database_schemas(callback)
  -- Since cross-database queries fail, just return empty
  -- This prevents hard-coded suggestions and errors
  print("cmp-dbee: Cross-database schema queries not supported, returning empty")
  callback({})
end

--- Get tables from current database schema only
---@param schema string The schema name
---@param callback function Callback with table results  
function M.get_current_database_tables(schema, callback)
  -- Since cross-database queries fail, just return empty
  -- This prevents hard-coded suggestions and errors
  print("cmp-dbee: Cross-database table queries not supported, returning empty")
  callback({})
end

--- Get schemas from a specific database - returns empty for cross-database
---@param database string The database name (ignored for now)
---@param connection_id string The connection ID (ignored for now)
---@param callback function Callback with schema results
function M.get_schemas_from_database(database, connection_id, callback)
  print("cmp-dbee: Cross-database schema access not supported for " .. database)
  callback({})
end

--- Get tables from a specific database.schema - returns empty for cross-database  
---@param database string The database name (ignored for now)
---@param schema string The schema name (ignored for now)
---@param connection_id string The connection ID (ignored for now)
---@param callback function Callback with table results  
function M.get_tables_from_database_schema(database, schema, connection_id, callback)
  print("cmp-dbee: Cross-database table access not supported for " .. database .. "." .. schema)
  callback({})
end

return M