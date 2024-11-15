-- AstroCommunity: import any community modules here
-- We import this file in `lazy_setup.lua` before the `plugins/` folder.
-- This guarantees that the specs are processed before any user plugins.

---@type LazySpec
return {
  "AstroNvim/astrocommunity",
  { import = "astrocommunity.colorscheme.catppuccin" },

  { import = "astrocommunity.lsp.lsp-lens-nvim" },
  { import = "astrocommunity.lsp.lsp-signature-nvim" },

  { import = "astrocommunity.pack.go" },
  { import = "astrocommunity.pack.lua" },
  { import = "astrocommunity.pack.python" },
  { import = "astrocommunity.pack.typescript" },

  { import = "astrocommunity.test.neotest" },
}
