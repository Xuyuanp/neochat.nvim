local M = {}

local default_options = {
    python_exepath = vim.fn.exepath('python') or vim.fn.exepath('python3'),
    spinners = 'dots_negative',
    layout_opts = {
        relative = 'editor',
        position = '50%',
        size = {
            width = '60%',
            height = '80%',
        },
    },
    layout_box = {
        conversation_opts = {
            size = '75%',
        },
        input_opts = {
            size = '25%',
        },
        opts = {
            dir = 'col', -- col or row
            -- grow: number
            -- size: number/string/table
        },
    },
    openai = {
        chat_completions = {
            model = 'gpt-3.5-turbo',
            stream = true,
            -- temperature
            -- top_p
            -- n,
            -- max_tokens
            -- presence_penalty
            -- frequency_penalty
            -- logit_bias
        },
    },
}

function M.setup(opts)
    opts = opts or {}
    local options = vim.tbl_deep_extend('force', default_options, opts)

    if type(options.spinners) == 'string' then
        options.spinners = require('neochat.spinners')[options.spinners]
    end

    M.options = options
end

return M
