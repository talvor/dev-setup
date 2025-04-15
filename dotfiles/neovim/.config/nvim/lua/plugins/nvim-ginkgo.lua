return {
  "nvim-neotest/neotest",
  optional = true,
  dependencies = { "nvim-contrib/nvim-ginkgo", config = function() end },
  opts = function(_, opts)
    if not opts.adapters then opts.adapters = {} end
    table.insert(opts.adapters, require "nvim-ginkgo")
  end,
}
