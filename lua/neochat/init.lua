local M = {}

function M.setup(opts)
    require('neochat.config').setup(opts)
end

function M.toggle()
    if not M.chat or not M.chat:mounted() then
        M.chat = require('neochat.chat').new()
        return
    end

    M.chat:toggle()
end

return M
