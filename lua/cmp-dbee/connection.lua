local api = require("dbee").api.core

local Connection = {}

function Connection:new()
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

function Connection:clear_cache()
	self.current_connection_id = nil
	self.structure = {}
end

function Connection:on_current_connection_changed(data)
	print("connection changed!", "before:", self.current_connection_id, "after:", data.conn_id) -- TODO: remove later

	-- if the connection is changed => change the current connection id
	if self.current_connection_id ~= data.conn_id then
		self:set_connection_id()
	end

	-- if the structure for the current connection is not yet cached => cache it
	if not self.structure[data.conn_id] then
		self:set_structure()
	end
end

function Connection:set_connection_id()
	vim.schedule(function()
		local conn_id = api.get_current_connection()
		self.current_connection_id = conn_id.id
	end)
end

function Connection:set_structure()
	vim.schedule(function()
		local conn_id = self.current_connection_id
		local structure = api.connection_get_structure(conn_id)
		self.structure[conn_id] = structure
	end)
end

function Connection:get_schemas()
	return self.structure[self.current_connection_id]
end

function Connection:get_nodes(schema)
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

return Connection
