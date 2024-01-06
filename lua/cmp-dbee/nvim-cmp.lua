-- source is the source of the completion items.
local source = {}

local connection = require("cmp-dbee.connection")
local dbee = require("dbee")

function source:new()
	local cls = {
		connection = connection:new(),
	}
	setmetatable(cls, self)
	self.__index = self
	return cls
end

---@param params cmp.SourceCompletionApiParams
---@param callback fun(response: lsp.CompletionResponse|nil)
function source:complete(params, callback)
	local ctx = params.context
	local line = ctx.cursor_before_line:match("%S+$")

	local suggestions = {}

	-- TODO: add column cmp support
	if not line then
		-- User is typing at the beginning of the line, suggesting schemas
		suggestions = self.connection:get_schemas()
	else
		-- User is typing in the middle of the line, suggesting tables
		suggestions = self.connection:get_nodes(line)
	end

	-- Transform suggestions into completion items
	local completion_items = {}
	for _, item in ipairs(suggestions) do
		table.insert(completion_items, { label = item.name })
	end

	callback(completion_items)
end

function source:get_trigger_characters()
	return { ".", " " }
end

function source:is_available()
	return dbee.is_open()
end

function source:get_debug_name()
	return "cmp-dbee"
end

return source
