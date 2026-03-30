-- Bootstrap for the plenary-based test suite.
-- Run via: nvim --headless -u test/minimal_init.lua -c "PlenaryBustedDirectory test/ {sequential=true}"
local data = vim.fn.stdpath("data")

-- Test dependencies from the user's nvim opt pack.
vim.opt.rtp:prepend(data .. "/site/pack/core/opt/plenary.nvim")
vim.opt.rtp:prepend(data .. "/site/pack/core/opt/luassert")

-- The plugin under test (loaded from the repo root).
vim.opt.rtp:prepend(vim.fn.getcwd())
