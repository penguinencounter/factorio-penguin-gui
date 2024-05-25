script = setmetatable({}, {
    __index = function()
        return function() end
    end
})

local compiler = require 'uipiler.compile'
local types = require 'types'
local s = require 'serpnt'

compiler.compile({
    type = "button"
})
-- print(compiler.translate_type(payload, attachments))
-- print(s.block(attachments.set, 2))
