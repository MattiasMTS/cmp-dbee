-- TODO: add error handling
-- TODO: add logging
-- TODO: add tests
-- TODO: add documentation
-- TODO: add readme
-- TODO: add installation instructions
-- TODO: add vim.notify or errors where appropriate

local source = require("cmp-dbee.source")
local config = require("cmp-dbee.config")

local okk, cmp = pcall(require, "cmp")
if not okk then
  return
end

local M = {}

--- Setup cmp-dbee
---@param opts? Config
M.setup = function(opts)
  -- merge defaults
  local user_opts = config.merge_defaults(opts)

  -- validate
  local ok = config.validate(user_opts)
  if not ok then
    return
  end

  M._on_attach(user_opts)
end

---
---@param opts Config
M._on_attach = function(opts)
  local s = source:new(opts)
  if s:is_available() then
    cmp.register_source("cmp-dbee", s)
  end
end

return M
