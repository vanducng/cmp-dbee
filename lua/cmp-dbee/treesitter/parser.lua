local Parser = {}

-- SQL specific queries for Tree-sitter.
Parser.filetype = "sql"
Parser.query_object_reference = [[
(relation
 (
  object_reference
    schema: (identifier) @_schema
    name: (identifier) @_table
  )
  alias: (identifier)? @_alias
)
]]

Parser.query_cte_references = "(cte (identifier) @cte)"

-- Get the root of the AST for the current buffer if it matches the filetype.
function Parser.get_root()
  local bufnr = vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].filetype ~= Parser.filetype then
    return nil
  end

  local parser = vim.treesitter.get_parser(bufnr, Parser.filetype, {})
  return parser:parse()[1]:root()
end

-- Get the node under the cursor.
function Parser.get_cursor_node()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_row = vim.api.nvim_win_get_cursor(0)[1]

  if vim.bo[bufnr].filetype ~= Parser.filetype then
    return nil
  end

  local root = Parser.get_root()
  if not root then
    return nil
  end

  for node in root:iter_children() do
    if node:type() == "statement" then
      local row_start, _, row_end, _ = node:range()
      if cursor_row >= row_start and cursor_row <= row_end + 2 then
        return node
      end
    end
  end
  return nil
end

-- Retrieve CTE references from the current cursor node or a specified node.
local function get_cte_references(node)
  local captures = {}
  local query = vim.treesitter.query.parse(Parser.filetype, Parser.query_cte_references)
  local bufnr = vim.api.nvim_get_current_buf()

  for _, n in query:iter_captures(node, bufnr) do
    local found = vim.treesitter.get_node_text(n, bufnr)
    table.insert(captures, { cte = found })
  end

  return captures
end

-- Retrieve schema, table, and alias references from the current cursor node or a specified node.
local function get_schema_table_alias_references(node)
  local out = {}
  local query = vim.treesitter.query.parse(Parser.filetype, Parser.query_object_reference)
  local bufnr = vim.api.nvim_get_current_buf()

  local schemas, models, aliases = {}, {}, {} -- placeholders
  for id, n in query:iter_captures(node, bufnr) do
    local capture_text = vim.treesitter.get_node_text(n, bufnr)
    local capture_name = query.captures[id]

    if capture_name == "_schema" then
      table.insert(schemas, capture_text) -- Add to schemas
    elseif capture_name == "_table" then
      table.insert(models, capture_text) -- Add to models
    elseif capture_name == "_alias" then
      table.insert(aliases, capture_text) -- Add to aliases
    end
  end

  -- Construct the captures based on pairs of schemas and models
  for i, model in ipairs(models) do
    local schema = schemas[i] or "" -- Get the corresponding schema or empty if none
    local alias = aliases[i] or "" -- Get the corresponding alias or empty if none
    if schema ~= "" and model ~= "" then
      table.insert(out, { schema = schema, model = model, alias = alias })
    end
  end

  return out
end

-- New function to get all references based on the cursor position
-- TODO: fix so that you can capture multiple statement without having to add ';' at the end.
function Parser.get_references_at_cursor()
  local current_node = Parser.get_cursor_node()
  if not current_node then
    return nil
  end

  local cte_references = get_cte_references(current_node)
  local schema_table_references = get_schema_table_alias_references(current_node)

  return {
    cte_references = cte_references,
    schema_table_references = schema_table_references,
  }
end

return Parser
