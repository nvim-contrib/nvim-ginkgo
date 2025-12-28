local utils = require("nvim-ginkgo.utils")

describe("nvim-ginkgo.utils", function()
	describe("get_build_tags", function()
		local temp_file

		before_each(function()
			temp_file = vim.fn.tempname() .. ".go"
		end)

		after_each(function()
			pcall(os.remove, temp_file)
		end)

		it("returns empty string for file without build tags", function()
			local content = [[package main

func main() {}
]]
			local f = io.open(temp_file, "w")
			f:write(content)
			f:close()

			local result = utils.get_build_tags(temp_file)
			assert.equals("", result)
		end)

		it("parses //go:build tags", function()
			local content = [[//go:build integration
package main
]]
			local f = io.open(temp_file, "w")
			f:write(content)
			f:close()

			local result = utils.get_build_tags(temp_file)
			assert.equals("--tags=integration", result)
		end)

		it("parses // +build tags (legacy)", function()
			local content = [[// +build unit e2e
package main
]]
			local f = io.open(temp_file, "w")
			f:write(content)
			f:close()

			local result = utils.get_build_tags(temp_file)
			assert.equals("--tags=unit,e2e", result)
		end)

		it("returns empty string for non-existent file", function()
			local result = utils.get_build_tags("/non/existent/file.go")
			assert.equals("", result)
		end)
	end)

	describe("get_color", function()
		it("returns yellow for pending state", function()
			local spec = { State = "pending" }
			local result = utils.get_color(spec)
			assert.is_not_nil(result)
			assert.is_true(result:find("11m") ~= nil) -- yellow ANSI code
		end)

		it("returns magenta for panicked state", function()
			local spec = { State = "panicked" }
			local result = utils.get_color(spec)
			assert.is_not_nil(result)
			assert.is_true(result:find("13m") ~= nil) -- magenta ANSI code
		end)

		it("returns cyan for skipped state", function()
			local spec = { State = "skipped" }
			local result = utils.get_color(spec)
			assert.is_not_nil(result)
			assert.is_true(result:find("14m") ~= nil) -- cyan ANSI code
		end)

		it("returns red for failure", function()
			local spec = { State = "failed", Failure = {} }
			local result = utils.get_color(spec)
			assert.is_not_nil(result)
			assert.is_true(result:find("9m") ~= nil) -- red ANSI code
		end)

		it("returns green for passed", function()
			local spec = { State = "passed" }
			local result = utils.get_color(spec)
			assert.is_not_nil(result)
			assert.is_true(result:find("10m") ~= nil) -- green ANSI code
		end)
	end)

	describe("create_position_focus", function()
		it("creates focus pattern from position id", function()
			local position = { id = "/path/to/file.go::Describe text::It test" }
			local result = utils.create_position_focus(position)
			assert.equals("'\\bDescribe text It test\\b'", result)
		end)

		it("handles nested namespaces", function()
			local position = { id = "/path/file.go::Outer::Inner::test name" }
			local result = utils.create_position_focus(position)
			assert.equals("'\\bOuter Inner test name\\b'", result)
		end)

		it("removes quotes from pattern", function()
			local position = { id = '/path/file.go::"Describe"::"It"' }
			local result = utils.create_position_focus(position)
			assert.equals("'\\bDescribe It\\b'", result)
		end)

		it("returns fallback pattern when no separator found", function()
			local position = { id = "/path/to/file.go" }
			local result = utils.create_position_focus(position)
			assert.equals("'.*'", result)
		end)
	end)

	describe("create_location_id", function()
		it("creates id from spec", function()
			local spec = {
				LeafNodeLocation = { FileName = "/path/to/file_test.go" },
				ContainerHierarchyTexts = { "Describe block", "Context block" },
				LeafNodeText = "test case",
			}
			local result = utils.create_location_id(spec)
			assert.equals('/path/to/file_test.go::"Describe block"::"Context block"::"test case"', result)
		end)

		it("handles empty container hierarchy", function()
			local spec = {
				LeafNodeLocation = { FileName = "/path/to/file_test.go" },
				ContainerHierarchyTexts = {},
				LeafNodeText = "test case",
			}
			local result = utils.create_location_id(spec)
			assert.equals('/path/to/file_test.go::"test case"', result)
		end)
	end)

	describe("create_location", function()
		it("creates location string", function()
			local spec = { FileName = "/path/to/file.go", LineNumber = 42 }
			local result = utils.create_location(spec)
			assert.equals("/path/to/file.go:42", result)
		end)
	end)

	describe("format_output", function()
		it("indents each line", function()
			local message = "line1\nline2\nline3"
			local result = utils.format_output(message)
			assert.equals("  line1\n  line2\n  line3", result)
		end)

		it("handles single line", function()
			local message = "single line"
			local result = utils.format_output(message)
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
			local result = utils.create_error(spec)
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
			local result = utils.create_error(spec)
			assert.equals(9, result.line) -- Uses FailureNodeLocation (0-indexed)
		end)
	end)
end)
