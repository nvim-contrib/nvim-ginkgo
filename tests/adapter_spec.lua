describe("nvim-ginkgo adapter", function()
	local adapter

	before_each(function()
		-- Reset the module
		package.loaded["nvim-ginkgo"] = nil
		package.loaded["nvim-ginkgo.utils"] = nil
		package.loaded["nvim-ginkgo.style"] = nil
	end)

	describe("setup", function()
		it("returns adapter with default config", function()
			adapter = require("nvim-ginkgo")()
			assert.is_not_nil(adapter)
			assert.equals("nvim-ginkgo", adapter.name)
		end)

		it("returns adapter with custom config", function()
			adapter = require("nvim-ginkgo")({
				race = true,
				timeout = "5m",
			})
			assert.is_not_nil(adapter)
			assert.equals("nvim-ginkgo", adapter.name)
		end)
	end)

	describe("is_test_file", function()
		before_each(function()
			adapter = require("nvim-ginkgo")()
		end)

		it("returns true for *_test.go files", function()
			assert.is_true(adapter.is_test_file("/path/to/foo_test.go"))
			assert.is_true(adapter.is_test_file("/path/to/bar_test.go"))
		end)

		it("returns false for non-test Go files", function()
			assert.is_false(adapter.is_test_file("/path/to/foo.go"))
			assert.is_false(adapter.is_test_file("/path/to/main.go"))
		end)

		it("returns false for suite_test.go files", function()
			assert.is_false(adapter.is_test_file("/path/to/suite_test.go"))
			assert.is_false(adapter.is_test_file("/path/to/foo_suite_test.go"))
		end)

		it("returns false for non-Go files", function()
			assert.is_false(adapter.is_test_file("/path/to/test.js"))
			assert.is_false(adapter.is_test_file("/path/to/test.lua"))
		end)
	end)

	describe("filter_dir", function()
		it("excludes vendor directory", function()
			adapter = require("nvim-ginkgo")()
			assert.is_false(adapter.filter_dir("vendor", "vendor", "/root"))
			assert.is_false(adapter.filter_dir("vendor", "pkg/vendor", "/root"))
		end)

		it("includes normal directories", function()
			adapter = require("nvim-ginkgo")()
			assert.is_true(adapter.filter_dir("pkg", "pkg", "/root"))
			assert.is_true(adapter.filter_dir("internal", "internal", "/root"))
			assert.is_true(adapter.filter_dir("cmd", "cmd", "/root"))
		end)

		it("excludes user-configured directories", function()
			adapter = require("nvim-ginkgo")({
				exclude_dirs = { "testdata", "fixtures" },
			})
			assert.is_false(adapter.filter_dir("testdata", "testdata", "/root"))
			assert.is_false(adapter.filter_dir("fixtures", "pkg/fixtures", "/root"))
			assert.is_true(adapter.filter_dir("pkg", "pkg", "/root"))
		end)
	end)

	describe("build_spec", function()
		before_each(function()
			adapter = require("nvim-ginkgo")()
		end)

		it("builds command as a table", function()
			-- Mock the tree data
			local mock_tree = {
				data = function()
					return {
						type = "file",
						path = "/path/to/foo_test.go",
					}
				end,
			}

			local spec = adapter.build_spec({ tree = mock_tree })
			assert.is_table(spec.command)
			assert.equals("ginkgo", spec.command[1])
			assert.equals("run", spec.command[2])
		end)

		it("includes race flag when configured", function()
			adapter = require("nvim-ginkgo")({ race = true })

			local mock_tree = {
				data = function()
					return {
						type = "file",
						path = "/path/to/foo_test.go",
					}
				end,
			}

			local spec = adapter.build_spec({ tree = mock_tree })
			local has_race = false
			for _, arg in ipairs(spec.command) do
				if arg == "--race" then
					has_race = true
					break
				end
			end
			assert.is_true(has_race)
		end)

		it("includes timeout when configured", function()
			adapter = require("nvim-ginkgo")({ timeout = "10m" })

			local mock_tree = {
				data = function()
					return {
						type = "file",
						path = "/path/to/foo_test.go",
					}
				end,
			}

			local spec = adapter.build_spec({ tree = mock_tree })
			local has_timeout = false
			local timeout_value = nil
			for i, arg in ipairs(spec.command) do
				if arg == "--timeout" then
					has_timeout = true
					timeout_value = spec.command[i + 1]
					break
				end
			end
			assert.is_true(has_timeout)
			assert.equals("10m", timeout_value)
		end)

		it("includes label filter when configured", function()
			adapter = require("nvim-ginkgo")({ label_filter = "!slow" })

			local mock_tree = {
				data = function()
					return {
						type = "file",
						path = "/path/to/foo_test.go",
					}
				end,
			}

			local spec = adapter.build_spec({ tree = mock_tree })
			local has_label_filter = false
			local filter_value = nil
			for i, arg in ipairs(spec.command) do
				if arg == "--label-filter" then
					has_label_filter = true
					filter_value = spec.command[i + 1]
					break
				end
			end
			assert.is_true(has_label_filter)
			assert.equals("!slow", filter_value)
		end)

		it("uses custom ginkgo command", function()
			adapter = require("nvim-ginkgo")({ ginkgo_cmd = "/custom/path/ginkgo" })

			local mock_tree = {
				data = function()
					return {
						type = "file",
						path = "/path/to/foo_test.go",
					}
				end,
			}

			local spec = adapter.build_spec({ tree = mock_tree })
			assert.equals("/custom/path/ginkgo", spec.command[1])
		end)
	end)
end)
