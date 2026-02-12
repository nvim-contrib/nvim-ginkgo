-- Helper functions for report spec tests

local async = require("neotest.async")

local M = {}

---Create a temporary JSON report file for testing
---@param report_data table Report data to encode as JSON
---@return string Path to temporary report file
function M.create_temp_report(report_data)
	local report_path = async.fn.tempname()
	local json_content = vim.json.encode(report_data)
	vim.fn.writefile({ json_content }, report_path)
	return report_path
end

---Create a mock spec with report path for testing
---@param report_path string Path to report file
---@return table Mock spec with context
function M.create_mock_spec(report_path)
	return {
		context = {
			report_output_path = report_path,
		},
	}
end

return M
