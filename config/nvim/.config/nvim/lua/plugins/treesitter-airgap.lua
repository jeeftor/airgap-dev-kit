return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = false, -- Parsers are compiled by the connected kit builder.
    opts = function(_, opts)
      -- Keep highlighting/folding; never download missing parsers at startup.
      opts.ensure_installed = {}
    end,
  },
}
