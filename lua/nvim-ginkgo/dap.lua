-- DAP (Debug Adapter Protocol) support for Ginkgo v2
-- Enhances a RunSpec with DAP strategy configuration
-- Requires: leoluz/nvim-dap-go

local M = {}

---Validate that DAP is available, error if not
local function check_dap_available()
	local ok, _ = pcall(require, "dap-go")
	if not ok then
		local msg = "nvim-dap-go is required for DAP strategy. Install: https://github.com/leoluz/nvim-dap-go"
		error(msg)
	end
end

---Build DAP strategy from spec context
---Takes context from spec.build() and returns DAP configuration
---@param context table The context from RunSpec
---@return table DAP strategy configuration
function M.build(context)
	-- Check that DAP dependencies are available
	check_dap_available()

	-- Extract from context
	local focus_dir_path = context.focus_dir_path
	local report_path = context.report_output_path
	local focus_file_path = context.focus_file_path
	local focus_pattern = context.focus_pattern
	local extra_args = context.extra_args or {}

	-- Build DAP-specific arguments with --ginkgo. prefix
	-- When debugging with Delve, Ginkgo flags need the --ginkgo. prefix
	local dap_args = {
		"--ginkgo.json-report",
		report_path,
		"--ginkgo.silence-skips",
	}

	-- Add focus parameters if present
	if focus_file_path then
		vim.list_extend(dap_args, { "--ginkgo.focus-file", focus_file_path })
	end

	if focus_pattern then
		vim.list_extend(dap_args, { "--ginkgo.focus", focus_pattern })
	end

	-- Add extra arguments
	for _, value in ipairs(extra_args) do
		table.insert(dap_args, value)
	end

	-- Build and return DAP configuration
	local config = {
		name = "Debug Ginkgo Test",
		request = "launch",
		type = "go",
		mode = "test",
		outputMode = "remote",
		program = focus_dir_path,
		args = dap_args,
		cwd = focus_dir_path,
	}

	return config
end

return M
