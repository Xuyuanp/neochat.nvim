local Popup = require('nui.popup')
local NuiText = require('nui.text')

local api = require('neochat.api')
local config = require('neochat.config')

local function you_text()
    return NuiText('#  @You:', 'Keyword')
end

local function chatgpt_text()
    return NuiText('# 󰚩 @ChatGPT:', 'Function')
end

local function spinner_text(idx)
    return NuiText(config.options.spinners[idx], 'Comment')
end

local function done_text()
    return NuiText('', 'String')
end

local function error_text()
    return NuiText('', 'Error')
end

local Conversation = Popup:extend('NeoChatConversation')

---@param popup_opts table
function Conversation:init(popup_opts)
    Conversation.super.init(self, popup_opts)

    self.messages = {}
end

function Conversation:clear()
    self.messages = {}
    vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, {})
end

---@param input string | string[]
function Conversation:ask(input)
    local content = type(input) == 'table' and vim.fn.join(input, '\n') or input
    table.insert(self.messages, {
        role = 'user',
        content = content,
    })

    input = type(input) == 'table' and input or { input }
    self:_display_question(input)
    ---@diagnostic disable-next-line: param-type-mismatch
    vim.defer_fn(function()
        self:_display_response()
        ---@diagnostic disable-next-line: param-type-mismatch
    end, 500)
end

function Conversation:focus()
    vim.api.nvim_set_current_win(self.winid)
end

---@param delta number
function Conversation:scroll(delta)
    local function t(key)
        return vim.api.nvim_replace_termcodes(key, true, false, true)
    end
    local cmd = delta > 0 and t('<C-E>') or t('<C-Y>')
    local count = math.abs(delta)
    vim.api.nvim_win_call(self.winid, function()
        vim.cmd([[normal! ]] .. count .. cmd)
    end)
end

function Conversation:scroll_to_bottom()
    local line_count = vim.api.nvim_buf_line_count(self.bufnr)
    vim.api.nvim_win_set_cursor(self.winid, { line_count, 0 })
end

---@param input string[]
function Conversation:_display_question(input)
    -- send to chat
    local line_count = vim.api.nvim_buf_line_count(self.bufnr)
    you_text():render(self.bufnr, -1, line_count, 0, line_count, 0)
    -- print input
    vim.api.nvim_buf_set_lines(self.bufnr, -1, -1, false, input)
    -- add two new lines
    vim.api.nvim_buf_set_lines(self.bufnr, -1, -1, false, { '', '' })

    self:scroll_to_bottom()
end

function Conversation:_display_response()
    self.spinner_idx = 1
    local head_line = vim.api.nvim_buf_line_count(self.bufnr)
    local chatgpt = chatgpt_text()
    local head_len = chatgpt:content():len()
    chatgpt:render(self.bufnr, -1, head_line, 0, head_line, 0)
    NuiText(' ', 'Function'):render(self.bufnr, -1, head_line, head_len, head_line, head_len)
    spinner_text(self.spinner_idx):render_char(self.bufnr, -1, head_line, head_len + 1)

    local timer = vim.loop.new_timer()
    assert(timer) -- make linter happy
    timer:start(
        100,
        100,
        vim.schedule_wrap(function()
            self.spinner_idx = self.spinner_idx + 1
            if self.spinner_idx > #config.options.spinners then
                self.spinner_idx = 1
            end
            spinner_text(self.spinner_idx):render(self.bufnr, -1, head_line, head_len + 1)
        end)
    )

    -- add newline
    vim.api.nvim_buf_set_lines(self.bufnr, -1, -1, false, { '' })
    self:scroll_to_bottom()

    api.chat_completions(self.messages, {
        on_start = function() end,
        ---@diagnostic disable-next-line: unused-local
        on_exit = vim.schedule_wrap(function(code, signal)
            timer:stop()
            local res_mark
            if code == 0 then
                res_mark = done_text()
            else
                res_mark = error_text()
            end
            res_mark:render(self.bufnr, -1, head_line, head_len + 1)
        end),
        on_stdout = vim.schedule_wrap(function(err, data)
            if err then
                vim.notify('got error: ' .. err, vim.log.levels.ERROR, {
                    title = 'NeoChat',
                })
                return
            end

            self:_on_delta(data)
        end),
        on_stderr = vim.schedule_wrap(function(err, data)
            assert(not err, err)
            if data then
                vim.notify('got error: ' .. data, vim.log.levels.ERROR, {
                    title = 'NeoChat',
                })
            end
        end),
    })

    -- prepare an empty response
    table.insert(self.messages, {
        role = 'assistant',
        content = '',
    })
end

---@param data string | nil
function Conversation:_on_delta(data)
    if not data then
        -- output ends, print new line
        data = '\n\n'
    else
        local content = self.messages[#self.messages].content
        self.messages[#self.messages].content = content .. data
    end

    local line_count = vim.api.nvim_buf_line_count(self.bufnr)
    local last_line = vim.api.nvim_buf_get_lines(self.bufnr, -2, -1, false)[1] or ''
    local row = line_count
    local col = last_line:len()

    local lines = vim.split(data, '\n', { plain = true })
    vim.api.nvim_buf_set_text(self.bufnr, row - 1, col, row - 1, col, lines)

    row = row + #lines - 1
    if #lines > 1 then
        col = lines[#lines]:len()
    else
        col = col + lines[#lines]:len()
    end

    -- move cursor to the end
    vim.api.nvim_win_set_cursor(self.winid, { row, col })
end

return Conversation
