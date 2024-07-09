-- source is the source of the completion items.
local source = {}

local dbee = require("dbee")
local handler = require("cmp-dbee.handler")

function is_available()
    return dbee.api.core.is_loaded() and dbee.api.ui.is_loaded()
end

--- Constructor for nvim-cmp source
---@param cfg Config
function source:new(cfg)
  local cls = { cfg = cfg }
  setmetatable(cls, self)
  self.__index = self
  return cls
end

function source:complete(_, callback)
  if not self.handler then
    if is_available() then
        self.handler = handler:new(self.cfg, true)
    else
        return callback {}
    end
  end

  local items = self.handler:get_completion()
  callback {
    items = items,
    isIncomplete = false,
  }
end

function source:is_available()
  return is_available()
end

function source:get_trigger_characters()
  return { '"', "`", "[", "]", ".", "(", ")" }
end

function source:get_debug_name()
  return "cmp-dbee"
end

return source
