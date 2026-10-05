-- Air-gap LSP configuration
-- The connected builder installs the manifest's tools before packaging.
return {
  -- Mason still activates installed servers; target startup never installs tools.
  {
    "mason-org/mason-lspconfig.nvim",
    opts = function(_, opts)
      opts.ensure_installed = {}
    end,
  },

  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = {}
    end,
  },
}
