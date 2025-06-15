---@mod cmp-dbee.blink Blink.cmp Provider Module
---@brief [[
---This module provides blink.cmp compatibility for the cmp-dbee plugin.
---It adapts the existing nvim-cmp source to work with blink.cmp's API.
---@brief ]]

local Database = require("cmp-dbee.database")
local Parser = require("cmp-dbee.treesitter")
local Utils = require("cmp-dbee.source.utils")

--- @class BlinkDbeeProvider
local BlinkDbeeProvider = {}

--- Helper function to create a blink.cmp completion item
--- @param label string The label of the completion item.
--- @param kind number The kind of the completion item.
--- @param documentation string The documentation for the completion item.
--- @param priority number The priority of the completion item.
--- @return table The completion item.
local function create_blink_completion_item(label, kind, documentation, priority)
  -- Ensure type safety for string.format to prevent E5101 errors
  local safe_label = tostring(label or "")
  local safe_priority = tonumber(priority) or 0
  local safe_documentation = tostring(documentation or "")
  
  return {
    label = safe_label,
    kind = kind,
    documentation = {
      kind = "markdown",
      value = safe_documentation,
    },
    sortText = string.format("%04d_%s", 10000 - safe_priority, safe_label),
    filterText = safe_label,
    insertText = safe_label,
  }
end

--- Function to map database schemas and tables to blink completion items
--- @param db_structure DBStructure[] The database structure to map.
--- @return table The list of completion items.
local function map_to_blink_completion_items(db_structure)
  local items = {}

  for _, schema in ipairs(db_structure) do
    table.insert(
      items,
      create_blink_completion_item(
        tostring(schema.name or ""),
        17, -- Struct kind in blink.cmp
        "**Type:** " .. tostring(schema.type or "") .. "\n**Schema:** " .. tostring(schema.schema or ""),
        100
      )
    )

    for _, model in ipairs(schema.children or {}) do
      table.insert(
        items,
        create_blink_completion_item(
          tostring(model.name or ""),
          1, -- Text kind in blink.cmp
          "**Type:** " .. tostring(model.type or "") .. "\n**Name:** " .. tostring(model.name or "") .. "\n**Schema:** " .. tostring(model.schema or ""),
          100
        )
      )
    end
  end
  return items
end

--- Function to map columns to blink completion items
--- @param columns Column[] The columns to map.
--- @param schema string The schema name.
--- @param model string The model name.
--- @return table The list of completion items.
local function map_columns_to_blink_completion_items(columns, schema, model)
  local items = {}
  for _, column in ipairs(columns) do
    table.insert(
      items,
      create_blink_completion_item(
        tostring(column.name or ""),
        5, -- Field kind in blink.cmp
        "**Column:** " .. tostring(column.name or "") .. "\n**Type:** " .. tostring(column.type or "") .. "\n**Schema:** " .. tostring(schema or "") .. "\n**Table:** " .. tostring(model or ""),
        1000
      )
    )
  end
  return items
end

--- Function to map models to blink completion items
--- @param models DBStructure[] The models to map.
--- @param schema string The schema name.
--- @return table The list of completion items.
local function map_models_to_blink_completion_items(models, schema)
  local items = {}
  for _, model in ipairs(models) do
    table.insert(
      items,
      create_blink_completion_item(
        tostring(model.name or ""),
        1, -- Text kind in blink.cmp
        "**Type:** " .. tostring(model.type or "") .. "\n**Name:** " .. tostring(model.name or "") .. "\n**Schema:** " .. tostring(schema or ""),
        100
      )
    )
  end
  return items
end

