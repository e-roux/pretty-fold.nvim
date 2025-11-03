local ffi = require("ffi")
local wo = vim.wo
local fn = vim.fn
local api = vim.api

ffi.cdef([[
  typedef struct window_S win_T;
  int win_col_off(win_T *wp);
  extern win_T *curwin;
]])

--- Default configuration for pretty-fold.nvim
---@class DefaultConfig
---@field fill_char string Character used to fill the fold line
---@field remove_fold_markers boolean Remove fold markers from the fold string
---@field keep_indentation boolean Keep the indentation of the content of the fold string
---|"'delete'" Remove all comment signs from the fold string
---|"'spaces'" Replace all comment signs with equal number of spaces
---|false Do nothing with comment signs
---@field process_comment_signs string|boolean How to process comment signs in the fold string
---@field comment_signs table Additional comment signs to consider
---@field stop_words table Patterns to remove from the content fold text section
--@field sections table Sections of the fold line
---@field add_close_pattern boolean|string Add close pattern to the fold line
---@field matchup_patterns table Patterns to match for folding
---@field ft_ignore table File types to ignore

local M = {
  foldtext = {}, -- Table with all 'foldtext' functions.
  ft_ignore = {}, -- Set with filetypes to be ignored.
  -- config = {}
}

-- Labels for each vim foldmethod (:help foldmethod) configuration table and one
-- global configuration table, to look for missing keys if the key is not found
-- in a particular foldmethod configuration table.
local foldmethods = {
  "global", -- One global config table for all foldmethods to look missing keys into.
  "manual",
  "indent",
  "expr",
  "marker",
  "syntax",
  "diff",
}

---@type DefaultConfig
local default_config = {
  fill_char = "•",
  remove_fold_markers = true,
  keep_indentation = true,
  process_comment_signs = "spaces",
  comment_signs = {},
  stop_words = {
    "@brief%s*", -- (for cpp) Remove '@brief' and all spaces after.
  },
  sections = {
    left = {
      "content",
    },
    right = {
      " ",
      "number_of_folded_lines",
      ": ",
      "percentage",
      " ",
      function(config)
        return config.fill_char:rep(3)
      end,
    },
  },

  add_close_pattern = true, -- true, 'last_line' or false
  matchup_patterns = {
    { "{", "}" },
    { "%(", ")" }, -- % to escape lua pattern char
    { "%[", "]" }, -- % to escape lua pattern char
  },
  ft_ignore = { "neorg" },
}

for _, ft in ipairs(default_config.ft_ignore) do
  M.ft_ignore[ft] = true
end

-- The main function which produses the string which will be shown
-- in the fold line.
---@param config table
local function fold_text(config)
  config = config[wo.foldmethod]

  local r = { left = {}, right = {} }

  -- Get the text of all components of the fold string.
  for _, lr in ipairs({ "left", "right" }) do
    for _, sec_name in ipairs(config.sections[lr] or {}) do
      local sec = require("pretty-fold.components")[sec_name]
      if vim.is_callable(sec) then
        local ok, out = pcall(sec, config)
        if not ok then
          vim.notify(string.format("pretty-fold: component '%s' error: %s", tostring(sec_name), tostring(out)), vim.log.levels.ERROR)
          table.insert(r[lr], "<pretty-fold:error>")
        else
          table.insert(r[lr], out)
        end
      else
        table.insert(r[lr], sec)
      end
    end
  end

  ---The width of offset of a window, occupied by line number column,
  ---fold column and sign column.
  ---@type number
  local function compute_gutter_width()
    -- 1) Fast FFI path, guarded
    if package.loaded.ffi then
      local ok, res = pcall(function()
        return ffi.C.win_col_off(ffi.C.curwin)
      end)
      if ok and type(res) == "number" and res >= 0 and res <= api.nvim_win_get_width(0) then
        return res
      end
    end

    -- 2) Public API: getwininfo().textoff
    local ok2, wininfo = pcall(fn.getwininfo, api.nvim_get_current_win())
    if ok2 and type(wininfo) == "table" and wininfo[1] and wininfo[1].textoff then
      local n = tonumber(wininfo[1].textoff)
      if n and n >= 0 then
        return n
      end
    end

    -- 3) Conservative heuristic fallback
    local w = 0
    w = w + (tonumber(vim.wo.foldcolumn) or 0)
    if vim.wo.number or vim.wo.relativenumber then
      local lines = api.nvim_buf_line_count(0)
      local digits = #tostring(lines)
      w = w + math.max(tonumber(vim.wo.numberwidth) or 1, digits)
    end
    local sc = vim.wo.signcolumn
    if sc and sc ~= 'no' then
      if sc == 'yes' or sc:match('^yes') then
        w = w + 2
      else
        w = w + 1
      end
    end
    return w
  end

  local gutter_width = compute_gutter_width()

  local visible_win_width = api.nvim_win_get_width(0) - gutter_width

  -- The summation length of all components of the fold text string.
  local fold_text_str = table.concat(vim.iter(vim.tbl_values(r)):flatten():totable())
  local fold_text_len = fn.strdisplaywidth(fold_text_str)

  r.expansion_str = string.rep(config.fill_char, visible_win_width - fold_text_len)

  return table.concat(vim.iter({ r.left, r.expansion_str, r.right }):flatten():totable())
end

---Make a ready to use config table with all keys for all foldmethos from the
---default config table -and input config table.
---@param config? DefaultConfig
---@return table
local function configure(config)
  -- Flag indicating whether current function got a non-empty parameter.
  local got_input = config and not vim.tbl_isempty(config) and true or false

  if got_input then
    -- Flag shows if only one global config table has been passed or
    -- several config tables for different foldmethods.
    local input_config_is_fdm_specific = false
    for _, fdm in ipairs(foldmethods) do
      if config[fdm] then
        input_config_is_fdm_specific = true
        break
      end
    end
    if not config.global and config[1] and input_config_is_fdm_specific then
      config.global, config[1] = config[1], nil
    elseif not input_config_is_fdm_specific then
      config = { global = config }
    end

    -- Sort out with ft_ignore option.
    for fdm, _ in pairs(config) do
      if config[fdm].ft_ignore then
        for _, ft in ipairs(config[fdm].ft_ignore) do
          M.ft_ignore[ft] = true
        end
        config[fdm].ft_ignore = nil
      end
    end
  else
    config = { global = {} }
  end

  for fdm, _ in pairs(config) do
    setmetatable(config[fdm], {
      __index = (fdm == "global") and default_config or config.global,
    })
  end

  setmetatable(config, {
    __index = function(self, _)
      return self.global
    end,
  })

  return config
end

-- Setup global configuration.
---@param config table
function M.setup(config)
  config = configure(config)
  -- M.config.global = config
  M.foldtext.global = function()
    return fold_text(config)
  end
  vim.o.foldtext = 'v:lua.require("pretty-fold").foldtext.global()'

  vim.api.nvim_create_autocmd("BufWinEnter", {
    callback = function()
      local filetype = vim.bo.filetype
      if M.ft_ignore[filetype] then
        return
      end
      if M.foldtext[filetype] then
        vim.wo.foldtext = string.format("v:lua.require('pretty-fold').foldtext.%s()", filetype)
      else
        vim.wo.foldtext = "v:lua.require('pretty-fold').foldtext.global()"
      end
    end,
  })
end

-- Setup filetype specific configuration.
---@param filetype string
---@param config table
function M.ft_setup(filetype, config)
  if not M.foldtext[filetype] then
    config = configure(config)
    -- M.config[filetype] = config
    M.foldtext[filetype] = function()
      return fold_text(config)
    end
  end
end

return M
