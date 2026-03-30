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
		assert.is_string(out)
		assert.is_truthy(out:find("<pretty%-fold:error>"))
		assert.stub(notify_stub).was_called(1)

		-- Cleanup
		notify_stub:revert()
		components.right = orig
		package.loaded["pretty-fold"] = nil
		vim.g.pretty_fold_opts = nil
	end)
end)
 