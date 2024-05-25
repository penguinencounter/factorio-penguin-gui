local events = require "ui_events"
local spec   = require 'spec'
local types  = require 'types'
local blocks = {}

local ElSpec = spec.ElementSpec

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
        iconset = spec.fill_icon_set {
            default = icon
        }
    else
        iconset = spec.fill_icon_set(icon)
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
            name = "titlebar",
            direction = "horizontal",
            s = {
                horizontally_stretchable = true,
                horizontal_spacing = 8,
                vertically_stretchable = false,
            },
            x = {
                drag_target = types.ref "window"
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
    local base = blocks.GenericWindow(
        name, window_label, {
            blocks.WindowActionButton(
                "close",
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

-- FIXME: it's broken :)
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
                if not spec.non_ui_add_names[k] then
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
                if not spec.non_ui_add_names[k] then
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
    blocks = blocks,
    build = build,
    build_dry = build_dry,
    auto_name = auto_name,
    ElementSpec = ElSpec,
}
