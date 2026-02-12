-- Tests for spec.lua module (spec building)

---@diagnostic disable: undefined-field

local nio_tests = require("nio.tests")
local spec = require("nvim-ginkgo.spec")
local helpers = dofile(vim.fn.getcwd() .. "/spec/helpers/spec.lua")

-- Use helpers from spec/helpers/spec.lua
local create_mock_tree = helpers.create_mock_tree
local contains = helpers.contains
local table_contains = helpers.table_contains

describe("spec.build", function()
	describe("directory position", function()
		nio_tests.it("builds command for directory with no filters", function()
			-- Use an actual existing directory for the test
			local test_dir = vim.fn.getcwd() .. "/spec"

			local position = {
				type = "dir",
				path = test_dir,
				name = "spec",
				range = { 0, 0, 0, 0 },
			}

			local args = {
				tree = create_mock_tree(position),
			}

			local result = spec.build(args)

			assert.is_not_nil(result)
			assert.is_table(result.command)

			-- Should start with ginkgo run -v
			assert.are.equal("ginkgo", result.command[1])
			assert.are.equal("run", result.command[2])
			assert.is_true(table_contains(result.command, "-v"))

			-- Should have --keep-going, --silence-skips, and --json-report
			assert.is_true(table_contains(result.command, "--keep-going"))
			assert.is_true(table_contains(result.command, "--silence-skips"))
			assert.is_true(table_contains(result.command, "--json-report"))

			-- Should NOT have --focus or --focus-file for directory runs
			assert.is_false(table_contains(result.command, "--focus"))
			assert.is_false(table_contains(result.command, "--focus-file"))

			-- Should end with package path
			local last_arg = result.command[#result.command]
			assert.is_true(contains(last_arg, test_dir))
		end)
	end)

	describe("file position", function()
		nio_tests.it("builds command with --focus-file for entire file", function()
			local position = {
				type = "file",
				path = "/project/pkg/example_test.go",
				name = "example_test.go",
				range = { 0, 0, 100, 0 },
			}

			local args = {
				tree = create_mock_tree(position),
			}

			local result = spec.build(args)

			assert.is_not_nil(result)
			assert.is_table(result.command)

			-- Should have --focus-file with the file path
			assert.is_true(table_contains(result.command, "--focus-file"))
			assert.is_true(table_contains(result.command, "/project/pkg/example_test.go"))

			-- Should NOT have --focus pattern for file-level runs
			assert.is_false(table_contains(result.command, "--focus"))

			-- Package path should be the parent directory
			local last_arg = result.command[#result.command]
			assert.are.equal("/project/pkg/...", last_arg)
		end)
	end)

	describe("namespace position", function()
		nio_tests.it("builds command with --focus-file and --focus pattern", function()
			local position = {
				type = "namespace",
				path = "/project/pkg/example_test.go",
				name = '"Book Store"',
				id = '/project/pkg/example_test.go::"Book Store"',
				range = { 10, 0, 50, 0 },
			}

			local args = {
				tree = create_mock_tree(position),
			}

			local result = spec.build(args)

			assert.is_not_nil(result)
			assert.is_table(result.command)

			-- Should have --focus-file with line number
			assert.is_true(table_contains(result.command, "--focus-file"))
			-- Find --focus-file in command and check next element has line number
			local focus_file_idx = nil
			for i, arg in ipairs(result.command) do
				if arg == "--focus-file" then
					focus_file_idx = i
					break
				end
			end
			assert.is_not_nil(focus_file_idx)
			assert.are.equal("/project/pkg/example_test.go:11", result.command[focus_file_idx + 1])

			-- Should have --focus pattern
			assert.is_true(table_contains(result.command, "--focus"))
			-- Find --focus in command and check the pattern
			local focus_idx = nil
			for i, arg in ipairs(result.command) do
				if arg == "--focus" then
					focus_idx = i
					break
				end
			end
			assert.is_not_nil(focus_idx)
			local pattern = result.command[focus_idx + 1]
			assert.is_true(contains(pattern, "Book Store"))
		end)

		nio_tests.it("builds correct focus pattern for nested namespaces", function()
			local position = {
				type = "namespace",
				path = "/project/pkg/example_test.go",
				name = '"Context"',
				id = '/project/pkg/example_test.go::"Describe"::"Context"',
				range = { 20, 0, 40, 0 },
			}

			local args = {
				tree = create_mock_tree(position),
			}

			local result = spec.build(args)

			assert.is_not_nil(result)
			assert.is_table(result.command)

			-- Find --focus in command
			local focus_idx = nil
			for i, arg in ipairs(result.command) do
				if arg == "--focus" then
					focus_idx = i
					break
				end
			end
			assert.is_not_nil(focus_idx)
			local pattern = result.command[focus_idx + 1]

			-- Pattern should have "Describe Context" (:: replaced with space, quotes removed)
			assert.is_true(contains(pattern, "Describe"))
			assert.is_true(contains(pattern, "Context"))
			-- Should have word boundaries
			assert.is_true(contains(pattern, "\\b"))
		end)
	end)

	describe("test position", function()
		nio_tests.it("builds command with --focus-file and --focus pattern", function()
			local position = {
				type = "test",
				path = "/project/pkg/example_test.go",
				name = '"adds books correctly"',
				id = '/project/pkg/example_test.go::"Book Store"::"adds books correctly"',
				range = { 15, 0, 20, 0 },
			}

			local args = {
				tree = create_mock_tree(position),
			}

			local result = spec.build(args)

			assert.is_not_nil(result)
			assert.is_table(result.command)

			-- Should have --focus-file with line number
			assert.is_true(table_contains(result.command, "--focus-file"))
			local focus_file_idx = nil
			for i, arg in ipairs(result.command) do
				if arg == "--focus-file" then
					focus_file_idx = i
					break
				end
			end
			assert.is_not_nil(focus_file_idx)
			assert.are.equal("/project/pkg/example_test.go:16", result.command[focus_file_idx + 1])

			-- Should have --focus pattern with both namespace and test name
			assert.is_true(table_contains(result.command, "--focus"))
			local focus_idx = nil
			for i, arg in ipairs(result.command) do
				if arg == "--focus" then
					focus_idx = i
					break
				end
			end
			assert.is_not_nil(focus_idx)
			local pattern = result.command[focus_idx + 1]
			assert.is_true(contains(pattern, "Book Store"))
			assert.is_true(contains(pattern, "adds books correctly"))
		end)
	end)

	describe("extra_args handling", function()
		nio_tests.it("includes extra_args in command", function()
			local position = {
				type = "dir",
				path = "/project/pkg",
				name = "pkg",
				range = { 0, 0, 0, 0 },
			}

			local args = {
				tree = create_mock_tree(position),
				extra_args = { "--label-filter", "slow", "-p" },
			}

			local result = spec.build(args)

			assert.is_not_nil(result)
			assert.is_table(result.command)

			-- Should include extra args
			assert.is_true(table_contains(result.command, "--label-filter"))
			assert.is_true(table_contains(result.command, "slow"))
			assert.is_true(table_contains(result.command, "-p"))
		end)

		nio_tests.it("handles empty extra_args", function()
			local position = {
				type = "dir",
				path = "/project/pkg",
				name = "pkg",
				range = { 0, 0, 0, 0 },
			}

			local args = {
				tree = create_mock_tree(position),
				extra_args = {},
			}

			local result = spec.build(args)

			assert.is_not_nil(result)
			assert.is_table(result.command)
		end)

		nio_tests.it("handles missing extra_args", function()
			local position = {
				type = "dir",
				path = "/project/pkg",
				name = "pkg",
				range = { 0, 0, 0, 0 },
			}

			local args = {
				tree = create_mock_tree(position),
			}

			local result = spec.build(args)

			assert.is_not_nil(result)
			assert.is_table(result.command)
		end)
	end)

	describe("context metadata", function()
		nio_tests.it("includes position info in context", function()
			local position = {
				type = "test",
				path = "/project/pkg/example_test.go",
				name = '"test name"',
				id = '/project/pkg/example_test.go::"test name"',
				range = { 10, 0, 20, 0 },
			}

			local args = {
				tree = create_mock_tree(position),
			}

			local result = spec.build(args)

			assert.is_not_nil(result.context)
			assert.are.equal("test", result.context.report_input_type)
			assert.are.equal("/project/pkg/example_test.go", result.context.report_input_path)
			assert.is_string(result.context.report_output_path)
		end)

		nio_tests.it("generates report paths for each call", function()
			local position = {
				type = "test",
				path = "/project/pkg/example_test.go",
				name = '"test"',
				id = '/project/pkg/example_test.go::"test"',
				range = { 10, 0, 20, 0 },
			}

			local args = {
				tree = create_mock_tree(position),
			}

			local result1 = spec.build(args)
			local result2 = spec.build(args)

			-- Report paths should be valid strings
			assert.is_not_nil(result1.context.report_output_path)
			assert.is_not_nil(result2.context.report_output_path)
			assert.is_string(result1.context.report_output_path)
			assert.is_string(result2.context.report_output_path)
		end)
	end)

	describe("focus pattern formatting", function()
		nio_tests.it("removes quotes from test names", function()
			local position = {
				type = "test",
				path = "/project/pkg/example_test.go",
				name = '"test with quotes"',
				id = '/project/pkg/example_test.go::"test with quotes"',
				range = { 10, 0, 20, 0 },
			}

			local args = {
				tree = create_mock_tree(position),
			}

			local result = spec.build(args)

			assert.is_table(result.command)

			-- Find --focus in command
			local focus_idx = nil
			for i, arg in ipairs(result.command) do
				if arg == "--focus" then
					focus_idx = i
					break
				end
			end
			assert.is_not_nil(focus_idx)
			local pattern = result.command[focus_idx + 1]

			-- Should have "test with quotes" (quotes removed)
			assert.is_true(contains(pattern, "test with quotes"))
			-- Should NOT have the quote characters in the pattern
			assert.is_nil(pattern:find('""', 1, true))
		end)

		nio_tests.it("replaces :: with spaces", function()
			local position = {
				type = "test",
				path = "/project/pkg/example_test.go",
				name = '"nested test"',
				id = '/project/pkg/example_test.go::"Outer"::"Inner"::"nested test"',
				range = { 10, 0, 20, 0 },
			}

			local args = {
				tree = create_mock_tree(position),
			}

			local result = spec.build(args)

			assert.is_table(result.command)

			-- Find --focus in command
			local focus_idx = nil
			for i, arg in ipairs(result.command) do
				if arg == "--focus" then
					focus_idx = i
					break
				end
			end
			assert.is_not_nil(focus_idx)
			local pattern = result.command[focus_idx + 1]

			-- Should have spaces between levels, not ::
			assert.is_true(contains(pattern, "Outer Inner nested test"))
			-- Should NOT have :: in the focus pattern
			assert.is_nil(pattern:find("::", 1, true))
		end)

		nio_tests.it("adds word boundaries to pattern", function()
			local position = {
				type = "test",
				path = "/project/pkg/example_test.go",
				name = '"test"',
				id = '/project/pkg/example_test.go::"test"',
				range = { 10, 0, 20, 0 },
			}

			local args = {
				tree = create_mock_tree(position),
			}

			local result = spec.build(args)

			assert.is_table(result.command)

			-- Find --focus in command
			local focus_idx = nil
			for i, arg in ipairs(result.command) do
				if arg == "--focus" then
					focus_idx = i
					break
				end
			end
			assert.is_not_nil(focus_idx)
			local pattern = result.command[focus_idx + 1]

			-- Should have \b word boundaries
			assert.is_true(contains(pattern, "\\b"))
		end)

		nio_tests.it("escapes regex special characters in focus pattern", function()
			local position = {
				type = "test",
				path = "/project/pkg/example_test.go",
				name = '"handles $var.field() correctly"',
				id = '/project/pkg/example_test.go::"handles $var.field() correctly"',
				range = { 10, 0, 20, 0 },
			}

			local args = {
				tree = create_mock_tree(position),
			}

			local result = spec.build(args)

			assert.is_not_nil(result)
			assert.is_table(result.command)

			-- Find focus pattern in command array
			local focus_idx = nil
			for i, arg in ipairs(result.command) do
				if arg == "--focus" then
					focus_idx = i
					break
				end
			end

			assert.is_not_nil(focus_idx)
			local pattern = result.command[focus_idx + 1]

			-- Special characters should be escaped: $ . ( )
			assert.is_true(pattern:find("\\%$") ~= nil, "Should escape $")
			assert.is_true(pattern:find("%.") ~= nil, "Should escape .")
			assert.is_true(pattern:find("\\%(") ~= nil, "Should escape (")
			assert.is_true(pattern:find("\\%)") ~= nil, "Should escape )")
		end)

		nio_tests.it("includes line number in --focus-file for test positions", function()
			local position = {
				type = "test",
				path = "/project/pkg/example_test.go",
				name = '"test name"',
				id = '/project/pkg/example_test.go::"test name"',
				range = { 15, 0, 20, 0 },
			}

			local args = {
				tree = create_mock_tree(position),
			}

			local result = spec.build(args)

			assert.is_table(result.command)

			-- Find --focus-file flag
			local focus_file_idx = nil
			for i, arg in ipairs(result.command) do
				if arg == "--focus-file" then
					focus_file_idx = i
					break
				end
			end

			assert.is_not_nil(focus_file_idx)
			-- Should include line number (range[1] + 1 = 16)
			assert.are.equal("/project/pkg/example_test.go:16", result.command[focus_file_idx + 1])
		end)
	end)
end)
