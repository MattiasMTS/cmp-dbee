local M = {}

-- Function to get the text of the line before the cursor
function M:get_cursor_before_line()
  -- local lines = vim.api.nvim_buf_get_lines(0, 0, vim.api.nvim_win_get_cursor(0)[1], false)

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

-- Function to get the schema from the line before the cursor
function M:captured_schema(line)
  local cursor_before_line = line or self:get_cursor_before_line()
  -- take into account the keyword can be upper or lower case and stuff before it
  local schema = cursor_before_line:match("[from|FROM|join|JOIN]%s+([^%.%s|%.]+)")
  if schema then
    return schema
  end

  return cursor_before_line:match('[from|FROM|join|JOIN]%s+"([^"]+)')
end

-- Function to get the table from the line before the cursor
function M:capture_table_based_on_schema(line)
  local cursor_before_line = line or self:get_cursor_before_line()
  return cursor_before_line:match("[from|FROM|JOIN|join]%s+[^%.%s]+%.([^%.%s]+)")
end

-- Function to check if a table exists in a list
function M:table_exist_in_list(list, target_table)
  for _, tbl in ipairs(list) do
    if self:table_equal(tbl, target_table) then
      return true
    end
  end
  return false
end

-- Function to check if two tables are equal
function M:table_equal(table1, table2)
  if #table1 ~= #table2 then
    return false
  end

  for k, v in pairs(table1) do
    if table2[k] ~= v then
      return false
    end
  end

  return true
end

return M
