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

function source:get_documentation(item)
	-- found schema + table => show columns + dtype
	if not item.schema then
		return "column: " .. item.name .. "\n" .. "type: " .. item.type
	end

	-- found schema => show all models
	if item.name == item.schema then
		local description = {}
		local leafs = self.connection:get_schema_leafs(item.name)
		for _, leaf in ipairs(leafs) do
			table.insert(description, "\t" .. leaf.type .. ": " .. leaf.name .. "\n")
		end
		return "schema: " .. item.name .. "\n" .. table.concat(description)
	end

	-- found model => show type
	if item.schema and item.name then
		return "type: " .. item.type .. "\n" .. "schema: " .. item.schema
	end

	return "NA 😳"
end

function source:convert_to_completion_item(item)
	return {
		label = item.name,
		kind = vim.lsp.protocol.CompletionItemKind.Struct,
		documentation = self:get_documentation(item),
	}
end

function source:get_completion()
	local schema_regex = "([^%.]+)%.+"
	local suggestions = {}

	-- match any non-whitespace character at the end of the line
	local before = utils.get_cursor_before_line():match("%S+$")
	local nodes = self.queries:parse_node() or {}

	-- User has ideally chosen table => suggest columns (bottom level)
	if #nodes ~= 0 then
		for _, node in ipairs(nodes) do
			local columns = self.connection:get_columns(node) or {}
			suggestions = vim.tbl_extend("force", suggestions, columns)
		end

	-- User has ideally chosen schema => suggest tables (middle level)
	elseif before and before:match(schema_regex) then
		suggestions = self.connection:get_schema_leafs(before) or {}

	-- User is typing at the beginning of the line => suggest schemas (top level)
	else
		suggestions = self.connection:get_schemas() or {}
	end

	-- exit early if no suggestions are found
	if #suggestions == 0 then
		return {}
	end

	-- Transform suggestions into completion items
	local completion_items = {}
	for _, item in ipairs(suggestions) do
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
	return { ".", " " }
end

function source:get_debug_name()
	return "cmp-dbee"
end

return source
