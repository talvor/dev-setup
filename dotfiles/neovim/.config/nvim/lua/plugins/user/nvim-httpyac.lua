return {
  {
    "abidibo/nvim-httpyac",
    event = "VeryLazy",
    opts = {},
    keys = {
      { "<leader>Hr", "<cmd>:NvimHttpYac<CR>", desc = "Run request" },
      { "<leader>Ha", "<cmd>:NvimHttpYacAll<CR>", desc = "Run all requests" },
    },
  },
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>H", group = "HTTPYac", icon = { icon = require("icons").get_icon("WebRequest") } },
      },
    },
  },
}
