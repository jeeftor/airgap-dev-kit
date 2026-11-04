return {
  {
    "saghen/blink.cmp",
    -- Use the bundled Lua matcher instead of downloading a native library.
    opts = { fuzzy = { implementation = "lua" } },
  },
  {
    "stevearc/conform.nvim",
    opts = {
      -- Installing a Mason formatter alone does not connect it to Conform.
      formatters_by_ft = {
        javascript = { "prettier" },
        javascriptreact = { "prettier" },
        typescript = { "prettier" },
        typescriptreact = { "prettier" },
        json = { "prettier" },
        jsonc = { "prettier" },
        yaml = { "prettier" },
        markdown = { "prettier" },
        html = { "prettier" },
        css = { "prettier" },
      },
    },
  },
}
