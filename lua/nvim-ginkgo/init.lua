local lib = require("neotest.lib")
local plenary = require("plenary.path")
local async = require("neotest.async")
local logger = require("neotest.logging")
local utils = require("nvim-ginkgo.utils")

---@class nvim-ginkgo.Config
---@field args? string[] Extra arguments to pass to ginkgo
---@field exclude_dirs? string[] Directories to exclude (in addition to vendor)
---@field race? boolean Enable race detection (--race)
---@field label_filter? string Ginkgo v2 label filter expression
---@field timeout? string Test timeout (e.g., "60s", "5m")
---@field ginkgo_cmd? string Path to ginkgo binary (default: "ginkgo")

---@type nvim-ginkgo.Config
local default_config = {
	args = {},
	exclude_dirs = {},
	race = false,
	label_filter = nil,
	timeout = nil,
	ginkgo_cmd = "ginkgo",
}

---@type nvim-ginkgo.Config
local config = vim.deepcopy(default_config)

---@type neotest.Adapter
local adapter = { name = "nvim-ginkgo" }

---Find the project root directory given a current directory to work from.
---Should no root be found, the adapter can still be used in a non-project context if a test file matches.
---@async
---@return string | nil @Absolute root dir of test suite
adapter.root = lib.files.match_root_pattern("go.mod", "go.sum")

---Filter directories when searching for test files
---@async
---@param name string Name of directory
---@param rel_path string Path to directory, relative to root
---@param root string Root directory of project
---@return boolean
function adapter.filter_dir(name, rel_path, root)
	-- exclude vendor directories at any level
	if name == "vendor" then
		return false
	end
	-- exclude user-configured directories
	for _, excluded in ipairs(config.exclude_dirs) do
		if name == excluded then
			return false
		end
	end
	return true
end

