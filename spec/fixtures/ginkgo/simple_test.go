package simple_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Simple Test", func() {
	It("passes", func() {
		Expect(true).To(BeTrue())
	})
})
