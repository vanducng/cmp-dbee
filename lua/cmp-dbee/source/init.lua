local cmp = require("cmp")
local Database = require("cmp-dbee.database")
local Parser = require("cmp-dbee.treesitter.parser")

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

-- Completion function for the Dbee source
Source.complete = function(self, params, callback)
  local db_structure = Database.get_db_structure() -- Fetch the cached structure
  local items = {}

  -- Get the items for schemas and tables based on the current context
  items = map_to_completion_items(db_structure)

  -- get treesitter context (schema, table, alias, ctes, etc)
  local references = Parser.get_references_at_cursor()

  -- Get CTE references from the cursor context
  if references and references.cte_references then
    local cte_references = references.cte_references or {}
    for _, cte in ipairs(cte_references) do
      table.insert(items, {
        label = cte.cte,
        kind = cmp.lsp.CompletionItemKind.Struct,
        documentation = "CTE: " .. cte.cte,
        priority = 100,
      })
    end
  end

  -- Get schema and table references from the cursor context
  if references and references.schema_table_references then
    -- Access schema/table references
    local schema_tables = references.schema_table_references or {}
    for _, refs in ipairs(schema_tables) do
      local schema, model, alias = refs.schema, refs.model, refs.alias

      if schema and model and schema ~= "" and model ~= "" then
        local columns = Database.get_column_completion(schema, model) -- Fetch column completions
        local column_items = map_to_column_completion_items(columns, schema, model)

        -- Add alias as a completion item
        if alias then
          table.insert(items, {
            label = alias,
            kind = cmp.lsp.CompletionItemKind.Text,
            documentation = "Alias for " .. schema .. "." .. model,
            priority = 200, -- Set a lower priority for aliases
          })
        end

        -- Combine the items
        items = vim.list_extend(items, column_items)
      end
    end
  end

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

return Source
