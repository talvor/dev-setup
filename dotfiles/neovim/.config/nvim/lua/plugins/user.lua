---@type LazySpec
return {
  {
    "catppuccin",
    opts = {
      flavor = "frappe",
      transparent_background = true,
    },
  },
  -- {
  --   "AlexvZyl/nordic.nvim",
  --   opts = {
  --     transparent = {
  --       -- Enable transparent background.
  --       bg = true,
  --       -- Enable transparent background for floating windows.
  --       float = true,
  --     },
  --   },
  -- },
  {
    "abidibo/nvim-httpyac",
    -- lazy = true,
    dependencies = {
      {
        "AstroNvim/astroui",
        opts = {
          icons = {
            WebRequest = "󱞑",
          },
        },
      },
      {
        "AstroNvim/astrocore",
        opts = function(_, opts)
          local maps = opts.mappings

          local prefix = "<Leader>H"

          maps.n[prefix] = { desc = require("astroui").get_icon("WebRequest", 1, true) .. "HTTPYac" }
          maps.n[prefix .. "r"] = {
            "<cmd>:NvimHttpYac<CR>",
            desc = "Run request",
          }
          maps.n[prefix .. "a"] = {
            "<cmd>:NvimHttpYacAll<CR>",
            desc = "Run all requests",
          }
        end,
      },
    },
    config = function()
      require("nvim-httpyac").setup {
        default = {
          headers = {
            ["User-Agent"] = "httpyac",
          },
        },
      }
    end,
  },
}
