---@mod cmp-dbee.source Source Module
---@brief [[
---This module provides functions to map database schemas, tables, and columns
---to completion items for the cmp-dbee plugin.
---
---Access it like this:
--->
---local Source = require("cmp-dbee.source")
---<
---@brief ]]

local cmp = require("cmp")
local Database = require("cmp-dbee.database")
local Parser = require("cmp-dbee.treesitter")
local Utils = require("cmp-dbee.source.utils")

--- @class Source
local Source = {}

--- Helper function to create a completion item
--- @param label string The label of the completion item.
--- @param kind number The kind of the completion item.
--- @param documentation string The documentation for the completion item.
--- @param priority number The priority of the completion item.
--- @return table The completion item.
local function create_completion_item(label, kind, documentation, priority)
  return {
    label = label,
    kind = kind,
    documentation = documentation,
    priority = priority,
  }
end

--- Function to map database schemas and tables to completion items
--- @param db_structure DBStructure[] The database structure to map.
--- @return table The list of completion items.
local function map_to_completion_items(db_structure)
  local items = {}

  for _, schema in ipairs(db_structure) do
    table.insert(
      items,
      create_completion_item(
        tostring(schema.name or ""),
        cmp.lsp.CompletionItemKind.Struct,
        "Type: " .. tostring(schema.type or "") .. "\nSchema: " .. tostring(schema.schema or ""),
        100
      )
    )

    for _, model in ipairs(schema.children or {}) do
      table.insert(
        items,
        create_completion_item(
          tostring(model.name or ""),
          cmp.lsp.CompletionItemKind.Text,
          "Type: " .. tostring(model.type or "") .. "\nName: " .. tostring(model.name or "") .. "\nSchema: " .. tostring(model.schema or ""),
          100
        )
      )
    end
  end
  return items
end

--- Function to map columns to completion items
--- @param columns Column[] The columns to map.
--- @param schema string The schema name.
--- @param model string The model name.
--- @return table The list of completion items.
local function map_columns_to_completion_items(columns, schema, model)
  local items = {}
  for _, column in ipairs(columns) do
    table.insert(
      items,
      create_completion_item(
        tostring(column.name or ""),
        cmp.lsp.CompletionItemKind.Field,
        "Column Name: "
          .. tostring(column.name or "")
          .. "\nType: "
          .. tostring(column.type or "")
          .. "\nSchema: "
          .. tostring(schema or "")
          .. "\nModel: "
          .. tostring(model or ""),
        1000
      )
    )
  end
  return items
end

--- Function to map models to completion items
--- @param models DBStructure[] The models to map.
--- @param schema string The schema name.
--- @return table The list of completion items.
local function map_models_to_completion_items(models, schema)
  local items = {}
  for _, model in ipairs(models) do
    table.insert(
      items,
      create_completion_item(
        tostring(model.name or ""),
        cmp.lsp.CompletionItemKind.Text,
        "Type: " .. tostring(model.type or "") .. "\nName: " .. tostring(model.name or "") .. "\nSchema: " .. tostring(schema or ""),
        100
      )
    )
  end
  return items
end

--- Completion function for the Dbee source
--- @param callback Callback The callback function to return the completion items.
Source.complete = function(_, _, callback)
  Database.get_db_structure(function(db_structure)
    local line = Utils:get_cursor_before_line()
    local re_references = Utils:captured_schema(line)
    local ts_references = Parser.get_references_at_cursor()
    local items = {}

    -- Get current connection for strategy selection
    local current_connection = Database.get_current_connection()

    if re_references then
      if ts_references and ts_references.schema_table_references then
        for _, ref in ipairs(ts_references.schema_table_references) do
          if ref.alias == re_references then
            Database.get_column_completion(ref.schema, ref.model, function(columns)
              callback {
                items = map_columns_to_completion_items(columns, ref.schema, ref.model),
                isIncomplete = false,
              }
            end)
            return
          end
        end
      end

      -- Use strategy pattern for database-specific completion
      local strategy = require("cmp-dbee.database.strategy")
      local completion_context = strategy.parse_completion_context(line, current_connection)
      
      if completion_context then
        -- Use database-specific strategy
        completion_context.strategy:get_qualified_completions(completion_context, function(results)
          if completion_context.type == "column" then
            callback {
              items = map_columns_to_completion_items(results, completion_context.parts.schema or "public", completion_context.parts.table),
              isIncomplete = false,
            }
          elseif completion_context.type == "table" then
            callback {
              items = map_models_to_completion_items(results, completion_context.parts.schema or completion_context.parts.database),
              isIncomplete = false,
            }
          else
            -- Handle special results like guidance messages
            if type(results[1]) == "table" and results[1].label then
              -- Convert to nvim-cmp format
              local guidance_items = {}
              for _, item in ipairs(results) do
                table.insert(guidance_items, create_completion_item(
                  item.label,
                  cmp.lsp.CompletionItemKind.Text,
                  item.documentation and item.documentation.value or item.detail or "",
                  50
                ))
              end
              callback {
                items = guidance_items,
                isIncomplete = false,
              }
            else
              callback {
                items = map_models_to_completion_items(results, re_references),
                isIncomplete = false,
              }
            end
          end
        end)
      else
        -- Fallback to legacy logic
        Database.get_models(re_references, function(models)
          callback {
            items = map_models_to_completion_items(models, re_references),
            isIncomplete = false,
          }
        end)
      end
      return
    end

    items = map_to_completion_items(db_structure)

    if ts_references then
      if ts_references.cte_references then
        for _, cte in ipairs(ts_references.cte_references) do
          table.insert(
            items,
            create_completion_item(
              tostring(cte.cte or ""),
              cmp.lsp.CompletionItemKind.Struct,
              "CTE: " .. tostring(cte.cte or ""),
              100
            )
          )
        end
      end

      if ts_references.schema_table_references then
        for _, refs in ipairs(ts_references.schema_table_references) do
          if refs.schema and refs.model and refs.schema ~= "" and refs.model ~= "" then
            Database.get_column_completion(refs.schema, refs.model, function(columns)
              local column_items = map_columns_to_completion_items(columns, refs.schema, refs.model)
              if refs.alias then
                table.insert(
                  items,
                  create_completion_item(
                    tostring(refs.alias or ""),
                    cmp.lsp.CompletionItemKind.Text,
                    "Alias for " .. tostring(refs.schema or "") .. "." .. tostring(refs.model or ""),
                    200
                  )
                )
              end
              items = vim.list_extend(items, column_items)
              callback { items = items, isIncomplete = false }
            end)

            return
          end
        end
      end
    end

    callback { items = items, isIncomplete = false }
  end)
end

--- Construct a new source object
--- @return Source The new source object.
Source.new = function()
  return setmetatable({}, { __index = Source })
end

--- Return the debug name for the source
--- @return string The debug name.
Source.get_debug_name = function()
  return "dbee"
end

--- Check if the source is available for completion
--- @return boolean True if the source is available, false otherwise.
Source.is_available = function()
  return Database.is_available()
end

--- Get the trigger characters for the source
--- @return string[] The list of trigger characters.
Source.get_trigger_characters = function()
  return { '"', "`", "[", "]", ".", "(", ")" }
end

return Source
