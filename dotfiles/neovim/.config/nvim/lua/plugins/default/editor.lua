local get_icon = require("icons").get_icon

return {
  {
    "folke/which-key.nvim",
    opts = {
      preset = "modern",
    },
  },
  {
    "folke/snacks.nvim",
    opts = {
      explorer = {},
      picker = {
        icons = {
          git = {
            enabled = true, -- show git icons
            added = get_icon("GitAdd"),
            deleted = get_icon("GitDelete"),
            modified = get_icon("GitChange"),
            renamed = get_icon("GitRenamed"),
            untracked = get_icon("GitUntracked"),
            ignored = get_icon("GitIgnored"),
            unstaged = get_icon("GitUnstaged"),
            staged = get_icon("GitStaged"),
            conflict = get_icon("GitConflict"),
          },
        },
      },
    },
  },
}
