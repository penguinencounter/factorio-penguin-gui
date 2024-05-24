local types = require 'types'

---@class ui.compile.options
---@field headers? string
---@field footers? string

---@class ui.compile.options.concrete : ui.compile.options
---@field headers string
---@field footers string

---@type ui.compile.options.concrete
local defaults = {
    headers = [[
        ---@param parent LuaGuiElement
        ---@param options {[string]: any}
        ---@return LuaGuiElement
        return function(parent, options)
    ]],
    footers = [[
        end
    ]]
}

---@class ui.compiled.translate_opt

---@class ui.compile.static_res
---@field set (string|number|boolean|function)[]
---@field rget { [string|number|boolean|function]: integer }

---@type fun(object: ui.any_type, resources: ui.compile.static_res?): string
local translate_type


---@type {[string]: (fun(t: table, m: metatable?, r: ui.compile.static_res): string)}
local translation_rules
translation_rules = {
    ['_nil'] = function(t, m, r)
        local out = '{'
        for k, v in pairs(t) do
            local key = '[' .. translate_type(k, r) .. ']'
            local value = translate_type(v, r)
            out = out .. key .. '=' .. value .. ','
        end
        out = out .. '}'
        return out
    end,
    ---@param t ui.ast.binop
    ['ui.ast.binop'] = function(t, m, r)
        -- Binary operator.
        return translate_type(t.left, r) .. ' ' .. t.op .. ' ' .. translate_type(t.right, r)
    end,
    ---@param t ui.compiled.param
    ['ui.compiled.param'] = function (t, m, r)
        return 'options[' .. translate_type(t.name) .. ']'
    end,
    ---@param t ui.compiled._static
    ['ui.compiled._static'] = function (t, m, r)
        return '_RESOURCES[' .. t.id .. ']'
    end
}

---@param object ui.any_type
---@param resources ui.compile.static_res
---@return string
function translate_type(object, resources)
    resources = resources or {
        set = {},
        rget = {}
    }
    local statics = {
        ["string"] = true,
        ["number"] = true,
        ["function"] = true
    }
    if type(object) == "table" then
        local mt = getmetatable(object)
        local type = (mt and mt._type)
        if not type then type = '_nil' end
        local action = translation_rules[type]
        if not action then error('Don\'t know how to handle type ' .. type) end
        return action(object, mt, resources)
    elseif type(object) == "boolean" then
        return object and "true" or "false"
    elseif statics[type(object)] then
        ---@cast object string|number|function
        local exist = resources.rget[object]
        if exist then
            return translate_type(types._static(exist))
        end
        if type(object) == "number" and object % 1 == 0 then
            return tostring(object)
        end
        local i = #resources.set + 1
        resources.set[i] = object
        resources.rget[object] = i
        return translate_type(types._static(i))
    end
    error('Don\'t know how to deal with ' .. type(object))
end

---Compile a ElemSpec to Lua code.
---@param target ui.ElementSpec
---@param options ui.compile.options
---@return fun(parent: LuaGuiElement, options: {[string]: any}): LuaGuiElement compiled compiled function. callable
---@return string source source code
local function compile(target, options)
    ---@type ui.compile.options.concrete
    local opts = setmetatable(options or {}, { __index = defaults })
end
return {
    compile = compile,
    translate_type = translate_type
}
