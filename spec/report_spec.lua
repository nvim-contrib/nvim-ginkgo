-- Tests for report.lua module (test result parsing)

---@diagnostic disable: undefined-field

local nio_tests = require("nio.tests")
local report = require("nvim-ginkgo.report")
local async = require("neotest.async")
local lib = require("neotest.lib")

-- Helper to create a temporary JSON report file
local function create_temp_report(report_data)
	local report_path = async.fn.tempname()
	local json_content = vim.json.encode(report_data)
	vim.fn.writefile({ json_content }, report_path)
	return report_path
end

-- Helper to create a mock spec with report path
local function create_mock_spec(report_path)
	return {
		context = {
			report_output_path = report_path,
		},
	}
end

describe("report.parse", function()
	describe("successful test parsing", function()
		nio_tests.it("parses a passing test correctly", function()
			local report_data = {
				{
					SuitePath = "/test/example_test.go",
					SuiteSucceeded = true,
					SpecReports = {
						{
							LeafNodeType = "It",
							LeafNodeText = "should pass",
							State = "passed",
							LeafNodeLocation = {
								FileName = "/test/example_test.go",
								LineNumber = 10,
							},
							ContainerHierarchyTexts = { "Describe Test" },
							CapturedGinkgoWriterOutput = "test output",
						},
					},
				},
			}

			local report_path = create_temp_report(report_data)
			local spec = create_mock_spec(report_path)

			local results = report.parse(spec, {}, nil)

			assert.is_not_nil(results)
			assert.is_table(results)

			-- Check that results contain the test
			local found = false
			for id, result in pairs(results) do
				if id:match("should pass") then
					found = true
					assert.are.equal("passed", result.status)
					assert.are.equal(10, result.location)
					assert.is_string(result.short)
					assert.is_string(result.output)
				end
			end
			assert.is_true(found, "Expected to find test result")

			-- Cleanup
			async.fn.delete(report_path)
		end)

		nio_tests.it("parses a skipped test correctly", function()
			local report_data = {
				{
					SuitePath = "/test/example_test.go",
					SuiteSucceeded = true,
					SpecReports = {
						{
							LeafNodeType = "It",
							LeafNodeText = "should skip",
							State = "pending",
							LeafNodeLocation = {
								FileName = "/test/example_test.go",
								LineNumber = 20,
							},
							ContainerHierarchyTexts = { "Describe Test" },
							CapturedGinkgoWriterOutput = "skipped",
						},
					},
				},
			}

			local report_path = create_temp_report(report_data)
			local spec = create_mock_spec(report_path)

			local results = report.parse(spec, {}, nil)

			assert.is_not_nil(results)

			-- Check that skipped test has correct status
			local found = false
			for id, result in pairs(results) do
				if id:match("should skip") then
					found = true
					assert.are.equal("skipped", result.status)
				end
			end
			assert.is_true(found, "Expected to find skipped test")

			-- Cleanup
			async.fn.delete(report_path)
		end)
	end)

	describe("failed test parsing", function()
		nio_tests.it("parses a failed test with error details", function()
			local report_data = {
				{
					SuitePath = "/test/example_test.go",
					SuiteSucceeded = false,
					SpecReports = {
						{
							LeafNodeType = "It",
							LeafNodeText = "should fail",
							State = "failed",
							LeafNodeLocation = {
								FileName = "/test/example_test.go",
								LineNumber = 30,
							},
							ContainerHierarchyTexts = { "Describe Test" },
							Failure = {
								Message = "Expected true to be false",
								FailureNodeType = "It",
								FailureNodeLocation = {
									FileName = "/test/example_test.go",
									LineNumber = 31,
								},
								Location = {
									FileName = "/test/example_test.go",
									LineNumber = 32,
									FullStackTrace = "stack trace here",
								},
							},
							CapturedGinkgoWriterOutput = "failure output",
						},
					},
				},
			}

			local report_path = create_temp_report(report_data)
			local spec = create_mock_spec(report_path)

			local results = report.parse(spec, {}, nil)

			assert.is_not_nil(results)

			-- Check that failed test has correct status and errors
			local found = false
			for id, result in pairs(results) do
				if id:match("should fail") then
					found = true
					assert.are.equal("failed", result.status)
					assert.is_table(result.errors)
					assert.are.equal(1, #result.errors)
					assert.are.equal("Expected true to be false", result.errors[1].message)
					assert.are.equal(31, result.errors[1].line)
				end
			end
			assert.is_true(found, "Expected to find failed test")

			-- Cleanup
			async.fn.delete(report_path)
		end)

		nio_tests.it("parses a panicked test correctly", function()
			local report_data = {
				{
					SuitePath = "/test/example_test.go",
					SuiteSucceeded = false,
					SpecReports = {
						{
							LeafNodeType = "It",
							LeafNodeText = "should panic",
							State = "panicked",
							LeafNodeLocation = {
								FileName = "/test/example_test.go",
								LineNumber = 40,
							},
							ContainerHierarchyTexts = { "Describe Test" },
							Failure = {
								Message = "Test panicked",
								FailureNodeType = "It",
								FailureNodeLocation = {
									FileName = "/test/example_test.go",
									LineNumber = 41,
								},
								Location = {
									FileName = "/test/example_test.go",
									LineNumber = 42,
									FullStackTrace = "panic stack trace",
								},
								ForwardedPanic = "runtime error: index out of range",
							},
							CapturedGinkgoWriterOutput = "panic output",
						},
					},
				},
			}

			local report_path = create_temp_report(report_data)
			local spec = create_mock_spec(report_path)

			local results = report.parse(spec, {}, nil)

			assert.is_not_nil(results)

			-- Check that panicked test has failed status
			local found = false
			for id, result in pairs(results) do
				if id:match("should panic") then
					found = true
					assert.are.equal("failed", result.status) -- panicked maps to failed
				end
			end
			assert.is_true(found, "Expected to find panicked test")

			-- Cleanup
			async.fn.delete(report_path)
		end)
	end)

	describe("test without captured output", function()
		nio_tests.it("handles missing CapturedGinkgoWriterOutput", function()
			local report_data = {
				{
					SuitePath = "/test/example_test.go",
					SuiteSucceeded = true,
					SpecReports = {
						{
							LeafNodeType = "It",
							LeafNodeText = "test without output",
							State = "passed",
							LeafNodeLocation = {
								FileName = "/test/example_test.go",
								LineNumber = 50,
							},
							ContainerHierarchyTexts = {},
							-- CapturedGinkgoWriterOutput is nil
						},
					},
				},
			}

			local report_path = create_temp_report(report_data)
			local spec = create_mock_spec(report_path)

			local results = report.parse(spec, {}, nil)

			assert.is_not_nil(results)

			-- Should still parse successfully
			local found = false
			for id, result in pairs(results) do
				if id:match("test without output") then
					found = true
					assert.are.equal("passed", result.status)
					assert.is_string(result.output) -- Should have output file
				end
			end
			assert.is_true(found, "Expected to find test without output")

			-- Cleanup
			async.fn.delete(report_path)
		end)
	end)

	describe("suite-level results", function()
		nio_tests.it("parses suite without spec reports", function()
			local report_data = {
				{
					SuitePath = "/test/example_test.go",
					SuiteSucceeded = true,
					-- SpecReports is nil
				},
			}

			local report_path = create_temp_report(report_data)
			local spec = create_mock_spec(report_path)

			local results = report.parse(spec, {}, nil)

			assert.is_not_nil(results)

			-- Should have suite-level result
			assert.is_not_nil(results["/test/example_test.go"])
			assert.are.equal("passed", results["/test/example_test.go"].status)

			-- Cleanup
			async.fn.delete(report_path)
		end)
	end)

	describe("error handling", function()
		nio_tests.it("returns empty table when report file is missing", function()
			local spec = create_mock_spec("/nonexistent/path.json")

			local results = report.parse(spec, {}, nil)

			assert.is_table(results)
			assert.are.equal(0, vim.tbl_count(results))
		end)

		nio_tests.it("returns empty table when JSON is invalid", function()
			local report_path = async.fn.tempname()
			vim.fn.writefile({ "invalid json {{{" }, report_path)

			local spec = create_mock_spec(report_path)

			local results = report.parse(spec, {}, nil)

			assert.is_table(results)
			assert.are.equal(0, vim.tbl_count(results))

			-- Cleanup
			async.fn.delete(report_path)
		end)
	end)

	describe("location ID generation", function()
		nio_tests.it("creates unique IDs for nested tests", function()
			local report_data = {
				{
					SuitePath = "/test/example_test.go",
					SuiteSucceeded = true,
					SpecReports = {
						{
							LeafNodeType = "It",
							LeafNodeText = "test one",
							State = "passed",
							LeafNodeLocation = {
								FileName = "/test/example_test.go",
								LineNumber = 10,
							},
							ContainerHierarchyTexts = { "Outer", "Inner" },
							CapturedGinkgoWriterOutput = "output",
						},
						{
							LeafNodeType = "It",
							LeafNodeText = "test two",
							State = "passed",
							LeafNodeLocation = {
								FileName = "/test/example_test.go",
								LineNumber = 20,
							},
							ContainerHierarchyTexts = { "Outer", "Inner" },
							CapturedGinkgoWriterOutput = "output",
						},
					},
				},
			}

			local report_path = create_temp_report(report_data)
			local spec = create_mock_spec(report_path)

			local results = report.parse(spec, {}, nil)

			assert.is_not_nil(results)

			-- Should have two distinct IDs
			local ids = {}
			for id, _ in pairs(results) do
				if id:match("test one") or id:match("test two") then
					table.insert(ids, id)
				end
			end

			assert.are.equal(2, #ids)
			assert.are_not.equal(ids[1], ids[2])

			-- IDs should include hierarchy
			for _, id in ipairs(ids) do
				assert.is_true(id:match("Outer") ~= nil)
				assert.is_true(id:match("Inner") ~= nil)
			end

			-- Cleanup
			async.fn.delete(report_path)
		end)
	end)

	describe("namespace result generation", function()
		nio_tests.it("generates results for namespace nodes", function()
			local report_data = {
				{
					SuitePath = "/test/example_test.go",
					SuiteSucceeded = true,
					SpecReports = {
						{
							LeafNodeType = "It",
							LeafNodeText = "test in describe",
							State = "passed",
							LeafNodeLocation = {
								FileName = "/test/example_test.go",
								LineNumber = 10,
							},
							ContainerHierarchyTexts = { "My Describe" },
							CapturedGinkgoWriterOutput = "output",
						},
					},
				},
			}

			local report_path = create_temp_report(report_data)
			local spec = create_mock_spec(report_path)

			local results = report.parse(spec, {}, nil)

			assert.is_not_nil(results)

			-- Should have namespace result
			local namespace_id = '/test/example_test.go::"My Describe"'
			assert.is_not_nil(results[namespace_id], "Expected namespace result for " .. namespace_id)
			assert.are.equal("passed", results[namespace_id].status)
			assert.is_string(results[namespace_id].output)

			-- Cleanup
			async.fn.delete(report_path)
		end)

		nio_tests.it("generates results for nested namespaces", function()
			local report_data = {
				{
					SuitePath = "/test/example_test.go",
					SuiteSucceeded = true,
					SpecReports = {
						{
							LeafNodeType = "It",
							LeafNodeText = "test in nested context",
							State = "passed",
							LeafNodeLocation = {
								FileName = "/test/example_test.go",
								LineNumber = 15,
							},
							ContainerHierarchyTexts = { "Outer Describe", "Inner Context" },
							CapturedGinkgoWriterOutput = "output",
						},
					},
				},
			}

			local report_path = create_temp_report(report_data)
			local spec = create_mock_spec(report_path)

			local results = report.parse(spec, {}, nil)

			assert.is_not_nil(results)

			-- Should have both namespace levels
			local outer_id = '/test/example_test.go::"Outer Describe"'
			local inner_id = '/test/example_test.go::"Outer Describe"::"Inner Context"'

			assert.is_not_nil(results[outer_id], "Expected outer namespace result")
			assert.is_not_nil(results[inner_id], "Expected inner namespace result")

			assert.are.equal("passed", results[outer_id].status)
			assert.are.equal("passed", results[inner_id].status)

			-- Cleanup
			async.fn.delete(report_path)
		end)

		nio_tests.it("aggregates status correctly with mixed results", function()
			local report_data = {
				{
					SuitePath = "/test/example_test.go",
					SuiteSucceeded = false,
					SpecReports = {
						{
							LeafNodeType = "It",
							LeafNodeText = "passing test",
							State = "passed",
							LeafNodeLocation = {
								FileName = "/test/example_test.go",
								LineNumber = 10,
							},
							ContainerHierarchyTexts = { "Mixed Results" },
							CapturedGinkgoWriterOutput = "output",
						},
						{
							LeafNodeType = "It",
							LeafNodeText = "failing test",
							State = "failed",
							LeafNodeLocation = {
								FileName = "/test/example_test.go",
								LineNumber = 20,
							},
							ContainerHierarchyTexts = { "Mixed Results" },
							Failure = {
								Message = "Test failed",
								FailureNodeType = "It",
								FailureNodeLocation = {
									FileName = "/test/example_test.go",
									LineNumber = 21,
								},
								Location = {
									FileName = "/test/example_test.go",
									LineNumber = 22,
									FullStackTrace = "stack trace",
								},
							},
							CapturedGinkgoWriterOutput = "failure output",
						},
					},
				},
			}

			local report_path = create_temp_report(report_data)
			local spec = create_mock_spec(report_path)

			local results = report.parse(spec, {}, nil)

			assert.is_not_nil(results)

			-- Namespace should have failed status (failed > passed)
			local namespace_id = '/test/example_test.go::"Mixed Results"'
			assert.is_not_nil(results[namespace_id])
			assert.are.equal("failed", results[namespace_id].status)

			-- Cleanup
			async.fn.delete(report_path)
		end)

		nio_tests.it("aggregates status as skipped when all tests are skipped", function()
			local report_data = {
				{
					SuitePath = "/test/example_test.go",
					SuiteSucceeded = true,
					SpecReports = {
						{
							LeafNodeType = "It",
							LeafNodeText = "skipped test one",
							State = "pending",
							LeafNodeLocation = {
								FileName = "/test/example_test.go",
								LineNumber = 10,
							},
							ContainerHierarchyTexts = { "All Skipped" },
							CapturedGinkgoWriterOutput = "",
						},
						{
							LeafNodeType = "It",
							LeafNodeText = "skipped test two",
							State = "pending",
							LeafNodeLocation = {
								FileName = "/test/example_test.go",
								LineNumber = 20,
							},
							ContainerHierarchyTexts = { "All Skipped" },
							CapturedGinkgoWriterOutput = "",
						},
					},
				},
			}

			local report_path = create_temp_report(report_data)
			local spec = create_mock_spec(report_path)

			local results = report.parse(spec, {}, nil)

			assert.is_not_nil(results)

			-- Namespace should have skipped status
			local namespace_id = '/test/example_test.go::"All Skipped"'
			assert.is_not_nil(results[namespace_id])
			assert.are.equal("skipped", results[namespace_id].status)

			-- Cleanup
			async.fn.delete(report_path)
		end)

		nio_tests.it("creates output with counts and failed test list", function()
			local report_data = {
				{
					SuitePath = "/test/example_test.go",
					SuiteSucceeded = false,
					SpecReports = {
						{
							LeafNodeType = "It",
							LeafNodeText = "passing test",
							State = "passed",
							LeafNodeLocation = {
								FileName = "/test/example_test.go",
								LineNumber = 10,
							},
							ContainerHierarchyTexts = { "Test Suite" },
							CapturedGinkgoWriterOutput = "output",
						},
						{
							LeafNodeType = "It",
							LeafNodeText = "failing test",
							State = "failed",
							LeafNodeLocation = {
								FileName = "/test/example_test.go",
								LineNumber = 20,
							},
							ContainerHierarchyTexts = { "Test Suite" },
							Failure = {
								Message = "Expected true to be false",
								FailureNodeType = "It",
								FailureNodeLocation = {
									FileName = "/test/example_test.go",
									LineNumber = 21,
								},
								Location = {
									FileName = "/test/example_test.go",
									LineNumber = 22,
									FullStackTrace = "stack",
								},
							},
							CapturedGinkgoWriterOutput = "",
						},
						{
							LeafNodeType = "It",
							LeafNodeText = "skipped test",
							State = "pending",
							LeafNodeLocation = {
								FileName = "/test/example_test.go",
								LineNumber = 30,
							},
							ContainerHierarchyTexts = { "Test Suite" },
							CapturedGinkgoWriterOutput = "",
						},
					},
				},
			}

			local report_path = create_temp_report(report_data)
			local spec = create_mock_spec(report_path)

			local results = report.parse(spec, {}, nil)

			assert.is_not_nil(results)

			-- Check namespace output content
			local namespace_id = '/test/example_test.go::"Test Suite"'
			assert.is_not_nil(results[namespace_id])
			assert.is_string(results[namespace_id].output)

			-- Read output file and verify content
			local output_text = lib.files.read(results[namespace_id].output)

			-- Should have Ginkgo-style format
			assert.is_true(output_text:match("FAILED!") ~= nil, "Expected 'FAILED!' status")
			assert.is_true(output_text:match("Passed") ~= nil, "Expected 'Passed' count")
			assert.is_true(output_text:match("Failed") ~= nil, "Expected 'Failed' count")
			assert.is_true(output_text:match("Skipped") ~= nil, "Expected 'Skipped' count")

			-- Should list failed test
			assert.is_true(output_text:match("Failed tests:") ~= nil, "Expected 'Failed tests:' section")
			assert.is_true(output_text:match("failing test") ~= nil, "Expected failing test in output")

			-- Cleanup
			async.fn.delete(report_path)
		end)

		nio_tests.it("handles deeply nested namespace hierarchy", function()
			local report_data = {
				{
					SuitePath = "/test/example_test.go",
					SuiteSucceeded = true,
					SpecReports = {
						{
							LeafNodeType = "It",
							LeafNodeText = "deeply nested test",
							State = "passed",
							LeafNodeLocation = {
								FileName = "/test/example_test.go",
								LineNumber = 25,
							},
							ContainerHierarchyTexts = { "Level 1", "Level 2", "Level 3" },
							CapturedGinkgoWriterOutput = "output",
						},
					},
				},
			}

			local report_path = create_temp_report(report_data)
			local spec = create_mock_spec(report_path)

			local results = report.parse(spec, {}, nil)

			assert.is_not_nil(results)

			-- Should have all three namespace levels
			local level1_id = '/test/example_test.go::"Level 1"'
			local level2_id = '/test/example_test.go::"Level 1"::"Level 2"'
			local level3_id = '/test/example_test.go::"Level 1"::"Level 2"::"Level 3"'

			assert.is_not_nil(results[level1_id], "Expected Level 1 namespace")
			assert.is_not_nil(results[level2_id], "Expected Level 2 namespace")
			assert.is_not_nil(results[level3_id], "Expected Level 3 namespace")

			-- All should have passed status
			assert.are.equal("passed", results[level1_id].status)
			assert.are.equal("passed", results[level2_id].status)
			assert.are.equal("passed", results[level3_id].status)

			-- Cleanup
			async.fn.delete(report_path)
		end)

		nio_tests.it("works with real calculator report structure", function()
			-- Using actual Ginkgo report structure from calculator demo
			local report_data = {
				{
					SuitePath = "/demo/calculator/calculator_test.go",
					SuiteSucceeded = true,
					SpecReports = {
						{
							LeafNodeType = "It",
							LeafNodeText = "should return the correct sum",
							State = "passed",
							LeafNodeLocation = {
								FileName = "/demo/calculator/calculator_test.go",
								LineNumber = 22,
							},
							ContainerHierarchyTexts = { "Calculator", "Addition", "with positive numbers" },
							CapturedGinkgoWriterOutput = "",
						},
						{
							LeafNodeType = "It",
							LeafNodeText = "should handle large numbers",
							State = "passed",
							LeafNodeLocation = {
								FileName = "/demo/calculator/calculator_test.go",
								LineNumber = 27,
							},
							ContainerHierarchyTexts = { "Calculator", "Addition", "with positive numbers" },
							CapturedGinkgoWriterOutput = "",
						},
						{
							LeafNodeType = "It",
							LeafNodeText = "should return the correct sum",
							State = "passed",
							LeafNodeLocation = {
								FileName = "/demo/calculator/calculator_test.go",
								LineNumber = 35,
							},
							ContainerHierarchyTexts = { "Calculator", "Addition", "with negative numbers" },
							CapturedGinkgoWriterOutput = "",
						},
						{
							LeafNodeType = "It",
							LeafNodeText = "should support floating point operations",
							State = "pending",
							LeafNodeLocation = {
								FileName = "/demo/calculator/calculator_test.go",
								LineNumber = 144,
							},
							ContainerHierarchyTexts = { "Calculator", "Future Features" },
						},
					},
				},
			}

			local report_path = create_temp_report(report_data)
			local spec = create_mock_spec(report_path)

			local results = report.parse(spec, {}, nil)

			assert.is_not_nil(results)

			-- Verify nested namespace structure
			local calc_id = '/demo/calculator/calculator_test.go::"Calculator"'
			local addition_id = '/demo/calculator/calculator_test.go::"Calculator"::"Addition"'
			local positive_id =
				'/demo/calculator/calculator_test.go::"Calculator"::"Addition"::"with positive numbers"'
			local negative_id =
				'/demo/calculator/calculator_test.go::"Calculator"::"Addition"::"with negative numbers"'
			local future_id = '/demo/calculator/calculator_test.go::"Calculator"::"Future Features"'

			-- All namespaces should exist
			assert.is_not_nil(results[calc_id], "Expected Calculator namespace")
			assert.is_not_nil(results[addition_id], "Expected Addition namespace")
			assert.is_not_nil(results[positive_id], "Expected positive numbers namespace")
			assert.is_not_nil(results[negative_id], "Expected negative numbers namespace")
			assert.is_not_nil(results[future_id], "Expected Future Features namespace")

			-- Check status aggregation
			assert.are.equal("passed", results[calc_id].status) -- Has passed tests
			assert.are.equal("passed", results[addition_id].status) -- All passed
			assert.are.equal("passed", results[positive_id].status) -- 2 passed
			assert.are.equal("passed", results[negative_id].status) -- 1 passed
			assert.are.equal("skipped", results[future_id].status) -- 1 pending

			-- Verify output files exist
			assert.is_string(results[calc_id].output)
			assert.is_string(results[addition_id].output)

			-- Cleanup
			async.fn.delete(report_path)
		end)
	end)
end)
