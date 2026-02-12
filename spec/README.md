# Tests

This directory contains integration tests for nvim-ginkgo using plenary.nvim's test framework.

## Prerequisites

The following Neovim plugins must be installed:
- nvim-nio
- nvim-treesitter (with Go parser installed)
- plenary.nvim
- neotest

## Running Tests

From the project root:

```bash
make test
```

Or directly with nvim:

```bash
nvim --headless --noplugin -u tests/setup.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/setup.lua'}"
```

## Test Structure

- `tests/tree_spec.lua` - Tests for the tree.lua module (TreeSitter query parsing)
- `tests/fixtures/` - Test fixture files (Go test files)
- `tests/helpers/` - Test helper utilities

## Writing Tests

Tests use the `nio.tests` wrapper for async support:

```lua
local nio_tests = require("nio.tests")

describe("my test suite", function()
  nio_tests.it("test case", function()
    -- Your async test code here
  end)
end)
```

## Test Coverage

Current test coverage:
- ✅ Simple Describe/It structures
- ✅ DescribeTableSubtree support
- ✅ Nested contexts (Context, When)
- ✅ Focus variants (FDescribe, FIt)
- ✅ Pending variants (PDescribe, PIt)
- ✅ Specify keyword
- ✅ Error handling (non-existent files)

Known limitations (documented in tree.lua):
- ⚠️ Entry nodes are not detected (neotest limitation)
