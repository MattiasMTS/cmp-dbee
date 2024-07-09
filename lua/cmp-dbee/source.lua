-- source is the source of the completion items.
local source = {}

local dbee = require("dbee")
local handler = require("cmp-dbee.handler")

--- Constructor for nvim-cmp source
---@param cfg Config
function source:new(cfg)
  local is_available = self:is_available()
  local cls = { handler = handler:new(cfg, is_available) }
  setmetatable(cls, self)
  self.__index = self
  return cls
end

function source:complete(_, callback)
  if not self.handler then
    return callback {}
  end

  local items = self.handler:get_completion()
  callback {
    items = items,
    isIncomplete = false,
  }
end

function source:is_available()
  return dbee.api.core.is_loaded() and dbee.api.ui.is_loaded()
end

function source:get_trigger_characters()
  return { '"', "`", "[", "]", ".", "(", ")" }
end

function source:get_debug_name()
  return "cmp-dbee"
end

return source
