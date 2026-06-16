# Pretty Fold

> :warning: This is a personal fork of [`anuvyklack/pretty-fold.nvim`](https://github.com/anuvyklack/pretty-fold.nvim).
>
> **Neovim v0.12 or higher is required** (Modern `foldtext` List return API)

**Pretty Fold** is a lua plugin for Neovim which provides framework for easy
foldtext customization. It leverages modern Neovim APIs to support rich
highlighting within the fold line.

## Installation

### vim.pack (Neovim 0.12+)

The plugin auto-initialises on load — no `setup()` call needed.

```lua
-- In your init.lua, set options BEFORE adding the plugin:

---@module 'pretty-fold'
---@type PrettyFold.Config
vim.g.pretty_fold_opts = {
  fill_char = '•',
  process_comment_signs = 'spaces',
  sections = {
    left = { 'content' },
    right = {
      ' ', { 'number_of_folded_lines', 'Comment' }, ': ', 'percentage', ' ',
    }
  }
}

vim.pack.add('e-roux/pretty-fold.nvim')
```

Default configuration is applied when `vim.g.pretty_fold_opts` is absent or `nil`.

## Foldtext configuration

The plugin comes with the following defaults:

```lua
config = {
   sections = {
      left = {
         'content',
      },
      right = {
         ' ', 'number_of_folded_lines', ': ', 'percentage', ' ',
         function(config) return config.fill_char:rep(3) end
      }
   },
   fill_char = '•',

   remove_fold_markers = true,

   -- Keep the indentation of the content of the fold string.
   keep_indentation = true,

   -- Possible values:
   -- "delete" : Delete all comment signs from the fold string.
   -- "spaces" : Replace all comment signs with equal number of spaces.
   -- false    : Do nothing with comment signs.
   process_comment_signs = 'spaces',

   -- Comment signs additional to the value of `&commentstring` option.
   comment_signs = {},

   -- List of patterns that will be removed from content foldtext section.
   stop_words = {
      '@brief%s*', -- (for C++) Remove '@brief' and all spaces after.
   },

   add_close_pattern = true, -- true, 'last_line' or false

   matchup_patterns = {
      {  '{', '}' },
      { '%(', ')' }, -- % to escape lua pattern char
      { '%[', ']' }, -- % to escape lua pattern char
   },

   ft_ignore = { 'neorg' },
}
```

### `sections`

The main part. Contains two tables: `config.sections.left` and
`config.sections.right`.

Each section is a list of components. A component can be:
- A **string**: name of a [built-in component](#built-in-components) or literal text.
- A **function**: `function(config): string|chunk|chunks` (where chunk is `{text, hl}`).
- A **table**: `{ name_or_func, highlight_group }` to apply a specific highlight.

#### Example with Highlights

```lua
sections = {
  left = { { 'content', 'Identifier' } },
  right = {
    ' ', 
    { 'number_of_folded_lines', 'Comment' }, 
    ': ', 
    { 'percentage', 'Number' },
    ' '
  }
}
```

#### Built-in components

The strings from the table below will be expanded according to the table.

| Item                       | Expansion |
| -------------------------- | --------- |
| `'content'`                | The content of the first non-blank line of the folded region, somehow modified according to other options. |
| `'number_of_folded_lines'` | The number of folded lines. |
| `'percentage'`             | The percentage of the folded lines out of the whole buffer. |

#### Custom functions

All functions accept config table as an argument.

```lua
vim.g.pretty_fold_opts = {
   custom_function_arg = 'Hello from inside custom function!',
   sections = {
      left = {
         function(config)
            return config.custom_function_arg
         end
      },
   }
}
```

### `fill_char`
**default**: `'•'`

Character used to fill the space between the left and right sections.

### `remove_fold_markers`
**default**: `true`

Remove foldmarkers from the `content` component.

### `keep_indentation`
**default**: `true`

Keep the indentation of the content of the fold string.

### `process_comment_signs`

What to do with comment signs:
**default**: `spaces`

| Option     | Description |
| ---------- | ----------- |
| `'delete'` | delete all comment signs from the foldstring |
| `'spaces'` | replace all comment signs with equal number of spaces |
| `false`    | do nothing with comment signs |

### `comment_signs`
**default**: `{}`

Table with comment signs additional to the value of `&commentstring` option.

Example for Lua. Default `&commentstring` value for Lua is: `'--'`.

```lua
comment_signs = {
    { '--[[', '--]]' }, -- multiline comment
}
```

### `stop_words`

**default**: `'@brief%s*'` (for C++) Remove '@brief' and all spaces after.

[Lua patterns](https://www.lua.org/manual/5.1/manual.html#5.4.1) that will be
removed from the `content` section.

### `add_close_pattern`
**default:** `true`

If this option is set to `true` for all opening patterns that will be found in
the first non-blank line of the folded region, all corresponding closing
elements will be added after ellipsis.

### `matchup_patterns`

The list with matching elements.
Each item is a list itself with two items: opening
[lua pattern](https://www.lua.org/manual/5.1/manual.html#5.4.1) and
close string which will be added if opening pattern is found.

### Setup for particular filetype

Pass per-filetype options inside the `ft` sub-table of `vim.g.pretty_fold_opts`.

### Foldmethod specific configuration

Example:

```lua
vim.g.pretty_fold_opts = {
  global = {}, -- global config table for all foldmethods
  marker = { process_comment_signs = 'spaces' },
  expr   = { process_comment_signs = false },
}
```

### Examples

```lua
-- Minimal: just override fill_char and left sections.
vim.g.pretty_fold_opts = {
  keep_indentation = false,
  fill_char = '•',
  sections = {
    left = { '+', ' ', 'number_of_folded_lines', ':', 'content' },
  },
}
```

```lua
vim.g.pretty_fold_opts = {
  keep_indentation = false,
  fill_char = '━',
  sections = {
    left  = { '━ ', ' ━┫', 'content', '┣' },
    right = { '┫ ', 'number_of_folded_lines', ': ', 'percentage', ' ┣━━' },
  },
}
```

## Preview

Preview module have been moved into separate [plugin](https://github.com/anuvyklack/fold-preview.nvim).

## Additional information

Check ['fillchars'](https://neovim.io/doc/user/options.html#'fillchars')
option. From lua it can be set the next way:
```lua
vim.opt.fillchars:append('fold:•')
```
