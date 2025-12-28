# nvim-ginkgo

A [Neotest](https://github.com/nvim-neotest/neotest) adapter for the
[Ginkgo](https://github.com/onsi/ginkgo) testing framework.

## Requirements

- Neovim >= 0.9.0
- [neotest](https://github.com/nvim-neotest/neotest)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- [Ginkgo CLI](https://github.com/onsi/ginkgo) v2
- (Optional) [nvim-dap](https://github.com/mfussenegger/nvim-dap) and [nvim-dap-go](https://github.com/leoluz/nvim-dap-go) for debugging

### Ginkgo CLI

The plugin automatically tries `go tool ginkgo` first (requires Go 1.24+ with ginkgo in go.mod),
then falls back to the globally installed `ginkgo` command.

**Option 1: Add to go.mod (recommended)**

```bash
go get github.com/onsi/ginkgo/v2/ginkgo
```

**Option 2: Install globally**

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

      -- Fallback ginkgo binary (plugin tries "go tool ginkgo" first)
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
| `ginkgo_cmd` | `string` | `"ginkgo"` | Fallback ginkgo binary (plugin tries `go tool ginkgo` first) |
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
