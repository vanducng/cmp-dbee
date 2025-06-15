local Config = {}

-- Default configuration settings
local defaults = {
  connection_timeout = 5000, -- Timeout for connection
  cmp_highlight = "CmpItemMenu", -- Highlight for completion items
  lazy_column_completion = false, -- Whether to enable lazy column completion
  polling_interval = 10000, -- Default polling interval in milliseconds
  enable_change_detection = true, -- Enable change detection by default
  disabled_databases = {}, -- List of database types to disable completion for
}

-- Function to set up configuration
function Config.setup(user_config)
  Config.settings = vim.tbl_deep_extend("force", {}, defaults, user_config or {})
end

-- Function to get current configuration settings
function Config.get()
  return Config.settings
end

return Config
