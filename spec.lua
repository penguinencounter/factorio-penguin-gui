local events = require 'ui_events'

---@class ui.IconSetPartial
---@field default SpritePath
---@field hovered? SpritePath
---@field clicked? SpritePath

---@class ui.IconSet
---@field default SpritePath
---@field hovered SpritePath
---@field clicked SpritePath


---Turn a partial IconSet into a completed IconSet.
---@param base ui.IconSetPartial | ui.IconSet
---@return ui.IconSet
local function fill_icon_set(base)
    ---@type ui.IconSet
    return {
        default = base.default,
        hovered = base.hovered or base.default,
        clicked = base.clicked or base.hovered or base.default
    }
end


---@alias ui.ElementSpec.events {[ui.EventName]: integer}

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
---@param handler integer|ui.Handler
---@param can_overwrite? boolean
function ElementSpec:on(event_name, handler, can_overwrite)
    self.handlers = self.handlers or {}
    if self.handlers[event_name] and not can_overwrite then
        error("handler for " .. event_name .. " already exists")
    end
    if type(handler) == "number" then
        self.handlers[event_name] = handler
    elseif type(handler) == "function" then
        self.handlers[event_name] = events.register(handler)
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
    fill_icon_set = fill_icon_set
}