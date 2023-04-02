# neochat.nvim

ChatGPT in neovim

![preview](https://user-images.githubusercontent.com/2245664/229365814-000db288-c277-4fee-b367-a69e49534e85.gif)


## Please Be Cautious

This plugin is currently in its early developmental stages and is only suitable for my personal usage preferences.
It is advisable that you are aware of the implications before attempting to utilize it.
Additionally, I may not respond to any issues that may arise.

## Prerequistes

- neovim 0.8+
- Python3+
- [nui.nvim](https://github.com/MunifTanjim/nui.nvim)
- Env: `OPENAI_API_KEY`

## Installation

Using `lazy.nvim`

```lua
{
    'Xuyuanp/neochat.nvim',
    build = function()
        vim.fn.system({ 'pip', 'install', '-U', 'openai', })
    end,
    dependencies = {
        'MunifTanjim/nui.nvim',
        -- optional
        'nvim-telescope/telescope.nvim',
        'f/awesome-chatgpt-prompts'
    },
    config = function()
        require('neochat').setup({
            python_exepath = '<path_to_python_binary>' -- optional
        })
    end,
}
```
