local lib = require("neotest.lib")
local logger = require("neotest.logging")
local Tree = require("neotest.types").Tree

local M = {}

-- Get the plugin root directory
local plugin_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")

-- Module-level cache for loaded queries
local query_cache = {}

--- Load a query file from the queries directory
--- @param path string Relative path to query file
--- @return string Query content
local function load(path)
	if query_cache[path] then
		return query_cache[path]
	end

	local absolute_path = plugin_root .. "/" .. path
	local file = io.open(absolute_path, "r")

	if not file then
		logger.error("Could not open query file: " .. absolute_path)
		return ""
	end

	local content = file:read("*all")
	file:close()
	query_cache[path] = content

	return content
end

local queries = {
	load("queries/go/namespace.scm"),
	load("queries/go/test.scm"),
}

--- Clear the query cache
function M.flush_cache()
	query_cache = {}
end

--- Check if the required parsers are available
--- @return boolean
function M.has_parser()
	if vim.treesitter.language and vim.treesitter.language.add then
		return pcall(function()
			vim.treesitter.language.add("go")
		end)
	end
	return false
end

--- Check if an Entry node is inside a DescribeTableSubtree
--- @param definition userdata The call_expression node
--- @param source string Source content
--- @return boolean
local function is_entry_in_describe_table_subtree(definition, source)
	local parent = definition:parent()
	if not parent or parent:type() ~= "argument_list" then
		return false
	end

	local grandparent = parent:parent()
	if not grandparent or grandparent:type() ~= "call_expression" then
		return false
	end

	local func_field = grandparent:field("function")
	if not func_field or not func_field[1] then
		return false
	end

	local parent_func_name = vim.treesitter.get_node_text(func_field[1], source)

	return parent_func_name:match("^[FPX]?DescribeTableSubtree$") ~= nil
end

