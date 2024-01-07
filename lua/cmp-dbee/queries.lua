local Queries = {}

function Queries:new()
	local o = {
		filetype = "sql",
		bufnr = vim.api.nvim_get_current_buf(),
		-- we only capture schema + table combination.
		-- having e.g. only "name" is ambiguous.
		object_reference_query = [[
(
 relation
 (
  object_reference
    schema: (identifier) @_schema
    name: (identifier) @_name
  )
)
  ]],
	}
	setmetatable(o, self)
	self.__index = self
	return o
end

function Queries:get_root()
	local bufnr = self.bufnr or vim.api.nvim_get_current_buf()
	if vim.bo[bufnr].filetype ~= self.filetype then
		vim.notify("Filetype is not " .. self.filetype)
		return
	end

	local parser = vim.treesitter.get_parser(bufnr, self.filetype, {})
	local tree = parser:parse()[1]
	return tree:root()
end

function Queries:get_valid_nodes()
	local bufnr = self.bufnr or vim.api.nvim_get_current_buf()
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
	local bufnr = self.bufnr or vim.api.nvim_get_current_buf()
	local win = vim.api.nvim_get_current_win()
	local cursor_row = vim.api.nvim_win_get_cursor(win)[1]

	if vim.bo[bufnr].filetype ~= self.filetype then
		vim.notify("Filetype is not " .. self.filetype)
		return
	end

	local nodes = self:get_valid_nodes()
	if not nodes then
		return
	end

	for _, node in ipairs(nodes) do
		-- start_row, start_col, end_row, end_col
		local start_row, _, end_row, _ = node:range()
		-- +1 and +2 since treesitter is 0-based. +2 since we want to include the last line.
		if start_row + 1 <= cursor_row and cursor_row <= end_row + 2 then
			return node
		end
	end
end

function Queries:parse_node(node)
	local current_node = node or self:get_cursor_node()
	if not current_node then
		return
	end

	if current_node:type() == "cte" then
		return self:_parse(current_node)
	elseif current_node:type() == "from" then
		return self:_parse(current_node)
	elseif current_node:type() == "select" then
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
	local out = {}
	local start_row, start_col, _, _ = node:range()
	local obj = vim.treesitter.query.parse(self.filetype, self.object_reference_query)

	for _, o in obj:iter_captures(node, self.bufnr, start_row, start_col) do
		local sql = vim.treesitter.get_node_text(o, self.bufnr)
		table.insert(out, sql)
	end

	return out
end

return Queries
