-- TODO: add error handling
-- TODO: add logging
-- TODO: add tests
-- TODO: add documentation
-- TODO: add readme
-- TODO: add installation instructions
-- TODO: add vim.notify or errors where appropriate

local M = {}

--- Setup cmp-dbee
---@param opts? Config
M.setup = function(opts)
  local source = require("cmp-dbee.source")
  local config = require("cmp-dbee.config")

  local has_nvim_cmp, cmp = pcall(require, "cmp")
  if not has_nvim_cmp then
    return
  end

  -- merge defaults
  local user_opts = config.merge_defaults(opts)

  -- validate
  local ok = config.validate(user_opts)
  if not ok then
    return
  end

  -- register
  local s = source:new(user_opts)
  cmp.register_source("cmp-dbee", s)
end

return M
