-- source is the source of the completion items.
local source = {}

local connection = require("cmp-dbee.connection")
local queries = require("cmp-dbee.queries")
local dbee = require("dbee")
local utils = require("cmp-dbee.utils")

function source:new()
  local cls = {
    connection = connection:new(),
    queries = queries:new(),
    latest_model = nil,
    latest_schema = nil,
    latest_metadata = {},
  }
  setmetatable(cls, self)
  self.__index = self
  return cls
end

function source:get_documentation(item)
  -- found schema + table => show columns + dtype
  if not item.schema then
    return "column: " .. item.name .. "\n" .. "type: " .. item.type
  end

  -- found schema => show all models
  if item.name == item.schema then
    local description = {}
    local models = self.connection:get_models(item.name)
    for _, m in ipairs(models) do
      table.insert(description, "\t" .. m.type .. ": " .. m.name .. "\n")
    end
    return "schema: " .. item.name .. "\n" .. table.concat(description)
  end

  -- found model => show type
  if item.schema and item.name then
    return "type: " .. item.type .. "\n" .. "schema: " .. item.schema
  end

  return "unknown => open an issue!"
end

function source:convert_to_completion_item(item)
  return {
    label = item.name,
    kind = vim.lsp.protocol.CompletionItemKind.Struct,
    documentation = self:get_documentation(item),
  }
end

function source:convert_many_to_completion_items(items)
  if not items then
    return {}
  end

  if #items == 0 then
    return {}
  end

  local completion_items = {}
  for _, item in ipairs(items) do
    table.insert(completion_items, self:convert_to_completion_item(item))
  end
  return completion_items
end

function source:get_completion()
  local cursor_before_line = utils:get_cursor_before_line()
  local schema = utils:captured_schema(cursor_before_line)
  local model = utils:capture_table_based_on_schema(cursor_before_line)
  local metadata = self.queries:get_metadata()

  if #self.latest_metadata > 0 or #metadata > 0 then
    if #metadata > 0 then
      self.latest_metadata = metadata
    end
    for _, m in ipairs(self.latest_metadata) do
      if not m.alias then
        goto continue
      end
      if cursor_before_line:match(m.alias .. "%.$") then
        return self:convert_many_to_completion_items(self.connection:get_columns(m.schema, m.table))
      end
      ::continue::
    end
  end

  if schema and model then
    self.latest_schema, self.latest_model = schema, model
    return self:convert_many_to_completion_items(self.connection:get_columns(schema, model))
  end

  if schema then
    self.latest_schema = schema
    return self:convert_many_to_completion_items(self.connection:get_models(schema))
  end

  -- if we don't find anything => show schemas or aliases
  local schemas = self.connection:get_schemas()
  if #self.latest_metadata > 0 then
    for _, m in ipairs(self.latest_metadata) do
      if not m.alias then
        goto continue
      end
      local alias = { name = m.alias, type = "alias" }
      if not utils:table_exist_in_list(schemas, alias) then
        table.insert(schemas, alias)
      end
      ::continue::
    end
  end
  return self:convert_many_to_completion_items(schemas)
end

function source:is_available()
  if not dbee.is_open() or self.connection.current_connection_id == nil then
    return false
  end

  return true
end

function source:get_trigger_characters()
  return { ".", " ", "(", ")", '"' }
end

function source:get_debug_name()
  return "cmp-dbee"
end

return source
