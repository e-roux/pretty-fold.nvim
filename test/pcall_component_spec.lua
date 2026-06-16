local components = require("pretty-fold.components")
local stub = require("luassert.stub")

describe("pretty-fold / pcall protection in fold_text", function()
	it("returns placeholder string when a component errors", function()
		local orig = components.right

		-- Inject a broken component.
		components.right = function()
			error("boom!")
		end

		local notify_stub = stub(vim, "notify")

		-- Reload with a config that exercises the broken component.
		package.loaded["pretty-fold"] = nil
		vim.g.pretty_fold_opts = { sections = { right = { "right" } } }
		local pf = require("pretty-fold")

		local ok, out = pcall(pf.foldtext.global)

		assert.is_true(ok)
		assert.is_table(out)
		local found = false
		for _, chunk in ipairs(out) do
			if chunk[1]:find("<pretty%-fold:error>") then
				found = true
				break
			end
		end
		assert.is_true(found)
		assert.stub(notify_stub).was_called(1)

		-- Cleanup
		notify_stub:revert()
		components.right = orig
		package.loaded["pretty-fold"] = nil
		vim.g.pretty_fold_opts = nil
	end)
end)
 