-- TODO: add error handling
-- TODO: add logging
-- TODO: add tests
-- TODO: add documentation
-- TODO: add readme
-- TODO: add installation instructions
-- TODO: add vim.notify or errors where appropriate

local dbee_cmp = require("cmp-dbee.nvim-cmp")

local M = {}

function M:setup() end

function M:new()
  local o = dbee_cmp:new()
  return o
end

return M
