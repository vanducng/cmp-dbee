local Config = require("cmp-dbee.config")
local Source = require("cmp-dbee.source")

local M = {}

M.setup = function(user_config)
  print("cmp-dbee setup")
  Config.setup(user_config)

  local cmp = require("cmp")
  cmp.register_source("cmp-dbee", Source.new())
end

return M
