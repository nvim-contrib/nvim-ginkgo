local style = require("nvim-ginkgo.style")

local utils = {}

---@return string
function utils.create_success_output(spec)
	local output = {}

	local info_color = utils.get_color(spec)
	local info_text = utils.create_desc(spec, info_color)

	-- prepare the info
	local spec_location = spec.LeafNodeLocation
		and utils.create_location(spec.LeafNodeLocation) or "unknown"

	-- prepare the output
	table.insert(output, info_color .. style.clear .. info_text)
	table.insert(output, style.gray .. spec_location)

	-- include GinkgoWriter output
	if spec.CapturedGinkgoWriterOutput and spec.CapturedGinkgoWriterOutput ~= "" then
		table.insert(output, style.clear .. "\n" .. style.gray .. "GinkgoWriter output:")
		table.insert(output, style.clear .. utils.format_output(spec.CapturedGinkgoWriterOutput))
	end

	-- include stdout/stderr
	if spec.CapturedStdOutErr and spec.CapturedStdOutErr ~= "" then
		table.insert(output, style.clear .. "\n" .. style.gray .. "stdout/stderr:")
		table.insert(output, style.clear .. utils.format_output(spec.CapturedStdOutErr))
	end

	-- done
	return table.concat(output, "\n") .. "\n"
end

---@return table
function utils.create_error(spec)
	local failure = spec.Failure
	if not failure then
		return { line = 0, message = "Unknown error" }
	end

	local err = {
		line = 0,
		message = failure.Message or "Test failed",
	}

	-- safely get line number from failure location
	if failure.FailureNodeLocation and failure.FailureNodeLocation.LineNumber then
		err.line = failure.FailureNodeLocation.LineNumber - 1
	end

	-- prefer Location line number if same file
	if failure.Location and failure.FailureNodeLocation
		and failure.Location.FileName == failure.FailureNodeLocation.FileName
		and failure.Location.LineNumber then
		err.line = failure.Location.LineNumber - 1
	end

	return err
end

---@return string
function utils.create_error_output(spec)
	local info_color = utils.get_color(spec)
	local info_text = utils.create_desc(spec, info_color)

	local failure = spec.Failure
	local output = {}

	-- prepare the output header
	table.insert(output, info_color .. style.clear .. info_text)

	if not failure then
		table.insert(output, style.red .. "  [ERROR] No failure details available")
		return table.concat(output, "\n") .. "\n"
	end

	-- safely build info with nil checks
	local failure_status = "[" .. string.upper(spec.State or "UNKNOWN") .. "]"
	local failure_node_type = failure.FailureNodeType and ("[" .. failure.FailureNodeType .. "]") or "[UNKNOWN]"
	local failure_node_location = failure.FailureNodeLocation
		and utils.create_location(failure.FailureNodeLocation) or "unknown"
	local failure_message = failure.Message and utils.format_output(failure.Message) or "No message"
	local failure_location = failure.Location and utils.create_location(failure.Location) or "unknown"

	table.insert(output, style.gray .. failure_location .. "\n")
	table.insert(output, info_color .. "  " .. failure_status .. " " .. failure_message)
	table.insert(output, style.bold .. "  " .. "In " .. failure_node_type .. " at " .. failure_node_location)

	-- include GinkgoWriter output
	if spec.CapturedGinkgoWriterOutput and spec.CapturedGinkgoWriterOutput ~= "" then
		table.insert(output, style.clear .. "\n" .. style.gray .. "GinkgoWriter output:")
		table.insert(output, style.clear .. utils.format_output(spec.CapturedGinkgoWriterOutput))
	end

	-- include stdout/stderr
	if spec.CapturedStdOutErr and spec.CapturedStdOutErr ~= "" then
		table.insert(output, style.clear .. "\n" .. style.gray .. "stdout/stderr:")
		table.insert(output, style.clear .. utils.format_output(spec.CapturedStdOutErr))
	end

	-- include panic info and stack trace
	if spec.State == "panicked" then
		if failure.ForwardedPanic then
			table.insert(output, style.clear .. "\n" .. info_color .. failure.ForwardedPanic)
		end
		if failure.Location and failure.Location.FullStackTrace then
			table.insert(output, style.clear .. info_color .. "Full Stack Trace")
			table.insert(output, style.clear .. failure.Location.FullStackTrace)
		end
	end

	-- done
	return table.concat(output, "\n") .. "\n"
end

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

---@param file_path string
---@return string
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
	local tags = vim.split(line:gsub(tag_style, ""), " ")
	if #tags < 1 then
		return ""
	end
	return string.format("--tags=%s", table.concat(tags, ","))
end

---@return string
function utils.get_color(spec)
	-- check state first as it takes precedence
	if spec.State == "pending" then
		return style.yellow
	elseif spec.State == "panicked" then
		return style.magenta
	elseif spec.State == "skipped" then
		return style.cyan
	elseif spec.Failure then
		return style.red
	else
		return style.green
	end
end

---@return string
function utils.create_desc(spec, color)
	local spec_desc_texts = {}
	-- prepare
	for index, line in ipairs(spec.ContainerHierarchyTexts) do
		local line_color = ""

		if index % 2 == 0 then
			line_color = style.gray
		else
			line_color = style.clear
		end

		table.insert(spec_desc_texts, line_color .. line)
	end

	local spec_desc = table.concat(spec_desc_texts, " ")
	local spec_name = "[" .. spec.LeafNodeType .. "] " .. spec.LeafNodeText
	-- done
	return spec_desc .. " " .. color .. spec_name
end

---@return string
function utils.format_output(message)
	local output = {}
	-- tab
	for line in string.gmatch(message, "([^\n]+)") do
		table.insert(output, "  " .. line)
	end
	-- done
	return table.concat(output, "\n")
end

---@return string
function utils.create_location_id(spec)
	local segments = {}
	-- add the spec filename
	table.insert(segments, spec.LeafNodeLocation.FileName)
	-- add the spec hierarchy
	for _, segment in pairs(spec.ContainerHierarchyTexts) do
		table.insert(segments, '"' .. segment .. '"')
	end
	-- add the spec text
	table.insert(segments, '"' .. spec.LeafNodeText .. '"')

	local id = table.concat(segments, "::")
	-- done
	return id
end

---@return string
function utils.create_location(spec)
	return spec.FileName .. ":" .. spec.LineNumber
end

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

---@param position neotest.Position
---@return string
function utils.create_position_focus(position)
	-- pos.id in form "path/to/file::describe text::test text"
	local sep_pos = string.find(position.id, "::")
	if not sep_pos then
		-- fallback to match all tests if no separator found
		return "'.*'"
	end
	local name = string.sub(position.id, sep_pos + 2)
	name, _ = string.gsub(name, "::", " ")
	name, _ = string.gsub(name, '"', "")
	-- prepare the pattern
	-- https://github.com/onsi/ginkgo/issues/1126#issuecomment-1409245937
	return "'\\b" .. name .. "\\b'"
end

return utils
