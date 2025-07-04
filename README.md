# cmp-dbee

[![ci](https://github.com/MattiasMTS/cmp-dbee/actions/workflows/ci.yml/badge.svg)](https://github.com/MattiasMTS/cmp-dbee/actions/workflows/ci.yml)

<!--toc:start-->

- [cmp-dbee](#cmp-dbee)
  - [Showcase](#showcase)
  - [Usage](#usage)
    - [Suggestions](#suggestions)
  - [Installation](#installation)
  - [Configuration](#configuration)
    - [Disabling Completion for Specific Databases](#disabling-completion-for-specific-databases)
    - [Advanced Configuration](#advanced-configuration)
  <!--toc:end-->

Autocompletion plugin for [nvim-dbee](https://github.com/kndndrj/nvim-dbee/) database client.

> Still very much a WIP plugin => expect some breaking changes.

Feel free to open any issues or PRs as you seem fit!

## Showcase

https://github.com/MattiasMTS/cmp-dbee/assets/86059470/1a0141dd-cb4d-47ce-b510-148d654d9503

## Usage

cmp-dbee is using a little bit of regex but mostly Treesitter to generate
suggestions.

### Suggestions

TL;DR

- schemas
- leaf of schemas (tables, views, functions, etc)
- aliases
- CTEs
- columns: name and dtype (by referencing aliases)

By default, schema + model suggestion is generated whenever a user hits "space".
At this point, the syntax for the SQL query isn't complete and the plugin
therefore uses a little bit of regex to "find/match" the selected schema.

Ones the schemas has been found, the plugin suggests all the "leafs"
for the schema.

CTEs and aliases are suggested based on the cursor position. I.e. if you've
two _complete_ (complete = ended with ';') queries in the buffer. Then, only
the aliases and ctes which the current cursor are nearest will be suggested.

Column suggestion is provided by being explicit. I.e. you'd have to refer the
alias of a table if you want column completion. This is to reduce ambiguity
when there are other suggestions that compete. Column completion provide you
with the current name and the datatype of the column. As of now, only table
leafs provides columns. This might change in the future.

## Installation

- Using **lazy**:

```lua
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      {
        "MattiasMTS/cmp-dbee",
        dependencies = {
          {"kndndrj/nvim-dbee"}
        },
        ft = "sql", -- optional but good to have
        opts = {}, -- needed
      },
    },
    opts = {
      sources = {
        { "cmp-dbee" },
      },
    },
  }
```

- Using **packer**:

```lua
   use({"hrsh7th/nvim-cmp", requires = {"MattiasMTS/cmp-dbee"}})
   use{
     "kndndrj/nvim-dbee",
      run = function()
        require("dbee").install()
      end,
   }
```

## Configuration

cmp-dbee supports configuration to customize behavior for different database types.

### Disabling Completion for Specific Databases

You can disable completion for specific database types (useful for large databases or to prevent lag):

```lua
require("cmp-dbee").setup({
  -- Disable completion for Snowflake to prevent lag
  disabled_databases = { "snowflake" },
})
```

### Advanced Configuration

For more control, use database-specific overrides:

```lua
require("cmp-dbee").setup({
  database_overrides = {
    snowflake = {
      completion_enabled = false,  -- Disable completion
      execution_enabled = true,    -- Still allow query execution
    },
    bigquery = {
      completion_enabled = false,
    },
  },
  debug = {
    enabled = false,
    log_disabled_connections = true,
  },
})
```

See [CONFIGURATION.md](docs/CONFIGURATION.md) for detailed configuration options.
