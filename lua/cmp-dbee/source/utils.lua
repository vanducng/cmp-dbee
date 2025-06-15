local M = {}

--- Get the text of the line before the cursor
---@return string The text of the line before the cursor
function M:get_cursor_before_line()
  -- Early return if completion is disabled for current connection
  local database_ok, database = pcall(require, "cmp-dbee.database")
  if database_ok then
    local current_connection = database.get_current_connection()
    if current_connection then
      local filter_ok, filter = pcall(require, "cmp-dbee.database.filter")
      if filter_ok and not filter.is_completion_enabled(current_connection) then
        return "" -- Return empty string to avoid processing
      end
    end
  end
  
  local line_number = vim.fn.line(".")
  local col_number = vim.fn.col(".")

  -- If the cursor is not at the beginning of the line, get the substring before the cursor
  if col_number > 1 then
    local current_line = vim.api.nvim_get_current_line()
    return string.sub(current_line, 1, col_number - 1)
  end

  -- If the cursor is at the beginning of the line, get the text of the previous line
  if line_number > 1 then
    return vim.fn.getline(line_number - 1)
  end

  -- If the cursor is at the beginning of the first line, return an empty string
  return ""
end

--- The schema is the text between the last space or opening parenthesis and the dot
---@param line? string The line to get the schema from
---@return any
function M:captured_schema(line)
  -- Early return if completion is disabled for current connection
  local database_ok, database = pcall(require, "cmp-dbee.database")
  if database_ok then
    local current_connection = database.get_current_connection()
    if current_connection then
      local filter_ok, filter = pcall(require, "cmp-dbee.database.filter")
      if filter_ok and not filter.is_completion_enabled(current_connection) then
        return nil -- Skip processing
      end
    end
  end
  
  local cursor_before_line = line or self:get_cursor_before_line()
  -- Match word boundaries: space, parenthesis, or start of string
  return cursor_before_line:match("[%s%(]*([%w_]+)%.$")
end

--- Capture three-part Snowflake naming: database.schema.table
--- @param line? string The line to parse
--- @return table|nil Returns {database=string, schema=string} or nil
function M:captured_snowflake_parts(line)
  -- Early return if completion is disabled for current connection
  local database_ok, database = pcall(require, "cmp-dbee.database")
  if database_ok then
    local current_connection = database.get_current_connection()
    if current_connection then
      local filter_ok, filter = pcall(require, "cmp-dbee.database.filter")
      if filter_ok and not filter.is_completion_enabled(current_connection) then
        return nil -- Skip processing
      end
    end
  end
  
  local cursor_before_line = line or self:get_cursor_before_line()
  
  -- Match patterns like "database.schema." or "from database.schema."
  -- Use * instead of + to allow zero or more spaces
  local database, schema = cursor_before_line:match("[%s%(]*([%w_]+)%.([%w_]+)%.$")
  if database and schema then
    return {database = database, schema = schema}
  end
  
  return nil
end

return M
