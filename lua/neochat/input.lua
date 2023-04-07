local Popup = require('nui.popup')

local Input = Popup:extend('NeoChatInput')

---@param popup_opts table
---@param opts table | nil
function Input:init(popup_opts, opts)
    Input.super.init(self, popup_opts)

    opts = opts or {}
end

function Input:clear()
    vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, {})
end

function Input:focus()
    vim.api.nvim_set_current_win(self.winid)
end

---@param input string | string[]
function Input:set_text(input)
    input = type(input) == 'table' and input or { input }
    vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, input)
end

---@return string[] | nil
function Input:get_text()
    local lines = vim.api.nvim_buf_get_lines(self.bufnr, 0, -1, false)
    if not lines or lines[1] == '' then
        return
    end

    return lines
end

---@return string[] | nil
function Input:submit()
    local lines = self:get_text()
    self:clear()
    return lines
end

return Input
