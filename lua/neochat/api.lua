local config = require("neochat.config")

local M = {}

function M.chat_completions(messages, opts)
	local uv = vim.loop

	local pipe_stdin = uv.new_pipe()
	local pipe_stdout = uv.new_pipe()
	local pipe_stderr = uv.new_pipe()

	assert(pipe_stdin, "pipe failed")
	assert(pipe_stdout, "pipe failed")
	assert(pipe_stderr, "pipe failed")

	local handle
	handle = uv.spawn(vim.fn.exepath("python"), {
		args = { "scripts/neochat.py" },
		cwd = config.options.cwd,
		stdio = { pipe_stdin, pipe_stdout, pipe_stderr },
	}, function(code)
		uv.close(pipe_stdout)
		uv.close(pipe_stderr)

		if handle then
			handle:close()
		end

		if code ~= 0 then
			print("neochat.py exited with code", code)
		end
	end)
	assert(handle, "spawn failed")

	uv.read_start(pipe_stdout, opts.on_stdout)

	uv.read_start(pipe_stderr, opts.on_stderr)

	uv.write(pipe_stdin, vim.fn.json_encode(messages))
	uv.shutdown(pipe_stdin)
end

return M
