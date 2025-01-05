local config = require('neochat.config')

local M = {}

local script = vim.api.nvim_get_runtime_file('scripts/neochat.py', false)[1]

function M.chat_completions(messages, opts)
    if opts.on_start then
        opts.on_start()
    end
    local args = vim.tbl_deep_extend('force', config.options.openai.chat_completions, { messages = messages })
    vim.system({ config.options.python_exepath, script, 'chat' }, {
        stdin = vim.json.encode(args),
        stdout = opts.on_stdout,
        stderr = opts.on_stderr,
    }, function(out)
        if opts.on_exit then
            opts.on_exit(out.code, out.signal)
        end
    end)
end

return M
