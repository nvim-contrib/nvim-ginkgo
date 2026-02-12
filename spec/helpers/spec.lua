-- Helper functions for spec spec tests

local M = {}

---Create a mock neotest tree for testing
---@param position_data table Position data for the tree
---@return table Mock tree with data and children methods
function M.create_mock_tree(position_data)
	return {
		data = function()
			return position_data
		end,
		children = function()
			return {}
		end,
	}
end

---Plain string matching helper (avoids Lua pattern special characters)
---@param str string String to search in
---@param substr string Substring to find
---@return boolean True if substr is found in str
function M.contains(str, substr)
	return str:find(substr, 1, true) ~= nil
end

---Check if a table contains a specific value
---@param tbl table Table to search
---@param value any Value to find
---@return boolean True if value is in table
function M.table_contains(tbl, value)
	for _, v in ipairs(tbl) do
		if v == value then
			return true
		end
	end
	return false
end

return M