--- Build a position from captured treesitter nodes
--- @param path string File path
--- @param source string Source content
--- @param captured_nodes table Captured nodes from query
--- @return neotest.Position|nil
function M.build_position(path, source, captured_nodes)
	local match_type
	if captured_nodes["test.name"] then
		match_type = "test"
	elseif captured_nodes["namespace.name"] then
		match_type = "namespace"
	else
		return nil
	end

	local name = vim.treesitter.get_node_text(captured_nodes[match_type .. ".name"], source)
	local match_name = vim.treesitter.get_node_text(captured_nodes["func_name"], source)
	local definition = captured_nodes[match_type .. ".definition"]

	-- Skip Entry nodes inside DescribeTableSubtree (they'll be parsed manually during restructure)
	if match_name:match("^[FPX]?Entry$") and is_entry_in_describe_table_subtree(definition, source) then
		return nil
	end

	-- Remove quotes from name
	name = name:gsub('"', "")

	-- Special formatting for When
	if match_name == "When" then
		name = string.lower(match_name) .. " " .. name
	end

	-- Create position
	local range
	if match_name:match("^[FPX]?DescribeTableSubtree$") then
		-- Extend range to include all Entry arguments
		local args = definition:field("arguments")
		if args and args[1] then
			local arg_list = args[1]
			local start_row, start_col, _, _ = definition:range()
			local _, _, end_row, end_col = arg_list:range()
			range = { start_row, start_col, end_row, end_col }
		else
			range = { definition:range() }
		end
	else
		range = { definition:range() }
	end

	return {
		type = match_type,
		path = path,
		name = '"' .. name .. '"',
		range = range,
	}
end

--- Parse Entry nodes from source within a given range
--- @param source string Source content
--- @param range table Range to search within
--- @return table[] Array of entry info {name, range}
local function parse_entries_from_source(source, range)
	local parser = vim.treesitter.get_string_parser(source, "go")
	local tree = parser:parse()[1]
	local root = tree:root()

	local query = vim.treesitter.query.parse("go", load("queries/go/entry.scm"))
	local entries = {}

	for id, node in query:iter_captures(root, source, range[1], range[3] + 1) do
		local name = query.captures[id]
		if name == "entry.name" then
			local entry_name = vim.treesitter.get_node_text(node, source):gsub('"', "")
			local parent = node:parent():parent() -- call_expression
			local start_row, start_col, end_row, end_col = parent:range()

			-- Verify this Entry belongs to a DescribeTableSubtree
			local arg_list = parent:parent()
			if arg_list and arg_list:type() == "argument_list" then
				local desc_call = arg_list:parent()
				if desc_call and desc_call:type() == "call_expression" then
					local func_node = desc_call:field("function")
					if func_node and func_node[1] then
						local func_name = vim.treesitter.get_node_text(func_node[1], source)
						if func_name:match("^[FPX]?DescribeTableSubtree$") then
							table.insert(entries, {
								name = '"' .. entry_name .. '"',
								range = { start_row, start_col, end_row, end_col },
							})
						end
					end
				end
			end
		end
	end

	return entries
end

--- Update IDs in a tree to insert a new parent in the hierarchy
--- @param tree neotest.Tree
--- @param parent_id string The parent ID to insert after
--- @param insert_segment string The segment to insert
--- @return neotest.Tree
local function update_tree_ids(tree, parent_id, insert_segment)
	local data = tree:data()

	-- Create a copy of the data to avoid mutating the original
	local new_data = {}
	for k, v in pairs(data) do
		new_data[k] = v
	end

	-- Update this node's ID by inserting the new segment after parent_id
	if new_data.id:find(parent_id, 1, true) then
		new_data.id = new_data.id:gsub("^(" .. vim.pesc(parent_id) .. ")(::)", "%1::" .. insert_segment .. "%2")
	end

	-- Recursively update children
	local children = tree:children()
	if #children > 0 then
		local new_children = {}
		for _, child in ipairs(children) do
			table.insert(new_children, update_tree_ids(child, parent_id, insert_segment))
		end
		return Tree:new(new_data, new_children, tree._key, nil, tree._nodes)
	end

	return Tree:new(new_data, {}, tree._key, nil, tree._nodes)
end

--- Post-process tree to duplicate body tests under DescribeTableSubtree Entry namespaces
--- @param tree neotest.Tree
--- @param source string Source content
--- @return neotest.Tree
local function restructure_describe_table_subtree(tree, source)
	local data = tree:data()

	-- Check if this is a DescribeTableSubtree by looking for Entry nodes in its range
	if data.type == "namespace" then
		local entries = parse_entries_from_source(source, data.range)

		if #entries > 0 then
			-- This is a DescribeTableSubtree - first recursively process all children
			local children = tree:children()
			local processed_children = {}
			for _, child in ipairs(children) do
				table.insert(processed_children, restructure_describe_table_subtree(child, source))
			end

			-- Calculate ranges for Entry namespaces
			-- First Entry gets range from DescribeTableSubtree start to first Entry end
			-- Other Entries get range from their Entry line only
			local body_start_row = data.range[1]

			-- Now duplicate the processed children under each Entry
			local new_children = {}
			for i, entry_info in ipairs(entries) do
				local entry_range
				if i == 1 then
					-- First Entry: range from body start through this Entry
					entry_range = { body_start_row, data.range[2], entry_info.range[3], entry_info.range[4] }
				else
					-- Other Entries: just their own line
					entry_range = entry_info.range
				end

				local entry_data = {
					type = "namespace",
					path = data.path,
					name = entry_info.name,
					range = entry_range,
					id = data.path .. "::" .. data.name .. "::" .. entry_info.name,
				}

				-- Duplicate all processed body nodes under this Entry
				local entry_children = {}
				for _, processed_node in ipairs(processed_children) do
					-- Update the IDs to include the Entry name in the hierarchy
					local updated = update_tree_ids(processed_node, data.id, entry_info.name)
					table.insert(entry_children, updated)
				end

				local entry_tree = Tree:new(entry_data, entry_children, tree._key, nil, tree._nodes)
				table.insert(new_children, entry_tree)
			end

			return Tree:new(data, new_children, tree._key, nil, tree._nodes)
		end
	end

	-- Recursively process children
	local children = tree:children()
	if #children > 0 then
		local new_children = {}
		for _, child in ipairs(children) do
			table.insert(new_children, restructure_describe_table_subtree(child, source))
		end
		return Tree:new(data, new_children, tree._key, nil, tree._nodes)
	end

	return tree
end

--- Detect Ginkgo tests in a file
--- @param path string Absolute path to the Go test file
--- @return neotest.Tree|nil Tree of detected tests, or nil if parsing failed
function M.parse(path)
	if not M.has_parser() then
		logger.error("Go tree-sitter parser not found. Install with :TSInstall go")
		return nil
	end

	-- Read source content
	local file = io.open(path, "r")
	if not file then
		logger.error("Could not open file: " .. path)
		return nil
	end
	local source = file:read("*all")
	file:close()

	-- Parse positions using treesitter queries
	local tree = lib.treesitter.parse_positions(path, table.concat(queries, "\n"), {
		nested_namespaces = true,
		require_namespaces = false,
		build_position = M.build_position,
	})

	if not tree then
		return nil
	end

	-- Post-process to handle DescribeTableSubtree
	return restructure_describe_table_subtree(tree, source)
end

return M
