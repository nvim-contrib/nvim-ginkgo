local M = {}

---@return string
function M.create_location_id(spec)
	local segments = {}
	-- add the spec filename
	table.insert(segments, spec.LeafNodeLocation.FileName)

	local hierarchy = {}
	for _, segment in pairs(spec.ContainerHierarchyTexts) do
		table.insert(hierarchy, segment)
	end

	for _, segment in pairs(hierarchy) do
		table.insert(segments, '"' .. segment .. '"')
	end
	-- add the spec text
	table.insert(segments, '"' .. spec.LeafNodeText .. '"')

	local id = table.concat(segments, "::")
	-- done
	return id
end

---@return string
function M.create_location(spec)
	return spec.FileName .. ":" .. spec.LineNumber
end

---Generate a Ginkgo focus pattern for a position
---@param position neotest.Position
---@return string
function M.create_position_focus(position)
	-- Build focus pattern from full position path
	local logger = require("neotest.logging")
	logger.debug("create_position_focus: position.id = " .. position.id)
	logger.debug("create_position_focus: position.name = " .. position.name)

	local name = string.sub(position.id, string.find(position.id, "::") + 2)
	logger.debug("create_position_focus: extracted name = " .. name)

	name = name:gsub("::", " ")
	name = name:gsub('"', "")
	name = name:gsub("/", "\\/")
	name = name:gsub("([%.%+%-%*%?%[%]%(%)%$%^%|])", "\\%1")

	local pattern = "\\b" .. name .. "\\b"
	logger.debug("create_position_focus: final pattern = " .. pattern)

	return pattern
end

return M
