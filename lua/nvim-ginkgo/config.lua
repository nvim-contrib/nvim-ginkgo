local M = {}

---@class nvim-ginkgo.Config
---@field command string[]
---@field dap nvim-ginkgo.ConfigDap

---@class nvim-ginkgo.ConfigDap
---@field args string[]

---@type nvim-ginkgo.Config
local defaults = {
	command = {
		"ginkgo",
		"run",
		"-v",
	},
	dap = {
		args = {
			"--ginkgo.v",
		},
	},
}

---@type nvim-ginkgo.Config
---@diagnostic disable-next-line: missing-fields
M.options = nil

---@return nvim-ginkgo.Config
function M.read()
	return M.options or defaults
end

---@param config nvim-ginkgo.Config
---@return nvim-ginkgo.Config
function M.setup(config)
	M.options = vim.tbl_deep_extend("force", {}, defaults, config or {})

	return M.options
end

return M
