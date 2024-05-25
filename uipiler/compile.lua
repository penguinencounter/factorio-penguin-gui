local types = require 'types'
local spec = require 'spec'
local runtime = require 'runtime'

---@class ui.compiled.translate_opt

---@class ui.compile.static_res
---@field set (string|number|boolean|function)[]
---@field rget { [string|number|boolean|function]: integer }

---@class ui.compile.context
---@field stage integer
---@field local_context string

---@param bundle ui.compile.static_res
---@param target string|number|boolean|function
---@return integer
local function res_register(bundle, target)
    if bundle.rget[target] then return bundle.rget[target] end
    local i = #bundle.set + 1
    bundle.set[i] = target
    bundle.rget[target] = i
    return i
end

---@type fun(object: ui.any_type, ctx: ui.compile.context, resources: ui.compile.static_res?): string?
local translate_type


---@type {[string]: (fun(t: table, context: ui.compile.context, r: ui.compile.static_res): string?)}
local translation_rules
translation_rules = {
    ['_nil'] = function(t, m, r)
        local out = '{'
        for k, v in pairs(t) do
            local key = '[' .. translate_type(k, m, r) .. ']'
            local value = translate_type(v, m, r)
            if value == nil then return nil end
            out = out .. key .. '=' .. value .. ','
        end
        out = out .. '}'
        return out
    end,
    ---@param t ui.ast.binop
    ['ui.ast.binop'] = function(t, m, r)
        -- Binary operator.
        return translate_type(t.left, m, r) .. ' ' .. t.op .. ' ' .. translate_type(t.right, m, r)
    end,
    ---@param t ui.compiled.param
    ['ui.compiled.param'] = function(t, m, r)
        return 'options[' .. translate_type(t.name, m, r) .. ']'
    end,
    ---@param t ui.compiled.const
    ['ui.compiled.const'] = function(t, m, r)
        return translate_type(types._static(res_register(r, t.value)), m, r)
    end,
    ---@param t ui.compiled._static
    ['ui.compiled._static'] = function(t, m, r)
        return '_RESOURCES[' .. t.id .. ']'
    end,
    ---@param t ui.ast.unop
    ['ui.ast.unop'] = function(t, m, r)
        return t.op .. translate_type(t.target, m, r)
    end,

    ---@param t ui.ref_type
    ['ui.ref'] = function(t, m, r)
        if m.stage < 2 then return nil end
        return m.local_context .. '[' .. translate_type(t.name, m, r) .. ']'
    end,

    ---@param t ui.lazy_type
    ['ui.lazy'] = function(t, m, r)
        runtime.assert_const()
        local builder_id = res_register(r, t.builder)
        return translate_type(types._static(builder_id), m, r) .. '()'
    end,
}

---@param object ui.any_type
---@param ctx ui.compile.context
---@param resources ui.compile.static_res
---@return string | nil
function translate_type(object, ctx, resources)
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
        return action(object, ctx, resources)
    elseif type(object) == "boolean" then
        return object and "true" or "false"
    elseif statics[type(object)] then
        ---@cast object string|number|function
        if type(object) == "number" and object % 1 == 0 then
            return tostring(object)
        end
        return translate_type(types._static(res_register(resources, object)), ctx, resources)
    end
    error('Don\'t know how to deal with ' .. type(object))
end

---@class ui.compile.options
---@field headers? string
---@field footers? string
---@field _parent_varn? string
---@field log_debug? boolean
---@field child? boolean
---@field _local_context? string

---@class ui.compile.options.concrete : ui.compile.options
---@field headers string
---@field footers string
---@field _parent_varn string
---@field log_debug boolean
---@field child boolean
---@field _local_context string

---@type ui.compile.options.concrete
local defaults = {
    headers = [[
        ---@param parent LuaGuiElement
        ---@param options {[string]: any}
        ---@return LuaGuiElement
        return function(parent, options)
            local unames = {}
    ]],
    footers = [[
        end
    ]],
    _parent_varn = 'parent',
    _local_context = 'ctx_0',
    log_debug = false,
    child = false,
}

local nonruntime_element_count = 0

---@param tack boolean?
local function counter(tack)
    if runtime.is_runtime() then
        global.element_counter = global.element_counter or 0
        global.element_counter = global.element_counter + 1
        if tack then return 'r' .. global.element_counter end
        return global.element_counter
    else
        nonruntime_element_count = nonruntime_element_count + 1
        return nonruntime_element_count
    end
end

---@diagnostic disable: missing-return

