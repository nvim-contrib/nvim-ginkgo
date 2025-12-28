local watch = require("nvim-ginkgo.watch")

describe("nvim-ginkgo.watch", function()
	after_each(function()
		-- clean up any active watches
		watch.stop_all()
	end)

	describe("default_cmd", function()
		it("defaults to ginkgo", function()
			assert.equals("ginkgo", watch.default_cmd)
		end)

		it("can be overridden", function()
			watch.default_cmd = "/custom/ginkgo"
			assert.equals("/custom/ginkgo", watch.default_cmd)
			watch.default_cmd = "ginkgo" -- reset
		end)
	end)

	describe("is_watching", function()
		it("returns false for unwatched directory", function()
			assert.is_false(watch.is_watching("/some/random/directory"))
		end)
	end)

	describe("get_active_watches", function()
		it("returns empty table when no watches active", function()
			local watches = watch.get_active_watches()
			assert.is_table(watches)
			assert.equals(0, #watches)
		end)
	end)

	describe("stop", function()
		it("handles non-existent watch gracefully", function()
			-- should not error
			watch.stop("/non/existent/directory")
		end)
	end)

	describe("stop_all", function()
		it("handles empty watches gracefully", function()
			-- should not error
			watch.stop_all()
		end)
	end)
end)
