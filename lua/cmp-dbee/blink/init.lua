local Database = require("cmp-dbee.database")
local Config = require("cmp-dbee.config")
local Parser = require("cmp-dbee.treesitter")
local Utils = require("cmp-dbee.source.utils")
local CompletionItemKind = require("blink.cmp.types").CompletionItemKind

--- @type blink.cmp.Source
--- @diagnostic disable-next-line: missing-fields
local source = {}

-- `opts` table comes from `sources.providers.your_provider.opts`
-- You may also accept a second argument `config`, to get the full
-- `sources.providers.your_provider` table
---@param opts blink-cmp-dbee.Options
function source.new(opts)
  Config.setup(opts)
  local self = setmetatable({}, { __index = source })
  self.opts = Config.get()
  return self
end

-- (Optional) Enable the source in specific contexts only
function source:enabled()
  return Database.is_available()
end

-- (Optional) Non-alphanumeric characters that trigger the source
function source:get_trigger_characters()
  return { '"', "`", "[", "]", ".", "(", ")" }
end

--- Helper function to create a completion item
--- @param label string The label of the completion item.
--- @param kind number The kind of the completion item.
--- @param documentation string The documentation for the completion item.
--- @param priority number The priority of the completion item.
--- @return lsp.CompletionItem #A completion item
local function create_completion_item(label, kind, documentation, priority)
  return {
    label = label,
    kind = kind,
    documentation = documentation,
    priority = priority,
  }
end

--- Function to map database schemas and tables to completion items
--- @param db_structure DBStructure[] The database structure to map.
--- @return lsp.CompletionItem[] #The list of completion items.
local function map_to_completion_items(db_structure)
  local items = {}

  for _, schema in ipairs(db_structure) do
    table.insert(
      items,
      create_completion_item(
        schema.name,
        CompletionItemKind.Folder,
        "Type: " .. schema.type .. "\nSchema: " .. schema.schema,
        100
      )
    )

    for _, model in ipairs(schema.children or {}) do
      table.insert(
        items,
        create_completion_item(
          model.name,
          CompletionItemKind.Class,
          "Type: " .. model.type .. "\nName: " .. model.name .. "\nSchema: " .. model.schema,
          100
        )
      )
    end
  end
  return items
end

--- Function to map columns to completion items
--- @param columns Column[] The columns to map.
--- @param schema string The schema name.
--- @param model string The model name.
--- @return lsp.CompletionItem[] #The list of completion items.
local function map_columns_to_completion_items(columns, schema, model)
  local items = {}
  for _, column in ipairs(columns) do
    table.insert(
      items,
      create_completion_item(
        column.name,
        CompletionItemKind.Field,
        "Column Name: "
          .. column.name
          .. "\nType: "
          .. column.type
          .. "\nSchema: "
          .. schema
          .. "\nModel: "
          .. model,
        1000
      )
    )
  end
  return items
end

--- Function to map models to completion items
--- @param models DBStructure[] The models to map.
--- @param schema string The schema name.
--- @return lsp.CompletionItem[] #The list of completion items
local function map_models_to_completion_items(models, schema)
  local items = {}
  for _, model in ipairs(models) do
    table.insert(
      items,
      create_completion_item(
        model.name,
        CompletionItemKind.Class,
        "Type: " .. model.type .. "\nName: " .. model.name .. "\nSchema: " .. schema,
        100
      )
    )
  end
  return items
end

---@param _ blink.cmp.Context - contains the current keyword, cursor position, bufnr, etc.
---@param callback fun(response?: blink.cmp.CompletionResponse)
---@return fun() #A cancelation function for long-running completions
function source:get_completions(_, callback)
  Database.get_db_structure(function(db_structure)
    local line = Utils:get_cursor_before_line()
    local re_references = Utils:captured_schema(line)
    local ts_references = Parser.get_references_at_cursor()

    ---@type lsp.CompletionItem[]
    local items = {}

    if re_references then
      if ts_references and ts_references.schema_table_references then
        for _, ref in ipairs(ts_references.schema_table_references) do
          if ref.alias == re_references then
            Database.get_column_completion(ref.schema, ref.model, function(columns)
              callback {
                items = map_columns_to_completion_items(columns, ref.schema, ref.model),
                is_incomplete_backward = false,
                is_incomplete_forward = false,
              }
            end)
            return
          end
        end
      end

      Database.get_models(re_references, function(models)
        callback {
          items = map_models_to_completion_items(models, re_references),
          is_incomplete_backward = false,
          is_incomplete_forward = false,
        }
      end)
      return
    end

    items = map_to_completion_items(db_structure)

    if ts_references then
      if ts_references.cte_references then
        for _, cte in ipairs(ts_references.cte_references) do
          table.insert(
            items,
            create_completion_item(cte.cte, CompletionItemKind.Struct, "CTE: " .. cte.cte, 100)
          )
        end
      end

      if ts_references.schema_table_references then
        for _, refs in ipairs(ts_references.schema_table_references) do
          if refs.schema and refs.model and refs.schema ~= "" and refs.model ~= "" then
            Database.get_column_completion(refs.schema, refs.model, function(columns)
              local column_items = map_columns_to_completion_items(columns, refs.schema, refs.model)
              if refs.alias then
                table.insert(
                  items,
                  create_completion_item(
                    refs.alias,
                    CompletionItemKind.Variable,
                    "Alias for " .. refs.schema .. "." .. refs.model,
                    200
                  )
                )
              end
              items = vim.list_extend(items, column_items)
              callback {
                items = items,
                is_incomplete_backward = false,
                is_incomplete_forward = false,
              }
            end)

            return
          end
        end
      end
    end

    callback { items = items, is_incomplete_forward = false, is_incomplete_backward = false }
  end)
  return function() end
end

return source
