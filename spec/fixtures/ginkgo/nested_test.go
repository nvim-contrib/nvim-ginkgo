package nested_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Nested Structures", func() {
	Context("outer context", func() {
		It("test in outer", func() {
			Expect(true).To(BeTrue())
		})

		When("something happens", func() {
			It("test in when", func() {
				Expect(1).To(Equal(1))
			})

			Context("inner context", func() {
				It("test in inner", func() {
					Expect("test").To(Equal("test"))
				})
			})
		})
	})
})
