local style = require("nvim-ginkgo.style")

local utils = {}

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
function utils.create_location_path(spec)
	return spec.FileName .. ":" .. spec.LineNumber
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
function utils.create_spec_output(spec)
	local main = style.green

	if spec.State == "pending" then
		main = style.yellow
	elseif spec.State == "skipped" then
		main = style.cyan
	end

	local info_text = utils.create_spec_description(spec, main)
	-- prepare the info
	local info = {
		spec_status = "[" .. string.upper(spec.State) .. "]",
	}

	local output = {}
	-- prepare the output
	table.insert(output, main .. info.spec_status .. " " .. style.clear .. info_text .. "\n")

	if spec.CapturedGinkgoWriterOutput ~= nil then
		table.insert(output, style.clear .. spec.CapturedGinkgoWriterOutput .. "\n")
	end

	-- done
	return table.concat(output, "\n")
end

---@return string
function utils.create_spec_description(spec, color)
	if color == nil then
		color = ""
	end

	local spec_desc = table.concat(spec.ContainerHierarchyTexts, " ")
	local spec_name = "[" .. spec.LeafNodeType .. "] " .. spec.LeafNodeText
	-- done
	return spec_desc .. " " .. color .. spec_name
end

---@return string
function utils.create_error_output(spec)
	local failure = spec.Failure

	local main = style.red
	-- find the main color
	if spec.State == "panicked" then
		main = style.magenta
	end

	local info_text = utils.create_spec_description(spec, main)
	-- prepare the info
	local info = {
		failure_status = "[" .. string.upper(spec.State) .. "]",
		failure_node_type = "[" .. failure.FailureNodeType .. "]",
		failure_node_location = utils.create_location_path(failure.FailureNodeLocation),
		failure_message = failure.Message,
		failure_location = utils.create_location_path(failure.Location),
		failure_stack_trace = failure.Location.FullStackTrace,
	}

	local output = {}
	-- prepare the output
	table.insert(output, main .. info.failure_status .. " " .. style.clear .. info_text)
	table.insert(output, style.gray .. info.failure_location .. "\n")
	table.insert(output, main .. info.failure_status .. " " .. info.failure_message)
	table.insert(output, style.bold .. "In " .. info.failure_node_type .. " at " .. info.failure_node_location .. "\n")

	if spec.CapturedGinkgoWriterOutput ~= nil then
		table.insert(output, style.clear .. spec.CapturedGinkgoWriterOutput)
	end

	if spec.State == "panicked" then
		table.insert(output, style.clear .. main .. failure.ForwardedPanic .. "\n")
		table.insert(output, style.clear .. main .. "Full Stack Trace")
		table.insert(output, style.clear .. info.failure_stack_trace .. "\n")
	end
	-- done
	return table.concat(output, "\n")
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

return utils
