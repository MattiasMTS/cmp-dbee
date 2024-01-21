local Queries = {}

function Queries:new()
	local o = {
		filetype = "sql",
		ts_query = [[
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
	}
	setmetatable(o, self)
	self.__index = self
	return o
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

	-- capture all the "statement" nodes in the current buffer/window.
	-- to handle e.g. commented code at the top, middle or bottom
	local out = {}
	for root_statement in root:iter_children() do
		if root_statement:type() == "statement" then
			for node in root_statement:iter_children() do
				table.insert(out, node)
			end
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

	-- go down the list of "statement" nodes and find
	-- the one that contains the cursor.
	for _, node in ipairs(nodes) do
		-- start_row, start_col, end_row, end_col
		local node_start_row, _, node_end_row, _ = node:range()
		-- +2 and +1 since treesitter is 0-based and we want to include the last line.
		if cursor_row >= node_start_row and cursor_row <= node_end_row + 2 then
			return node
		end
	end
end

function Queries:get_metadata(node)
	local current_node = node or self:get_cursor_node()
	if not current_node then
		return {}
	end

	local obj = vim.treesitter.query.parse(self.filetype, self.ts_query)
	local current_bufr = vim.api.nvim_get_current_buf()

	-- ones found our node => capture the query representing the schema+table
	local captures = {}
	for _, n in obj:iter_captures(current_node, current_bufr) do
		local sql = vim.treesitter.get_node_text(n, current_bufr)
		table.insert(captures, sql)
	end

	local out = {}
	if #captures == 0 then
		return out
	end

	-- order is based on the self.ts_query capture order.
	for i = 1, #captures, 3 do
		local schema = captures[i]
		local model = captures[i + 1]
		local alias = captures[i + 2]
		table.insert(out, { schema = schema, table = model, alias = alias })
	end

	return out
end

return Queries
