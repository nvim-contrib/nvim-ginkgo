local style = require("nvim-ginkgo.style")

local utils = {}

---Format timing information
---@param spec table The spec report
---@return string|nil Formatted timing string or nil
local function format_timing(spec)
	if not spec.StartTime and not spec.EndTime then
		return nil
	end

	local parts = {}

	-- format start time if available
	if spec.StartTime and spec.StartTime ~= "" then
		-- StartTime is in RFC3339 format, extract just the time portion
		local time_part = spec.StartTime:match("T([%d:]+)")
		if time_part then
			table.insert(parts, "started: " .. time_part)
		end
	end

	-- format end time if available
	if spec.EndTime and spec.EndTime ~= "" then
		local time_part = spec.EndTime:match("T([%d:]+)")
		if time_part then
			table.insert(parts, "ended: " .. time_part)
		end
	end

	if #parts > 0 then
		return table.concat(parts, ", ")
	end
	return nil
end

---Format report entries for output
---@param entries table[] Array of report entries
---@return string[] Array of formatted lines
local function format_report_entries(entries)
	local lines = {}
	for _, entry in ipairs(entries) do
		local entry_name = entry.Name or "unnamed"
		local entry_loc = entry.Location and utils.create_location(entry.Location) or ""
		local entry_value = ""

		-- handle different value types
		if entry.StringRepresentation then
			entry_value = entry.StringRepresentation
		elseif type(entry.Value) == "string" then
			entry_value = entry.Value
		elseif type(entry.Value) == "table" then
			-- try to serialize table
			local ok, json = pcall(vim.json.encode, entry.Value)
			entry_value = ok and json or vim.inspect(entry.Value)
		elseif entry.Value ~= nil then
			entry_value = tostring(entry.Value)
		end

		-- format the entry
		local header = style.cyan .. "  [" .. entry_name .. "]"
		if entry_loc ~= "" then
			header = header .. style.gray .. " at " .. entry_loc
		end
		table.insert(lines, header)

		if entry_value ~= "" then
			table.insert(lines, style.clear .. utils.format_output(entry_value))
		end
	end
	return lines
end

