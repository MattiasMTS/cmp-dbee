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
    latest_ts_structure = {},
    latest_cte_references = {},
  }
  setmetatable(cls, self)
  self.__index = self
  return cls
end

function source:get_completion()
  local cursor_before_line = utils:get_cursor_before_line()
  local schema = utils:captured_schema(cursor_before_line)
  local ts_structure = self.queries:get_schema_table_alias_references()
  local cte_references = self.queries:get_cte_references()

  if #ts_structure > 0 then
    self.latest_ts_structure = ts_structure
  end

  if #cte_references > 0 then
    self.latest_cte_references = cte_references
  end

  -- if we have an alias, show columns
  if #self.latest_ts_structure > 0 then
    for _, m in ipairs(self.latest_ts_structure) do
      -- if alias exists and cursor before is matching it from right to left => show columns
      if m.alias and cursor_before_line:match("[%s%(]" .. m.alias .. "%.$") then
        local columns = self.connection:get_columns(m.schema, m.table)
        return self:convert_many_to_completion_items(columns)
      end
    end
  end

  -- if we have a schema, show models
  if schema then
    local models = self.connection:get_models(schema)
    return self:convert_many_to_completion_items(models)
  end

  -- if we don't find anything => show schemas/ctes/aliases
  local schemas = {}

  if #self.latest_cte_references > 0 then
    for _, m in ipairs(self.latest_cte_references) do
      if m.cte then
        local rv = { name = m.cte, type = "cte" }
        if not utils:table_exist_in_list(schemas, rv) then
          table.insert(schemas, rv)
        end
      end
    end
  end

  if #self.latest_ts_structure > 0 then
    for _, m in ipairs(self.latest_ts_structure) do
      if m.alias then
        local rv = { name = m.alias, type = "alias" }
        if not utils:table_exist_in_list(schemas, rv) then
          table.insert(schemas, rv)
        end
      end
    end
  end

  -- extend with schemas from the connection
  -- so we don't modify the original list
  vim.list_extend(schemas, self.connection:get_schemas())
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
  return dbee.is_core_loaded()
    and dbee.is_ui_loaded()
    and dbee.is_open()
    and self.connection.current_connection_id ~= nil
end

function source:get_trigger_characters()
  return { ".", " ", "(" }
end

function source:get_debug_name()
  return "cmp-dbee"
end

return source
