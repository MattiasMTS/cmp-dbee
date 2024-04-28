local Queries = {}

--- @class Queries

---
---@return Queries
function Queries:new()
  local cls = {
    filetype = "sql",
    query_object_reference = [[
(
 relation
 (
  object_reference
    schema: (identifier) @_schema (#not-eq? @_schema "")
    name: (identifier) @_name (#not-eq?  @_name  "")
  )*
 alias: (identifier) @_alias (#not-eq? @_alias "")
)
  ]],
    query_cte_references = [[( cte (identifier) @capture )]],
  }
  setmetatable(cls, self)
  self.__index = self

  return cls
end

function Queries:get_root()
  local bufnr = vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].filetype ~= self.filetype then
    vim.notify("Filetype is not " .. self.filetype)
    return
  end

  local parser = vim.treesitter.get_parser(bufnr, self.filetype, {})
  local tree = parser:parse()[1]
  return tree:root()
end

function Queries:get_valid_nodes()
  local bufnr = vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].filetype ~= self.filetype then
    vim.notify("Filetype is not " .. self.filetype)
    return
  end

  local root = self:get_root()
  if not root then
    return
  end

  local out = {}
  for root_nodes in root:iter_children() do
    if root_nodes:type() == "statement" then
      table.insert(out, root_nodes)
    end
  end

  return out
end

function Queries:get_cursor_node()
  local bufnr = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()
  local cursor_row = vim.api.nvim_win_get_cursor(win)[1]

  if vim.bo[bufnr].filetype ~= self.filetype then
    vim.notify("Filetype is not " .. self.filetype)
    return
  end

  -- get all the "statement" nodes in the current buffer/window.
  -- to handle e.g. commented code at the top, middle or bottom
  local nodes = self:get_valid_nodes()
  if not nodes then
    return
  end

  -- find the node block where the cursor is located
  for _, node in ipairs(nodes) do
    local row_start, _, row_end, _ = node:range()
    if cursor_row >= row_start and cursor_row <= row_end + 2 then
      return node
    end
  end
end

---@param node any
---@return Item
function Queries:get_cte_references(node)
  local current_node = node or self:get_cursor_node()
  if not current_node then
    return {}
  end

  local obj = vim.treesitter.query.parse(self.filetype, self.query_cte_references)
  local current_bufr = vim.api.nvim_get_current_buf()

  local out = {}
  for _, n in obj:iter_captures(current_node, current_bufr) do
    local found = vim.treesitter.get_node_text(n, current_bufr)
    table.insert(out, { schema = "", table = "", cte = found })
  end

  return out
end

---@param node any
---@return Item
function Queries:get_schema_table_alias_references(node)
  local current_node = node or self:get_cursor_node()
  if not current_node then
    return {}
  end

  local obj = vim.treesitter.query.parse(self.filetype, self.query_object_reference)
  local current_bufr = vim.api.nvim_get_current_buf()

  -- capture the schema, model and alias
  local captures = {}
  for _, n in obj:iter_captures(current_node, current_bufr) do
    local sql = vim.treesitter.get_node_text(n, current_bufr)
    table.insert(captures, sql)
  end

  local out = {}
  for i = 1, #captures, 3 do
    local schema = captures[i]
    local model = captures[i + 1]
    local alias = captures[i + 2]
    table.insert(out, { schema = schema, table = model, alias = alias })
  end

  return out
end

return Queries
