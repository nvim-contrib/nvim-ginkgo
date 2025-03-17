local M = {}

local logger = require("neotest.logging")

---This will prepare and setup nvim-dap-go for debugging.
---@param cwd string
function M.setup_debugging(cwd)
	local ok, adapter = pcall(require, "dap-go")
	if not ok then
		local msg = "You must have leoluz/nvim-dap-go installed to use DAP strategy. "
			.. "See the neotest-golang README for more information."
		logger.error(msg)
		error(msg)
	end

	local opts = {
		delve = {
			cwd = cwd,
		},
	}
	logger.debug({ "Setting up dap-go for DAP: ", opts })

	adapter.setup(opts)
end

--- @param path string
--- @param args string[]?
--- @return table | nil
function M.get_dap_config(path, args)
	-- :help dap-configuration
	local config = {
		type = "go",
		name = "Neotest-golang",
		request = "launch",
		mode = "test",
		program = path,
		args = args,
		outputMode = "remote",
	}

	logger.debug({ "DAP configuration: ", config })

	return config
end

return M
