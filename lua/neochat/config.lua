local M = {}

local function get_root_dir()
    local str = debug.getinfo(1, 'S').source:sub(2)
    -- lua/neochat/config.lua
    return vim.fn.fnamemodify(str, ':h:h:h')
end

local default_options = {
    python_exepath = vim.fn.exepath('python') or vim.fn.exepath('python3'),
}

function M.setup(opts)
    opts = opts or {}
    local options = vim.tbl_deep_extend('force', default_options, opts)

    options.cwd = get_root_dir()

    M.options = options
end

return M
