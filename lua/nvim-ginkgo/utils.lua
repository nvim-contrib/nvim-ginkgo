local utils = {}

---Get the first line of a file
---@param file_path string
---@return string|nil
local function get_first_line(file_path)
	local file = io.open(file_path, "r")
	if not file then
		return nil
	end
	local line = file:read("*l")
	file:close()
	return line and vim.trim(line) or nil
end

---Extract build tags from a Go test file
---@param file_path string
---@return string Build tags argument or empty string
function utils.get_build_tags(file_path)
	local line = get_first_line(file_path)
	if not line then
		return ""
	end
	local tag_style
	for _, item in ipairs({ "// +build ", "//go:build " }) do
		if vim.startswith(line, item) then
			tag_style = item
		end
	end
	if not tag_style then
		return ""
	end
	-- escape Lua pattern metacharacters for gsub (+ is special)
	local escaped_style = vim.pesc(tag_style)
	local tags = vim.split(line:gsub(escaped_style, ""), " ")
	if #tags < 1 then
		return ""
	end
	return string.format("--tags=%s", table.concat(tags, ","))
end

---Create a neotest position from treesitter captured nodes
---@param file_path string
---@param source number
---@param captured_nodes table
---@return neotest.Position|nil
function utils.create_position(file_path, source, captured_nodes)
	local function get_match_type()
		if captured_nodes["test.name"] then
			return "test"
		end
		if captured_nodes["namespace.name"] then
			return "namespace"
		end
	end

	local match_type = get_match_type()
	-- if we have a match
	if match_type then
		---@type string
		local name = vim.treesitter.get_node_text(captured_nodes[match_type .. ".name"], source)
		local match_name = vim.treesitter.get_node_text(captured_nodes["func_name"], source)
		local definition = captured_nodes[match_type .. ".definition"]

		name, _ = string.gsub(name, '"', "")
		-- prepare the name
		if match_name == "When" then
			name = string.lower(match_name) .. " " .. name
		end

		return {
			type = match_type,
			path = file_path,
			name = '"' .. name .. '"',
			range = { definition:range() },
		}
	end
end

---Create a focus pattern for ginkgo from a neotest position
---@param position neotest.Position
---@return string Focus pattern
function utils.create_position_focus(position)
	-- pos.id in form "path/to/file::describe text::test text"
	local sep_pos = string.find(position.id, "::")
	if not sep_pos then
		-- fallback to match all tests if no separator found
		return ".*"
	end
	local name = string.sub(position.id, sep_pos + 2)
	name, _ = string.gsub(name, "::", " ")
	name, _ = string.gsub(name, '"', "")
	-- prepare the pattern with word boundaries
	-- https://github.com/onsi/ginkgo/issues/1126#issuecomment-1409245937
	-- Note: no shell quotes needed since neotest passes command as table
	return "\\b" .. name .. "\\b"
end

return utils
