package table_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = DescribeTableSubtree("Math Operations",
	func(a, b, expected int) {
		It("adds correctly", func() {
			Expect(a + b).To(Equal(expected))
		})

		It("subtracts correctly", func() {
			Expect(a - b).To(Equal(a - b))
		})
	},
	Entry("small numbers", 1, 2, 3),
	Entry("large numbers", 100, 200, 300),
	Entry("negative numbers", -1, -2, -3),
)
