local M = {
  icons = {
    ActiveLSP = "",
    ActiveTS = "",
    ArrowLeft = "",
    ArrowRight = "",
    Bookmarks = "",
    BufferClose = "󰅖",
    DapBreakpoint = "",
    DapBreakpointCondition = "",
    DapBreakpointRejected = "",
    DapLogPoint = "󰛿",
    DapStopped = "󰁕",
    Debugger = "",
    DefaultFile = "󰈙",
    Diagnostic = "󰒡",
    DiagnosticError = "",
    DiagnosticHint = "󰌵",
    DiagnosticInfo = "󰋼",
    DiagnosticWarn = "",
    Ellipsis = "…",
    Environment = "",
    FileNew = "",
    FileModified = "",
    FileReadOnly = "",
    FoldClosed = "",
    FoldOpened = "",
    FoldSeparator = " ",
    FolderClosed = "",
    FolderEmpty = "",
    FolderOpen = "",
    Git = "󰊢",
    GitAdd = "",
    GitBranch = "",
    GitChange = "",
    GitConflict = "",
    GitDelete = "",
    GitIgnored = "◌",
    GitRenamed = "➜",
    GitSign = "▎",
    GitStaged = "✓",
    GitUnstaged = "✗",
    GitUntracked = "★",
    List = "",
    LSPLoading1 = "",
    LSPLoading2 = "󰀚",
    LSPLoading3 = "",
    MacroRecording = "",
    Package = "󰏖",
    Paste = "󰅌",
    Refresh = "",
    Search = "",
    Selected = "❯",
    Session = "󱂬",
    Sort = "󰒺",
    Spellcheck = "󰓆",
    Tab = "󰓩",
    TabClose = "󰅙",
    Terminal = "",
    WebRequest = "󱞑",
    Window = "",
    WordFile = "󰈭",
  },
}

--- Get an icon from the internal icons if it is available and return it
---@param kind string The kind of icon in icons to retrieve
---@param padding? integer Padding to add to the end of the icon
---@return string icon
function M.get_icon(kind, padding)
  local icon = M.icons[kind]
  -- print("Icon: " .. kind .. " = " .. (icon or "nil"))
  return icon and icon .. (" "):rep(padding or 0) or ""
end

return M