---@async
---@param file_path string
---@return boolean
function adapter.is_test_file(file_path)
	if not vim.endswith(file_path, ".go") or vim.endswith(file_path, "suite_test.go") then
		return false
	end

	local file_path_segments = vim.split(file_path, plenary.path.sep)
	local file_path_basename = file_path_segments[#file_path_segments]
	return vim.endswith(file_path_basename, "_test.go")
end

---Given a file path, parse all the tests within it.
---@async
---@param file_path string Absolute file path
---@return neotest.Tree | nil
function adapter.discover_positions(file_path)
	local query = [[
    ; -- Namespaces --
    ; Matches: `describe('subject')` and `context('case')`
    ((call_expression
      function: (identifier) @func_name (#any-of? @func_name "Describe" "FDescribe" "PDescribe" "XDescribe" "DescribeTable" "FDescribeTable" "PDescribeTable" "XDescribeTable" "Context" "FContext" "PContext" "XContext" "When" "FWhen" "PWhen" "XWhen")
      arguments: (argument_list ((interpreted_string_literal) @namespace.name))
    )) @namespace.definition

    ; -- Tests --
    ; Matches: `it('test')`
    ((call_expression
      function: (identifier) @func_name (#any-of? @func_name "It" "FIt" "PIt" "XIt" "Specify" "FSpecify" "PSpecify" "XSpecify" "Entry" "FEntry" "PEntry" "XEntry")
      arguments: (argument_list ((interpreted_string_literal) @test.name))
    )) @test.definition
  ]]

	local options = {
		nested_namespaces = true,
		require_namespaces = true,
		build_position = utils.create_position,
	}

	return lib.treesitter.parse_positions(file_path, query, options)
end

---@param args neotest.RunArgs
---@return nil | neotest.RunSpec | neotest.RunSpec[]
function adapter.build_spec(args)
	local report_path = async.fn.tempname()
	local report_filename = vim.fn.fnamemodify(report_path, ":t")
	local report_directory = vim.fn.fnamemodify(report_path, ":h")

	-- build command as a table for proper argument handling
	local cargs = {
		config.ginkgo_cmd,
		"run",
		"-v",
		"--keep-going",
		"--output-dir",
		report_directory,
		"--json-report",
		report_filename,
		"--silence-skips",
	}

	-- add race detection if enabled
	if config.race then
		table.insert(cargs, "--race")
	end

	-- add timeout if configured
	if config.timeout then
		table.insert(cargs, "--timeout")
		table.insert(cargs, config.timeout)
	end

	-- add label filter if configured (Ginkgo v2)
	if config.label_filter then
		table.insert(cargs, "--label-filter")
		table.insert(cargs, config.label_filter)
	end

	-- add user-configured extra args
	for _, arg in ipairs(config.args) do
		table.insert(cargs, arg)
	end

	local position = args.tree:data()

	-- add build tags if present in the test file
	local test_file_path = position.path
	if vim.fn.isdirectory(test_file_path) ~= 1 then
		local build_tags = utils.get_build_tags(test_file_path)
		if build_tags ~= "" then
			table.insert(cargs, build_tags)
		end
	end

	local directory = position.path
	-- The path for the position is not a directory, ensure the directory variable refers to one
	if vim.fn.isdirectory(position.path) ~= 1 then
		local focus_file_path = position.path
		-- prepare the focus path
		if position.type == "test" or position.type == "namespace" then
			local line_number = position.range[1] + 1
			-- replace the focus_file_path with its line number
			focus_file_path = position.path .. ":" .. line_number
			-- create the focus pattern
			local focus_pattern = utils.create_position_focus(position)
			-- prepare the arguments
			table.insert(cargs, "--focus")
			table.insert(cargs, focus_pattern)
		end

		table.insert(cargs, "--focus-file")
		table.insert(cargs, focus_file_path)
		-- find the directory
		directory = vim.fn.fnamemodify(position.path, ":h")
	end

	-- add runtime extra_args (passed via neotest run command)
	local extra_args = args.extra_args or {}
	for _, value in ipairs(extra_args) do
		table.insert(cargs, value)
	end

	-- add the target directory
	table.insert(cargs, directory .. plenary.path.sep .. "...")

	return {
		command = cargs,
		context = {
			-- input
			report_input_type = position.type,
			report_input_path = position.path,
			-- output
			report_output_path = report_path,
		},
	}
end

---@async
---@param spec neotest.RunSpec
---@param result neotest.StrategyResult
---@param tree neotest.Tree
---@return table<string, neotest.Result>
function adapter.results(spec, result, tree)
	local collection = {}
	local report_path = spec.context.report_output_path
	local temp_files = { report_path }

	local fok, report_data = pcall(lib.files.read, report_path)
	if not fok then
		logger.error("No test output file found ", report_path)
		-- check if ginkgo command failed
		if result.code ~= 0 then
			local output = result.output or ""
			if output:match("ginkgo: command not found") or output:match("executable file not found") then
				logger.error("Ginkgo CLI not found. Please install it: go install github.com/onsi/ginkgo/v2/ginkgo@latest")
			end
		end
		return {}
	end

	local dok, report = pcall(vim.json.decode, report_data, { luanil = { object = true } })
	if not dok then
		logger.error("Failed to parse test output json ", report_path)
		return {}
	end

	for _, suite_item in pairs(report) do
		-- track suite-level results
		local suite_item_node = {}
		local suite_item_node_id = suite_item.SuitePath

		if suite_item.SuiteSucceeded then
			suite_item_node.status = "passed"
		else
			suite_item_node.status = "failed"
		end

		-- add suite summary as short description
		local passed = 0
		local failed = 0
		local skipped = 0
		for _, spec_item in pairs(suite_item.SpecReports or {}) do
			if spec_item.State == "passed" then
				passed = passed + 1
			elseif spec_item.State == "failed" or spec_item.State == "panicked" then
				failed = failed + 1
			elseif spec_item.State == "pending" or spec_item.State == "skipped" then
				skipped = skipped + 1
			end
		end
		suite_item_node.short = string.format("Passed: %d, Failed: %d, Skipped: %d", passed, failed, skipped)
		collection[suite_item_node_id] = suite_item_node

		-- leaf node types that represent test cases
		local test_leaf_types = { It = true, Specify = true, Entry = true }

		for _, spec_item in pairs(suite_item.SpecReports or {}) do
			if test_leaf_types[spec_item.LeafNodeType] then
				local spec_item_node = {}
				local spec_item_node_id = utils.create_location_id(spec_item)

				if spec_item.State == "pending" then
					spec_item_node.status = "skipped"
				elseif spec_item.State == "panicked" then
					spec_item_node.status = "failed"
				elseif spec_item.State == "skipped" then
					goto continue
				else
					spec_item_node.status = spec_item.State
				end

				-- color definition
				local spec_item_color = utils.get_color(spec_item)
				-- set the node short attribute
				spec_item_node.short = utils.create_desc(spec_item, spec_item_color)
				-- set the node location
				spec_item_node.location = spec_item.LeafNodeLocation.LineNumber

				-- set the node errors
				if spec_item.Failure then
					spec_item_node.errors = {}

					local err = utils.create_error(spec_item)
					-- add the error
					table.insert(spec_item_node.errors, err)
					-- prepare the output
					local err_output = utils.create_error_output(spec_item)
					-- set the node output
					spec_item_node.output = async.fn.tempname()
					table.insert(temp_files, spec_item_node.output)
					-- write the output
					lib.files.write(spec_item_node.output, err_output)
					-- set the node short attribute
					spec_item_node.short = spec_item_node.short .. ": " .. err.message
				elseif spec_item.CapturedGinkgoWriterOutput then
					-- prepare the output
					local spec_output = utils.create_success_output(spec_item)
					-- set the node output
					spec_item_node.output = async.fn.tempname()
					table.insert(temp_files, spec_item_node.output)
					-- write the output
					lib.files.write(spec_item_node.output, spec_output)
				else
					spec_item_node.short = nil
				end

				-- set the node
				collection[spec_item_node_id] = spec_item_node
			end

			::continue::
		end
	end

	-- schedule cleanup of temporary files (after neotest has read them)
	vim.defer_fn(function()
		for _, temp_file in ipairs(temp_files) do
			pcall(os.remove, temp_file)
		end
	end, 5000) -- 5 second delay to ensure neotest has processed results

	return collection
end

---Setup the adapter with user configuration
---@param opts? nvim-ginkgo.Config
---@return neotest.Adapter
return function(opts)
	opts = opts or {}
	config = vim.tbl_deep_extend("force", default_config, opts)
	return adapter
end
