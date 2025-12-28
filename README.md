# nvim-ginkgo

A [Neotest](https://github.com/nvim-neotest/neotest) adapter for the
[Ginkgo](https://github.com/onsi/ginkgo) testing framework.

## Requirements

- Neovim >= 0.9.0
- [neotest](https://github.com/nvim-neotest/neotest)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- [Ginkgo CLI](https://github.com/onsi/ginkgo) v2
- (Optional) [nvim-dap](https://github.com/mfussenegger/nvim-dap) and [nvim-dap-go](https://github.com/leoluz/nvim-dap-go) for debugging

Install Ginkgo CLI:

```bash
go install github.com/onsi/ginkgo/v2/ginkgo@latest
```

## Installation

Install with the package manager of your choice:

### lazy.nvim

```lua
{
  "nvim-neotest/neotest",
  lazy = true,
  dependencies = {
    "nvim-contrib/nvim-ginkgo",
  },
  config = function()
    require("neotest").setup({
      adapters = {
        require("nvim-ginkgo")(),
      },
    })
  end
}
```

## Configuration

The adapter accepts the following configuration options:

```lua
require("neotest").setup({
  adapters = {
    require("nvim-ginkgo")({
      -- Extra arguments to pass to ginkgo (default: {})
      args = { "--fail-fast" },

      -- Directories to exclude from test discovery (default: {})
      -- Note: "vendor" is always excluded
      exclude_dirs = { "testdata", "fixtures" },

      -- Enable race detection (default: false)
      race = true,

      -- Ginkgo v2 label filter expression (default: nil)
      label_filter = "!slow",

      -- Test timeout (default: nil, uses ginkgo default)
      timeout = "5m",

      -- Path to ginkgo binary (default: "ginkgo")
      ginkgo_cmd = "/custom/path/ginkgo",

      -- Coverage options
      cover = true,                    -- Enable coverage (default: false)
      coverprofile = "coverage.out",   -- Coverage output file (default: nil)
      covermode = "atomic",            -- Coverage mode: set, count, atomic (default: nil)

      -- DAP (Debug Adapter Protocol) configuration
      dap = {
        adapter = "go",        -- DAP adapter name (default: "go")
        port = 40000,          -- Delve port (default: 40000)
        build_flags = {},      -- Extra build flags for go test -c
      },
    }),
  },
})
```

### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `args` | `string[]` | `{}` | Extra arguments passed to ginkgo on every run |
| `exclude_dirs` | `string[]` | `{}` | Directories to exclude from test discovery |
| `race` | `boolean` | `false` | Enable Go race detector (`--race`) |
| `label_filter` | `string` | `nil` | Ginkgo v2 label filter expression |
| `timeout` | `string` | `nil` | Test timeout (e.g., "60s", "5m") |
| `ginkgo_cmd` | `string` | `"ginkgo"` | Path to ginkgo binary |
| `cover` | `boolean` | `false` | Enable coverage collection |
| `coverprofile` | `string` | `nil` | Coverage profile output file |
| `covermode` | `string` | `nil` | Coverage mode: set, count, or atomic |
| `dap` | `table` | see above | DAP configuration for debugging |

## Features

- Discover and run Ginkgo tests directly from Neovim
- Support for all Ginkgo test types: `Describe`, `Context`, `When`, `It`, `Specify`, `Entry`
- Support for focused (`F*`) and pending (`P*`, `X*`) tests
- Automatic build tag detection from test files
- Detailed test output with color-coded results
- Suite-level result summaries
- Automatic cleanup of temporary files
- Debug tests with DAP (delve)
- Watch mode for continuous testing
- Coverage collection

## Debugging Tests

To debug tests, you need [nvim-dap](https://github.com/mfussenegger/nvim-dap) and
[nvim-dap-go](https://github.com/leoluz/nvim-dap-go) configured.

Run tests with the `dap` strategy:

```lua
require("neotest").run.run({ strategy = "dap" })
```

Or set up a keybinding:

```lua
vim.keymap.set("n", "<leader>td", function()
  require("neotest").run.run({ strategy = "dap" })
end, { desc = "Debug nearest test" })
```

## Watch Mode

nvim-ginkgo includes a watch mode that runs `ginkgo watch` in a terminal buffer.

### Basic Usage

```lua
local ginkgo = require("nvim-ginkgo")

-- Start watching a directory
ginkgo.watch.start("/path/to/your/package")

-- Start with options
ginkgo.watch.start("/path/to/your/package", {
  focus_file = "foo_test.go",           -- Focus on specific file
  focus_pattern = "should do something", -- Focus on specific test
  args = { "--fail-fast" },              -- Extra ginkgo args
  notify = true,                         -- Show notifications (default: true)
})

-- Stop watching
ginkgo.watch.stop("/path/to/your/package")

-- Stop all watches
ginkgo.watch.stop_all()

-- Toggle watch mode
ginkgo.watch.toggle("/path/to/your/package")

-- Check if watching
if ginkgo.watch.is_watching("/path/to/your/package") then
  -- ...
end

-- Get all active watches
local dirs = ginkgo.watch.get_active_watches()
```

### Example Keybindings

```lua
local ginkgo = require("nvim-ginkgo")

-- Toggle watch for current file's directory
vim.keymap.set("n", "<leader>tw", function()
  local dir = vim.fn.expand("%:p:h")
  ginkgo.watch.toggle(dir)
end, { desc = "Toggle Ginkgo watch" })

-- Stop all watches
vim.keymap.set("n", "<leader>tW", function()
  ginkgo.watch.stop_all()
end, { desc = "Stop all Ginkgo watches" })
```

## Coverage

Enable coverage collection in your config:

```lua
require("nvim-ginkgo")({
  cover = true,
  coverprofile = "coverage.out",
  covermode = "atomic",
})
```

After running tests, view coverage with Go tools:

```bash
go tool cover -html=coverage.out
```

Or integrate with [nvim-coverage](https://github.com/andythigpen/nvim-coverage) for in-editor display.

## Running Tests

This plugin includes a test suite. To run the tests:

```bash
make test
```

## Notice

This project is still in the early stages of development. Please use it at your
own risk.

## License

MIT
