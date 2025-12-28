local report = require("nvim-ginkgo.report")

describe("nvim-ginkgo.report", function()
	describe("state_map", function()
		it("maps pending to skipped", function()
			assert.equals("skipped", report.state_map.pending)
		end)

		it("maps panicked to failed", function()
			assert.equals("failed", report.state_map.panicked)
		end)

		it("maps all 8 ginkgo states", function()
			assert.equals("skipped", report.state_map.pending)
			assert.equals("failed", report.state_map.panicked)
			assert.equals("skipped", report.state_map.skipped)
			assert.equals("passed", report.state_map.passed)
			assert.equals("failed", report.state_map.failed)
			assert.equals("failed", report.state_map.interrupted)
			assert.equals("failed", report.state_map.aborted)
			assert.equals("failed", report.state_map.timedout)
		end)
	end)

	describe("test_leaf_types", function()
		it("includes It", function()
			assert.is_true(report.test_leaf_types.It)
		end)

		it("includes Specify", function()
			assert.is_true(report.test_leaf_types.Specify)
		end)

		it("includes Entry", function()
			assert.is_true(report.test_leaf_types.Entry)
		end)

		it("excludes other types", function()
			assert.is_nil(report.test_leaf_types.Describe)
			assert.is_nil(report.test_leaf_types.Context)
		end)
	end)

	describe("get_color", function()
		it("returns yellow for pending state", function()
			local spec = { State = "pending" }
			local result = report.get_color(spec)
			assert.is_not_nil(result)
			assert.is_true(result:find("11m") ~= nil) -- yellow ANSI code
		end)

		it("returns magenta for panicked state", function()
			local spec = { State = "panicked" }
			local result = report.get_color(spec)
			assert.is_not_nil(result)
			assert.is_true(result:find("13m") ~= nil) -- magenta ANSI code
		end)

		it("returns cyan for skipped state", function()
			local spec = { State = "skipped" }
			local result = report.get_color(spec)
			assert.is_not_nil(result)
			assert.is_true(result:find("14m") ~= nil) -- cyan ANSI code
		end)

		it("returns red for failure", function()
			local spec = { State = "failed", Failure = {} }
			local result = report.get_color(spec)
			assert.is_not_nil(result)
			assert.is_true(result:find("9m") ~= nil) -- red ANSI code
		end)

		it("returns green for passed", function()
			local spec = { State = "passed" }
			local result = report.get_color(spec)
			assert.is_not_nil(result)
			assert.is_true(result:find("10m") ~= nil) -- green ANSI code
		end)

		it("returns orange for timedout state", function()
			local spec = { State = "timedout" }
			local result = report.get_color(spec)
			assert.is_not_nil(result)
			assert.is_true(result:find("214m") ~= nil) -- orange ANSI code
		end)

		it("returns orange for interrupted state", function()
			local spec = { State = "interrupted" }
			local result = report.get_color(spec)
			assert.is_not_nil(result)
			assert.is_true(result:find("214m") ~= nil) -- orange ANSI code
		end)

		it("returns coral for aborted state", function()
			local spec = { State = "aborted" }
			local result = report.get_color(spec)
			assert.is_not_nil(result)
			assert.is_true(result:find("204m") ~= nil) -- coral ANSI code
		end)
	end)

	describe("create_location_id", function()
		it("creates id from spec", function()
			local spec = {
				LeafNodeLocation = { FileName = "/path/to/file_test.go" },
				ContainerHierarchyTexts = { "Describe block", "Context block" },
				LeafNodeText = "test case",
			}
			local result = report.create_location_id(spec)
			assert.equals('/path/to/file_test.go::"Describe block"::"Context block"::"test case"', result)
		end)

		it("handles empty container hierarchy", function()
			local spec = {
				LeafNodeLocation = { FileName = "/path/to/file_test.go" },
				ContainerHierarchyTexts = {},
				LeafNodeText = "test case",
			}
			local result = report.create_location_id(spec)
			assert.equals('/path/to/file_test.go::"test case"', result)
		end)
	end)

	describe("create_location", function()
		it("creates location string", function()
			local loc = { FileName = "/path/to/file.go", LineNumber = 42 }
			local result = report.create_location(loc)
			assert.equals("/path/to/file.go:42", result)
		end)
	end)

	describe("format_output", function()
		it("indents each line", function()
			local message = "line1\nline2\nline3"
			local result = report.format_output(message)
			assert.equals("  line1\n  line2\n  line3", result)
		end)

		it("handles single line", function()
			local message = "single line"
			local result = report.format_output(message)
			assert.equals("  single line", result)
		end)
	end)

	describe("create_error", function()
		it("extracts error info from spec", function()
			local spec = {
				Failure = {
					FailureNodeLocation = { FileName = "/path/file.go", LineNumber = 10 },
					Location = { FileName = "/path/file.go", LineNumber = 15 },
					Message = "Expected true to be false",
				},
			}
			local result = report.create_error(spec)
			assert.equals(14, result.line) -- 0-indexed
			assert.equals("Expected true to be false", result.message)
		end)

		it("uses failure node location when files differ", function()
			local spec = {
				Failure = {
					FailureNodeLocation = { FileName = "/path/file.go", LineNumber = 10 },
					Location = { FileName = "/other/file.go", LineNumber = 15 },
					Message = "Error message",
				},
			}
			local result = report.create_error(spec)
			assert.equals(9, result.line) -- Uses FailureNodeLocation (0-indexed)
		end)

		it("returns default error when no failure", function()
			local spec = {}
			local result = report.create_error(spec)
			assert.equals(0, result.line)
			assert.equals("Unknown error", result.message)
		end)
	end)

	describe("create_desc", function()
		it("creates description from spec", function()
			local spec = {
				ContainerHierarchyTexts = { "Describe", "Context" },
				LeafNodeType = "It",
				LeafNodeText = "should work",
			}
			local result = report.create_desc(spec, "")
			assert.is_true(result:find("Describe") ~= nil)
			assert.is_true(result:find("Context") ~= nil)
			assert.is_true(result:find("%[It%]") ~= nil)
			assert.is_true(result:find("should work") ~= nil)
		end)

		it("includes labels if present", function()
			local spec = {
				ContainerHierarchyTexts = {},
				LeafNodeType = "It",
				LeafNodeText = "test",
				LeafNodeLabels = { "slow", "integration" },
			}
			local result = report.create_desc(spec, "")
			assert.is_true(result:find("%[slow, integration%]") ~= nil)
		end)
	end)
end)
