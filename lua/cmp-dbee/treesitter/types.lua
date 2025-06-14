---@class CTEReference
---@field cte string The name of the Common Table Expression (CTE).

---@class SchemaTableAliasReference
---@field schema string The schema name.
---@field model string The table/model name.
---@field alias string The alias name.

---@class ReferencesAtCursor
---@field cte_references CTEReference[] A list of CTE references.
---@field schema_table_references SchemaTableAliasReference[] A list of schema, table, and alias references.
