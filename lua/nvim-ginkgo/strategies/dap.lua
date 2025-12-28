local M = {}

local logger = require("neotest.logging")

---Checks if dap-go is available for debugging.
function M.check_dap_available()
	local ok, _ = pcall(require, "dap-go")
	if not ok then
		local msg = "You must have leoluz/nvim-dap-go installed to use DAP strategy."
		logger.error(msg)
		error(msg)
	end
end

---@param cwd string
---@param args string[]?
---@return table
function M.get_dap_config(cwd, args)
	-- :help dap-configuration
	local config = {
		type = "go",
		name = "nvim-ginkgo",
		request = "launch",
		mode = "test",
		program = cwd,
		args = args,
		cwd = cwd,
		outputMode = "remote",
	}

	logger.debug({ "DAP configuration: ", config })

	return config
end

return M