---Compile a ElemSpec to Lua code.
---@param target ui.ElementSpec
---@param options ui.compile.options?
---@param res ui.compile.static_res?
---@return fun(parent: LuaGuiElement, options: {[string]: any}): LuaGuiElement compiled compiled function. callable
---@return string source source code
local function compile(target, options, res)
    res = res or {
        set = {},
        rget = {}
    }
    local opts = setmetatable(options or {}, { __index = defaults }) --[[@as ui.compile.options.concrete]]

    local direct = {}
    for k, v in pairs(target) do
        if not spec.non_ui_add_names[k] then
            direct[k] = v
        end
    end

    -- Create element.
    local output = ""
    local context_name = opts._local_context
    local need_new_ctx_header = not opts.child
    if target.isolate then
        context_name = 'ctx_' .. counter(true)
        need_new_ctx_header = true
    end
    if need_new_ctx_header then
        output = output .. 'local ' .. context_name .. ' = {}\n'
    end
    local generate_name = target.type:gsub("[^a-zA-Z]", "") .. '_' .. counter(true)

    ---@type ui.compile.context
    local ctx = {
        stage = 1,
        local_context = context_name
    }
    local create_elem = 'local ' ..
        generate_name .. ' = ' .. opts._parent_varn .. '.add(' .. translate_type(direct, ctx, res) .. ')\n'
    output = output .. create_elem

    if target.uname then
        output = output ..
        context_name .. '[' .. translate_type(target.uname, ctx, res) .. '] = ' .. generate_name .. '\n'
    end

    local stage2_styles = {}
    local stage2_props = {}

    for k, v in pairs(target.s or {}) do
        local value = translate_type(v, ctx, res)
        if value == nil then
            stage2_styles[k] = v
        else
            output = output .. generate_name .. '.style.' .. k .. ' = ' .. value .. '\n'
        end
    end
    for k, v in pairs(target.x or {}) do
        local value = translate_type(v, ctx, res)
        if value == nil then
            stage2_props[k] = v
        else
            output = output .. generate_name .. '.' .. k .. ' = ' .. value .. '\n'
        end
    end

    ---@type ui.compile.options
    local child_overlay = {
        log_debug = false,
        child = true,
        _local_context = context_name
    }

    for k, v in pairs(target.c or {}) do
        local _, child = compile(v, setmetatable(child_overlay, { __index = opts }), res)
        output = output .. child .. '\n'
    end

    if table_size(stage2_styles) > 0 or table_size(stage2_props) > 0 then
        output = output .. '--[[ Stage 2 initialization for ' .. generate_name .. ' ]]\n'
        ctx.stage = 2
        for k, v in pairs(stage2_styles) do
            output = output .. generate_name .. '.style.' .. k .. ' = ' .. translate_type(v, ctx, res) .. '\n'
        end
        for k, v in pairs(stage2_props) do
            output = output .. generate_name .. '.' .. k .. ' = ' .. translate_type(v, ctx, res) .. '\n'
        end
    end

    if opts.log_debug then
        log(output)
        -- log(serpent.block(res))
    end
    return function() end, output
end

---@param target ui.ElementSpec
---@param options ui.compile.options?
---@param res ui.compile.static_res?
local function compile2(target, options, res)
    res = res or {
        set = {},
        rget = {}
    }
    local opts = setmetatable(options or {}, { __index = defaults }) --[[@as ui.compile.options.concrete]]
    ---@type { [ui.ElementSpec]: string }
    local references = {}
    ---@type { spec: ui.ElementSpec, parent_varn: string }
    local sub_contexts = {}
    local output = ""

    local context_name = opts._local_context
    output = output .. "local " .. context_name .. " = {}\n--[[ stage 1 init for " .. context_name .. " ]]\n"

    local ctx = { stage = 1, local_context = context_name }

    ---@param struct ui.ElementSpec
    ---@param parent_name string?
    local function build_tree(struct, parent_name)
        parent_name = parent_name or opts._parent_varn
        local generate_name = target.type:gsub("[^a-zA-Z]", "") .. '_' .. counter(true)
        
        local direct = {}
        for k, v in pairs(struct) do
            if not spec.non_ui_add_names[k] then
                direct[k] = v
            end
        end

        if struct.handlers then
            direct.tags = direct.tags or {}
            direct.tags.handlers = struct.handlers
        end
        output = output .. "local " .. generate_name .. " = " .. parent_name .. ".add(" .. translate_type(direct, ctx, res) .. ")\n"

        if struct.uname then
            output = output .. context_name .. "[" .. translate_type(struct.uname, ctx, res) .. "] = " .. generate_name .. "\n"
        end

        for _, child in ipairs(struct.c or {}) do
            if child.isolate then
                sub_contexts[#sub_contexts + 1] = {
                    spec = child,
                    parent_varn = generate_name
                }
            else
                build_tree(child, generate_name)
            end
        end
    end

    build_tree(target)

    if opts.log_debug then
        log(output)
        log(serpent.block(res.set))
    end
end

---@diagnostic enable: missing-return
return {
    compile = compile,
    translate_type = translate_type,
    compile2 = compile2
}
