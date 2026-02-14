-- TreeSitter-based test tree parsing for Ginkgo v2
-- Wraps neotest.lib.treesitter.parse_positions with Ginkgo-specific logic

local M = {}

-- Query cache to avoid repeated file reads
local query_cache = {}

-- Get the plugin root directory
local function get_plugin_root()
	local source = debug.getinfo(1, "S").source:sub(2)
	return vim.fn.fnamemodify(source, ":p:h:h:h")
end

-- Load a query file by name
-- @param name string Query name (namespace, test, lifecycle, entry)
-- @return string Query content
local function load_query(name)
	if query_cache[name] then
		return query_cache[name]
	end

	local plugin_root = get_plugin_root()
	local query_path = plugin_root .. "/lua/nvim-ginkgo/queries/ginkgo/" .. name .. ".scm"

	local file = io.open(query_path, "r")
	if not file then
		error("Could not open query file: " .. query_path)
	end

	local content = file:read("*all")
	file:close()

	query_cache[name] = content
	return content
end

-- Parse test positions from a Go test file
-- @param path string Absolute path to Go test file
-- @return neotest.Tree|nil Tree of positions or nil on error
--
-- Entry Node Support:
-- Entry nodes in DescribeTable are now detected as test nodes (like It).
-- They are included in the test.scm query and automatically detected by neotest.lib.
function M.parse_positions(path)
	-- Load and combine queries (namespace + test, including Entry as tests)
	local namespace_query = load_query("namespace")
	local test_query = load_query("test")
	local combined_query = namespace_query .. "\n" .. test_query

	-- Parse using neotest lib to get all nodes including Entry as tests
	local lib = require("neotest.lib")
	local opts = {
		nested_tests = true,
		nested_namespaces = true,
		require_namespaces = true,
	}

	-- Wrap in pcall to handle file read errors gracefully
	local ok, tree = pcall(lib.treesitter.parse_positions, path, combined_query, opts)
	if not ok then
		return nil
	end

	return tree
end

return M
