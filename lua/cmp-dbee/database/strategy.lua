---@mod cmp-dbee.database.strategy Database Strategy Pattern
---@brief [[
---This module provides a strategy pattern for database-specific completion logic.
---Different databases have different naming conventions and query patterns.
---
---Usage:
--->
---local strategy = require("cmp-dbee.database.strategy")
---local db_strategy = strategy.get_strategy(connection)
---<
---@brief ]]

local M = {}

--- Base strategy interface
---@class DatabaseStrategy
local DatabaseStrategy = {}
DatabaseStrategy.__index = DatabaseStrategy

--- Get the naming convention for this database
---@return table naming convention info
function DatabaseStrategy:get_naming_convention()
  return {
    supports_cross_database = false,
    max_parts = 2, -- schema.table
    pattern = "schema.table"
  }
end

--- Parse a qualified name into its components
---@param qualified_name string The qualified name to parse
---@return table|nil parsed components
function DatabaseStrategy:parse_qualified_name(qualified_name)
  -- Default implementation for two-part names
  local parts = {}
  for part in qualified_name:gmatch("[^%.]+") do
    table.insert(parts, part)
  end
  
  if #parts == 2 then
    return {schema = parts[1], table = parts[2]}
  elseif #parts == 1 then
    return {table = parts[1]}
  end
  
  return nil
end

--- Check if a cross-database query is supported and safe
---@param database string The target database
---@param current_connection table The current connection info
---@return boolean is_safe
function DatabaseStrategy:is_cross_database_safe(database, current_connection)
  return false -- Default: not supported
end

--- Get completions for a qualified reference
---@param context table Completion context
---@param callback function Callback with results
function DatabaseStrategy:get_qualified_completions(context, callback)
  callback({}) -- Default: no results
end

--- Snowflake-specific strategy
---@class SnowflakeStrategy : DatabaseStrategy
local SnowflakeStrategy = setmetatable({}, {__index = DatabaseStrategy})
SnowflakeStrategy.__index = SnowflakeStrategy

function SnowflakeStrategy:get_naming_convention()
  return {
    supports_cross_database = true,
    max_parts = 3, -- database.schema.table
    pattern = "database.schema.table"
  }
end

function SnowflakeStrategy:parse_qualified_name(qualified_name)
  local parts = {}
  for part in qualified_name:gmatch("[^%.]+") do
    table.insert(parts, part)
  end
  
  if #parts == 4 then
    return {database = parts[1], schema = parts[2], table = parts[3], column = parts[4]}
  elseif #parts == 3 then
    return {database = parts[1], schema = parts[2], table = parts[3]}
  elseif #parts == 2 then
    return {database = parts[1], schema = parts[2]}
  elseif #parts == 1 then
    return {schema = parts[1]}
  end
  
  return nil
end

function SnowflakeStrategy:is_cross_database_safe(database, current_connection)
  -- Extract current database from connection URL
  local current_db = current_connection.url and current_connection.url:match("database=([^&]+)")
  
  if current_db then
    -- Safe if same database (case insensitive)
    return string.upper(current_db) == string.upper(database)
  end
  
  -- If we can't determine current database, be conservative
  return false
end

function SnowflakeStrategy:get_qualified_completions(context, callback)
  local Database = require("cmp-dbee.database")
  
  if context.type == "column" and context.parts and context.parts.database and context.parts.schema and context.parts.table then
    -- Four-part reference: database.schema.table.column
    local database = context.parts.database
    local schema = context.parts.schema
    local table = context.parts.table
    
    if self:is_cross_database_safe(database, context.current_connection) then
      -- Safe to query - same database
      print("cmp-dbee: Snowflake querying columns in " .. database .. "." .. schema .. "." .. table)
      Database.get_column_completion(schema, table, callback)
    else
      -- Cross-database reference - provide guidance instead of failing query
      print("cmp-dbee: Cross-database column reference detected: " .. database .. "." .. schema .. "." .. table)
      callback({
        {
          label = "-- Switch to " .. database .. " database first",
          kind = 1, -- Text
          detail = "Cross-database column query",
          documentation = {
            kind = "markdown",
            value = "Use `USE DATABASE " .. database .. ";` first, then access columns from " .. schema .. "." .. table
          }
        },
        {
          label = "USE DATABASE " .. database .. ";",
          kind = 15, -- Snippet
          detail = "Switch database",
          documentation = {
            kind = "markdown", 
            value = "Execute this to switch to the " .. database .. " database, then you can access " .. schema .. "." .. table .. " columns."
          }
        }
      })
    end
  elseif context.type == "table" and context.parts and context.parts.database and context.parts.schema then
    -- Three-part reference: database.schema.table
    local database = context.parts.database
    local schema = context.parts.schema
    
    if self:is_cross_database_safe(database, context.current_connection) then
      -- Safe to query - same database
      print("cmp-dbee: Snowflake querying tables in " .. database .. "." .. schema)
      Database.get_models(schema, callback)
    else
      -- Cross-database reference - provide guidance
      print("cmp-dbee: Cross-database table reference detected: " .. database .. "." .. schema)
      callback({
        {
          label = "-- Switch to " .. database .. " database first",
          kind = 1, -- Text
          detail = "Cross-database table query",
          documentation = {
            kind = "markdown",
            value = "Use `USE DATABASE " .. database .. ";` first, then query tables in " .. schema .. " schema."
          }
        },
        {
          label = "USE DATABASE " .. database .. ";",
          kind = 15, -- Snippet
          detail = "Switch database",
          documentation = {
            kind = "markdown", 
            value = "Execute this to switch to the " .. database .. " database."
          }
        }
      })
    end
  elseif context.type == "schema" and context.parts and context.parts.database then
    -- Two-part reference: database.schema
    local database = context.parts.database
    
    if self:is_cross_database_safe(database, context.current_connection) then
      Database.get_models(database, callback)
    else
      print("cmp-dbee: Cross-database schema reference detected: " .. database)
      callback({
        {
          label = "-- Switch to " .. database .. " database first",
          kind = 1, -- Text
          detail = "Cross-database schema query",
          documentation = {
            kind = "markdown",
            value = "Use `USE DATABASE " .. database .. ";` to access schemas in " .. database
          }
        }
      })
    end
  else
    -- Single part or unsupported
    callback({})
  end
