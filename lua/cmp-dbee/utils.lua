local M = {}
-- Function to get the text of the line before the cursor
function M:get_cursor_before_line()
	-- Get the current line number and cursor position
	local line_number = vim.fn.line(".")
	local col_number = vim.fn.col(".")

	-- If the cursor is not at the beginning of the line, get the substring before the cursor
	if col_number > 1 then
		local current_line = vim.api.nvim_get_current_line()
		return string.sub(current_line, 1, col_number - 1)
	end

	-- If the cursor is at the beginning of the line, get the text of the previous line
	if line_number > 1 then
		return vim.fn.getline(line_number - 1)
	end

	-- If the cursor is at the beginning of the first line, return an empty string
	return ""
end

return M
