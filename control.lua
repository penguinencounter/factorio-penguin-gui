local runtime = require 'runtime'

script.on_init(function()
    runtime.on_init()
end)
script.on_load(function()
    runtime.on_load()
end)