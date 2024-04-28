--- @class api
--- @field register_event_listener fun(event: string, callback: fun(data: table))
--- @field get_current_connection fun(): table
--- @field connection_get_structure fun(conn_id: string): table
--- @field connection_get_columns fun(conn_id: string, filter: table): table
local api = require("dbee").api.core

---@class Connection
---@field id string
---@field structures Structures
---@field columns table
---@field timeout_ms number
local Connection = {}

---@class Structures
---@field id string
---@field children Children

---@class Children
---@field name string
---@field schema string
---@field type string
---@field children Children

---@class Item
---@field name string
---@field schema string
---@field type string
---@field alias string?
---@field cte string?
---@field description string?

--- Constructor for Connection
---@param cfg Config
---@return Connection
function Connection:new(cfg)
  local cls = {
    id = "",
    db_name = "",
    structures = {},
    flatten_structure = {},
    columns = {},
    timeout_ms = cfg.connection.timeout_ms or 1000,
    config = cfg,
  }
  setmetatable(cls, self)
  self.__index = self

  -- TODO: add event bus for structure change

  -- listen to switch in connections
  api.register_event_listener("current_connection_changed", function(data)
    local on_current_connection_changed = function()
      if cls.id ~= data.conn_id then
        cls:set_id()
      end

      -- if the structure for the current connection is not yet cached => cache it
      if not cls.structures[data.conn_id] then
        cls:set_structure()
      end
    end
    on_current_connection_changed()
  end)

  -- listen to all database switch events
  api.register_event_listener("current_database_changed", function(data)
    local on_current_database_changed = function()
      if cls.db_name ~= data.db_name then
        cls:set_structure()
      end
    end
    on_current_database_changed()
  end)

  return cls
end

function Connection:set_id()
  local _set_id_fn = function()
    local ok, conn_id = pcall(api.get_current_connection)
    if not ok then
      return
    end

    if not conn_id then
      return
    end
    self.id = conn_id.id
  end

  vim.defer_fn(function()
    _set_id_fn()
  end, self.timeout_ms)
end

function Connection:set_structure()
  local _set_structure_fn = function()
    if not self.id then
      return
    end

    local ok, structure = pcall(api.connection_get_structure, self.id)
    if not ok then
      return
    end

    self.structures[self.id] = structure
  end

  vim.defer_fn(function()
    _set_structure_fn()
  end, self.timeout_ms)
end

function Connection:get_flatten_structure()
  local exist = self.flatten_structure[self.id]
  if exist then
    return exist
  end

  local get_flatten_structure = function(iterable)
    local out = {}
    vim.tbl_map(function(node)
      if #node.children > 0 then
        vim.tbl_map(function(child)
          table.insert(out, {
            name = node.name .. "." .. child.name,
            schema = node.name,
            type = child.type,
            children = {},
          })
        end, node.children)
      end
    end, iterable)

    return out
  end

  local structure = self.structures[self.id]
  if structure then
    local flatten = get_flatten_structure(structure)
    self.flatten_structure[self.id] = flatten
    return flatten
  end
end

function Connection:get_schemas()
  return self.structures[self.id]
end

--- Returns the models for the given schema.
function Connection:get_models(schema)
  local structure = self.structures[self.id]
  if not structure then
    return {}
  end

  for _, node in ipairs(structure) do
    if schema:match(node.name) and node.children then
      return node.children
    end
  end
end

function Connection:get_columns(schema, table)
  if not schema or not table then
    return
  end

  local sha = self.id .. "_" .. schema .. "_" .. table
  if not self.columns[sha] then
    local input = {
      schema = schema,
      table = table,
    }
    local ok, columns = pcall(api.connection_get_columns, self.id, input)
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
