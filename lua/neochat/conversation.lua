local Popup = require('nui.popup')
local NuiText = require('nui.text')
local event = require('nui.utils.autocmd').event

local api = require('neochat.api')
local config = require('neochat.config')
local color = require('neochat.color')

local function you_text()
    return NuiText(config.options.user_text, 'NeoChatUser')
end

local function chatgpt_text()
    return NuiText(config.options.bot_text, 'NeoChatBot')
end

local ns_id = vim.api.nvim_create_namespace('neochat-conversation-spinner')

local Conversation = Popup:extend('NeoChatConversation')

---@param popup_opts table
function Conversation:init(popup_opts)
    Conversation.super.init(self, popup_opts)

    self:on({ event.BufWinEnter }, function()
        color.attach_window(self.winid)
    end)

    self.messages = {}
end

function Conversation:clear()
    self.messages = {}
    vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, {})

    vim.api.nvim_buf_clear_namespace(self.bufnr, ns_id, 0, -1)
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
    vim.api.nvim_buf_set_extmark(self.bufnr, ns_id, line_count - 1, 0, {
        sign_text = config.options.user_sign,
        sign_hl_group = 'NeoChatUser',
    })
    -- print input
    vim.api.nvim_buf_set_lines(self.bufnr, -1, -1, false, input)
    vim.api.nvim_buf_set_lines(self.bufnr, -1, -1, false, { '' })

    self:scroll_to_bottom()
end

---@private
function Conversation:_display_response()
    self.spinner_idx = 1
    local head_line = vim.api.nvim_buf_line_count(self.bufnr)
    local chatgpt = chatgpt_text()
    chatgpt:render(self.bufnr, -1, head_line, 0, head_line, 0)
    vim.api.nvim_buf_set_extmark(self.bufnr, ns_id, head_line - 1, 0, {
        sign_text = config.options.bot_sign,
        sign_hl_group = 'NeoChatBot',
    })

    -- add newline
    vim.api.nvim_buf_set_lines(self.bufnr, -1, -1, false, { '' })
    self:scroll_to_bottom()

    self.extmark_id = vim.api.nvim_buf_set_extmark(self.bufnr, ns_id, vim.api.nvim_buf_line_count(self.bufnr), 0, {
        id = self.extmark_id,
        virt_text = { { config.options.spinners[self.spinner_idx], 'NeoChatResponsePending' } },
    })

    local stderr_buf = ''

    local timer = vim.loop.new_timer()
    assert(timer) -- make linter happy
    timer:start(
        100,
        100,
        vim.schedule_wrap(function()
            if not self.extmark_id then
                return
            end

            self.spinner_idx = self.spinner_idx + 1
            if self.spinner_idx > #config.options.spinners then
                self.spinner_idx = 1
            end

            vim.api.nvim_buf_set_extmark(self.bufnr, ns_id, vim.api.nvim_buf_line_count(self.bufnr) - 1, 0, {
                id = self.extmark_id,
                virt_text = { { config.options.spinners[self.spinner_idx], 'NeoChatResponsePending' } },
            })
        end)
    )

    api.chat_completions(self.messages, {
        on_start = function() end,
        ---@diagnostic disable-next-line: unused-local
        on_exit = vim.schedule_wrap(function(code, signal)
            timer:stop()
            timer:close()

            local virt_text = code == 0 and { '', 'NeoChatResponseOk' } or { '', 'NeoChatResponseError' }
            if stderr_buf ~= '' then
                local level = code == 0 and vim.log.levels.WARN or vim.log.levels.ERROR
                vim.notify(stderr_buf, level, { title = 'NeoChat stderr' })
            end

            vim.api.nvim_buf_set_extmark(self.bufnr, ns_id, vim.api.nvim_buf_line_count(self.bufnr) - 1, 0, {
                id = self.extmark_id,
                virt_text = { virt_text },
            })
            self.extmark_id = nil

            vim.api.nvim_buf_set_lines(self.bufnr, -1, -1, false, { '', '' })
            self:scroll_to_bottom()
        end),
        on_stdout = vim.schedule_wrap(function(err, data)
            assert(not err, err)
            if not data then
                return
            end
            self:_on_delta(data)
        end),
        on_stderr = vim.schedule_wrap(function(err, data)
            assert(not err, err)
            stderr_buf = stderr_buf .. (data or '')
        end),
    })

    -- prepare an empty response
    table.insert(self.messages, {
        role = 'assistant',
        content = '',
    })
end

---@private
---@param data string
function Conversation:_on_delta(data)
    local content = self.messages[#self.messages].content
    self.messages[#self.messages].content = content .. data

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
