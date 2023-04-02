local M = {}

local function parse_prompts_csv(path)
    local file = io.open(path, 'r')
    assert(file, 'Failed to open ' .. path)

    local lines = {}

    for line in file:lines('*l') do
        table.insert(lines, line)
    end

    file:close()

    -- remove the header line
    table.remove(lines, 1)

    local prompts = {}

    for _, line in ipairs(lines) do
        local fields = vim.split(line, '","', { plain = true })

        local act = string.sub(fields[1], 2)
        local content = string.sub(fields[2], 1, -2)
        content = string.gsub(content, '""', '"')
        table.insert(prompts, {
            act = act,
            content = content,
        })
    end

    return prompts
end

function M.pick(on_select)
    local prompts_csv = vim.api.nvim_get_runtime_file('prompts.csv', false)[1]
    if not prompts_csv then
        vim.notify('Could not find prompts.csv', vim.log.levels.WARN, {
            title = 'NeoChat',
        })
        return
    end

    local prompts = parse_prompts_csv(prompts_csv)
    if not prompts then
        vim.notify('Could not parse prompts.csv', vim.log.levels.ERROR, {
            title = 'NeoChat',
        })
        return
    end

    local pickers = require('telescope.pickers')
    local previewers = require('telescope.previewers')

    local previewer = previewers.new_buffer_previewer({
        ---@diagnostic disable-next-line: unused-local
        define_preview = function(self, entry, _status)
            vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, { entry.value.content })
            vim.api.nvim_win_set_option(self.state.winid, 'wrap', true)
        end,
    })

    pickers
        .new({}, {
            prompt_title = 'Prompts',
            finder = require('telescope.finders').new_table({
                results = prompts,
                entry_maker = function(entry)
                    return {
                        value = entry,
                        display = entry.act,
                        ordinal = entry.act,
                    }
                end,
            }),
            sorter = require('telescope.config').values.generic_sorter({}),
            previewer = previewer,
            attach_mappings = function(prompt_bufnr, map)
                map('i', '<CR>', function()
                    local selection = require('telescope.actions.state').get_selected_entry()
                    require('telescope.actions').close(prompt_bufnr)

                    on_select(selection.prompt)
                end)

                return true
            end,
        })
        :find()
end

return M
