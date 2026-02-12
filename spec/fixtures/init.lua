-- Test fixture helpers

local M = {}

-- Get absolute path to a fixture file
-- @param relative_path string Path relative to fixtures directory (e.g., "ginkgo/simple_test.go")
-- @return string Absolute path to fixture file
function M.path(relative_path)
	local cwd = vim.fn.getcwd()
	return cwd .. "/spec/fixtures/" .. relative_path
end

return M
