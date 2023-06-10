# nvim-ginkgo

This plugin provides a [ginkgo](https://github.com/onsi/ginkgo) adapter for the [Neotest](https://github.com/nvim-neotest/neotest) framework.

## :package: Installation

Install with the package manager of your choice:

**Lazy**

```lua
{
  "nvim-neotest/neotest",
  lazy = true,
  dependencies = {
    "nvim-extensions/nvim-ginkgo",
  },
  config = function()
    require("neotest").setup({
      ...,
      adapters = {
        require("nvim-ginkgo")
      },
    }
  end
}
```

## :warning: Notice

This project is still in the early stages of development. Please use it on your own risk.
