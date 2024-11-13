local style = require("nvim-ginkgo.style")

local utils = {}

---@return string
function utils.create_success_output(spec)
	local output = {}

	local info_color = utils.get_color(spec)
	local info_text = utils.create_desc(spec, info_color)

	-- prepare the info
	local info = {
		spec_location = utils.create_location(spec.LeafNodeLocation),
	}

	-- prepare the output
	table.insert(output, info_color .. style.clear .. info_text)
	table.insert(output, style.gray .. info.spec_location)

	if spec.CapturedGinkgoWriterOutput ~= nil then
		table.insert(output, style.clear .. utils.format_output(spec.CapturedGinkgoWriterOutput))
	end

	-- done
	return table.concat(output, "\n") .. "\n"
end

function utils.create_error(spec)
	local failure = spec.Failure

	local err = {
		line = failure.FailureNodeLocation.LineNumber - 1,
		message = failure.Message,
	}

	if failure.Location.FileName == failure.FailureNodeLocation.FileName then
		err.line = failure.Location.LineNumber - 1
	end

	return err
end

---@return string
function utils.create_error_output(spec)
	local info_color = utils.get_color(spec)
	local info_text = utils.create_desc(spec, info_color)

	local failure = spec.Failure
	-- prepare the info
	local info = {
		failure_status = "[" .. string.upper(spec.State) .. "]",
		failure_node_type = "[" .. failure.FailureNodeType .. "]",
		failure_node_location = utils.create_location(failure.FailureNodeLocation),
		failure_message = utils.format_output(failure.Message),
		failure_location = utils.create_location(failure.Location),
		failure_stack_trace = failure.Location.FullStackTrace,
	}

	local output = {}
	-- prepare the output
	table.insert(output, info_color .. style.clear .. info_text)
	table.insert(output, style.gray .. info.failure_location .. "\n")
	table.insert(output, info_color .. "  " .. info.failure_status .. " " .. info.failure_message)
	table.insert(output, style.bold .. "  " .. "In " .. info.failure_node_type .. " at " .. info.failure_node_location)

	if spec.CapturedGinkgoWriterOutput ~= nil then
		table.insert(output, style.clear .. utils.format_output(spec.CapturedGinkgoWriterOutput))
	end

	if spec.State == "panicked" then
		table.insert(output, style.clear .. info_color .. failure.ForwardedPanic)
		table.insert(output, style.clear .. info_color .. "Full Stack Trace")
		table.insert(output, style.clear .. info.failure_stack_trace)
	end

	-- done
	return table.concat(output, "\n") .. "\n"
end

---Get a line in a buffer, defaulting to the first if none is specified
---@param buf number
---@param nr number?
---@return string
local function get_buf_line(buf, nr)
	nr = nr or 0
	assert(buf and type(buf) == "number", "A buffer is required to get the first line")
	return vim.trim(vim.api.nvim_buf_get_lines(buf, nr, nr + 1, false)[1])
end

---@return string
function utils.get_build_tags()
	local line = get_buf_line(0)
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
	local color = nil

	if spec.Failure ~= nil then
		color = style.red
	else
		color = style.green
	end

	if spec.State == "pending" then
		color = style.yellow
	elseif spec.State == "panicked" then
		color = style.magenta
	elseif spec.State == "skipped" then
		color = style.cyan
	end

	return color
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

return utils
