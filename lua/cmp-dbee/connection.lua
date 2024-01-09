local api = require("dbee").api.core

local Connection = {}

function Connection:new()
	local cls = {
		current_connection_id = nil,
		structure = {},
		columns = {},
	}
	setmetatable(cls, self)
	self.__index = self

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
	-- TODO: remove later
	-- print("connection changed!", "before:", self.current_connection_id, "after:", data.conn_id)

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
		if not conn_id then
			vim.notify_once("No connection found.")
			return
		end
		self.current_connection_id = conn_id.id
	end)
end

function Connection:set_structure()
	vim.schedule(function()
		if not self.current_connection_id then
			return
		end

		local structure = api.connection_get_structure(self.current_connection_id)
		self.structure[self.current_connection_id] = structure
	end)
end

function Connection:get_schemas()
	return self.structure[self.current_connection_id]
end

function Connection:get_schema_leafs(schema)
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

function Connection:get_columns(opts)
	if not opts.schema or not opts.table then
		return
	end

	local sha = self.current_connection_id .. "_" .. opts.schema .. "_" .. opts.table
	if not self.columns[sha] then
		local columns = api.connection_get_columns(self.current_connection_id, opts)
		if not columns then
			self.columns[sha] = {}
		end

		self.columns[sha] = columns
	end

	return self.columns[sha]
end
return Connection
