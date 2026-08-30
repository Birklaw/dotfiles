-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua

-- Terminal-first over SSH/tmux: use OSC52 so yanks reach the local clipboard
-- even inside devcontainers (Neovim >= 0.10 has built-in OSC52 support).
vim.opt.clipboard = "unnamedplus"
