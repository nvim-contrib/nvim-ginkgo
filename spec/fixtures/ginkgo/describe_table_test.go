package ginkgo_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Math Operations", func() {
	DescribeTable("Addition",
		func(a, b, expected int) {
			Expect(a + b).To(Equal(expected))
		},
		Entry("1 + 1 = 2", 1, 1, 2),
		Entry("2 + 3 = 5", 2, 3, 5),
		Entry("negative numbers", -1, -2, -3),
	)

	DescribeTable("Multiplication",
		func(a, b, expected int) {
			Expect(a * b).To(Equal(expected))
		},
		Entry("2 * 3 = 6", 2, 3, 6),
		Entry("5 * 5 = 25", 5, 5, 25),
	)
})
