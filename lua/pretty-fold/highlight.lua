--- pretty-fold: highlight-aware line chunking
---
--- Slices a buffer line into { text, hl_group } chunks whose highlight groups
--- match the *actual* treesitter or syntax highlight of each token, so the
--- fold-start line keeps its original colours instead of being blanketed by
--- the `Folded` group.
---
--- Neovim ≥ 0.10 foldtext accepts a list of { text, hl } pairs (rendered as
--- "overlay" virtual text).  No backward-compatibility layer is provided.
---
---@module 'pretty-fold.highlight'

local api = vim.api
local ts = vim.treesitter

local M = {}

-- ---------------------------------------------------------------------------
-- Internal: span → chunk conversion
-- ---------------------------------------------------------------------------

--- Convert a list of byte-indexed highlight spans into a list of {text, hl}
--- chunks that cover `line` exactly once from left to right.
---
--- When spans overlap, the *last* one in the list wins (narrower / higher-
--- priority captures are expected to be listed later by callers).
---
---@param line      string   the text to slice
---@param spans     { s:integer, e:integer, hl:string }[]  0-indexed byte spans, end exclusive
---@param fallback  string   hl-group for bytes not covered by any span
---@return { [1]:string, [2]:string }[]
local function spans_to_chunks(line, spans, fallback)
	local nbytes = #line
	if nbytes == 0 then
		return {}
	end

	-- Build a per-byte highlight array; last write wins.
	local byte_hl = {} ---@type (string|false)[]  false = use fallback
	for b = 1, nbytes do
		byte_hl[b] = false
	end

	for _, sp in ipairs(spans) do
		local s = math.max(sp.s, 0) + 1 -- convert to 1-indexed inclusive
		local e = math.min(sp.e, nbytes) -- 0-indexed exclusive → 1-indexed inclusive
		if s <= e then
			for b = s, e do
				byte_hl[b] = sp.hl
			end
		end
	end

	-- Group consecutive bytes with the same effective hl into chunks.
	local chunks = {}
	local ci = 1
	while ci <= nbytes do
		local hl = byte_hl[ci] or fallback
		local cj = ci + 1
		while cj <= nbytes and (byte_hl[cj] or fallback) == hl do
			cj = cj + 1
		end
		table.insert(chunks, { line:sub(ci, cj - 1), hl })
		ci = cj
	end

	return chunks
end

-- ---------------------------------------------------------------------------
-- Treesitter path
-- ---------------------------------------------------------------------------

--- Collect highlight spans for `row` (0-indexed) using the active treesitter
--- highlighter for `bufnr`.
---
---@param bufnr  integer
---@param row    integer  0-indexed line number
---@param line   string   the raw buffer line (to clamp end-column)
---@return { s:integer, e:integer, hl:string }[]
local function ts_spans(bufnr, row, line)
	local highlighter = ts.highlighter.active[bufnr]
	if not highlighter then
		return {}
	end

	local line_len = #line
	local spans = {} ---@type { s:integer, e:integer, hl:string }[]

	highlighter.tree:for_each_tree(function(tstree, ltree)
		if not tstree then
			return
		end

		local root = tstree:root()
		local root_sr, _, root_er, _ = root:range()
		if root_sr > row or root_er < row then
			return
		end

		local hl_query = highlighter:get_query(ltree:lang())
		local query = hl_query:query()
		if not query then
			return
		end

		-- Iterate captures restricted to this single row.
		for id, node, metadata in query:iter_captures(root, bufnr, row, row + 1) do
			local capture_name = query.captures[id]
			-- Skip internal captures (prefixed with "_") and non-highlight ones.
			if capture_name and not vim.startswith(capture_name, "_") then
				-- Get the range of this capture (may span multiple rows).
				local sr, sc, er, ec = ts.get_node_range(node)

				-- Apply metadata offset / range directive if present.
				local cap_meta = metadata and metadata[id]
				if cap_meta then
					local full = ts.get_range(node, bufnr, cap_meta)
					sr, sc, er, ec = full[1], full[2], full[4], full[5]
				end

				-- Clip to the current row.
				local s = (sr == row) and sc or 0
				local e = (er == row) and ec or line_len
				e = math.min(e, line_len)

				if sr <= row and er >= row and s < e then
					-- Resolve highlight group: prefer @capture.lang, fall back
					-- to @capture (treesitter convention).
					local hl_name = "@" .. capture_name .. "." .. ltree:lang()
					if api.nvim_get_hl_id_by_name(hl_name) == 0 then
						hl_name = "@" .. capture_name
					end
					table.insert(spans, { s = s, e = e, hl = hl_name })
				end
			end
		end
	end)

	return spans
end

-- ---------------------------------------------------------------------------
-- Legacy Vim syntax path
-- ---------------------------------------------------------------------------

