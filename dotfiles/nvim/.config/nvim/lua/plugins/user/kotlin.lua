return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- kotlin_lsp = {},
        kotlin_language_server = {},
      },
    },
  },
  {
    "nvim-neotest/neotest",
    optional = true,
    dependencies = {
      "codymikol/neotest-kotlin",
    },
    opts = {
      adapters = {
        ["neotest-kotlin"] = {},
      },
    },
  },
  {
    "mfussenegger/nvim-dap",
    optional = true,
    dependencies = "mason-org/mason.nvim",
    opts = function()
      local dap = require("dap")
      if not dap.adapters.kotlin then
        dap.adapters.kotlin = {
          type = "executable",
          command = "kotlin-debug-adapter",
          options = { auto_continue_if_many_stopped = false },
        }
      end

      dap.configurations.kotlin = {
        {
          type = "kotlin",
          request = "launch",
          name = "This file",
          -- may differ, when in doubt, whatever your project structure may be,
          -- it has to correspond to the class file located at `build/classes/`
          -- and of course you have to build before you debug
          mainClass = function()
            local remove_prefix = function(str, prefix)
              if str:sub(1, #prefix) == prefix then
                return str:sub(#prefix + 1)
              else
                return str
              end
            end

            -- local root = vim.fs.find("src", { path = vim.uv.cwd(), upward = true, stop = vim.env.HOME })[1] or ""
            local root = vim.fs.find("src", {
              path = vim.fs.dirname(vim.api.nvim_buf_get_name(0)),
              upward = true,
              stop = vim.env.HOME,
            })[1] or ""
            local fname = vim.api.nvim_buf_get_name(0)

            -- /main/kotlin/ seems to be the standard structure for a kotlin project
            -- created with "gradle init"
            local class = remove_prefix(fname, root .. "/main/kotlin/"):gsub(".kt", "Kt"):gsub("/", ".")
            return class
          end,
          projectRoot = "${workspaceFolder}/app/",
          jsonLogFile = "",
          enableJsonLogging = false,
        },
        {
          -- Use this for unit tests
          -- First, run
          -- ./gradlew --info cleanTest test --debug-jvm
          -- then attach the debugger to it
          type = "kotlin",
          request = "attach",
          name = "Attach to debugging session",
          port = 5005,
          args = {},
          projectRoot = vim.fn.getcwd,
          hostName = "localhost",
          timeout = 2000,
        },
      }
    end,
  },
}
