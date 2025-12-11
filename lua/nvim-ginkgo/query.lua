local lib = require("neotest.lib")
local logger = require("neotest.logging")
local utils = require("nvim-ginkgo.utils")

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
		build_position = utils.create_position,
	})
end

return M
