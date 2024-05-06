local Handler = {}

-- TODO: give this some more love later on.

---@class Handler
---@field connection Connection
---@field queries Queries
---@field latest_ts_structure table
---@field latest_cte_references table
---@field cfg Config

---@class CmpCandyItem
---@field kind_text string
---@field kind_hl_group string

local constants = require("cmp-dbee.constants")
local utils = require("cmp-dbee.utils")

---
---@param cfg Config
---@param is_available boolean
---@return any
function Handler:new(cfg, is_available)
  if not is_available then
    return
  end

  local connection = require("cmp-dbee.connection")
  local queries = require("cmp-dbee.queries")

  local cls = {
    conn = connection:new(cfg),
    queries = queries:new(),
    latest_ts_structure = {},
    latest_cte_references = {},
    cfg = cfg,
  }
  setmetatable(cls, self)
  self.__index = self
  return cls
end

function Handler:get_completion()
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
        local columns = self.conn:get_columns(m.schema, m.table)
        return self:convert_many_to_completion_items(columns)
      end
    end
  end

  -- if we have a schema, show models
  if schema then
    local models = self.conn:get_models(schema)
    return self:convert_many_to_completion_items(models)
  end

  -- if we don't find anything => show keywords/schemas/ctes/aliases
  local out = {}

  if #self.latest_cte_references > 0 then
    for _, m in ipairs(self.latest_cte_references) do
      if m.cte then
        local rv = { name = m.cte, type = "cte" }
        if not utils:table_exist_in_list(out, rv) then
          table.insert(out, rv)
        end
      end
    end
  end

  if #self.latest_ts_structure > 0 then
    for _, m in ipairs(self.latest_ts_structure) do
      if m.alias then
        local rv = { name = m.alias, type = "alias" }
        if not utils:table_exist_in_list(out, rv) then
          table.insert(out, rv)
        end
      end
    end
  end

  -- extend with schemas + tables from the connection
  -- so we don't modify the original list
  vim.list_extend(out, self.conn:get_schemas() or {})
  vim.list_extend(out, self.conn:get_flatten_structure() or {})
  -- we add these last so we don't polluted the list with reserved keywords
  vim.list_extend(out, constants.reserved_sql_keywords)
  return self:convert_many_to_completion_items(out)
end

---
---@param n Item
---@return string
function Handler:get_documentation(n)
  -- found schema + table => show columns + dtype or reserved_sql_keywords
  if not n.schema then
    return "name: " .. n.name .. "\n" .. "type: " .. n.type
  end

  -- found schema => show all models
  if n.name == n.schema then
    local description = {}
    local models = self.conn:get_models(n.name)
    for _, m in ipairs(models) do
      table.insert(description, "\t" .. m.type .. ": " .. m.name .. "\n")
    end
    return "schema: " .. n.name .. "\n" .. table.concat(description)
  end

  -- found model => show type
  if n.schema and n.name then
    local name = n.name
    if name:match("%.") then
      name = name:match("%.(.*)")
    end
    -- stylua: ignore
    return "name: "
      .. name
      .. "\n"
      .. "type: "
      .. n.type
      .. "\n"
      .. "schema: "
      .. n.schema
  end

  return "unknown => open an issue!"
end

--- TODO: make this prettier later
---@param item Item
---@return CmpCandyItem
function Handler:_resolve_cmp_candy(item)
  local default = {
    kind_text = "text",
    kind_hl_group = "String",
  }
  local out = {}
  local cfg = self.cfg.cmp_menu

  if not item.type or item.type ~= "" then
    out = cfg[item.type]

    if not item.schema then
      out = {
        kind_text = item.type,
        kind_hl_group = cfg.columns.kind_hl_group,
      }
    end
  end

  if item.name == item.schema then
    out = cfg.schema
  end

  if item.type == "keyword" then
    out = cfg.keyword
  end

  if item.type == "alias" then
    out = cfg.alias
  end

  if item.type == "cte" then
    out = cfg.cte
  end

  return out or default
end

function Handler:convert_to_completion_item(item)
  if item.name == "no schema to show" then
    return {}
  end

  return {
    label = item.name,
    documentation = {
      kind = "Markdown",
      value = "```\n" .. self:get_documentation(item) .. "\n```",
    },
    -- kind = "[DB]",
    -- detail = "doc:", -- TODO:
    ---@type CmpCandyItem
    cmp = self:_resolve_cmp_candy(item),
  }
end

function Handler:convert_many_to_completion_items(items)
  if not items or #items == 0 then
    return {}
  end

  local completion_items = {}
  for _, item in ipairs(items) do
    table.insert(completion_items, self:convert_to_completion_item(item))
  end
  return completion_items
end

return Handler
