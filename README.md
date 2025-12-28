# nvim-ginkgo

A [Neotest](https://github.com/nvim-neotest/neotest) adapter for the
[Ginkgo](https://github.com/onsi/ginkgo) testing framework.

## Requirements

- Neovim >= 0.9.0
- [neotest](https://github.com/nvim-neotest/neotest)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- [Ginkgo CLI](https://github.com/onsi/ginkgo) v2

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

## Features

- Discover and run Ginkgo tests directly from Neovim
- Support for all Ginkgo test types: `Describe`, `Context`, `When`, `It`, `Specify`, `Entry`
- Support for focused (`F*`) and pending (`P*`, `X*`) tests
- Automatic build tag detection from test files
- Detailed test output with color-coded results
- Suite-level result summaries
- Automatic cleanup of temporary files

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
