local cmp = require("cmp")
local Database = require("cmp-dbee.database")
local Parser = require("cmp-dbee.treesitter.parser")
local Utils = require("cmp-dbee.source.utils")

local Source = {}

-- Function to map database schemas and tables to completion items
local function map_to_completion_items(db_structure)
  local items = {}

  -- Map schemas to completion items
  for _, schema in ipairs(db_structure) do
    -- Add schema completion item
    table.insert(items, {
      label = schema.name, -- Use the schema name directly
      kind = cmp.lsp.CompletionItemKind.Struct, -- Change to an appropriate kind for schemas
      documentation = "Schema: " .. schema.name,
      priority = 100, -- Set a lower priority for schemas
    })

    -- Map tables to completion items
    for _, model in ipairs(schema.children or {}) do
      table.insert(items, {
        label = model.schema .. "." .. model.name,
        kind = cmp.lsp.CompletionItemKind.Text,
        documentation = "Type: "
          .. model.type
          .. "\nName: "
          .. model.name
          .. "\nSchema: "
          .. model.schema,
        priority = 100, -- Set a lower priority for schemas and tables
      })
    end
  end
  return items
end

-- Function to map columns to completion items
local function map_to_column_completion_items(columns, schema, model)
  local items = {}
  for _, column in ipairs(columns) do
    table.insert(items, {
      label = column.name, -- Fully qualify column names
      kind = cmp.lsp.CompletionItemKind.Field,
      documentation = "Column Name: "
        .. column.name
        .. "\nType: "
        .. column.type
        .. "\nSchema: "
        .. schema
        .. "\nModel: "
        .. model,
      priority = 1000, -- Set a higher priority for columns
    })
  end
  return items
end

-- Function to map models to completion items
local function map_models_to_completion_items(models, schema)
  local items = {}
  for _, model in ipairs(models) do
    table.insert(items, {
      label = model.name,
      kind = cmp.lsp.CompletionItemKind.Text,
      documentation = "Type: " .. model.type .. "\nName: " .. model.name .. "\nSchema: " .. schema,
      priority = 100,
    })
  end
  return items
end

-- Completion function for the Dbee source
Source.complete = function(self, params, callback)
  local db_structure = Database.get_db_structure() -- Fetch the cached structure
  local items = {}

  local line = Utils:get_cursor_before_line()
  local re_references = Utils:captured_schema(line)
  -- get treesitter context (schema, table, alias, ctes, etc)
  local ts_references = Parser.get_references_at_cursor()

  if re_references then
    -- Check if the reference is an alias
    local alias_found = false
    if ts_references and ts_references.schema_table_references then
      for _, ref in ipairs(ts_references.schema_table_references) do
        if ref.alias == re_references then
          -- Alias found; retrieve columns for schema + table associated with the alias
          local schema, model = ref.schema, ref.model
          local columns = Database.get_column_completion(schema, model)
          local column_items = map_to_column_completion_items(columns, schema, model)

          -- Early callback with column items for the alias
          callback { items = column_items, isIncomplete = false }
          return
        end
      end
    end

    -- Check if the reference is a schema (default behavior)
    if not alias_found then
      local schema = re_references
      local models = Database.get_models(schema)
      local model_items = map_models_to_completion_items(models, schema)

      -- Early callback with schema-specific model items
      callback { items = model_items, isIncomplete = false }
      return
    end
  end

  -- Default completion logic (schemas, tables, columns, etc.)
  items = map_to_completion_items(db_structure)

  -- Add CTE references if available
  if ts_references and ts_references.cte_references then
    for _, cte in ipairs(ts_references.cte_references) do
      table.insert(items, {
        label = cte.cte,
        kind = cmp.lsp.CompletionItemKind.Struct,
        documentation = "CTE: " .. cte.cte,
        priority = 100,
      })
    end
  end

  -- Add schema and table references if available
  if ts_references and ts_references.schema_table_references then
    for _, refs in ipairs(ts_references.schema_table_references) do
      local schema, model, alias = refs.schema, refs.model, refs.alias

      if schema and model and schema ~= "" and model ~= "" then
        local columns = Database.get_column_completion(schema, model)
        local column_items = map_to_column_completion_items(columns, schema, model)

        if alias then
          table.insert(items, {
            label = alias,
            kind = cmp.lsp.CompletionItemKind.Text,
            documentation = "Alias for " .. schema .. "." .. model,
            priority = 200,
          })
        end

        -- Combine the items
        items = vim.list_extend(items, column_items)
      end
    end
  end

  -- Final callback with full items list
  callback { items = items, isIncomplete = false }
end

-- Create a new source object
Source.new = function()
  return setmetatable({}, { __index = Source })
end

-- Return the debug name for the source
Source.get_debug_name = function()
  return "cmp-dbee"
end

-- Check if the source is available for completion
Source.is_available = function()
  return true
end

Source.get_trigger_characters = function()
  return { '"', "`", "[", "]", ".", "(", ")" }
end

return Source
