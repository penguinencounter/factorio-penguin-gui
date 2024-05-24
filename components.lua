local events       = require "ui.ui_events"
local blocks       = {}

---@class ui._SetNil

---sentinel value. represents clearing the value when passed to the style options.
---@type ui._SetNil
local NIL          = {} --[[@as ui._SetNil]]

---@type metatable
local ref_typeinfo = {
    _type = "ui.ref"
}

---@class ui.ref_type
---@field uname string

---Represents a LuaGuiElement in the same isolation context by unique name.
---
---Set {uname: string} to make an element available.
---@return ui.ref_type
local function ref(uname)
    return setmetatable({ uname = uname }, ref_typeinfo)
end

---@type metatable
local lazy_typeinfo = { _type = "ui.lazy" }
---@class ui.lazy_type
---@field fun fun(): any

---Represents a value that is not yet resolved.
---@param fun fun(): any
---@return ui.lazy_type
local function lazy(fun)
    events.desyncable()
    return setmetatable({ fun = fun }, lazy_typeinfo)
end

---@alias ui.labeler fun(name: string): string

---Create a labeler.
---@param base string | ui.labeler
local function create_labeler(base)
    ---@type string
    local base_str
    if type(base) == "function" then
        base_str = base("")
    else
        base_str = base
    end
    return function(leaf)
        return base_str .. "_" .. leaf
    end
end

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
local ElSpec = {}

---@param of ui.ElementSpec
---@return ui.ElementSpec
function ElSpec.new(of)
    of = of or {}
    if of.c then
        for i, v in ipairs(of.c) do
            of.c[i] = ElSpec.new(v)
        end
    end
    return setmetatable(of, ElSpec)
end

