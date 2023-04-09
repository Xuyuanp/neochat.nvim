local M = {}

---@private
function M._set_hls()
    local function set_hl(name, val)
        vim.api.nvim_set_hl(M.ns_id, name, val)
    end

    set_hl('NeoChatUser', {
        default = true,
        fg = '#957fb8',
        bold = true,
    })
    set_hl('NeoChatBot', {
        default = true,
        fg = '#7e9cd8',
        bold = true,
    })

    set_hl('NeoChatResponseOk', {
        default = true,
        link = 'DiagnosticVirtualTextOk',
    })

    set_hl('NeoChatResponseError', {
        default = true,
        link = 'DiagnosticVirtualTextError',
    })
    set_hl('NeoChatResponsePending', {
        default = true,
        link = 'Comment',
    })

    set_hl('SignColumn', {
        bg = 'NONE',
    })
end

function M.setup()
    M.ns_id = vim.api.nvim_create_namespace('neochat-highlight')
    M.group_id = vim.api.nvim_create_augroup('neochat-highlight', { clear = true })

    M._set_hls()

    vim.api.nvim_create_autocmd('ColorScheme', {
        pattern = '*',
        group = M.group_id,
        desc = '[NeoChat] refresh highlights',
        callback = function()
            M._set_hls()
        end,
    })
end

function M.attach_window(winid)
    vim.api.nvim_win_set_hl_ns(winid, M.ns_id)
end

return M
