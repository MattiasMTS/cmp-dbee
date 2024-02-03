--- @class api
--- @field register_event_listener fun(event: string, callback: fun(data: table))
--- @field get_current_connection fun(): table
--- @field connection_get_structure fun(conn_id: string): table
--- @field connection_get_columns fun(conn_id: string, filter: table): table
local api = require("dbee").api.core

---@class Connection
---@field current_connection_id string
---@field structure table
---@field columns table
---@field timeout_ms number
local Connection = {}

function Connection:new()
  local cls = {
    current_connection_id = nil,
    ---@type table<string, table>
    structure = {},
    columns = {},
    timeout_ms = 1000,
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

function Connection:set_connection_id_async()
  local ok, conn_id = pcall(api.get_current_connection)
  if not ok then
    return
  end

  if not conn_id then
    return
  end
  self.current_connection_id = conn_id.id
end

function Connection:set_connection_id()
  vim.defer_fn(function()
    self:set_connection_id_async()
  end, self.timeout_ms)
end

function Connection:set_structure_async()
  if not self.current_connection_id then
    return
  end

  local ok, structure = pcall(api.connection_get_structure, self.current_connection_id)
  if not ok then
    vim.notify_once("cmp-dbee no connection or structure found")
    return
  end

  self.structure[self.current_connection_id] = structure
end

function Connection:set_structure()
  vim.defer_fn(function()
    self:set_structure_async()
  end, self.timeout_ms)
end

function Connection:get_schemas()
  return self.structure[self.current_connection_id]
end

function Connection:get_models(schema)
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

function Connection:get_columns(schema, table)
  if not schema or not table then
    return
  end

  local sha = self.current_connection_id .. "_" .. schema .. "_" .. table
  if not self.columns[sha] then
    local ok, columns = pcall(
      api.connection_get_columns,
      self.current_connection_id,
      { schema = schema, table = table }
    )
    if not ok or not columns then
      return {}
    end

    -- if any column name contain spaces -> wrap them in double quotes
    for _, column in ipairs(columns) do
      if column.name and column.name:match("%s") then
        column.name = '"' .. column.name .. '"'
      end
    end

    self.columns[sha] = columns
  end

  return self.columns[sha]
end

return Connection
