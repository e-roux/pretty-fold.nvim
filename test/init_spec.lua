-- test/init_spec.lua  mirrors  lua/pretty-fold/init.lua
--
-- TDD: these tests define the expected no-setup public API.
-- They MUST fail before the implementation is changed.

--- Reload the module, optionally presetting vim.g.pretty_fold_opts.
---@param opts table|nil
---@return table
local function reload(opts)
	package.loaded["pretty-fold"] = nil
	vim.g.pretty_fold_opts = opts
	return require("pretty-fold")
end

local function cleanup()
	package.loaded["pretty-fold"] = nil
	vim.g.pretty_fold_opts = nil
end

describe("pretty-fold / public API (no-setup)", function()
	after_each(cleanup)

	describe("API surface", function()
		it("does not expose setup()", function()
			local pf = reload(nil)
			assert.is_nil(pf.setup)
		end)

		it("does not expose ft_setup()", function()
			local pf = reload(nil)
			assert.is_nil(pf.ft_setup)
		end)

		it("exposes a foldtext table", function()
			local pf = reload(nil)
			assert.is_table(pf.foldtext)
		end)
	end)

	describe("auto-initialisation from vim.g.pretty_fold_opts", function()
		it("sets foldtext.global without any config", function()
			local pf = reload(nil)
			assert.is_function(pf.foldtext.global)
		end)

		it("sets foldtext.global when given an empty config", function()
			local pf = reload({})
			assert.is_function(pf.foldtext.global)
		end)

		it("sets foldtext.global when given a non-empty config", function()
			local pf = reload({ fill_char = "X" })
			assert.is_function(pf.foldtext.global)
		end)

		it("registers filetype foldtext from the ft sub-table", function()
			local pf = reload({ ft = { lua = { fill_char = "L" } } })
			assert.is_function(pf.foldtext.lua)
		end)

		it("registers multiple filetypes from ft sub-table", function()
			local pf = reload({ ft = { lua = {}, python = {} } })
			assert.is_function(pf.foldtext.lua)
			assert.is_function(pf.foldtext.python)
		end)

		it("does not register foldtext for filetypes absent from ft", function()
			local pf = reload(nil)
			assert.is_nil(pf.foldtext.rust)
		end)

		it("honours ft_ignore from opts", function()
			local pf = reload({ ft_ignore = { "markdown" } })
			assert.is_true(pf.ft_ignore["markdown"] == true)
		end)
	end)
end)
