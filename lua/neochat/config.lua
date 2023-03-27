local M = {}

local function get_root_dir()
	local str = debug.getinfo(2, "S").source:sub(2)
    -- lua/neochat/config.lua
    return vim.fn.fnamemodify(str, ":h:h:h")
end

local default_options = {
	cwd = get_root_dir(),
}

function M.setup(opts)
	opts = opts or {}
	M.options = vim.tbl_deep_extend("force", default_options, opts)
end

return M
