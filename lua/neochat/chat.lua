local Popup = require('nui.popup')
local Layout = require('nui.layout')
local event = require('nui.utils.autocmd').event
local NuiText = require('nui.text')
local config = require('neochat.config')
local prompts = require('neochat.prompts')

local api = require('neochat.api')

local function You()
    -- TODO: add highlight group
    return NuiText('#  @You:', 'Keyword')
end

local function ChatGPT()
    -- TODO: add highlight group
    return NuiText('# 󰚩 @ChatGPT:', 'Function')
end

local Chat = {}

function Chat.new()
    local popup_conversation = Popup({
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

    local popup_input = Popup({
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

    local layout = Layout(
        config.options.layout_opts,
        Layout.Box({
            Layout.Box(popup_conversation, config.options.layout_box.conversation_opts),
            Layout.Box(popup_input, config.options.layout_box.input_opts),
        }, config.options.layout_box.opts)
    )

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

    self.popup_input:map('i', '<S-CR>', '<ESC>o', { noremap = true })
    self.popup_input:map('i', '<C-CR>', function()
        self:clear()
    end, { noremap = true })
    self.popup_input:map('i', '<CR>', function()
        self:on_submit()
    end, { noremap = false })

    self.popup_input:map('n', '<Up>', function()
        -- focus on conversation
        vim.api.nvim_set_current_win(self.popup_conversation.winid)
    end, { noremap = false })

    self.popup_conversation:map('n', '<Down>', function()
        -- focus on input
        vim.api.nvim_set_current_win(self.popup_input.winid)
    end, { noremap = false })

    self.popup_input:map('n', '<Tab>', function()
        -- focus on conversation
        vim.api.nvim_set_current_win(self.popup_conversation.winid)
    end, { noremap = false })

    self.popup_conversation:map('n', '<Tab>', function()
        -- focus on input
        vim.api.nvim_set_current_win(self.popup_input.winid)
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
    self.messages = {}
    vim.api.nvim_buf_set_lines(self.popup_conversation.bufnr, 0, -1, false, {})
    vim.api.nvim_buf_set_lines(self.popup_input.bufnr, 0, -1, false, {})
end

function Chat:clear_input()
    vim.api.nvim_buf_set_lines(self.popup_input.bufnr, 0, -1, false, {})
end

function Chat:get_input()
    local lines = vim.api.nvim_buf_get_lines(self.popup_input.bufnr, 0, -1, false)
    return lines
end

---@param input string[]
function Chat:append_input(input)
    -- send to chat
    local line_count = vim.api.nvim_buf_line_count(self.popup_conversation.bufnr)
    You():render(self.popup_conversation.bufnr, -1, line_count, 0, line_count, 0)
    -- print input
    vim.api.nvim_buf_set_lines(self.popup_conversation.bufnr, -1, -1, false, input)
    -- add two new lines
    vim.api.nvim_buf_set_lines(self.popup_conversation.bufnr, -1, -1, false, { '', '' })

    -- move cursor to the end
    local line_count = vim.api.nvim_buf_line_count(self.popup_conversation.bufnr)
    vim.api.nvim_win_set_cursor(self.popup_conversation.winid, { line_count, 0 })

    table.insert(self.messages, {
        role = 'user',
        content = vim.fn.join(input, '\n'),
    })
end

function Chat:on_submit()
    local lines = self:get_input()
    if not lines or lines[1] == '' then
        return
    end

    -- clear input
    self:clear_input()

    self:append_input(lines)

    ---@diagnostic disable-next-line: param-type-mismatch
    vim.defer_fn(function()
        self:perform_request()
        ---@diagnostic disable-next-line: param-type-mismatch
    end, 800)
end

function Chat:perform_request()
    self.spinner_idx = 1
    local head_line = vim.api.nvim_buf_line_count(self.popup_conversation.bufnr)
    local chatgpt = ChatGPT()
    local head_len = chatgpt:content():len()
    chatgpt:render(self.popup_conversation.bufnr, -1, head_line, 0, head_line, 0)
    NuiText(' ', 'Function'):render(self.popup_conversation.bufnr, -1, head_line, head_len, head_line, head_len)
    NuiText(config.options.spinners[self.spinner_idx], 'Comment'):render_char(self.popup_conversation.bufnr, -1, head_line, head_len + 1)

    local timer = vim.loop.new_timer()
    assert(timer)
    timer:start(
        0,
        100,
        vim.schedule_wrap(function()
            self.spinner_idx = self.spinner_idx + 1
            if self.spinner_idx > #config.options.spinners then
                self.spinner_idx = 1
            end
            NuiText(config.options.spinners[self.spinner_idx], 'Comment'):render(self.popup_conversation.bufnr, -1, head_line, head_len + 1)
        end)
    )

    -- add newline
    vim.api.nvim_buf_set_lines(self.popup_conversation.bufnr, -1, -1, false, { '' })
    -- move cursor to the end
    local line_count = vim.api.nvim_buf_line_count(self.popup_conversation.bufnr)
    vim.api.nvim_win_set_cursor(self.popup_conversation.winid, { line_count, 0 })

    api.chat_completions(self.messages, {
        on_start = function() end,
        ---@diagnostic disable-next-line: unused-local
        on_exit = function(code, signal)
            timer:stop()
            vim.schedule(function()
                NuiText('', 'String'):render(self.popup_conversation.bufnr, -1, head_line, head_len + 1)
            end)
        end,
        on_stdout = function(err, data)
            if err then
                vim.notify('got error: ' .. err, vim.log.levels.ERROR, {
                    title = 'NeoChat',
                })
                return
            end

            self:on_delta(data)
        end,
        on_stderr = function(err, data)
            assert(not err, err)
            if data then
                vim.notify('got error: ' .. data, vim.log.levels.ERROR, {
                    title = 'NeoChat',
                })
            end
        end,
    })

    table.insert(self.messages, {
        role = 'assistant',
        content = '',
    })
end

function Chat:on_delta(data)
    if not data then
        -- output ends, print new line
        data = '\n\n'
    else
        local content = self.messages[#self.messages].content
        self.messages[#self.messages].content = content .. data
    end

    vim.schedule(function()
        local line_count = vim.api.nvim_buf_line_count(self.popup_conversation.bufnr)
        local last_line = vim.api.nvim_buf_get_lines(self.popup_conversation.bufnr, -2, -1, false)[1] or ''
        local row = line_count
        local col = last_line:len()

        local lines = vim.split(data, '\n', { plain = true })
        vim.api.nvim_buf_set_text(self.popup_conversation.bufnr, row - 1, col, row - 1, col, lines)

        row = row + #lines - 1
        if #lines > 1 then
            col = lines[#lines]:len()
        else
            col = col + lines[#lines]:len()
        end

        -- move cursor to the end
        vim.api.nvim_win_set_cursor(self.popup_conversation.winid, { row, col })
    end)
end

function Chat:pick_prompts()
    prompts.pick(function(prompt)
        vim.api.nvim_buf_set_lines(self.popup_input.bufnr, 0, -1, false, { prompt.content })
    end)
end

return Chat
