-- source is the source of the completion items.
local source = {}

local connection = require("cmp-dbee.connection")
local queries = require("cmp-dbee.queries")
local dbee = require("dbee")

function source:new()
	local cls = {
		connection = connection:new(),
		queries = queries:new(),
	}
	setmetatable(cls, self)
	self.__index = self
	return cls
end

---@param params cmp.SourceCompletionApiParams
---@param callback fun(response: lsp.CompletionResponse|nil)
function source:complete(params, callback)
	local ctx = params.context
	local schema_regex = "([^%.]+)%.+"

	-- match any non-whitespace character at the end of the line
	local before = ctx.cursor_before_line:match("%S+$")
	local nodes = self.queries:parse_node()
	print("nodes", vim.inspect(nodes))
	-- if nodes then
	-- 	-- TODO: add lookup in structure for materialization
	-- 	-- (if we want to support more than just table)

	-- 	local opts = {
	-- 		schema = nodes[1],
	-- 		table = nodes[2],
	-- 		materialization = "table",
	-- 	}
	-- 	self.connection:get_columns(opts)
	-- end

	local suggestions = {}

	-- User has ideally chosen schema => suggest tables (middle level)
	if before and before:match(schema_regex) then
		suggestions = self.connection:get_schema_leafs(before)
	-- User is typing at the beginning of the line => suggest schemas (top level)
	else
		suggestions = self.connection:get_schemas()
	end

	-- exit early if no suggestions are found
	if not suggestions then
		callback({ items = {} })
	end

	-- TODO: add icon, documentation, kind, etc.

	-- Transform suggestions into completion items
	local completion_items = {}
	for _, item in ipairs(suggestions) do
		table.insert(completion_items, { label = item.name })
	end

	callback({ items = completion_items })
end

function source:get_trigger_characters()
	return { ".", " " }
end

function source:is_available()
	return dbee.is_open() and self.connection.current_connection_id
end

function source:get_debug_name()
	return "cmp-dbee"
end

return source
