return {
  "mfussenegger/nvim-dap",
  opts = function()
    local dap = require("dap")

    dap.configurations["typescript"] = {
      {
        type = "pwa-node",
        request = "launch",
        name = "Launch file",
        program = "${file}",
        cwd = "${workspaceFolder}",
        runtimeArgs = { "-r", "ts-node/register" },
        runtimeExecutable = "node",
        args = { "--inspect", "${file}" },
        skipFiles = { "node_modules/**" },
        console = "integratedTerminal",
      },
      {
        type = "pwa-node",
        request = "attach",
        name = "Attach",
        processId = require("dap.utils").pick_process,
        cwd = "${workspaceFolder}",
      },
    }
  end,
}
