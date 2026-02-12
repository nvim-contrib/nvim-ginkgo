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
-- KNOWN LIMITATION: Entry nodes in DescribeTable and DescribeTableSubtree are NOT detected.
--
-- Why Entry nodes are challenging:
-- 1. Entry nodes are call_expression nodes nested INSIDE an argument_list
-- 2. They're not at statement level (not direct children of a block)
-- 3. neotest.lib.treesitter.parse_positions() only builds trees from statement-level nodes
-- 4. Even though our Entry query matches correctly, neotest.lib filters them out
--
-- Example AST structure:
--   DescribeTable/DescribeTableSubtree call_expression
--   └── argument_list
--       ├── "Test Name" (string)
--       ├── func(...) { ... } (function body)
--       ├── Entry("case 1", 1, 2, 3)  ← Entry here (nested in argument_list)
--       └── Entry("case 2", 100, 200, 300)
--
-- Current behavior:
-- - DescribeTable/DescribeTableSubtree: ✅ Detected as namespace
-- - DescribeTableSubtree It blocks: ✅ Detected as tests (workaround available)
-- - DescribeTable: ⚠️ No It blocks, so no runnable tests without Entry support
-- - Entry nodes: ⚠️ Not detected (documented limitation)
--
-- Impact:
-- - DescribeTableSubtree users can still run tests (It blocks are detected)
-- - DescribeTable users should prefer DescribeTableSubtree for now
--
-- TODO: Future enhancement could implement Entry support through:
-- 1. Post-processing after main tree parse
-- 2. Using vim.treesitter directly to extract Entry nodes from argument_list
-- 3. Creating Entry Tree objects and integrating into the tree
-- This requires deep understanding of neotest.Tree API and is complex to implement correctly.
function M.parse_positions(path)
	-- Load and combine queries
	local namespace_query = load_query("namespace")
	local test_query = load_query("test")
	-- Note: entry.scm query file exists but is not loaded here due to Entry detection limitation (see above)
	-- Note: lifecycle.scm exists but is not loaded (lifecycle hooks are not runnable tests)

	local combined_query = namespace_query .. "\n" .. test_query

	-- Parse using neotest lib
	local lib = require("neotest.lib")
	local opts = {
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
