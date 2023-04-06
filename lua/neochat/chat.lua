local Popup = require('nui.popup')
local Layout = require('nui.layout')
local event = require('nui.utils.autocmd').event

local config = require('neochat.config')
local prompts = require('neochat.prompts')
local Conversation = require('neochat.conversation')

local Chat = {}

local function create_popup_conversation()
    return Conversation({
        border = {
            style = 'rounded',
            text = {
                top = '[Conversation]',
                top_align = 'center',
            },
        },
        buf_options = {
            filetype = 'markdown',
        },
        win_options = {
            wrap = true,
            conceallevel = 1,
        },
    })
end

local function create_popup_input()
    return Popup({
        border = {
            style = 'rounded',
            text = {
                top = '[Input]',
                top_align = 'center',
                bottom = '<CR>: submit, <S-CR>: add newline, <C-CR>: new chat',
                bottom_align = 'center',
            },
        },
        enter = true,
        buf_options = {
            filetype = 'markdown',
        },
        win_options = {
            wrap = true,
        },
    })
end

local function create_layout(popup_conversation, popup_input)
    return Layout(
        config.options.layout_opts,
        Layout.Box({
            Layout.Box(popup_conversation, config.options.layout_box.conversation_opts),
            Layout.Box(popup_input, config.options.layout_box.input_opts),
        }, config.options.layout_box.opts)
    )
end

function Chat.new()
    local popup_conversation = create_popup_conversation()
    local popup_input = create_popup_input()
    local layout = create_layout(popup_conversation, popup_input)

    local chat = setmetatable({
        hidden = false,
        layout = layout,
        popup_conversation = popup_conversation,
        popup_input = popup_input,
        messages = {},
    }, { __index = Chat })

    chat:init()
    layout:mount()

    return chat
end

function Chat:init()
    self.popup_input:on({ event.BufWinEnter }, function()
        vim.cmd('startinsert')
    end, { once = true })

    if config.options.openai.actas.enable then
        self.popup_input:on({ event.TextChangedI }, function()
            local lines = vim.api.nvim_buf_get_lines(self.popup_input.bufnr, 0, 1, false)
            if lines and #lines == 1 and lines[1] == config.options.openai.actas.keyword then
                vim.schedule(function()
                    self:pick_prompts()
                end)
            end
        end)
    end

    self.popup_input:map('i', '<S-CR>', function()
        vim.api.nvim_feedkeys('\n', 'i', true)
    end, { noremap = true })
    self.popup_input:map('i', '<C-CR>', function()
        self:clear()
    end, { noremap = true })
    self.popup_input:map('i', '<CR>', function()
        self:on_submit()
    end, { noremap = false })

    self.popup_input:map('n', '<Up>', function()
        -- focus on conversation
        self.popup_conversation:focus()
    end, { noremap = false })

    self.popup_conversation:map('n', '<Down>', function()
        -- focus on input
        vim.api.nvim_set_current_win(self.popup_input.winid)
    end, { noremap = false })

    self.popup_input:map('n', '<Tab>', function()
        -- focus on conversation
        self.popup_conversation:focus()
    end, { noremap = false })

    self.popup_conversation:map('n', '<Tab>', function()
        -- focus on input
        vim.api.nvim_set_current_win(self.popup_input.winid)
    end, { noremap = false })

    self.popup_input:map('i', '<C-d>', function()
        self.popup_conversation:scroll(5)
    end, { noremap = false })

    self.popup_input:map('i', '<C-u>', function()
        self.popup_conversation:scroll(-5)
    end, { noremap = false })
end

function Chat:toggle()
    if self.hidden then
        self.layout:show()
    else
        self.layout:hide()
    end
    self.hidden = not self.hidden
end

function Chat:clear()
    self.popup_conversation:clear()

    vim.api.nvim_buf_set_lines(self.popup_input.bufnr, 0, -1, false, {})
end

function Chat:clear_input()
    vim.api.nvim_buf_set_lines(self.popup_input.bufnr, 0, -1, false, {})
end

function Chat:get_input()
    local lines = vim.api.nvim_buf_get_lines(self.popup_input.bufnr, 0, -1, false)
    return lines
end

function Chat:on_submit()
    local lines = self:get_input()
    if not lines or lines[1] == '' then
        return
    end

    -- clear input
    self:clear_input()

    local input = lines
    self.popup_conversation:ask(input)
end

function Chat:pick_prompts()
    prompts.pick(function(prompt)
        vim.api.nvim_buf_set_lines(self.popup_input.bufnr, 0, -1, false, { prompt.content })
    end)
end

function Chat:mounted()
    return self.layout._.mounted
end

return Chat
