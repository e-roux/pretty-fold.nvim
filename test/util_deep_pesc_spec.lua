local util = require('pretty-fold.util')

describe('pretty-fold.util.deep_pesc', function()
  it('escapes simple strings', function()
    local out = util.deep_pesc({"%a", "(test)"})
    assert.are.same({"%%a", "%(test%)"}, out)
  end)

  it('recurses into nested lists', function()
    local inp = { {"--", "/*"}, {
      {"{"}
    } }
    local out = util.deep_pesc(inp)
    -- Expect structure preserved with escaped strings
    assert.are.same({ {"%-%-", "/%*"}, {{"{"}} }, out)
  end)
end)
