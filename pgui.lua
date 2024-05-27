-- MAIN INCLUDE TARGET
local runtime = require 'runtime'
local types = require 'types'
local spec = require 'spec'
local components = require 'components'
local events = require 'events'
local compile = require 'compile'
local utils = require 'helpers'

---@class pgui
local pgui = {
    _runtime = runtime,
    _types = types,
    _spec = spec,
    _components = components,
    _events = events,
    _compile = compile,
    _utils = utils,

    runtime = runtime,
    types = types,

    ElementSpec = spec.ElementSpec,
    fill_icon_set = utils.fill_icon_set,

    register = events.register,
    eval_handler = events.eval_handler,

    blocks = components.blocks,
    build = components.build,
    build_dry = components.build_dry,

    compile = compile.compile2,
    compile2 = compile.compile2,

    const = types.const,
    ref = types.ref,
    lazy = types.lazy,
    param = types.param,
    NIL = types.set_nil,
}

return pgui
