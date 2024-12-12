return {
  {
    "nvim-neotest/neotest",
    optional = true,
    dependencies = {
      "nvim-neotest/neotest-jest",
      -- "markemmons/neotest-deno",
    },
    opts = function(_, opts)
      if not opts.adapters then opts.adapters = {} end
      table.insert(opts.adapters, require "neotest-jest"(require("astrocore").plugin_opts "neotest-jest"))
      -- table.insert(opts.adapters, require "neotest-deno" (require("astrocore").plugin_opts "neotest-deno"))
    end,
  },
}
