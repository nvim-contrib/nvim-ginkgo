local lib = require("neotest.lib")
local plenary = require("plenary.path")
local async = require("neotest.async")
local logger = require("neotest.logging")
local utils = require("nvim-ginkgo.utils")

---@class neotest.Adapter
---@field name string
local adapter = { name = "nvim-ginkgo" }

---Find the project root directory given a current directory to work from.
---Should no root be found, the adapter can still be used in a non-project context if a test file matches.
---@async
---@return string | nil @Absolute root dir of test suite
adapter.root = lib.files.match_root_pattern("go.mod", "go.sum")

---Filter directories when searching for test files
---@async
---@diagnostic disable-next-line: undefined-doc-param
---@param name string Name of directory
---@param rel_path string Path to directory, relative to root
---@diagnostic disable-next-line: undefined-doc-param
---@param root string Root directory of project
---@return boolean
function adapter.filter_dir(_, rel_path, _)
	return rel_path ~= "vendor"
end

---@async
---@param file_path string
---@return boolean
function adapter.is_test_file(file_path)
	if not vim.endswith(file_path, ".go") then
		return false
	end

	local file_path_segments = vim.split(file_path, plenary.path.sep)
	local file_path_basename = file_path_segments[#file_path_segments]
	local file_path_is_test = vim.endswith(file_path_basename, "_test.go")
	-- done
	return file_path_is_test
end

---Given a file path, parse all the tests within it.
---@async
---@param file_path string Absolute file path
---@diagnostic disable-next-line: undefined-doc-name
---@return neotest.Tree | nil
function adapter.discover_positions(file_path)
	local query = [[
    ; -- Namespaces --
    ; Matches: `describe('subject')` and `context('case')`
    ((call_expression
      function: (identifier) @func_name (#any-of? @func_name "Describe" "Context")
      arguments: (argument_list ((interpreted_string_literal) @namespace.name))
    )) @namespace.definition

    ; -- Tests --
    ; Matches: `it('test')`
    ((call_expression
      function: (identifier) @func_name (#eq? @func_name "It")
      arguments: (argument_list ((interpreted_string_literal) @test.name))
    )) @test.definition
  ]]

	return lib.treesitter.parse_positions(file_path, query, { nested_namespaces = true, require_namespaces = true })
end

---@diagnostic disable-next-line: undefined-doc-name
---@param args neotest.RunArgs
---@diagnostic disable-next-line: undefined-doc-name
---@return nil | neotest.RunSpec | neotest.RunSpec[]
function adapter.build_spec(args)
	local report_filename = "suite_test.json"
	local cargs = {}

	table.insert(cargs, "ginkgo")
	table.insert(cargs, "run")
	table.insert(cargs, "-v")
	-- TODO: we should pass the tags in any case
	-- table.insert(cargs, utils.get_build_tags())
	table.insert(cargs, "--cover")
	---@diagnostic disable-next-line: undefined-field
	local position = args.tree:data()
	---@diagnostic disable-next-line: undefined-global
	if vim.fn.isdirectory(position.path) ~= 1 then
		table.insert(cargs, "--keep-separate-reports")
	end

	table.insert(cargs, "--keep-going")
	table.insert(cargs, "--json-report")
	table.insert(cargs, report_filename)

	-- prepare the focus
	if position.type == "test" or position.type == "namespace" then
		-- pos.id in form "path/to/file::Describe text::test text"
		local name = string.sub(position.id, string.find(position.id, "::") + 2)
		name, _ = string.gsub(name, "::", " ")
		name, _ = string.gsub(name, '"', "")
		-- prepare the pattern
		-- https://github.com/onsi/ginkgo/issues/1126#issuecomment-1409245937
		local pattern = "'\\b" .. name .. "\\b'"
		-- prepare tha arguments
		table.insert(cargs, "--focus")
		table.insert(cargs, pattern)
	end

	---@diagnostic disable-next-line: undefined-global
	local directory = position.path
	-- The path for the position is not a directory, ensure the directory variable refers to one
	if vim.fn.isdirectory(position.path) ~= 1 then
		table.insert(cargs, "--focus-file")
		table.insert(cargs, position.path)
		-- find the directory
		directory = vim.fn.fnamemodify(position.path, ":h")
	end

	---@diagnostic disable-next-line: undefined-field
	local extra_args = args.extra_args or {}
	-- merge the argument
	for _, value in ipairs(extra_args) do
		table.insert(cargs, value)
	end

	---@diagnostic disable-next-line: undefined-global
	table.insert(cargs, directory .. plenary.path.sep .. "...")
	-- report the results path
	local report_path = directory .. plenary.path.sep .. report_filename

	return {
		command = table.concat(cargs, " "),
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
---@diagnostic disable-next-line: undefined-doc-name
---@param spec neotest.RunSpec
---@diagnostic disable-next-line: undefined-doc-name
---@param result neotest.StrategyResult
---@diagnostic disable-next-line: undefined-doc-name
---@param tree neotest.Tree
---@diagnostic disable-next-line: undefined-doc-name
---@return table<string, neotest.Result>
---@diagnostic disable-next-line: unused-local
function adapter.results(spec, result, tree)
	local collection = {}
	---@diagnostic disable-next-line: undefined-field
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

	---@diagnostic disable-next-line: param-type-mismatch
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
				-- set the node short attribute
				spec_item_node.short = "[" .. string.upper(spec_item.State) .. "]"
				spec_item_node.short = spec_item_node.short .. " " .. utils.create_spec_description(spec_item)
				-- set the node location
				spec_item_node.location = spec_item.LeafNodeLocation.LineNumber

				---@diagnostic disable-next-line: undefined-field
				-- set the node output
				spec_item_node.output = async.fn.tempname()

				if spec_item.State == "pending" then
					spec_item_node.status = "skipped"
				elseif spec_item.State == "panicked" then
					spec_item_node.status = "failed"
				else
					spec_item_node.status = spec_item.State
				end

				-- set the node errors
				if spec_item.Failure ~= nil then
					spec_item_node.errors = {}

					local err = utils.create_error(spec_item)
					-- add the error
					table.insert(spec_item_node.errors, err)
					if spec_item_node.output ~= nil then
						-- write the output
						local err_output = utils.create_error_output(spec_item)
						lib.files.write(spec_item_node.output, err_output)
					end
					-- set the node short attribute
					spec_item_node.short = spec_item_node.short .. ": " .. err.message
				else
					-- write the output
					local spec_output = utils.create_spec_output(spec_item)
					lib.files.write(spec_item_node.output, spec_output)
				end

				local spec_item_node_id = utils.create_location_id(spec_item)
				collection[spec_item_node_id] = spec_item_node
			end
		end
	end

	return collection
end

--the adatper
return adapter
