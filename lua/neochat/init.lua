local M = {}

function M.setup(opts)
    require('neochat.config').setup(opts)
    require('neochat.color').setup()
end

function M.toggle()
    if not M.chat or not M.chat:mounted() then
        M.chat = require('neochat.chat').new()
        return
    end

    M.chat:toggle()
end

---@param input string | string[] | nil
function M.open(input)
    if not M.chat or not M.chat:mounted() then
        M.chat = require('neochat.chat').new()
    end

    if input then
        input = type(input) == 'string' and { input } or input
        M.chat:show(input)
    end
end

return M