--- Get completions for blink.cmp
--- @param context table The completion context from blink.cmp
--- @param callback function The callback function to return the completion items.
function BlinkDbeeProvider:get_completions(context, callback)
  Database.get_db_structure(function(db_structure)
    local line = Utils:get_cursor_before_line()
    local re_references = Utils:captured_schema(line)
    local ts_references = Parser.get_references_at_cursor()
    local items = {}

    if re_references then
      -- First check if TreeSitter found specific table references with aliases
      if ts_references and ts_references.schema_table_references then
        for _, ref in ipairs(ts_references.schema_table_references) do
          if ref.alias == re_references then
            Database.get_column_completion(ref.schema, ref.model, function(columns)
              callback({
                items = map_columns_to_blink_completion_items(columns, ref.schema, ref.model),
                is_incomplete_forward = false,
                is_incomplete_backward = false,
              })
            end)
            return
          end
        end
      end
      
      -- If no alias match, try to treat re_references as a direct table name
      -- This handles cases like "django_migrations." where it's a direct table reference
      
      -- First check if this is a database reference (for Snowflake cross-database queries)
      local current_connection = Database.get_current_connection()
      local is_snowflake = current_connection and current_connection.type == "snowflake"
      
      if is_snowflake then
        -- For Snowflake, handle three-part naming: database.schema.table
        local snowflake_parts = Utils:captured_snowflake_parts(line)
        
        if snowflake_parts then
          -- User typed "database.schema.", show tables from that schema
          print("cmp-dbee: Snowflake three-part reference detected: " .. snowflake_parts.database .. "." .. snowflake_parts.schema)
          
          -- For cross-database queries in Snowflake, we need to be very careful
          -- Instead of making a potentially failing query, return a helpful message
          -- or try to use the current database structure
          
          -- Check if the referenced database matches current connection database
          local current_db = current_connection.url and current_connection.url:match("database=([^&]+)")
          
          if current_db and string.upper(current_db) == string.upper(snowflake_parts.database) then
            -- Same database, safe to query
            Database.get_models(snowflake_parts.schema, function(models)
              callback({
                items = map_models_to_blink_completion_items(models, snowflake_parts.schema),
                is_incomplete_forward = false,
                is_incomplete_backward = false,
              })
            end)
          else
            -- Different database - avoid cross-database query that might fail
            print("cmp-dbee: Cross-database reference detected, skipping to prevent errors")
            callback({
              items = {
                create_blink_completion_item(
                  "-- Cross-database query",
                  1, -- Text kind
                  "Use database " .. snowflake_parts.database .. " first, then query " .. snowflake_parts.schema,
                  50
                )
              },
              is_incomplete_forward = false,
              is_incomplete_backward = false,
            })
          end
        else
          -- Single part before dot, treat as database or schema name
          Database.get_models(re_references, function(models)
            callback({
              items = map_models_to_blink_completion_items(models, re_references),
              is_incomplete_forward = false,
              is_incomplete_backward = false,
            })
          end)
        end
      else
        -- For other databases (PostgreSQL, MySQL, etc.), try column completion first
        Database.get_column_completion("public", re_references, function(columns)
          if #columns > 0 then
            -- Found columns for this table, return them
            callback({
              items = map_columns_to_blink_completion_items(columns, "public", re_references),
              is_incomplete_forward = false,
              is_incomplete_backward = false,
            })
            return
          else
            -- No columns found, fall back to schema/table completion
            Database.get_models(re_references, function(models)
              callback({
                items = map_models_to_blink_completion_items(models, re_references),
                is_incomplete_forward = false,
                is_incomplete_backward = false,
              })
            end)
          end
        end)
      end
      return
    end

    items = map_to_blink_completion_items(db_structure)

    if ts_references then
      if ts_references.cte_references then
        for _, cte in ipairs(ts_references.cte_references) do
          table.insert(
            items,
            create_blink_completion_item(
              tostring(cte.cte or ""),
              17, -- Struct kind in blink.cmp
              "**CTE:** " .. tostring(cte.cte or ""),
              100
            )
          )
        end
      end

      if ts_references.schema_table_references then
        for _, refs in ipairs(ts_references.schema_table_references) do
          if refs.schema and refs.model and refs.schema ~= "" and refs.model ~= "" then
            Database.get_column_completion(refs.schema, refs.model, function(columns)
              local column_items = map_columns_to_blink_completion_items(columns, refs.schema, refs.model)
              if refs.alias then
                table.insert(
                  items,
                  create_blink_completion_item(
                    tostring(refs.alias or ""),
                    1, -- Text kind in blink.cmp
                    "**Alias for:** " .. tostring(refs.schema or "") .. "." .. tostring(refs.model or ""),
                    200
                  )
                )
              end
              items = vim.list_extend(items, column_items)
              callback({
                items = items,
                is_incomplete_forward = false,
                is_incomplete_backward = false,
              })
            end)
            return
          end
        end
      end
    end

    callback({
      items = items,
      is_incomplete_forward = false,
      is_incomplete_backward = false,
    })
  end)
end

--- Check if the provider is available for completion
--- @param context table The completion context from blink.cmp
--- @return boolean True if the provider is available, false otherwise.
function BlinkDbeeProvider:is_available(context)
  return Database.is_available()
end

--- Get the trigger characters for the provider
--- @return string[] The list of trigger characters.
function BlinkDbeeProvider:get_trigger_characters()
  return { '"', "`", "[", "]", ".", "(", ")" }
end

--- Create a new blink.cmp provider instance
--- @return BlinkDbeeProvider The new provider instance.
local function new()
  return setmetatable({}, { __index = BlinkDbeeProvider })
end

return {
  new = new,
}