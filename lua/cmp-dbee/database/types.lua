---@class ConnectionID
---@field id connection_id string
---@field name string display name
---@field type string database type
---@field url string connection url

---@class DBStructure
---@field name string display name
---@field type structure_type type of node in structure
---@field schema string? parent schema
---@field children DBStructure[]? child layout nodes

---@class Column
---@field name string name of the column
---@field type string database type of the column

---@alias Callback function

---@class Database
---@field cache table<string, DBStructure[]> cache of database structures
---@field column_cache table<string, table<string, table<string, Column[]>>> cache of columns
---@field cache_expiry_s number cache expiry time in seconds
---@field cache_last_updated table<string, number> last updated time of cache
