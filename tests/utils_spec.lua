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

	describe("create_position_focus", function()
		it("creates focus pattern from position id", function()
			local position = { id = "/path/to/file.go::Describe text::It test" }
			local result = utils.create_position_focus(position)
			assert.equals("\\bDescribe text It test\\b", result)
		end)

		it("handles nested namespaces", function()
			local position = { id = "/path/file.go::Outer::Inner::test name" }
			local result = utils.create_position_focus(position)
			assert.equals("\\bOuter Inner test name\\b", result)
		end)

		it("removes quotes from pattern", function()
			local position = { id = '/path/file.go::"Describe"::"It"' }
			local result = utils.create_position_focus(position)
			assert.equals("\\bDescribe It\\b", result)
		end)

		it("returns fallback pattern when no separator found", function()
			local position = { id = "/path/to/file.go" }
			local result = utils.create_position_focus(position)
			assert.equals(".*", result)
		end)
	end)
end)
