local Queries = {}

function Queries:new()
	local o = {
		filetype = "sql",
		-- we only capture schema + table combination.
		-- having e.g. only "name" is ambiguous.
		object_reference_query = [[
(
 relation
 (
  object_reference
    schema: (identifier) @_schema (#not-eq? @_schema "")
    name: (identifier) @_name (#not-eq?  @_name  "")
  )
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

-- TODO: double check this on 2 incomplete sql statements
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

	for _, node in ipairs(nodes) do
		-- start_row, start_col, end_row, end_col
		local start_row, _, end_row, _ = node:range()
		-- +2 since treesitter is 0-based and we want to include the last line.
		if start_row <= cursor_row and cursor_row <= end_row + 2 then
			return node
		end
	end
end

function Queries:parse_node(node)
	local current_node = node or self:get_cursor_node()
	if not current_node then
		return
	end
	local node_type = current_node:type()

	if node_type == "cte" or node_type == "from" then
		return self:_parse(current_node)

	-- TODO: support incomplete SELECT statement
	elseif node_type == "select" then
		-- go to next node to get the "from" clause
		local next_node = current_node:next_named_sibling()
		if not next_node then
			return
		end
		return self:_parse(next_node)
	else
		return
	end
end

function Queries:_parse(node)
	local start_row, start_col, _, _ = node:range()
	local obj = vim.treesitter.query.parse(self.filetype, self.object_reference_query)
	local current_bufr = vim.api.nvim_get_current_buf()

	-- ones found our node => capture the query representing the schema+table
	local captures = {}
	for _, n in obj:iter_captures(node, current_bufr, start_row, start_col) do
		local sql = vim.treesitter.get_node_text(n, current_bufr)
		table.insert(captures, sql)
	end

	local out = {}
	if #captures == 0 then
		return out
	end

	for i = 1, #captures, 2 do
		local schema = captures[i]
		local model = captures[i + 1]
		table.insert(out, { schema = schema, table = model })
	end

	return out
end

return Queries
