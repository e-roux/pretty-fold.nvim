local fn = vim.fn
local api = vim.api

describe("pretty-fold / list return", function()
	it("fold_text returns a list of chunks", function()
		local pf = require("pretty-fold")
		-- We need to mock some things or setup a real environment
		-- Actually, we can just call the internal fold_text if we can access it,
		-- but it's local. M.foldtext.global() calls it.

		vim.opt.foldmethod = "manual"
		api.nvim_buf_set_lines(0, 0, -1, false, { "line1", "line2", "line3" })
		vim.cmd("1,3fold")

		local res = pf.foldtext.global()
		assert.is_table(res)
		assert.is_table(res[1])
		assert.is_string(res[1][1]) -- text
	end)

    it("supports components with custom highlights", function()
        -- This test will fail until we implement the feature
        vim.g.pretty_fold_opts = {
            sections = {
                left = { { "content", "MyHighlight" } },
                right = {}
            }
        }
        -- Reload pretty-fold to pick up new opts
        package.loaded["pretty-fold"] = nil
        local pf = require("pretty-fold")

		api.nvim_buf_set_lines(0, 0, -1, false, { "line1", "line2", "line3" })
		vim.cmd("1,3fold")

        local res = pf.foldtext.global()
        -- Find the chunk for 'content'
        local found = false
        for _, chunk in ipairs(res) do
            if chunk[2] == "MyHighlight" then
                found = true
                break
            end
        end
        assert.is_true(found)
    end)
end)
