local lib = require("neotest.lib")
local logger = require("neotest.logging")

local M = {}

-- Get the plugin root directory.
local plugin_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")

-- Module-level cache for loaded queries.
local query_cache = {}

--- Load a query file from the queries directory.
--- @param path string Relative path to query file.
--- @return string Query content
local function load(path)
	if query_cache[path] then
		logger.debug("Query loaded from cache: " .. path)
		return query_cache[path]
	end

	local absolute_path = plugin_root .. "/" .. path

	logger.debug("Attempting to load query from: " .. absolute_path)

	local file = io.open(absolute_path, "r")
	if not file then
		logger.error("Could not open query file: " .. absolute_path .. " (plugin_root: " .. plugin_root .. ")")
		return ""
	end

	local content = file:read("*all")
	file:close()

	logger.debug("Loaded query " .. path .. ": " .. #content .. " bytes")

	query_cache[path] = content

	return content
end

local queries = {
	load("queries/go/namespace.scm"),
	load("queries/go/test.scm"),
}

--- Clear the query cache.
--- @return nil
function M.flush_cache()
	query_cache = {}
end

--- Check if the required parsers are available.
--- @return boolean
function M.has_parser()
	if vim.treesitter.language and vim.treesitter.language.add then
		return pcall(function()
			vim.treesitter.language.add("go")
		end)
	end
	return false
end

---@type fun(file_path: string, source: string, captured_nodes: table<string, userdata>, metadata: table<string, vim.treesitter.query.TSMetadata>): neotest.Position|neotest.Position[]|nil Builds one or more positions from the captured nodes from a query match.
function M.build_position(path, source, captured_nodes)
	local function get_match_type()
		if captured_nodes["test.name"] then
			return "test"
		end
		if captured_nodes["namespace.name"] then
			return "namespace"
		end
	end

	local match_type = get_match_type()
	-- if we have a match
	if match_type then
		---@type string
		local name = vim.treesitter.get_node_text(captured_nodes[match_type .. ".name"], source)
		local match_name = vim.treesitter.get_node_text(captured_nodes["func_name"], source)
		local definition = captured_nodes[match_type .. ".definition"]

		-- Special handling for Entry: determine type based on parent context
		if match_name:match("^[FPX]?Entry$") then
			logger.debug("Found Entry: " .. name)
			-- The definition node is the Entry call_expression
			-- Its parent is argument_list, and that argument_list's parent is the containing call_expression
			local arg_list = definition:parent()
			logger.debug("Parent type: " .. (arg_list and arg_list:type() or "nil"))
			if arg_list and arg_list:type() == "argument_list" then
				local parent_call = arg_list:parent()
				logger.debug("Grandparent type: " .. (parent_call and parent_call:type() or "nil"))
				if parent_call and parent_call:type() == "call_expression" then
					local func_field = parent_call:field("function")
					if func_field and func_field[1] then
						local parent_func_name = vim.treesitter.get_node_text(func_field[1], source)
						logger.debug("Parent function: " .. parent_func_name)
						-- If parent is DescribeTableSubtree, Entry should be a namespace
						if parent_func_name:match("^[FPX]?DescribeTableSubtree$") then
							match_type = "namespace"
							logger.debug("Changed Entry to namespace")
						-- If parent is DescribeTable, Entry should be a test
						elseif parent_func_name:match("^[FPX]?DescribeTable$") then
							match_type = "test"
							logger.debug("Kept Entry as test (DescribeTable)")
						end
					end
				end
			end
		end

		name, _ = string.gsub(name, '"', "")
		-- prepare the name
		if match_name == "When" then
			name = string.lower(match_name) .. " " .. name
		end

		return {
			type = match_type,
			path = path,
			name = '"' .. name .. '"',
			range = { definition:range() },
		}
	end
end

--- Detect Ginkgo tests in a file.
--- @param path string Absolute path to the Go test file
--- @return neotest.Tree|nil Tree of detected tests, or nil if parsing failed
function M.parse(path)
	if not M.has_parser() then
		logger.error("Go tree-sitter parser not found. Install with :TSInstall go", true)
		return nil
	end

	return lib.treesitter.parse_positions(path, table.concat(queries, "\n"), {
		nested_namespaces = true,
		require_namespaces = true,
		build_position = M.build_position,
	})
end

return M
