-- Build test execution specifications for Ginkgo v2
-- Handles command generation and test targeting

local async = require("neotest.async")
local plenary = require("plenary.path")

local M = {}

---Generate a Ginkgo focus pattern for a position
---Extracts the test/namespace hierarchy from position ID and creates a regex pattern
---@param position neotest.Position
---@return string Focus pattern for --focus flag
local function create_focus_pattern(position)
	-- Position ID format: "file.go::\"Describe\"::\"Context\"::\"It\""
	-- Extract everything after the first "::"
	local name = position.id
	local first_sep = name:find("::")

	if first_sep then
		name = name:sub(first_sep + 2)
	end

	-- Replace :: with spaces (Ginkgo uses spaces in test hierarchy)
	name = name:gsub("::", " ")
	-- Remove quotes around test names
	name = name:gsub('"', "")

	-- Escape forward slashes
	name = name:gsub("/", "\\/")
	-- Escape regex special characters: . + - * ? [ ] ( ) $ ^ |
	name = name:gsub("([%.%+%-%*%?%[%]%(%)%$%^%|])", "\\%1")

	-- Add word boundaries for precise matching
	-- See: https://github.com/onsi/ginkgo/issues/1126#issuecomment-1409245937
	local pattern = "\\b" .. name .. "\\b"

	return pattern
end

---Build a test execution specification
---@param args neotest.RunArgs
---@return neotest.RunSpec|nil
function M.build(args)
	local position = args.tree:data()

	-- Generate temporary file for JSON report output
	local report_path = async.fn.tempname()

	-- Build ginkgo command arguments
	local cargs = {}

	table.insert(cargs, "ginkgo")
	table.insert(cargs, "run")
	table.insert(cargs, "-v")
	table.insert(cargs, "--keep-going")
	table.insert(cargs, "--silence-skips")
	table.insert(cargs, "--json-report")
	table.insert(cargs, report_path)

	-- Determine test targeting based on position type
	local focus_file_path = nil
	local focus_dir_path = position.path
	local focus_pattern = nil

	if vim.fn.isdirectory(position.path) ~= 1 then
		-- Position is a file, test, or namespace

		if position.type == "test" or position.type == "namespace" then
			-- Target specific test or namespace within file
			-- Use both --focus-file (with line) and --focus (with pattern) for precision
			local line_number = position.range[1] + 1
			focus_file_path = position.path .. ":" .. line_number
			focus_pattern = create_focus_pattern(position)

			table.insert(cargs, "--focus-file")
			table.insert(cargs, focus_file_path)
			table.insert(cargs, "--focus")
			table.insert(cargs, focus_pattern)
		else
			-- File-level run: run all tests in the file
			focus_file_path = position.path
			table.insert(cargs, "--focus-file")
			table.insert(cargs, focus_file_path)
		end

		-- Get the directory containing the test file (for package path)
		focus_dir_path = vim.fn.fnamemodify(position.path, ":h")
	end

	-- Add any extra arguments passed by user
	local extra_args = args.extra_args or {}
	for _, value in ipairs(extra_args) do
		table.insert(cargs, value)
	end

	-- Add package path (directory/... runs all tests in directory recursively)
	table.insert(cargs, focus_dir_path .. plenary.path.sep .. "...")

	-- Return RunSpec
	return {
		command = cargs,
		context = {
			-- Store position info for result parsing
			report_input_type = position.type,
			report_input_path = position.path,
			report_output_path = report_path,
			-- Store additional context for debugging and alternative strategies
			focus_file_path = focus_file_path,
			focus_dir_path = focus_dir_path,
			focus_pattern = focus_pattern,
			extra_args = extra_args,
		},
	}
end

return M
