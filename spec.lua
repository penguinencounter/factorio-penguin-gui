local events = require 'events'

---@alias ui.ElementSpec.events {[ui.EventName]: string}

---@class ui.ElementSpec._base
---@field c? ui.ElementSpec[] List of child elements.
---@field s? ui.d.StyleOptional Style modifications. Any nil or unset fields will be ignored.
---@field x? {[string]: any} Additional properties to apply to the element.
---@field isolate? boolean Begin a new isolation context. This allows assigning new unique names, but previously assigned names will remain available (or overwritten.)
---@field uname? string This element's unique name in this isolation context.
---@field handlers? ui.ElementSpec.events
local ElementSpec = {}

---@param of ui.ElementSpec
---@return ui.ElementSpec
function ElementSpec.new(of)
    of = of or {}
    if of.c then
        for i, v in ipairs(of.c) do
            of.c[i] = ElementSpec.new(v)
        end
    end
    return setmetatable(of, ElementSpec)
end

---@param event_name ui.EventName
---@param handler string|ui.Handler
---@param can_overwrite? boolean
function ElementSpec:on(event_name, handler, can_overwrite)
    self.handlers = self.handlers or {}
    if self.handlers[event_name] and not can_overwrite then
        error("handler for " .. event_name .. " already exists")
    end
    if type(handler) == "string" then
        self.handlers[event_name] = handler
    elseif type(handler) == "function" then
        local name = event_name
        if self.uname or self.name then
            name = (self.uname or self.name) .. "_" .. name
        end
        if self.type then
            name = self.type .. "_" .. name
        end
        self.handlers[event_name] = events.register(handler, name, "rename")
    else
        error("handler must be a function (if const) or a handler ID")
    end
    return self
end

---@param el ui.ElementSpec
---@return ui.ElementSpec
function ElementSpec:add(el)
    self.c = self.c or {}
    self.c[#self.c + 1] = ElementSpec.new(el)
    return el
end

---Add multiple elements to the current element.
---
---**Note:** This function returns the current element, *not the added elements*.
---@param els ui.ElementSpec[]
---@return ui.ElementSpec
function ElementSpec:adds(els)
    for _, el in ipairs(els) do
        self:add(el)
    end
    return self
end

---Update style information. Not named 'style' due to name conflicts with the `style` property to `LuaGuiElement.add`.
---@param self ui.ElementSpec
---@param style_opts ui.d.StyleOptional
---@return ui.ElementSpec
function ElementSpec:sty(style_opts)
    for k, v in pairs(style_opts) do
        self.s = self.s or {}
        self.s[k] = v
    end
    return self
end

ElementSpec.__index = ElementSpec

---@alias ui.ElementSpec (LuaGuiElement.add_param|ui.ElementSpec._base)

local non_ui_add_names = {
    c = true,
    x = true,
    s = true,
    uname = true,
    isolate = true,
    handlers = true
}

return {
    ElementSpec = ElementSpec,
    non_ui_add_names = non_ui_add_names,
}