end

--- PostgreSQL-specific strategy
---@class PostgresStrategy : DatabaseStrategy  
local PostgresStrategy = setmetatable({}, {__index = DatabaseStrategy})
PostgresStrategy.__index = PostgresStrategy

function PostgresStrategy:get_naming_convention()
  return {
    supports_cross_database = false,
    max_parts = 2, -- schema.table
    pattern = "schema.table"
  }
end

function PostgresStrategy:get_qualified_completions(context, callback)
  local Database = require("cmp-dbee.database")
  
  if context.type == "column" and context.parts and context.parts.table then
    -- Table.column reference
    local schema = context.parts.schema or "public"
    local table = context.parts.table
    
    Database.get_column_completion(schema, table, callback)
  elseif context.type == "table" and context.parts and context.parts.schema then
    -- Schema.table reference
    Database.get_models(context.parts.schema, callback)
  else
    callback({})
  end
end

--- MySQL-specific strategy
---@class MySQLStrategy : DatabaseStrategy
local MySQLStrategy = setmetatable({}, {__index = DatabaseStrategy})
MySQLStrategy.__index = MySQLStrategy

function MySQLStrategy:get_naming_convention()
  return {
    supports_cross_database = true,
    max_parts = 2, -- database.table (schema = database in MySQL)
    pattern = "database.table"
  }
end

function MySQLStrategy:parse_qualified_name(qualified_name)
  local parts = {}
  for part in qualified_name:gmatch("[^%.]+") do
    table.insert(parts, part)
  end
  
  if #parts == 2 then
    return {database = parts[1], table = parts[2]}
  elseif #parts == 1 then
    return {table = parts[1]}
  end
  
  return nil
end

--- Strategy factory
local strategies = {
  snowflake = SnowflakeStrategy,
  postgres = PostgresStrategy,
  postgresql = PostgresStrategy, -- Alternative name
  mysql = MySQLStrategy,
  mariadb = MySQLStrategy, -- Alternative name
}

--- Get the appropriate strategy for a database connection
---@param connection table Database connection info
---@return DatabaseStrategy strategy
function M.get_strategy(connection)
  if not connection or not connection.type then
    return DatabaseStrategy -- Default strategy
  end
  
  local strategy_class = strategies[string.lower(connection.type)]
  if strategy_class then
    return setmetatable({}, {__index = strategy_class})
  end
  
  return setmetatable({}, {__index = DatabaseStrategy}) -- Default fallback
end

--- Parse a line to determine completion context
---@param line string The current line content
---@param connection table Database connection info
---@return table|nil context
function M.parse_completion_context(line, connection)
  local strategy = M.get_strategy(connection)
  local convention = strategy:get_naming_convention()
  
  -- Try to match qualified references ending with dot
  -- Use * instead of + to allow zero or more spaces (handles start of string)
  local qualified_match = line:match("[%s%(]*([%w_.]+)%.$")
  if not qualified_match then
    return nil
  end
  
  local parts = strategy:parse_qualified_name(qualified_match)
  if not parts then
    return nil
  end
  
  -- Determine what type of completion is needed based on parts
  local context = {
    qualified_name = qualified_match,
    parts = parts,
    strategy = strategy,
    current_connection = connection
  }
  
  -- Determine completion type based on number of parts and database convention
  if connection.type == "snowflake" then
    if parts.database and parts.schema and parts.table then
      context.type = "column" -- database.schema.table. -> columns
    elseif parts.database and parts.schema then
      context.type = "table" -- database.schema. -> tables
    elseif parts.database then
      context.type = "schema" -- database. -> schemas
    else
      context.type = "table" -- schema. -> tables
    end
  elseif connection.type == "postgres" or connection.type == "postgresql" then
    if parts.schema and parts.table then
      context.type = "column" -- schema.table. -> columns
    elseif parts.schema then
      context.type = "table" -- schema. -> tables
    else
      context.type = "column" -- table. -> columns (assume public schema)
    end
  elseif connection.type == "mysql" then
    if parts.database and parts.table then
      context.type = "column" -- database.table. -> columns
    elseif parts.database then
      context.type = "table" -- database. -> tables
    else
      context.type = "column" -- table. -> columns
    end
  end
  
  return context
end

return M