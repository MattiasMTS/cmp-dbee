local M = {}

function M:new()
  local cls = {
    s = require("cmp-dbee.source"):new(),
  }
  setmetatable(cls, self)
  self.__index = self
  return cls
end

---@param params cmp.SourceCompletionApiParams
---@param callback fun(response: lsp.CompletionResponse|nil)
function M:complete(_, callback)
  local completion_items = self.s:get_completion()
  callback { items = completion_items, mark = "[DB]" }
end

function M:is_available()
  return self.s:is_available()
end

function M:get_trigger_characters()
  return self.s:get_trigger_characters()
end

function M:get_debug_name()
  return self.s:get_debug_name()
end

return M
