-- Integration tests for tree.lua module
-- Tests only the public API (parse_positions)

---@diagnostic disable: undefined-field

local tree = require("nvim-ginkgo.tree")
local tree_helpers = dofile(vim.fn.getcwd() .. "/spec/helpers/tree.lua")
local fixtures = dofile(vim.fn.getcwd() .. "/spec/fixtures/init.lua")
local nio_tests = require("nio.tests")

describe("tree.parse_positions", function()
	nio_tests.it("detects simple Describe with It", function()
		local fixture = fixtures.path("ginkgo/simple_test.go")
		local result = tree.parse_positions(fixture)

		assert.is_not_nil(result)

		local root = result:data()
		assert.are.equal("file", root.type)

		-- Should have one Describe as child
		local children = result:children()
		assert.are.equal(1, #children)

		local describe = children[1]:data()
		assert.are.equal("namespace", describe.type)
		assert.are.equal('"Simple Test"', describe.name)

		-- Describe should have one It as child
		local describe_children = children[1]:children()
		assert.are.equal(1, #describe_children)

		local it_node = describe_children[1]:data()
		assert.are.equal("test", it_node.type)
		assert.are.equal('"passes"', it_node.name)
	end)

	nio_tests.it("handles DescribeTableSubtree with Entry", function()
		local fixture = fixtures.path("ginkgo/table_test.go")
		local result = tree.parse_positions(fixture)

		assert.is_not_nil(result)

		-- Find the DescribeTableSubtree
		local table_node = tree_helpers.find_position(result, '"Math Operations"')
		assert.is_not_nil(table_node)
		assert.are.equal("namespace", table_node.type)

		-- Should have test children (the It blocks inside DescribeTableSubtree)
		local adds_test = tree_helpers.find_position(result, '"adds correctly"')
		assert.is_not_nil(adds_test, "Should find 'adds correctly' test")
		assert.are.equal("test", adds_test.type)

		local subtracts_test = tree_helpers.find_position(result, '"subtracts correctly"')
		assert.is_not_nil(subtracts_test, "Should find 'subtracts correctly' test")
		assert.are.equal("test", subtracts_test.type)
	end)

	nio_tests.it("detects Entry nodes in DescribeTable as tests", function()
		local fixture = fixtures.path("ginkgo/describe_table_test.go")
		local result = tree.parse_positions(fixture)

		assert.is_not_nil(result)

		-- Find the outer Describe
		local describe = tree_helpers.find_position(result, '"Math Operations"')
		assert.is_not_nil(describe)
		assert.are.equal("namespace", describe.type)

		-- Find DescribeTable namespaces
		local addition_table = tree_helpers.find_position(result, '"Addition"')
		assert.is_not_nil(addition_table, "Should find 'Addition' DescribeTable")
		assert.are.equal("namespace", addition_table.type)

		local multiplication_table = tree_helpers.find_position(result, '"Multiplication"')
		assert.is_not_nil(multiplication_table, "Should find 'Multiplication' DescribeTable")
		assert.are.equal("namespace", multiplication_table.type)

		-- Find Entry nodes as tests under Addition
		local entry1 = tree_helpers.find_position(result, '"1 + 1 = 2"')
		assert.is_not_nil(entry1, "Should find Entry '1 + 1 = 2' as test")
		assert.are.equal("test", entry1.type)

		local entry2 = tree_helpers.find_position(result, '"2 + 3 = 5"')
		assert.is_not_nil(entry2, "Should find Entry '2 + 3 = 5' as test")
		assert.are.equal("test", entry2.type)

		local entry3 = tree_helpers.find_position(result, '"negative numbers"')
		assert.is_not_nil(entry3, "Should find Entry 'negative numbers' as test")
		assert.are.equal("test", entry3.type)

		-- Find Entry nodes as tests under Multiplication
		local entry4 = tree_helpers.find_position(result, '"2 * 3 = 6"')
		assert.is_not_nil(entry4, "Should find Entry '2 * 3 = 6' as test")
		assert.are.equal("test", entry4.type)

		local entry5 = tree_helpers.find_position(result, '"5 * 5 = 25"')
		assert.is_not_nil(entry5, "Should find Entry '5 * 5 = 25' as test")
		assert.are.equal("test", entry5.type)
	end)

	nio_tests.it("handles nested contexts", function()
		local fixture = fixtures.path("ginkgo/nested_test.go")
		local result = tree.parse_positions(fixture)

		assert.is_not_nil(result)

		-- Find outer Describe
		local describe = tree_helpers.find_position(result, '"Nested Structures"')
		assert.is_not_nil(describe)
		assert.are.equal("namespace", describe.type)

		-- Find outer Context
		local outer_context = tree_helpers.find_position(result, '"outer context"')
		assert.is_not_nil(outer_context)
		assert.are.equal("namespace", outer_context.type)

		-- Find test in outer context
		local outer_test = tree_helpers.find_position(result, '"test in outer"')
		assert.is_not_nil(outer_test)
		assert.are.equal("test", outer_test.type)

		-- Find When
		local when_node = tree_helpers.find_position(result, '"something happens"')
		assert.is_not_nil(when_node)
		assert.are.equal("namespace", when_node.type)

		-- Find test in When
		local when_test = tree_helpers.find_position(result, '"test in when"')
		assert.is_not_nil(when_test)
		assert.are.equal("test", when_test.type)

		-- Find inner Context
		local inner_context = tree_helpers.find_position(result, '"inner context"')
		assert.is_not_nil(inner_context)
		assert.are.equal("namespace", inner_context.type)

		-- Find test in inner context
		local inner_test = tree_helpers.find_position(result, '"test in inner"')
		assert.is_not_nil(inner_test)
		assert.are.equal("test", inner_test.type)
	end)

	nio_tests.it("returns nil for non-existent file", function()
		local result = tree.parse_positions("/nonexistent/file.go")
		assert.is_nil(result)
	end)

	nio_tests.it("detects focus variants (FDescribe, FIt)", function()
		-- Create a temporary fixture with focus variants
		local tmpfile = vim.fn.tempname() .. "_test.go"
		local content = [[
package focus_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = FDescribe("Focused Describe", func() {
	FIt("focused test", func() {
		Expect(true).To(BeTrue())
	})
})
]]
		vim.fn.writefile(vim.split(content, "\n"), tmpfile)

		local result = tree.parse_positions(tmpfile)
		assert.is_not_nil(result)

		-- Should detect FDescribe as namespace
		local fdescribe = tree_helpers.find_position(result, '"Focused Describe"')
		assert.is_not_nil(fdescribe)
		assert.are.equal("namespace", fdescribe.type)

		-- Should detect FIt as test
		local fit = tree_helpers.find_position(result, '"focused test"')
		assert.is_not_nil(fit)
		assert.are.equal("test", fit.type)

		-- Clean up
		vim.fn.delete(tmpfile)
	end)

	nio_tests.it("detects pending variants (PDescribe, PIt)", function()
		-- Create a temporary fixture with pending variants
		local tmpfile = vim.fn.tempname() .. "_test.go"
		local content = [[
package pending_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = PDescribe("Pending Describe", func() {
	PIt("pending test", func() {
		Expect(true).To(BeTrue())
	})
})
]]
		vim.fn.writefile(vim.split(content, "\n"), tmpfile)

		local result = tree.parse_positions(tmpfile)
		assert.is_not_nil(result)

		-- Should detect PDescribe as namespace
		local pdescribe = tree_helpers.find_position(result, '"Pending Describe"')
		assert.is_not_nil(pdescribe)
		assert.are.equal("namespace", pdescribe.type)

		-- Should detect PIt as test
		local pit = tree_helpers.find_position(result, '"pending test"')
		assert.is_not_nil(pit)
		assert.are.equal("test", pit.type)

		-- Clean up
		vim.fn.delete(tmpfile)
	end)

	nio_tests.it("detects Specify as test", function()
		-- Create a temporary fixture with Specify
		local tmpfile = vim.fn.tempname() .. "_test.go"
		local content = [[
package specify_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Test with Specify", func() {
	Specify("something specific", func() {
		Expect(true).To(BeTrue())
	})
})
]]
		vim.fn.writefile(vim.split(content, "\n"), tmpfile)

		local result = tree.parse_positions(tmpfile)
		assert.is_not_nil(result)

		-- Should detect Specify as test
		local specify = tree_helpers.find_position(result, '"something specific"')
		assert.is_not_nil(specify)
		assert.are.equal("test", specify.type)

		-- Clean up
		vim.fn.delete(tmpfile)
	end)
end)
