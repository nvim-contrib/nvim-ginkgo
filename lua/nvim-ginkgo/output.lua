local M = {}

-- ANSI color codes for output formatting
local style = {
	clear = "\x1b[0m",
	bold = "\x1b[1m",
	underline = "\x1b[4m",
	red = "\x1b[38;5;9m",
	orange = "\x1b[38;5;214m",
	coral = "\x1b[38;5;204m",
	magenta = "\x1b[38;5;13m",
	green = "\x1b[38;5;10m",
	dark_green = "\x1b[38;5;28m",
	yellow = "\x1b[38;5;11m",
	yellow_light = "\x1b[38;5;228m",
	cyan = "\x1b[38;5;14m",
	gray = "\x1b[38;5;243m",
	gray_light = "\x1b[38;5;246m",
	blue = "\x1b[38;5;12m",
}

---@return string
local function create_location_path(spec)
	return spec.FileName .. ":" .. spec.LineNumber
end

---@return string
function M.create_spec_description(spec, color)
	if color == nil then
		color = ""
	end

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
function M.create_spec_output(spec)
	local main = style.green

	if spec.State == "pending" then
		main = style.yellow
	elseif spec.State == "skipped" then
		main = style.cyan
	end

	local info_text = M.create_spec_description(spec, main)
	-- prepare the info
	local info = {
		spec_location = create_location_path(spec.LeafNodeLocation),
	}

	local output = {}
	-- prepare the output
	table.insert(output, main .. style.clear .. info_text)
	table.insert(output, style.gray .. info.spec_location)
	table.insert(output, style.clear .. M.get_output(spec))

	-- done
	return table.concat(output, "\n")
end

---@return string
function M.create_error_output(spec)
	local failure = spec.Failure

	local main = style.red
	-- find the main color
	if spec.State == "panicked" then
		main = style.magenta
	end

	local info_text = M.create_spec_description(spec, main)
	-- prepare the info
	local info = {
		failure_status = "[" .. string.upper(spec.State) .. "]",
		failure_node_type = "[" .. failure.FailureNodeType .. "]",
		failure_node_location = create_location_path(failure.FailureNodeLocation),
		failure_message = M.get_error(failure),
		failure_location = create_location_path(failure.Location),
		failure_stack_trace = failure.Location.FullStackTrace,
	}

	local output = {}
	-- prepare the output
	table.insert(output, main .. style.clear .. info_text)
	table.insert(output, style.gray .. info.failure_location)
	table.insert(output, main .. "\n  " .. info.failure_status .. " " .. info.failure_message)
	table.insert(output, style.bold .. "  " .. "In " .. info.failure_node_type .. " at " .. info.failure_node_location)

	if spec.CapturedGinkgoWriterOutput ~= nil then
		table.insert(output, style.clear .. M.get_output(spec))
	end

	if spec.State == "panicked" then
		table.insert(output, style.clear .. main .. failure.ForwardedPanic)
		table.insert(output, style.clear .. main .. "Full Stack Trace")
		table.insert(output, style.clear .. info.failure_stack_trace)
	end
	-- done
	return table.concat(output, "\n")
end

---@return string
function M.get_output(item)
	local output = {}
	-- tab
	for line in string.gmatch(item.CapturedGinkgoWriterOutput, "([^\n]+)") do
		table.insert(output, "  " .. line)
	end
	-- done
	return table.concat(output, "\n")
end

---@return string
function M.get_error(item)
	local output = {}
	-- tab
	for line in string.gmatch(item.Message, "([^\n]+)") do
		table.insert(output, "  " .. line)
	end
	-- done
	return table.concat(output, "\n")
end

return M
