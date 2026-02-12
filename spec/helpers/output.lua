-- Helper functions for output spec tests

local M = {}

---Create a mock spec item for testing output formatting
---@param state string Test state (passed, failed, pending, etc.)
---@param has_failure boolean Whether to include failure info
---@return table Mock spec item
function M.create_mock_spec(state, has_failure)
	local spec = {
		LeafNodeType = "It",
		LeafNodeText = "should do something",
		State = state,
		LeafNodeLocation = {
			FileName = "/test/example_test.go",
			LineNumber = 42,
		},
		ContainerHierarchyTexts = { "Describe Feature", "Context Scenario" },
		CapturedGinkgoWriterOutput = "Test output\nLine 2",
	}

	if has_failure then
		spec.Failure = {
			Message = "Expected false\n  to be true",
			FailureNodeType = "It",
			FailureNodeLocation = {
				FileName = "/test/example_test.go",
				LineNumber = 43,
			},
			Location = {
				FileName = "/test/example_test.go",
				LineNumber = 44,
				FullStackTrace = "goroutine 1:\nstack trace here",
			},
		}
	end

	return spec
end

return M
