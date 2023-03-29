local config = require('neochat.config')

local M = {}

function M.chat_completions(messages, opts)
    local uv = vim.loop

    local pipe_stdin = uv.new_pipe()
    local pipe_stdout = uv.new_pipe()
    local pipe_stderr = uv.new_pipe()

    assert(pipe_stdin, 'pipe failed')
    assert(pipe_stdout, 'pipe failed')
    assert(pipe_stderr, 'pipe failed')

    local handle
    handle = uv.spawn(config.options.python_exepath, {
        args = { vim.api.nvim_get_runtime_file('scripts/neochat.py', false)[1] },
        stdio = { pipe_stdin, pipe_stdout, pipe_stderr },
    }, function(code, signal)
        pipe_stdout:close()
        pipe_stderr:close()

        if handle then
            handle:close()
        end

        if opts.on_exit then
            opts.on_exit(code, signal)
        end
    end)
    assert(handle, 'spawn failed')

    uv.read_start(pipe_stdout, opts.on_stdout)

    uv.read_start(pipe_stderr, opts.on_stderr)

    uv.write(pipe_stdin, vim.fn.json_encode(messages))
    uv.shutdown(pipe_stdin)

    if opts.on_start then
        opts.on_start()
    end
end

return M