--- Collect highlight spans for `row` (0-indexed) using Vim's legacy `:syntax`
--- engine.  O(line_length) `synID()` calls — only used when treesitter is off.
---
---@param bufnr  integer
---@param row    integer  0-indexed line number
---@param line   string   the raw buffer line
---@return { s:integer, e:integer, hl:string }[]
local function syn_spans(bufnr, row, line)
	local nbytes = #line
	if nbytes == 0 then
		return {}
	end

	local lnum = row + 1 -- 1-indexed for synID()

	-- Batch all synID calls inside a single nvim_buf_call to avoid repeated
	-- context switches.
	local hl_per_byte = api.nvim_buf_call(bufnr, function()
		local result = {}
		for col = 1, nbytes do
			local sid = vim.fn.synID(lnum, col, true)
			local name = vim.fn.synIDattr(vim.fn.synIDtrans(sid), "name")
			result[col] = (name ~= "") and name or false
		end
		return result
	end)

	-- Collapse identical consecutive highlights into spans.
	local spans = {}
	local ci = 1
	while ci <= nbytes do
		local hl = hl_per_byte[ci]
		local cj = ci + 1
		while cj <= nbytes and hl_per_byte[cj] == hl do
			cj = cj + 1
		end
		if hl then
			-- 0-indexed, end-exclusive.
			table.insert(spans, { s = ci - 1, e = cj - 1, hl = hl })
		end
		ci = cj
	end

	return spans
end

-- ---------------------------------------------------------------------------
-- Text alignment helper
-- ---------------------------------------------------------------------------

--- Map highlight chunks computed on `raw_line` onto the (potentially
--- differently-sized) `text` produced after fold content transformations
--- (marker removal, indentation substitution, etc.).
---
--- The strategy: walk `text` character by character and assign the highlight
--- of the corresponding position in `raw_line`.  Trailing bytes in `text`
--- that go beyond `raw_line` inherit the last seen hl.  This keeps visually
--- corresponding tokens coloured correctly even when byte lengths diverge.
---
---@param text     string
---@param raw_chunks { [1]:string, [2]:string }[]
---@param fallback string
---@return { [1]:string, [2]:string }[]
local function remap_chunks(text, raw_chunks, fallback)
	if text == "" then
		return {}
	end

	-- Build a flat byte→hl map for raw_chunks.
	local raw_byte_hl = {} ---@type string[]
	local pos = 1
	for _, chunk in ipairs(raw_chunks) do
		for _ = 1, #chunk[1] do
			raw_byte_hl[pos] = chunk[2]
			pos = pos + 1
		end
	end
	local raw_len = pos - 1
	local last_hl = raw_len > 0 and raw_byte_hl[raw_len] or fallback

	-- Walk `text` and assign hl from the raw map (clamped at raw_len).
	local result = {}
	local txt_len = #text
	local ci = 1
	while ci <= txt_len do
		local raw_idx = math.min(ci, raw_len)
		local hl = (raw_len > 0 and raw_byte_hl[raw_idx]) or last_hl or fallback
		local cj = ci + 1
		while cj <= txt_len do
			local nidx = math.min(cj, raw_len)
			local nhl = (raw_len > 0 and raw_byte_hl[nidx]) or last_hl or fallback
			if nhl ~= hl then
				break
			end
			cj = cj + 1
		end
		local seg = text:sub(ci, cj - 1)
		if seg ~= "" then
			if #result > 0 and result[#result][2] == hl then
				result[#result][1] = result[#result][1] .. seg
			else
				table.insert(result, { seg, hl })
			end
		end
		ci = cj
	end

	return result
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

--- Return a list of `{ text, hl_group }` chunks for `text` that preserve the
--- original treesitter / syntax highlight of each token on `foldstart_lnum`.
---
--- The `raw_line` is the unprocessed buffer line; its byte offsets are used to
--- compute span positions.  `text` is the already-transformed content string
--- (fold markers removed, indentation replaced, etc.).
---
---@param text         string   processed content text to slice
---@param raw_line     string   unmodified buffer line (for span computation)
---@param bufnr        integer  buffer number
---@param row          integer  0-indexed line number (= v.foldstart - 1)
---@param fallback_hl  string   group for un-highlighted bytes ("PrettyFoldContent")
---@return { [1]:string, [2]:string }[]
function M.line_chunks(text, raw_line, bufnr, row, fallback_hl)
	fallback_hl = fallback_hl or "PrettyFoldContent"

	if text == "" then
		return {}
	end

	-- Collect spans from the raw source line.
	local spans ---@type { s:integer, e:integer, hl:string }[]
	if ts.highlighter.active[bufnr] then
		spans = ts_spans(bufnr, row, raw_line)
	else
		spans = syn_spans(bufnr, row, raw_line)
	end

	if vim.tbl_isempty(spans) then
		-- No highlight info — return a single plain chunk.
		return { { text, fallback_hl } }
	end

	-- Build highlight chunks on the *raw* line, then remap to `text`.
	local raw_chunks = spans_to_chunks(raw_line, spans, fallback_hl)

	if text == raw_line then
		return raw_chunks
	end

	return remap_chunks(text, raw_chunks, fallback_hl)
end

return M
