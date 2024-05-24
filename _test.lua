script = setmetatable({}, {
    __index = function()
        return function() end
    end
})

local compiler = require 'uipiler.compile'
local types = require 'types'
local s = require 'serpnt'

---@type ui.compile.static_res
local attachments = {
    set = {},
    rget = {}
}
local payload = {
    nest = {
        me = {
            a = {
                two = 'a' .. types.param "tech_name" .. true,
                three = { 'me', 'a', 'three', 'two', 1023, 2.319, 3.141, 231 }
            }
        }
    }
}
print(compiler.translate_type(payload, attachments))
print(s.block(attachments.set))
