-- Tests for dap.lua module (DAP strategy building)

---@diagnostic disable: undefined-field

local nio_tests = require("nio.tests")
local helpers = dofile(vim.fn.getcwd() .. "/spec/helpers/spec.lua")

-- Mock dap-go to avoid dependency
package.loaded["dap-go"] = {}

local dap = require("nvim-ginkgo.dap")
local spec = require("nvim-ginkgo.spec")

-- Use helper from spec/helpers/spec.lua
local create_mock_tree = helpers.create_mock_tree

describe("dap.build", function()
	nio_tests.it("builds DAP strategy from context", function()
		local position = {
			type = "test",
			path = "/project/pkg/example_test.go",
			name = "test name",
			id = '/project/pkg/example_test.go::"test name"',
			range = { 10, 0, 20, 0 },
		}

		local args = {
			tree = create_mock_tree(position),
		}

		-- Build spec to get context
		local run_spec = spec.build(args)

		-- Build DAP strategy from context
		local strategy = dap.build(run_spec.context)

		-- Should return DAP configuration
		assert.is_not_nil(strategy)
		assert.are.equal("go", strategy.type)
		assert.are.equal("test", strategy.mode)
		assert.are.equal("/project/pkg", strategy.program)
	end)

	nio_tests.it("uses ginkgo-prefixed flags in DAP args", function()
		local position = {
			type = "test",
			path = "/project/pkg/example_test.go",
			name = "test",
			id = '/project/pkg/example_test.go::"test"',
			range = { 10, 0, 20, 0 },
		}

		local run_spec = spec.build({ tree = create_mock_tree(position) })
		local strategy = dap.build(run_spec.context)

		-- DAP args should have ginkgo prefix
		assert.is_true(vim.tbl_contains(strategy.args, "--ginkgo.json-report"))
		assert.is_true(vim.tbl_contains(strategy.args, "--ginkgo.silence-skips"))
	end)

	nio_tests.it("creates valid DAP configuration", function()
		local position = {
			type = "test",
			path = "/project/pkg/example_test.go",
			name = "test",
			id = '/project/pkg/example_test.go::"test"',
			range = { 10, 0, 20, 0 },
		}

		local run_spec = spec.build({ tree = create_mock_tree(position) })
		local strategy = dap.build(run_spec.context)

		assert.are.equal("go", strategy.type)
		assert.are.equal("Debug Ginkgo Test", strategy.name)
		assert.are.equal("launch", strategy.request)
		assert.are.equal("test", strategy.mode)
		assert.are.equal("/project/pkg", strategy.program)
		assert.are.equal("/project/pkg", strategy.cwd)
		assert.are.equal("remote", strategy.outputMode)
		assert.is_table(strategy.args)
	end)

	nio_tests.it("adds focus-file with line number for test positions", function()
		local position = {
			type = "test",
			path = "/project/pkg/example_test.go",
			name = "test",
			id = '/project/pkg/example_test.go::"test"',
			range = { 10, 0, 20, 0 },
		}

		local run_spec = spec.build({ tree = create_mock_tree(position) })
		local strategy = dap.build(run_spec.context)

		assert.is_true(vim.tbl_contains(strategy.args, "--ginkgo.focus-file"))

		-- Find the focus-file value
		local focus_file_value = nil
		for i, arg in ipairs(strategy.args) do
			if arg == "--ginkgo.focus-file" then
				focus_file_value = strategy.args[i + 1]
				break
			end
		end

		assert.is_not_nil(focus_file_value)
		assert.are.equal("/project/pkg/example_test.go:11", focus_file_value)
	end)

	nio_tests.it("adds focus pattern for test positions", function()
		local position = {
			type = "test",
			path = "/project/pkg/example_test.go",
			name = "test name",
			id = '/project/pkg/example_test.go::"Describe"::"test name"',
			range = { 10, 0, 20, 0 },
		}

		local run_spec = spec.build({ tree = create_mock_tree(position) })
		local strategy = dap.build(run_spec.context)

		assert.is_true(vim.tbl_contains(strategy.args, "--ginkgo.focus"))

		-- Find focus pattern
		local focus_pattern = nil
		for i, arg in ipairs(strategy.args) do
			if arg == "--ginkgo.focus" then
				focus_pattern = strategy.args[i + 1]
				break
			end
		end

		assert.is_not_nil(focus_pattern)
		assert.is_true(focus_pattern:find("Describe") ~= nil)
		assert.is_true(focus_pattern:find("test name") ~= nil)
		assert.is_true(focus_pattern:find("\\b") ~= nil)
	end)

	nio_tests.it("handles namespace positions", function()
		local position = {
			type = "namespace",
			path = "/project/pkg/example_test.go",
			name = "Describe Block",
			id = '/project/pkg/example_test.go::"Describe Block"',
			range = { 5, 0, 50, 0 },
		}

		local run_spec = spec.build({ tree = create_mock_tree(position) })
		local strategy = dap.build(run_spec.context)

		assert.is_true(vim.tbl_contains(strategy.args, "--ginkgo.focus-file"))
		assert.is_true(vim.tbl_contains(strategy.args, "--ginkgo.focus"))
	end)

	nio_tests.it("handles file-level positions", function()
		local position = {
			type = "file",
			path = "/project/pkg/example_test.go",
			name = "example_test.go",
			range = { 0, 0, 100, 0 },
		}

		local run_spec = spec.build({ tree = create_mock_tree(position) })
		local strategy = dap.build(run_spec.context)

		assert.is_true(vim.tbl_contains(strategy.args, "--ginkgo.focus-file"))
		-- Should NOT have focus pattern for file-level
		assert.is_false(vim.tbl_contains(strategy.args, "--ginkgo.focus"))
	end)

	nio_tests.it("handles directory positions", function()
		-- Use spec directory which exists
		local test_dir = vim.fn.getcwd() .. "/spec"

		local position = {
			type = "dir",
			path = test_dir,
			name = "spec",
			range = { 0, 0, 0, 0 },
		}

		local run_spec = spec.build({ tree = create_mock_tree(position) })
		local strategy = dap.build(run_spec.context)

		-- Directory runs should not have focus flags
		assert.is_false(vim.tbl_contains(strategy.args, "--ginkgo.focus-file"))
		assert.is_false(vim.tbl_contains(strategy.args, "--ginkgo.focus"))

		-- Program should be the directory
		assert.are.equal(test_dir, strategy.program)
	end)

	nio_tests.it("includes extra_args", function()
		local position = {
			type = "test",
			path = "/project/pkg/example_test.go",
			name = "test",
			id = '/project/pkg/example_test.go::"test"',
			range = { 10, 0, 20, 0 },
		}

		local run_spec = spec.build({
			tree = create_mock_tree(position),
			extra_args = { "--label-filter", "slow" },
		})
		local strategy = dap.build(run_spec.context)

		assert.is_true(vim.tbl_contains(strategy.args, "--label-filter"))
		assert.is_true(vim.tbl_contains(strategy.args, "slow"))
	end)
end)
