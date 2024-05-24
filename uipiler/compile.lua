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

local function translate_type()

end

---Compile a ElemSpec to Lua code.
---@param target ui.ElementSpec
---@param options ui.compile.options
---@return fun(parent: LuaGuiElement, options: {[string]: any}): LuaGuiElement compiled compiled function. callable
---@return string source source code
local function compile(target, options)
    ---@type ui.compile.options.concrete
    local opts = setmetatable(options or {}, {__index = defaults})


end
return compile
