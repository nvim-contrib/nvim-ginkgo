-- Tests for report.lua module (test result parsing)

---@diagnostic disable: undefined-field

local nio_tests = require("nio.tests")
local report = require("nvim-ginkgo.report")
local async = require("neotest.async")

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
end)
