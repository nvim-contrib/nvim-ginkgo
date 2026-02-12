local lib = require("neotest.lib")
local async = require("neotest.async")
local logger = require("neotest.logging")
local output = require("nvim-ginkgo.output")

local M = {}

---Create a unique location identifier for a test spec
---@param spec table The spec item from Ginkgo report
---@return string Unique identifier in format "file.go::\"Describe\"::\"Context\"::\"It\""
local function create_location_id(spec)
	local segments = {}
	-- add the spec filename
	table.insert(segments, spec.LeafNodeLocation.FileName)
	-- add the spec hierarchy
	for _, segment in pairs(spec.ContainerHierarchyTexts) do
		table.insert(segments, '"' .. segment .. '"')
	end
	-- add the spec text
	table.insert(segments, '"' .. spec.LeafNodeText .. '"')

	local id = table.concat(segments, "::")
	-- done
	return id
end

---Create an error object from a failed spec
---@param spec table The spec item from Ginkgo report
---@return table Error object with line number and message
local function create_error(spec)
	local failure = spec.Failure

	local err = {
		line = failure.FailureNodeLocation.LineNumber - 1,
		message = failure.Message,
	}

	if failure.Location.FileName == failure.FailureNodeLocation.FileName then
		err.line = failure.Location.LineNumber - 1
	end

	return err
end

---Parse Ginkgo test results from JSON report
---@async
---@param spec neotest.RunSpec
---@param result neotest.StrategyResult
---@param tree neotest.Tree
---@return table<string, neotest.Result>
function M.parse(spec, result, tree)
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
				spec_item_node.short = spec_item_node.short .. " " .. output.create_spec_description(spec_item)
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

					local err = create_error(spec_item)
					-- add the error
					table.insert(spec_item_node.errors, err)
					-- prepare the output
					local err_output = output.create_error_output(spec_item)
					-- set the node output
					spec_item_node.output = async.fn.tempname()
					-- write the output
					lib.files.write(spec_item_node.output, err_output)
					-- set the node short attribute
					spec_item_node.short = spec_item_node.short .. ": " .. err.message
				else
					-- set default output if no output captured
					if spec_item.CapturedGinkgoWriterOutput == nil then
						spec_item.CapturedGinkgoWriterOutput = "No output captured"
					end
					-- prepare the output
					local spec_output = output.create_spec_output(spec_item)
					-- set the node output
					spec_item_node.output = async.fn.tempname()
					-- write the output
					lib.files.write(spec_item_node.output, spec_output)
				end

				local spec_item_node_id = create_location_id(spec_item)
				-- set the node
				collection[spec_item_node_id] = spec_item_node
			end
		end
	end

	return collection
end

return M
