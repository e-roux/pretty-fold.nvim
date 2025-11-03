local util = {}

---Returns the comment signs table with all duplicate items removed.
---@param t table
---@return table
function util.unique_comment_tokens(t)
  if #t < 3 then
    return t
  end
  local ut = { t[1] }
  for i = 2, #t do
    local seen = false
    for j = 1, #ut do
      if ut[j] == t[i] then
        seen = true
        break
      end
    end
    if not seen then
      table.insert(ut, t[i])
    end
  end
  return ut
end

---Takes a list containing strings and nested lists of strings,
---and escapes all Lua magic chars everywhere.
---@param ts table
---@return table
function util.deep_pesc(ts)
  local function recurse(v)
    if type(v) == "string" then
      return vim.pesc(v)
    elseif type(v) == "table" then
      local out = {}
      for i, item in ipairs(v) do
        out[i] = recurse(item)
      end
      return out
    else
      return v
    end
  end
  return recurse(ts)
end

return util