---@param event_name ui.EventName
---@param handler integer|ui.Handler
---@param can_overwrite? boolean
function ElSpec:on(event_name, handler, can_overwrite)
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
function ElSpec:add(el)
    self.c = self.c or {}
    self.c[#self.c + 1] = ElSpec.new(el)
    return el
end

---Update style information. Not named 'style' due to name conflicts with the `style` property to `LuaGuiElement.add`.
---@param self ui.ElementSpec
---@param style_opts ui.d.StyleOptional
---@return ui.ElementSpec
function ElSpec:sty(style_opts)
    for k, v in pairs(style_opts) do
        self.s = self.s or {}
        self.s[k] = v
    end
    return self
end

ElSpec.__index = ElSpec

---@alias ui.ElementSpec (LuaGuiElement.add_param|ui.ElementSpec._base)

---Label element.
---@param text string | ui.lazy_type
---@param style? string
---@param name? string
function blocks.label(text, style, name)
    return ElSpec.new {
        type = "label",
        caption = text,
        style = style,
        name = name
    }
end

---Vertical orientation frame element with style.
---@param style_name string
---@param name? string
function blocks.vframe(style_name, name)
    return ElSpec.new {
        type = "frame",
        style = style_name,
        direction = "vertical",
        name = name
    }
end

---Horizontal orientation frame element with style.
---@param style_name string
---@param name? string
function blocks.hframe(style_name, name)
    return ElSpec.new {
        type = "frame",
        style = style_name,
        direction = "horizontal",
        name = name
    }
end

---Horizontal orientation flow.
---@param name? string
function blocks.hflow(name)
    return ElSpec.new {
        type = "flow",
        direction = "horizontal",
        name = name
    }
end

---Vertical orientation flow.
---@param name? string
function blocks.vflow(name)
    return ElSpec.new {
        type = "flow",
        direction = "vertical",
        name = name
    }
end

---@param options { h?: ScrollPolicy, v?: ScrollPolicy, name?: string }
function blocks.scroll(options)
    return ElSpec.new {
        type = "scroll-pane",
        name = options.name,
        horizontal_scroll_policy = options.h,
        vertical_scroll_policy = options.v
    }
end

---Minimal table.
---@param columns integer
---@param name? string
function blocks.table(columns, name)
    return ElSpec.new {
        type = "table",
        column_count = columns,
        name = name
    }
end

---Frame action button. Usually goes in the top right of a window.
---### Properties
---* **does not** provide an isolation context
---@param name string Element name
---@param icon SpritePath | ui.IconSetPartial Icon to display
---@param uname? string
---@return ui.ElementSpec
function blocks.WindowActionButton(name, icon, uname)
    ---@type ui.IconSet
    local iconset
    if type(icon) == "string" then
        iconset = fill_icon_set {
            default = icon
        }
    else
        iconset = fill_icon_set(icon)
    end
    return ElSpec.new {
        type = "sprite-button",
        style = "frame_action_button",
        name = name,
        sprite = iconset.default,
        hovered_sprite = iconset.hovered,
        clicked_sprite = iconset.clicked,
        uname = uname
    }
end

---Basic window with title, and some number of frame action buttons.
---### Properties
---* creates a new isolation context
---* provides `window` to contents
---* items in `frame_actions` are 2-deep (i.e. `fab.parent.parent` is `u:window`)
---@param name string
---@param window_label string
---@param frame_actions ui.ElementSpec[]
---@return ui.ElementSpec
function blocks.GenericWindow(name, window_label, frame_actions)
    local local_ns = create_labeler(name)
    ---@type ui.ElementSpec[]
    local titlebar_children = {
        {
            type = "label",
            style = "frame_title",
            caption = window_label,
            ignored_by_interaction = true,
            s = {
                vertically_stretchable = true,
                horizontally_squashable = true
            }
        },
        {
            type = "empty-widget",
            style = "draggable_space_header",
            ignored_by_interaction = true,
            s = {
                horizontally_stretchable = true,
                vertically_stretchable = true,
                height = 24,
                natural_height = 24
            }
        }
    }
    for _, val in ipairs(frame_actions) do
        titlebar_children[#titlebar_children + 1] = val
    end

    ---@type ui.ElementSpec
    return ElSpec.new {
        type = "frame",
        name = name,
        isolate = true,
        uname = "window",
        direction = "vertical",
        c = { {
            type = "flow",
            name = local_ns("titlebar"),
            direction = "horizontal",
            s = {
                horizontally_stretchable = true,
                horizontal_spacing = 8,
                vertically_stretchable = false,
            },
            x = {
                drag_target = ref "window"
            },
            c = titlebar_children
        } },
        x = {
            auto_center = true
        }
    }
end

local close_button_handler = events.register(function(event)
    local parent = event.element.parent and event.element.parent.parent
    if parent and parent.valid then
        parent.destroy()
    end
end)

---Window with a close button.
---@param name string
---@param window_label string
---@return ui.ElementSpec
function blocks.ClosableWindow(name, window_label)
    local local_ns = create_labeler(name)
    local base = blocks.GenericWindow(
        name, window_label, {
            blocks.WindowActionButton(
                local_ns("close"),
                {
                    default = "utility/close_white",
                    hovered = "utility/close_black"
                },
                "close"
            ):on("click", close_button_handler)
        }
    )
    return base
end

---Resolve a value, including any references (ref(...)) or NIL sentinels.
---@param value any
---@param unames { [string]: LuaGuiElement } | nil
---@return any, string
local function resolve_value(value, unames)
    if type(value) == "table" then
        if value == NIL then return nil, tostring(nil) end
        local mt = getmetatable(value)
        if mt == ref_typeinfo then
            if unames == nil then
                error("Cannot resolve ref() at this point, because there is no context available. "
                    .. "\nConsider putting this property in ElementSpec.x to defer resolution.")
            end
            ---@cast value ui.ref_type
            return unames[value.uname]
                or error("broken ref(...): no '" .. value.uname .. "' in context"),
                "ref to '" .. value.uname .. "'"
        elseif mt == lazy_typeinfo then
            ---@cast value ui.lazy_type
            local actual, actual_desc = resolve_value(value.fun(), unames)
            return actual, "lazy: " .. actual_desc
        else
            local new_table = {}
            for k, v in pairs(value) do
                new_table[k] = resolve_value(v, unames)
            end
            return new_table, "table(" .. table_size(new_table) .. ")"
        end
    else
        return value, tostring(value)
    end
end

---@param elspec ui.ElementSpec
local function auto_name(elspec)
    local c = 0
    ---@param e ui.ElementSpec
    local function inner(e)
        if not e.name then
            c = c + 1
            if events.is_runtime() then
                e.name = "__runtime_unnamed_ui_element_" .. c
            else
                e.name = "__unnamed_ui_element_" .. c
            end
        end
        if e.c then
            for _, subel in ipairs(e.c) do
                inner(subel)
            end
        end
    end
    inner(elspec)
end

local build, build_dry
do
    local non_ui_add_names = {
        c = true,
        x = true,
        s = true,
        uname = true,
        isolate = true,
        handlers = true
    }

    ---@param component ui.ElementSpec
    ---@param parent LuaGuiElement
    ---@param _unames? {[string]: LuaGuiElement}
    function build(component, parent, _unames)
        _unames = _unames or {}
        ---@type { spec: ui.ElementSpec, attach_to: LuaGuiElement }[]
        local sub_contexts = {}

        local name_counter = 0

        ---@param c ui.ElementSpec
        ---@param p LuaGuiElement
        local function build_tree(c, p)
            if not c.name then
                error("All components need to be assigned names. Use auto_name(...) to generate names.")
            end
            -- log("[ui.components] add " .. tostring(c.name) .. " to " .. tostring(p.name))

            local actualized = {}
            for k, v in pairs(c) do
                if not non_ui_add_names[k] then
                    actualized[k] = resolve_value(v, nil)
                end
            end
            if c.handlers then
                actualized.tags = actualized.tags or {}
                actualized.tags.handlers = c.handlers
            end
            local real = p.add(actualized --[[@as LuaGuiElement.add_param]])
            if c.uname then
                _unames[c.uname] = real
            end
            if c.c then
                for _, child in ipairs(c.c) do
                    if child.isolate then
                        sub_contexts[#sub_contexts + 1] = {
                            spec = child,
                            attach_to = real
                        }
                    else
                        build_tree(child, real)
                    end
                end
            end
        end

        build_tree(component, parent)

        ---Assign properties to elements in this context.
        ---@param c ui.ElementSpec
        ---@param p LuaGuiElement
        local function decorate_tree(c, p)
            -- all components need names
            if not c.name then
                error("no name assigned to component in decorate_tree!!")
            end
            local real = p[c.name]
            -- log("[ui.components] decorate " .. tostring(c.name))
            if c.s then
                for k, v in pairs(c.s) do
                    local val, desc = resolve_value(v, _unames)
                    -- log("  Style " .. tostring(k) .. " = " .. desc)
                    real.style[k] = val
                end
            end
            if c.x then
                for k, v in pairs(c.x) do
                    local val, desc = resolve_value(v, _unames)
                    -- log("  eXtra " .. tostring(k) .. " = " .. desc)
                    real[k] = val
                end
            end
            if c.c then
                for _, child in ipairs(c.c) do
                    if not child.isolate then
                        decorate_tree(child, real)
                    end
                end
            end
        end

        decorate_tree(component, parent)

        for _, sub_context in ipairs(sub_contexts) do
            local inner_unames = setmetatable({}, { __index = _unames })
            build(sub_context.spec, sub_context.attach_to, inner_unames)
        end
    end

    ---Compose the element. This function does not resolve special types - they will error when passed to Factorio.
    ---
    ---Contexts are ignored. Useful for building runtime components that don't have references to other objects.
    ---Names are not required.
    ---@param component ui.ElementSpec
    ---@param parent LuaGuiElement
    function build_dry(component, parent)
        local name_counter = 0

        ---@param c ui.ElementSpec
        ---@param p LuaGuiElement
        local function build_and_decorate_tree(c, p)
            local actualized = {}
            for k, v in pairs(c) do
                if not non_ui_add_names[k] then
                    actualized[k] = v
                end
            end
            if c.handlers then
                actualized.tags = actualized.tags or {}
                actualized.tags.handlers = c.handlers
            end
            local real = p.add(actualized --[[@as LuaGuiElement.add_param]])
            if c.s then
                for k, v in pairs(c.s) do
                    -- log("  Style " .. tostring(k) .. " = " .. desc)
                    real.style[k] = v
                end
            end
            if c.x then
                for k, v in pairs(c.x) do
                    -- log("  eXtra " .. tostring(k) .. " = " .. desc)
                    real[k] = v
                end
            end
            if c.c then
                for _, child in ipairs(c.c) do
                    build_and_decorate_tree(child, real)
                end
            end
        end

        build_and_decorate_tree(component, parent)
    end
end

---@class ui.components
return {
    NIL = NIL,
    ref = ref,
    lazy = lazy,
    blocks = blocks,
    build = build,
    build_dry = build_dry,
    auto_name = auto_name,
    ElementSpec = ElSpec,
}