---Format progress reports for output
---@param reports table[] Array of progress reports
---@return string[] Array of formatted lines
local function format_progress_reports(reports)
	local lines = {}
	for i, report in ipairs(reports) do
		local header = style.yellow .. "  [Progress " .. i .. "]"
		if report.Time and report.Time ~= "" then
			local time_part = report.Time:match("T([%d:]+)")
			if time_part then
				header = header .. style.gray .. " at " .. time_part
			end
		end
		table.insert(lines, header)

		-- show message if available
		if report.Message and report.Message ~= "" then
			table.insert(lines, style.clear .. utils.format_output(report.Message))
		end

		-- show current node information
		if report.CurrentNodeType and report.CurrentNodeType ~= "" then
			local node_info = "    In " .. report.CurrentNodeType
			if report.CurrentNodeText and report.CurrentNodeText ~= "" then
				node_info = node_info .. ": " .. report.CurrentNodeText
			end
			table.insert(lines, style.gray .. node_info)
		end

		-- show goroutines of interest (simplified)
		if report.GoroutineOfInterest and report.GoroutineOfInterest.Stack then
			table.insert(lines, style.gray .. "    Goroutine stack:")
			-- show first few lines of stack
			local stack_lines = vim.split(report.GoroutineOfInterest.Stack, "\n")
			for j = 1, math.min(4, #stack_lines) do
				if stack_lines[j] and stack_lines[j] ~= "" then
					table.insert(lines, style.clear .. "      " .. stack_lines[j])
				end
			end
			if #stack_lines > 4 then
				table.insert(lines, style.gray .. "      ... (" .. (#stack_lines - 4) .. " more lines)")
			end
		end
	end
	return lines
end

---Format spec events/timeline for output
---@param events table[] Array of spec events
---@return string[] Array of formatted lines
local function format_spec_events(events)
	local lines = {}
	for _, event in ipairs(events) do
		local event_type = event.SpecEventType or "Unknown"
		local time_part = ""
		if event.TimelineLocation and event.TimelineLocation.Time then
			local t = event.TimelineLocation.Time:match("T([%d:]+)")
			if t then
				time_part = style.gray .. " [" .. t .. "]"
			end
		end

		local event_line = style.cyan .. "  • " .. event_type .. time_part

		-- add message if present
		if event.Message and event.Message ~= "" then
			event_line = event_line .. style.clear .. " - " .. event.Message
		end

		-- add duration for certain events
		if event.Duration and event.Duration ~= "" then
			event_line = event_line .. style.gray .. " (" .. event.Duration .. ")"
		end

		table.insert(lines, event_line)

		-- add code location if available
		if event.CodeLocation then
			local loc = utils.create_location(event.CodeLocation)
			table.insert(lines, style.gray .. "    at " .. loc)
		end
	end
	return lines
end

---Format parallel process info
---@param spec table The spec report
---@return string|nil Formatted parallel info or nil
local function format_parallel_info(spec)
	if spec.ParallelProcess and spec.ParallelProcess > 0 then
		return "process #" .. spec.ParallelProcess
	end
	return nil
end

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

	-- build location line with parallel info
	local location_line = spec_location
	local parallel_info = format_parallel_info(spec)
	if parallel_info then
		location_line = location_line .. " (" .. parallel_info .. ")"
	end
	table.insert(output, style.gray .. location_line)

	-- include timing details
	local timing = format_timing(spec)
	if timing then
		table.insert(output, style.gray .. "  " .. timing)
	end

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

	-- include report entries (custom data from AddReportEntry)
	if spec.ReportEntries and #spec.ReportEntries > 0 then
		table.insert(output, style.clear .. "\n" .. style.gray .. "Report Entries:")
		local entry_lines = format_report_entries(spec.ReportEntries)
		for _, line in ipairs(entry_lines) do
			table.insert(output, line)
		end
	end

	-- include progress reports (for long-running tests)
	if spec.ProgressReports and #spec.ProgressReports > 0 then
		table.insert(output, style.clear .. "\n" .. style.gray .. "Progress Reports:")
		local progress_lines = format_progress_reports(spec.ProgressReports)
		for _, line in ipairs(progress_lines) do
			table.insert(output, line)
		end
	end

	-- include spec events/timeline
	if spec.SpecEvents and #spec.SpecEvents > 0 then
		table.insert(output, style.clear .. "\n" .. style.gray .. "Timeline:")
		local event_lines = format_spec_events(spec.SpecEvents)
		for _, line in ipairs(event_lines) do
			table.insert(output, line)
		end
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

	-- build location line with parallel info
	local location_line = failure_location
	local parallel_info = format_parallel_info(spec)
	if parallel_info then
		location_line = location_line .. " (" .. parallel_info .. ")"
	end
	table.insert(output, style.gray .. location_line .. "\n")
	table.insert(output, info_color .. "  " .. failure_status .. " " .. failure_message)
	table.insert(output, style.bold .. "  " .. "In " .. failure_node_type .. " at " .. failure_node_location)

	-- include timing details
	local timing = format_timing(spec)
	if timing then
		table.insert(output, style.gray .. "  " .. timing)
	end

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

	-- include additional failures (e.g., AfterEach failures)
	if spec.AdditionalFailures and #spec.AdditionalFailures > 0 then
		table.insert(output, style.clear .. "\n" .. style.orange .. "Additional Failures:")
		for i, addl_failure in ipairs(spec.AdditionalFailures) do
			local addl_loc = addl_failure.Location and utils.create_location(addl_failure.Location) or "unknown"
			local addl_msg = addl_failure.Message and utils.format_output(addl_failure.Message) or "No message"
			local addl_node_type = addl_failure.FailureNodeType or "UNKNOWN"
			table.insert(output, style.red .. "  [" .. i .. "] " .. addl_node_type .. " at " .. addl_loc)
			table.insert(output, style.clear .. "      " .. addl_msg)
		end
	end

	-- include report entries (custom data from AddReportEntry)
	if spec.ReportEntries and #spec.ReportEntries > 0 then
		table.insert(output, style.clear .. "\n" .. style.gray .. "Report Entries:")
		local entry_lines = format_report_entries(spec.ReportEntries)
		for _, line in ipairs(entry_lines) do
			table.insert(output, line)
		end
	end

	-- include progress reports (for long-running tests)
	if spec.ProgressReports and #spec.ProgressReports > 0 then
		table.insert(output, style.clear .. "\n" .. style.gray .. "Progress Reports:")
		local progress_lines = format_progress_reports(spec.ProgressReports)
		for _, line in ipairs(progress_lines) do
			table.insert(output, line)
		end
	end

	-- include spec events/timeline
	if spec.SpecEvents and #spec.SpecEvents > 0 then
		table.insert(output, style.clear .. "\n" .. style.gray .. "Timeline:")
		local event_lines = format_spec_events(spec.SpecEvents)
		for _, line in ipairs(event_lines) do
			table.insert(output, line)
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
	-- escape Lua pattern metacharacters for gsub (+ is special)
	local escaped_style = vim.pesc(tag_style)
	local tags = vim.split(line:gsub(escaped_style, ""), " ")
	if #tags < 1 then
		return ""
	end
	return string.format("--tags=%s", table.concat(tags, ","))
end

---@return string
function utils.get_color(spec)
	-- check state first as it takes precedence (matches Ginkgo's default reporter colors)
	if spec.State == "pending" then
		return style.yellow
	elseif spec.State == "panicked" then
		return style.magenta
	elseif spec.State == "skipped" then
		return style.cyan
	elseif spec.State == "timedout" or spec.State == "interrupted" then
		return style.orange
	elseif spec.State == "aborted" then
		return style.coral
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

	-- add labels if present
	if spec.LeafNodeLabels and #spec.LeafNodeLabels > 0 then
		spec_name = spec_name .. " [" .. table.concat(spec.LeafNodeLabels, ", ") .. "]"
	end

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
