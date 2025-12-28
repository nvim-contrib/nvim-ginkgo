-- Minimal init for running tests
local plenary_dir = os.getenv("PLENARY_DIR") or "/tmp/plenary.nvim"
local neotest_dir = os.getenv("NEOTEST_DIR") or "/tmp/neotest"

-- Clone plenary if not present
if vim.fn.isdirectory(plenary_dir) == 0 then
	vim.fn.system({ "git", "clone", "https://github.com/nvim-lua/plenary.nvim", plenary_dir })
end

-- Clone neotest if not present (for type definitions)
if vim.fn.isdirectory(neotest_dir) == 0 then
	vim.fn.system({ "git", "clone", "https://github.com/nvim-neotest/neotest", neotest_dir })
end

-- Add to runtime path
vim.opt.rtp:append(".")
vim.opt.rtp:append(plenary_dir)
vim.opt.rtp:append(neotest_dir)

-- Load plenary
require("plenary.busted")
