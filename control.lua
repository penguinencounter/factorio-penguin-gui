local runtime  = require 'runtime'
local compiler = require 'uipiler.compile'
local types    = require 'types'
local parts    = require 'components'
compiler.compile2(parts.blocks.ClosableWindow("test_window", "Hello, world!"), {
    log_debug = true
})

script.on_init(function()
    runtime.on_init()
end)
script.on_load(function()
    runtime.on_load()
end)
