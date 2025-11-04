local util = require('pretty-fold.util')

describe('pretty-fold.util', function()
  describe('unique_comment_tokens', function()
    it('returns the same table when less than 3 tokens', function()
      local t1 = { '//' }
      assert.are.same(t1, util.unique_comment_tokens(t1))

      local t2 = { '/*', '*/' }
      assert.are.same(t2, util.unique_comment_tokens(t2))
    end)

    it('removes duplicates and preserves order', function()
      local t = { '--', '--', '//' , '--' }
      local out = util.unique_comment_tokens(t)
      assert.are.same({ '--', '//'}, out)
    end)
  end)
end)
