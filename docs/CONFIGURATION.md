# cmp-dbee Configuration Guide

## Disabling Completion for Specific Databases

The cmp-dbee plugin now supports flexible configuration to disable completion for specific database types while maintaining query execution capabilities.

### Basic Configuration

To disable completion for specific database types, use the `disabled_databases` option:

```lua
require("cmp-dbee").setup({
  -- Disable completion for Snowflake and BigQuery
  disabled_databases = { "snowflake", "bigquery" },
})
```

### Advanced Configuration with Overrides

For fine-grained control over individual database types, use `database_overrides`:

```lua
require("cmp-dbee").setup({
  database_overrides = {
    snowflake = {
      completion_enabled = false,  -- Disable completion
      execution_enabled = true,    -- Still allow query execution
    },
    bigquery = {
      completion_enabled = false,
      -- execution_enabled defaults to true
    },
  },
})
```

### Configuration Options

#### `disabled_databases`
- **Type**: `table` (array of strings)
- **Default**: `{}`
- **Description**: List of database type names to disable completion for

#### `database_overrides`
- **Type**: `table` (map of database configs)
- **Default**: `{}`
- **Description**: Per-database configuration overrides
  - `completion_enabled`: `boolean` - Enable/disable completion
  - `execution_enabled`: `boolean` - Enable/disable query execution

### Supported Database Types

The following database type names are recognized:
- `snowflake`
- `postgres` / `postgresql`
- `mysql` / `mariadb`
- `bigquery`
- `sqlite`
- `sqlserver`
- `oracle`
- `redshift`
- `clickhouse`
- `databricks`
- `duckdb`

### Debug Options

To troubleshoot configuration:

```lua
require("cmp-dbee").setup({
  disabled_databases = { "snowflake" },
  debug = {
    enabled = true,
    log_disabled_connections = true,
  },
})
```

This will log messages when completion is disabled for a connection.

## Architecture

The filtering system uses a centralized approach:

1. **Filter Module** (`database/filter.lua`): Single source of truth for checking if completion/execution is enabled
2. **NoOpStrategy**: Special strategy that returns empty results for disabled databases
3. **Consistent Checks**: All modules use the same filter logic

This architecture makes it easy to:
- Add new database types to the disabled list
- Configure database-specific behavior
- Maintain consistency across the codebase
- Debug configuration issues