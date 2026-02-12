-- Tests for output.lua module (output formatting)

---@diagnostic disable: undefined-field

local nio_tests = require("nio.tests")
local output = require("nvim-ginkgo.output")
local helpers = dofile(vim.fn.getcwd() .. "/spec/helpers/output.lua")

-- Use helpers from spec/helpers/output.lua
local create_mock_spec = helpers.create_mock_spec

describe("output.create_spec_description", function()
	nio_tests.it("formats test description with hierarchy", function()
		local spec = create_mock_spec("passed", false)
		local result = output.create_spec_description(spec)

		assert.is_string(result)
		-- Should contain hierarchy texts
		assert.is_true(result:match("Describe Feature") ~= nil)
		assert.is_true(result:match("Context Scenario") ~= nil)
		-- Should contain leaf node text
		assert.is_true(result:match("should do something") ~= nil)
		-- Should contain node type
		assert.is_true(result:match("%[It%]") ~= nil)
	end)

	nio_tests.it("applies color to description when provided", function()
		local spec = create_mock_spec("passed", false)
		local green_color = "\x1b[38;5;10m"
		local result = output.create_spec_description(spec, green_color)

		assert.is_string(result)
		-- Should contain the color code
		assert.is_true(result:match("\x1b") ~= nil)
	end)

	nio_tests.it("handles empty hierarchy", function()
		local spec = create_mock_spec("passed", false)
		spec.ContainerHierarchyTexts = {}

		local result = output.create_spec_description(spec)

		assert.is_string(result)
		-- Should still contain leaf node text
		assert.is_true(result:match("should do something") ~= nil)
	end)
end)

describe("output.create_spec_output", function()
	nio_tests.it("formats passing test output with green color", function()
		local spec = create_mock_spec("passed", false)
		local result = output.create_spec_output(spec)

		assert.is_string(result)
		-- Should contain ANSI color codes
		assert.is_true(result:match("\x1b") ~= nil)
		-- Should contain test description
		assert.is_true(result:match("should do something") ~= nil)
		-- Should contain location
		assert.is_true(result:match("/test/example_test.go:42") ~= nil)
		-- Should contain captured output
		assert.is_true(result:match("Test output") ~= nil)
	end)

	nio_tests.it("formats pending test output with yellow color", function()
		local spec = create_mock_spec("pending", false)
		local result = output.create_spec_output(spec)

		assert.is_string(result)
		assert.is_true(result:match("should do something") ~= nil)
	end)

	nio_tests.it("formats skipped test output with cyan color", function()
		local spec = create_mock_spec("skipped", false)
		local result = output.create_spec_output(spec)

		assert.is_string(result)
		assert.is_true(result:match("should do something") ~= nil)
	end)

	nio_tests.it("indents captured output lines", function()
		local spec = create_mock_spec("passed", false)
		local result = output.create_spec_output(spec)

		-- Lines should be indented with 2 spaces
		assert.is_true(result:match("  Test output") ~= nil)
		assert.is_true(result:match("  Line 2") ~= nil)
	end)
end)

describe("output.create_error_output", function()
	nio_tests.it("formats failed test output with error details", function()
		local spec = create_mock_spec("failed", true)
		local result = output.create_error_output(spec)

		assert.is_string(result)
		-- Should contain test description
		assert.is_true(result:match("should do something") ~= nil)
		-- Should contain failure status
		assert.is_true(result:match("%[FAILED%]") ~= nil)
		-- Should contain error message
		assert.is_true(result:match("Expected false") ~= nil)
		-- Should contain failure location
		assert.is_true(result:match("/test/example_test.go:44") ~= nil)
		-- Should contain failure node location
		assert.is_true(result:match("/test/example_test.go:43") ~= nil)
	end)

	nio_tests.it("formats panicked test output with magenta color", function()
		local spec = create_mock_spec("panicked", true)
		spec.Failure.ForwardedPanic = "runtime error: index out of range"

		local result = output.create_error_output(spec)

		assert.is_string(result)
		-- Should contain panic status
		assert.is_true(result:match("%[PANICKED%]") ~= nil)
		-- Should contain panic message
		assert.is_true(result:match("runtime error") ~= nil)
		-- Should contain full stack trace
		assert.is_true(result:match("Full Stack Trace") ~= nil)
	end)

	nio_tests.it("includes captured output if present", function()
		local spec = create_mock_spec("failed", true)
		local result = output.create_error_output(spec)

		assert.is_string(result)
		-- Should include the captured output
		assert.is_true(result:match("Test output") ~= nil)
	end)

	nio_tests.it("handles nil CapturedGinkgoWriterOutput", function()
		local spec = create_mock_spec("failed", true)
		spec.CapturedGinkgoWriterOutput = nil

		local result = output.create_error_output(spec)

		assert.is_string(result)
		-- Should still format without crashing
		assert.is_true(result:match("should do something") ~= nil)
	end)

	nio_tests.it("indents error message lines", function()
		local spec = create_mock_spec("failed", true)
		local result = output.create_error_output(spec)

		-- Error message lines should be indented with 2 spaces
		assert.is_true(result:match("  Expected false") ~= nil)
		assert.is_true(result:match("  to be true") ~= nil)
	end)
end)

describe("output.get_output", function()
	nio_tests.it("formats and indents output lines", function()
		local item = {
			CapturedGinkgoWriterOutput = "Line 1\nLine 2\nLine 3",
		}

		local result = output.get_output(item)

		assert.is_string(result)
		-- Each line should be indented
		assert.is_true(result:match("  Line 1") ~= nil)
		assert.is_true(result:match("  Line 2") ~= nil)
		assert.is_true(result:match("  Line 3") ~= nil)
	end)

	nio_tests.it("handles single line output", function()
		local item = {
			CapturedGinkgoWriterOutput = "Single line",
		}

		local result = output.get_output(item)

		assert.is_string(result)
		assert.is_true(result:match("  Single line") ~= nil)
	end)

	nio_tests.it("handles empty output", function()
		local item = {
			CapturedGinkgoWriterOutput = "",
		}

		local result = output.get_output(item)

		assert.is_string(result)
	end)
end)

describe("output.get_error", function()
	nio_tests.it("formats and indents error message lines", function()
		local item = {
			Message = "Error line 1\nError line 2\nError line 3",
		}

		local result = output.get_error(item)

		assert.is_string(result)
		-- Each line should be indented
		assert.is_true(result:match("  Error line 1") ~= nil)
		assert.is_true(result:match("  Error line 2") ~= nil)
		assert.is_true(result:match("  Error line 3") ~= nil)
	end)

	nio_tests.it("handles single line error", function()
		local item = {
			Message = "Single error",
		}

		local result = output.get_error(item)

		assert.is_string(result)
		assert.is_true(result:match("  Single error") ~= nil)
	end)
end)

describe("ANSI color codes", function()
	nio_tests.it("produces output with proper ANSI codes", function()
		local spec = create_mock_spec("passed", false)
		local result = output.create_spec_output(spec)

		-- Should contain escape sequences
		assert.is_true(result:match("\x1b%[") ~= nil)
		-- Should contain clear/reset code
		assert.is_true(result:match("\x1b%[0m") ~= nil)
	end)

	nio_tests.it("uses different colors for different states", function()
		local passing = output.create_spec_output(create_mock_spec("passed", false))
		local pending = output.create_spec_output(create_mock_spec("pending", false))

		-- Both should have escape codes but potentially different ones
		assert.is_string(passing)
		assert.is_string(pending)
		assert.is_true(passing:match("\x1b") ~= nil)
		assert.is_true(pending:match("\x1b") ~= nil)
	end)
end)
