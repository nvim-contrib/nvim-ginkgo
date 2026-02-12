-- Tree test helpers

local M = {}

-- Find a position by name in a test tree (recursive)
-- @param tree neotest.Tree Tree to search
-- @param name string Position name to find
-- @return table|nil Position data if found, nil otherwise
function M.find_position(tree, name)
	local data = tree:data()
	if data.name == name then
		return data
	end

	for _, child in ipairs(tree:children()) do
		local found = M.find_position(child, name)
		if found then
			return found
		end
	end

	return nil
end

return M
