---@mod cmp-dbee.database.sql_engine SQL Query Engine for Cross-Database Completion
---@brief [[
---This module provides direct SQL execution for database completion across different databases.
---It bypasses the limitations of the nvim-dbee API by executing raw SQL queries.
---
---Usage:
--->
---local sql_engine = require("cmp-dbee.database.sql_engine")
---sql_engine.execute_query(connection_id, "SHOW DATABASES", callback)
---<
---@brief ]]

local M = {}

--- Cache for query results to avoid repeated expensive queries
local query_cache = {}
local cache_ttl = 30 -- seconds

--- Get current time for cache expiration
local function get_current_time()
  return vim.loop.hrtime() / 1e9 -- Convert nanoseconds to seconds
end

--- Check if cached result is still valid
local function is_cache_valid(cache_entry)
  if not cache_entry then
    return false
  end
  
  local current_time = get_current_time()
  return (current_time - cache_entry.timestamp) < cache_ttl
end

--- Execute a SQL query and call callback with results
---@param connection_id string The database connection ID
---@param query string The SQL query to execute
---@param callback function Callback function to call with results
---@param cache_key string|nil Optional cache key for result caching
function M.execute_query(connection_id, query, callback, cache_key)
  -- Check cache first if cache_key provided
  if cache_key then
    local cached = query_cache[cache_key]
    if is_cache_valid(cached) then
      print("cmp-dbee: Using cached result for " .. cache_key)
      callback(cached.result)
      return
    end
  end
  
  local core = require("dbee.api.core")
  
  if not core.is_loaded() then
    print("cmp-dbee: dbee core not loaded")
    callback({})
    return
  end
  
  -- Execute query
  local execute_ok, call_info = pcall(core.connection_execute, connection_id, query)
  if not execute_ok then
    print("cmp-dbee: Query execution failed: " .. tostring(call_info))
    callback({})
    return
  end
  
  if not call_info or not call_info.id then
    print("cmp-dbee: Invalid call info returned")
    callback({})
    return
  end
  
  print("cmp-dbee: Executing query: " .. query:sub(1, 50) .. "...")
  
  -- Set up result handler with timeout using correct dbee API
  local attempts = 0
  local max_attempts = 20 -- 10 seconds timeout
  
  local function handle_result()
    attempts = attempts + 1
    
    -- First try to store the result
    local store_ok, store_result = pcall(core.call_store_result, call_info.id)
    if not store_ok then
      -- Query might still be running
      if attempts < max_attempts then
        vim.defer_fn(handle_result, 500)
      else
        print("cmp-dbee: Query timeout after " .. (max_attempts * 0.5) .. " seconds")
        callback({})
      end
      return
    end
    
    -- Now get the call info to check status and result
    local calls_ok, calls = pcall(core.connection_get_calls, connection_id)
    if not calls_ok then
      print("cmp-dbee: Failed to get call list: " .. tostring(calls))
      callback({})
      return
    end
    
    -- Find our call
    local our_call = nil
    for _, call in ipairs(calls) do
      if call.id == call_info.id then
        our_call = call
        break
      end
    end
    
    if not our_call then
      print("cmp-dbee: Call not found in call list")
      callback({})
      return
    end
    
    -- Check call status
    if our_call.state == "executing" then
      -- Still running, check again
      if attempts < max_attempts then
        vim.defer_fn(handle_result, 500)
      else
        print("cmp-dbee: Query timeout - still executing after " .. (max_attempts * 0.5) .. " seconds")
        callback({})
      end
      return
    end
    
    -- Check for errors
    if our_call.error then
      print("cmp-dbee: Query error: " .. tostring(our_call.error))
      callback({})
      return
    end
    
    -- Try to read result file if available
    if our_call.result_file then
      local file_ok, file_content = pcall(vim.fn.readfile, our_call.result_file)
      if file_ok and file_content then
        -- Parse the result file (it should be JSON)
        local json_ok, result_data = pcall(vim.fn.json_decode, table.concat(file_content, "\n"))
        if json_ok and result_data then
          -- Process result
          local processed_result = M.process_query_result(result_data, query)
          
          -- Cache result if cache_key provided
          if cache_key then
            query_cache[cache_key] = {
              result = processed_result,
              timestamp = get_current_time()
            }
          end
          
          print("cmp-dbee: Query completed, found " .. #processed_result .. " items")
          callback(processed_result)
          return
        else
          print("cmp-dbee: Failed to parse result file JSON")
        end
      else
        print("cmp-dbee: Failed to read result file: " .. tostring(file_content))
      end
    end
    
    -- If we get here, query completed but no result file or parsing failed
    print("cmp-dbee: Query completed but no usable result")
    callback({})
  end
  
  -- Start checking for result after delay to let query execute
  vim.defer_fn(handle_result, 1000)
end

--- Process raw query result into structured format
---@param raw_result table Raw result from dbee API
---@param query string Original query for context
---@return table processed_result
function M.process_query_result(raw_result, query)
  if not raw_result or not raw_result.rows then
    return {}
  end
  
  local processed = {}
  
  -- Handle different query types
  if query:upper():find("SHOW DATABASES") then
    -- SHOW DATABASES returns rows with database names
    for _, row in ipairs(raw_result.rows) do
      if row and row[1] then
        table.insert(processed, {
          name = tostring(row[1]),
          type = "database"
        })
      end
    end
  elseif query:upper():find("SHOW SCHEMAS") then
    -- SHOW SCHEMAS returns rows with schema names
    for _, row in ipairs(raw_result.rows) do
      if row and row[1] then
        table.insert(processed, {
          name = tostring(row[1]),
          type = "schema"
        })
      end
    end
  elseif query:upper():find("SHOW TABLES") then
    -- SHOW TABLES returns rows with table information
    for _, row in ipairs(raw_result.rows) do
      if row and row[1] then
        table.insert(processed, {
          name = tostring(row[1]),
          type = "table"
        })
      end
    end
  elseif query:upper():find("INFORMATION_SCHEMA.COLUMNS") then
    -- Column queries return column information
    for _, row in ipairs(raw_result.rows) do
      if row and row[1] then
        table.insert(processed, {
          name = tostring(row[1]),
          type = "column",
          data_type = row[2] and tostring(row[2]) or nil
        })
      end
    end
  else
    -- Generic processing - use first column as name
    for _, row in ipairs(raw_result.rows) do
      if row and row[1] then
        table.insert(processed, {
          name = tostring(row[1]),
          type = "unknown"
        })
      end
    end
  end
  
  return processed
end

--- Snowflake-specific query builders
local SnowflakeQueries = {}

function SnowflakeQueries.get_databases()
  return "SHOW DATABASES"
end

function SnowflakeQueries.get_schemas(database)
  if database then
    return "SHOW SCHEMAS IN DATABASE " .. database
  else
    return "SHOW SCHEMAS"
  end
end

function SnowflakeQueries.get_tables(database, schema)
  if database and schema then
    return "SHOW TABLES IN SCHEMA " .. database .. "." .. schema
  elseif schema then
    return "SHOW TABLES IN SCHEMA " .. schema
  else
    return "SHOW TABLES"
  end
end

function SnowflakeQueries.get_columns(database, schema, table)
  local full_table_name
  if database and schema and table then
    full_table_name = database .. "." .. schema .. "." .. table
  elseif schema and table then
    full_table_name = schema .. "." .. table
  else
    full_table_name = table
  end
  
  return "SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = '" .. table .. "' ORDER BY ORDINAL_POSITION"
end

--- Get database list for Snowflake
---@param connection_id string Database connection ID
---@param callback function Callback with database list
function M.get_snowflake_databases(connection_id, callback)
  local query = SnowflakeQueries.get_databases()
  local cache_key = "snowflake_databases_" .. connection_id
  
  M.execute_query(connection_id, query, callback, cache_key)
end

--- Get schema list for Snowflake database
---@param connection_id string Database connection ID
---@param database string Database name
---@param callback function Callback with schema list
function M.get_snowflake_schemas(connection_id, database, callback)
  local query = SnowflakeQueries.get_schemas(database)
  local cache_key = "snowflake_schemas_" .. connection_id .. "_" .. database
  
  M.execute_query(connection_id, query, callback, cache_key)
end

--- Get table list for Snowflake database.schema
---@param connection_id string Database connection ID
---@param database string Database name
---@param schema string Schema name
---@param callback function Callback with table list
function M.get_snowflake_tables(connection_id, database, schema, callback)
  local query = SnowflakeQueries.get_tables(database, schema)
  local cache_key = "snowflake_tables_" .. connection_id .. "_" .. database .. "_" .. schema
  
  M.execute_query(connection_id, query, callback, cache_key)
end

--- Get column list for Snowflake table
---@param connection_id string Database connection ID
---@param database string Database name
---@param schema string Schema name
---@param table string Table name
---@param callback function Callback with column list
function M.get_snowflake_columns(connection_id, database, schema, table, callback)
  local query = SnowflakeQueries.get_columns(database, schema, table)
  local cache_key = "snowflake_columns_" .. connection_id .. "_" .. database .. "_" .. schema .. "_" .. table
  
  M.execute_query(connection_id, query, callback, cache_key)
end

--- Clear all cached results
function M.clear_cache()
  query_cache = {}
  print("cmp-dbee: SQL query cache cleared")
end

--- Get cache statistics
function M.get_cache_stats()
  local total_entries = 0
  local valid_entries = 0
  
  for key, entry in pairs(query_cache) do
    total_entries = total_entries + 1
    if is_cache_valid(entry) then
      valid_entries = valid_entries + 1
    end
  end
  
  return {
    total = total_entries,
    valid = valid_entries,
    expired = total_entries - valid_entries
  }
end

return M