-- source is the source of the completion items.
local source = {}

-- api is the api for interacting with the database etc.
local dbee = require("dbee")
local api = dbee.api.core

function source:new()
	local cls = {
		current_connection_id = nil,
		structure = {},
	}
	setmetatable(cls, self)
	self.__index = self

	-- add structure for the current connection async
	cls:set_connection_id()
	cls:set_structure()

	-- listen to connection changes
	api.register_event_listener("current_connection_changed", function(data)
		cls:on_current_connection_changed(data)
	end)

	return cls
end

---@private
---@param data { conn_id: connection_id }
function source:on_current_connection_changed(data)
	-- TODO: think about refreshing the connection

	-- if the connection is changed => change the current connection id
	if self.current_connection_id ~= data.conn_id then
		self:set_connection_id()
	end

	-- if the structure for the current connection is not yet cached => cache it
	if not self.structure[data.conn_id] then
		self:set_structure()
	end
end

function source:set_connection_id()
	vim.schedule(function()
		local conn_id = api.get_current_connection()
		self.current_connection_id = conn_id.id
	end)
end

function source:set_structure()
	vim.schedule(function()
		local conn_id = self.current_connection_id
		local structure = api.connection_get_structure(conn_id)
		self.structure[conn_id] = structure
	end)
end

function source:get_schemas()
	return self.structure[self.current_connection_id]
end

function source:get_nodes(schema)
	local structure = self.structure[self.current_connection_id]
	if structure then
		for _, node in ipairs(structure) do
			if schema:match(node.name) and node.children then
				return node.children
			end
		end
	end
	return {}
end

-- Use the source:complete function to provide autocompletion suggestions
---@param params cmp.SourceCompletionApiParams
---@param callback fun(response: lsp.CompletionResponse|nil)
function source:complete(params, callback)
	local ctx = params.context
	local line = ctx.cursor_before_line:match("%S+$")

	local suggestions = {}

	-- TODO: add column cmp support
	if not line then
		-- User is typing at the beginning of the line, suggesting schemas
		suggestions = self:get_schemas()
	else
		-- User is typing in the middle of the line, suggesting tables
		suggestions = self:get_nodes(line)
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
