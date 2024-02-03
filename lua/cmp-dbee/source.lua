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
  }
  setmetatable(cls, self)
  self.__index = self
  return cls
end

function source:get_completion()
  local cursor_before_line = utils:get_cursor_before_line()
  local schema = utils:captured_schema(cursor_before_line)
  local ts_structure = self.queries:get_metadata()

  -- if we have an alias, show columns
  if #ts_structure > 0 then
    for _, m in ipairs(ts_structure) do
      -- if we don't have an alias, skip
      if not m.alias then
        goto continue
      end
      if cursor_before_line:match("[%s%(]" .. m.alias .. "%.$") then
        return self:convert_many_to_completion_items(self.connection:get_columns(m.schema, m.table))
      end
      ::continue::
    end
  end

  -- if we have a schema, show models
  if schema then
    return self:convert_many_to_completion_items(self.connection:get_models(schema))
  end

  -- TODO: add ctes
  -- if we don't find anything => show schemas/ctes/aliases
  local schemas = self.connection:get_schemas()
  if #ts_structure > 0 then
    for _, m in ipairs(ts_structure) do
      if not m.alias or m.alias == "" then
        goto continue
      end

      local alias_found = { name = m.alias, type = "alias" }
      if not utils:table_exist_in_list(schemas, alias_found) then
        table.insert(schemas, alias_found)
      end

      ::continue::
    end
  end

  return self:convert_many_to_completion_items(schemas)
end

function source:get_documentation(item)
  -- found schema + table => show columns + dtype
  if not item.schema then
    return "name: " .. item.name .. "\n" .. "type: " .. item.type
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
  if item.name == "no schema to show" then
    return {}
  end
  return {
    label = item.name,
    documentation = self:get_documentation(item),
    kind = vim.lsp.protocol.CompletionItemKind.Text,
    -- TODO: add kind/mark etc
  }
end

function source:convert_many_to_completion_items(items)
  if not items or #items == 0 then
    return {}
  end

  local completion_items = {}
  for _, item in ipairs(items) do
    table.insert(completion_items, self:convert_to_completion_item(item))
  end
  return completion_items
end

function source:is_available()
  if not dbee.is_open() or self.connection.current_connection_id == nil then
    return false
  end

  return true
end

function source:get_trigger_characters()
  return { ".", " ", "(" }
end

function source:get_debug_name()
  return "cmp-dbee"
end

return source
