-- source is the source of the completion items.
local source = {}

local dbee = require("dbee")
local handler = require("cmp-dbee.handler")

--- Constructor for nvim-cmp source
---@param cfg Config
function source:new(cfg)
  local cls = { handler = handler:new(cfg) }
  setmetatable(cls, self)
  self.__index = self
  return cls
end

function source:complete(_, callback)
  local completion_items = self.handler:get_completion()
  callback {
    items = completion_items,
  }
end

function source:is_available()
  return dbee.api.core.is_loaded() and dbee.api.ui.is_loaded()
end

function source:get_trigger_characters()
  return { ".", " ", "(" }
end

function source:get_debug_name()
  return "cmp-dbee"
end

return source
