local api = require("dbee").api.core

local Connection = {}

-- TODO: set timeout to the calls in case the connection is bad => otherwise the plugin will hang
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
		local ok, conn_id = pcall(api.get_current_connection)
		if not ok then
			return
		end

		if not conn_id then
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

		local ok, structure = pcall(api.connection_get_structure, self.current_connection_id)
		if not ok then
			vim.notify_once("cmp-dbee: no connection or structure found")
			return
		end
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
		local ok, columns = pcall(api.connection_get_columns, self.current_connection_id, opts)
		if not ok or not columns then
			return {}
		end

		self.columns[sha] = columns
	end

	return self.columns[sha]
end

return Connection
