 local pf = require('pretty-fold')
 local components = require('pretty-fold.components')
 local stub = require('luassert.stub')
 
 describe('pretty-fold fold_text pcall protection', function()
   it('returns placeholder when component errors', function()
     -- Backup original component if present
     local orig = components.right
 
     -- Create a component that errors
     components.right = function()
       error('boom!')
     end
 
     -- Stub vim.notify to silence output and assert it was called
     local notify_stub = stub(vim, 'notify')
 
     -- Setup a filetype-specific foldtext that uses the 'right' component
     pf.ft_setup('pcall_ft', { sections = { right = {'right'} } })
 
     local ok, out = pcall(function()
       return pf.foldtext.pcall_ft()
     end)
 
     assert.is_true(ok)
     -- Expect the output to contain the error placeholder inserted by our implementation
     assert.is_true(type(out) == 'string')
     assert.is_true(string.find(out, '<pretty%-fold:error>') ~= nil)
 
     -- Ensure vim.notify was called once for the component error
     assert.stub(notify_stub).was_called(1)
 
     -- Revert the stub and restore original component
     notify_stub:revert()
     components.right = orig
   end)
 end)
 