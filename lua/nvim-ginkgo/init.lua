local lib = require("neotest.lib")
local plenary = require("plenary.path")
local async = require("neotest.async")
local logger = require("neotest.logging")
local utils = require("nvim-ginkgo.utils")
local tree = require("nvim-ginkgo.tree")
local cmd = require("nvim-ginkgo.cmd")

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
	return tree.parse_positions(file_path)
end

---@param args neotest.RunArgs
---@return nil | neotest.RunSpec | neotest.RunSpec[]
function adapter.build_spec(args)
	return cmd.build(args)
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
				-- set the node short attribute
				spec_item_node.short = "[" .. string.upper(spec_item.State) .. "]"
				spec_item_node.short = spec_item_node.short .. " " .. utils.create_spec_description(spec_item)
				-- set the node location
				spec_item_node.location = spec_item.LeafNodeLocation.LineNumber

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
					local spec_output = utils.create_spec_output(spec_item)
					-- set the node output
					spec_item_node.output = async.fn.tempname()
					-- write the output
					lib.files.write(spec_item_node.output, spec_output)
				end

				local spec_item_node_id = utils.create_location_id(spec_item)
				-- set the node
				collection[spec_item_node_id] = spec_item_node
			end
		end
	end

	return collection
end

--the adatper
return adapter
