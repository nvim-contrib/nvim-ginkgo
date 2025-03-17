local async = require("neotest.async")
local config = require("nvim-ginkgo.config")
local dap = require("nvim-ginkgo.strategies.dap")
local lib = require("neotest.lib")
local logger = require("neotest.logging")
local plenary = require("plenary.path")
local utils = require("nvim-ginkgo.utils")

---@class nvim-ginkgo.Adapter: neotest.Adapter
---@field setup fun(config: nvim-ginkgo.Config): nil

---@type nvim-ginkgo.Adapter
---@diagnostic disable-next-line: missing-fields
local adapter = { name = "nvim-ginkgo" }

---@param config nvim-ginkgo.Config
function adapter.setup(c)
	require("nvim-ginkgo.config").setup(c)
end

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
	return rel_path ~= "vendor"
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
	local c = config.read()

	local report_path = async.fn.tempname()

	local cargs = {}
	vim.list_extend(cargs, {
		"--keep-going",
		"--json-report",
		report_path,
		"--silence-skips",
	})

	local position = args.tree:data()
	local directory = position.path
	---@type string
	local focus_file_path = directory
	---@type string?
	local focus_pattern

	-- The path for the position is not a directory, ensure the directory variable refers to one
	if vim.fn.isdirectory(position.path) ~= 1 then
		-- prepare the focus path
		if position.type == "test" or position.type == "namespace" then
			local line_number = position.range[1] + 1
			-- replace the focus_file_path with its line number
			focus_file_path = position.path .. ":" .. line_number
			-- create the focus pattern
			focus_pattern = utils.create_position_focus(position)

			vim.list_extend(cargs, { "--focus", focus_pattern })
		end

		vim.list_extend(cargs, { "--focus-file", focus_file_path })
		-- find the directory
		directory = vim.fn.fnamemodify(position.path, ":h")
	end

	local extra_args = args.extra_args or {}
	-- merge the argument
	for _, value in ipairs(extra_args) do
		table.insert(cargs, value)
	end

	local command = {}
	vim.list_extend(command, c.command)
	vim.list_extend(command, cargs)
	vim.list_extend(command, { directory .. plenary.path.sep .. "..." })

	---@type nil | neotest.RunSpec | neotest.RunSpec[]
	local spec = {
		command = command,
		context = {
			-- input
			report_input_type = position.type,
			report_input_path = position.path,
			-- output
			report_output_path = report_path,
		},
	}

	if args.strategy == "dap" then
		dap.setup_debugging(directory)

		local dap_args = vim.deepcopy(c.dap.args)

		-- only some of the arguments are valid here so we can not directly use cargs
		vim.list_extend(dap_args, {
			"--ginkgo.json-report",
			report_path,
			"--ginkgo.silence-skips",
			"--ginkgo.focus-file",
			focus_file_path,
		})

		if focus_pattern then
			vim.list_extend(dap_args, { "--ginkgo.focus", focus_pattern })
		end

		spec.strategy = dap.get_dap_config(directory, dap_args)
	end

	return spec
end

---@async
---@param spec neotest.RunSpec
---@param result neotest.StrategyResult
---@param tree neotest.Tree
---@return table<string, neotest.Result>
function adapter.results(spec, result, tree)
	local collection = {}
	local report_path = spec.context.report_output_path

	local fok, report_data = pcall(lib.files.read, report_path)
	if not fok then
		logger.error("No test output file found ", report_path)
		return {}
	end

	local dok, report = pcall(vim.json.decode, report_data, { luanil = { object = true } })
	if not dok then
		logger.error("Failed to parse test output json ", report_path)
		return {}
	end

	for _, suite_item in pairs(report) do
		if suite_item.SpecReports == nil then
			local suite_item_node = {}
			-- set the node errors
			if suite_item.SuiteSucceeded then
				suite_item_node.status = "passed"
			end

			local suite_item_node_id = suite_item.SuitePath
			collection[suite_item_node_id] = suite_item_node
		end

		for _, spec_item in pairs(suite_item.SpecReports or {}) do
			if spec_item.LeafNodeType == "It" then
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
				if spec_item.Failure ~= nil then
					spec_item_node.errors = {}

					local err = utils.create_error(spec_item)
					-- add the error
					table.insert(spec_item_node.errors, err)
					-- prepare the output
					local err_output = utils.create_error_output(spec_item)
					-- set the node output
					spec_item_node.output = async.fn.tempname()
					-- write the output
					lib.files.write(spec_item_node.output, err_output)
					-- set the node short attribute
					spec_item_node.short = spec_item_node.short .. ": " .. err.message
				elseif spec_item.CapturedGinkgoWriterOutput ~= nil then
					-- prepare the output
					local spec_output = utils.create_success_output(spec_item)
					-- set the node output
					spec_item_node.output = async.fn.tempname()
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

	return collection
end

--the adatper
return adapter
