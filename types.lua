local assert_const = require 'runtime'.assert_const

---@class ui.types
local export = {}

---@class ui.base_type
---@operator concat: ui.ast.binop
---@operator add: ui.ast.binop
---@operator sub: ui.ast.binop
---@operator mul: ui.ast.binop
---@operator div: ui.ast.binop
---@operator mod: ui.ast.binop
---@operator pow: ui.ast.binop
---@operator unm: ui.ast.unop

---@class ui.ast.binop : ui.base_type
---@field left any
---@field right any
---@field op string

---@class ui.ast.unop : ui.base_type
---@field target any
---@field op string

---@class ui.ref_type : ui.base_type
---@field name string

---@class ui.lazy_type
---@field resolve fun(): any

---@class ui.compiled.param : ui.base_type
---@field name string

---Mark an entire value as constant and not containing any special types.
--- The entire value will be added to the resource bundle.
---@class ui.compiled.const : ui.base_type
---@field value any

---@class ui.compiled._static : ui.base_type
---@field id integer

---@alias ui.any_type ui.base_type | string | number | boolean | table | function

---@param name string
local function mktypemeta(name)
    assert_const()
    local function invalid(what_is_it)
        error("Illegal operation " .. what_is_it .. " on " .. name .. ".\n  hint: try adjusting the data passed to the template instead of manipulating it in the template definition", 3)
    end
    ---@type metatable
    local ret = {
        _type = name,
        __concat = function(a, b)
            return setmetatable({
                left = a,
                right = b,
                op = '..'
            }, export.binop_type)
        end,
        __add = function (t1, t2)
            return setmetatable({
                left = t1,
                right = t2,
                op = '+'
            }, export.binop_type)
        end,
        __sub = function (t1, t2)
            return setmetatable({
                left = t1,
                right = t2,
                op = '-'
            }, export.binop_type)
        end,
        __mul = function (t1, t2)
            return setmetatable({
                left = t1,
                right = t2,
                op = '*'
            }, export.binop_type)
        end,
        __div = function (t1, t2)
            return setmetatable({
                left = t1,
                right = t2,
                op = '/'
            }, export.binop_type)
        end,
        __mod = function (t1, t2)
            return setmetatable({
                left = t1,
                right = t2,
                op = '%'
            }, export.binop_type)
        end,
        __pow = function (t1, t2)
            return setmetatable({
                left = t1,
                right = t2,
                op = '^'
            }, export.binop_type)
        end,
        __unm = function (t)
            return setmetatable({
                op = '-',
                target = t
            }, export.unop_type)
        end,
        __eq = function (t1, t2)
            ---@diagnostic disable-next-line: missing-return
            invalid "equals"
        end,
        __lt = function (t1, t2)
            ---@diagnostic disable-next-line: missing-return
            invalid "compare"
        end,
        __le = function (t1, t2)
            ---@diagnostic disable-next-line: missing-return
            invalid "compare"
        end
    }
    script.register_metatable(name, ret)
    return ret
end

export.binop_type = mktypemeta("ui.ast.binop")
export.unop_type = mktypemeta("ui.ast.unop")
export.ref_type = mktypemeta("ui.ref")
export.lazy_type = mktypemeta("ui.lazy")
export.param_type = mktypemeta("ui.compiled.param")
export.code_type = mktypemeta("ui.compiled.code")
export.const_type = mktypemeta("ui.compiled.const")
export.internal_static_type = mktypemeta("ui.compiled._static")

---Represents an unfilled parameter to the function.
---
---**Not supported** with build and build_dry.
---@param name string
---@return ui.compiled.param
function export.param(name)
    return setmetatable({name = name}, export.param_type)
end

---Represents a LuaGuiElement in the same isolation context by unique name.
---
---Set {uname: string} to make an element available.
---@param name string
---@return ui.ref_type
function export.ref(name)
    return setmetatable({name = name}, export.ref_type)
end

---Represents a value that is not yet resolved.
---@param resolve fun(): any
---@return ui.lazy_type
function export.lazy(resolve)
    return setmetatable({resolve = resolve}, export.lazy_type)
end

---@param value any
---@return ui.compiled.const
function export.const(value)
    return setmetatable({value = value}, export.const_type)
end

function export._static(id)
    return setmetatable({id = id}, export.internal_static_type)
end

return export