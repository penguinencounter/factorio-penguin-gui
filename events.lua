local runtime = require "runtime"
-- Stateless event handling based on flib's handler system.

---@type ui.Handler[]
local handlers = {}

---@alias ui.Handler fun(event: ui.GUIEvent)

---@param func ui.Handler
---@param name? string
---@param strategy nil | "fail" | "overwrite" | "rename"
---@return string
local function register(func, name, strategy)
    strategy = strategy or "fail"
    runtime.assert_const()
    if not name then
        if not debug.getinfo then error("A name must be provided to register this event handler", 2) end
        local fninf = debug.getinfo(func)
        name = fninf.short_src .. ":" .. fninf.linedefined
        if not name then
            error(
                "Can't generate a name for this unnamed function - pass `name` as param 2 to register, or name the function",
                2)
        end
        runtime.warn("ui_events.register() missing 'name', using source location instead: `" ..
            name .. "` - you may have reference errors when interacting after updating the mod")
    end

    local namespaced = script.mod_name .. "/" .. name
    if handlers[namespaced] then
        if strategy == "fail" then
            error("Handler " .. namespaced .. " already exists")
        elseif strategy == "overwrite" then
            handlers[namespaced] = func
            return namespaced
        elseif strategy == "rename" then
            local i = 1
            local new_name = namespaced
            while handlers[new_name] do
                new_name = namespaced .. "_" .. i
                i = i + 1
            end
            namespaced = new_name
        else
            error("Invalid strategy: " .. strategy)
        end
    end
    handlers[namespaced] = func
    return namespaced
end


local function freeze()
    is_runtime = true
end

---@alias ui.GUIEvent
--- | EventData.on_gui_checked_state_changed
--- | EventData.on_gui_click
--- | EventData.on_gui_closed
--- | EventData.on_gui_confirmed
--- | EventData.on_gui_elem_changed
--- | EventData.on_gui_hover
--- | EventData.on_gui_leave
--- | EventData.on_gui_location_changed
--- | EventData.on_gui_opened
--- | EventData.on_gui_selected_tab_changed
--- | EventData.on_gui_selection_state_changed
--- | EventData.on_gui_switch_state_changed
--- | EventData.on_gui_text_changed
--- | EventData.on_gui_value_changed

---@alias ui.EventName
--- | "checked_state_changed"
--- | "click"
--- | "closed"
--- | "confirmed"
--- | "elem_changed"
--- | "hover"
--- | "leave"
--- | "location_changed"
--- | "opened"
--- | "selected_tab_changed"
--- | "selection_state_changed"
--- | "switch_state_changed"
--- | "text_changed"
--- | "value_changed"

local function Dispatcher(name)
    runtime.assert_const()

    ---@param event_data ui.GUIEvent
    return function(event_data)
        if not (event_data.element and event_data.element.valid) then return end
        local element = event_data.element
        ---@cast element -nil
        local target = element.tags and element.tags.handlers and element.tags.handlers[name]
        if not target then return end
        if type(target) == "function" then
            error(
                "Somehow stored a function on LuaGuiElement.tags and didn't crash. Still invalid - try uie.reg(fn).")
        end
        local actual = handlers[target]
        if not actual then error("Broken reference to handler: " .. tostring(target)) end
        actual(event_data)
    end
end

local gui_events = {}
do
    for k, v in pairs(defines.events) do
        local trimmed_name = k:match("^on_gui_(.*)")
        if trimmed_name then
            gui_events[trimmed_name] = v
        end
    end
    for name, evid in pairs(gui_events) do
        if not script.get_event_handler(evid) then
            script.on_event(evid, Dispatcher(name))
        end
    end
end

local eval_handler = register(function (event)
    local element = event.element
    if not element then return end
    if not element.tags then return end
    local action = element.tags.action --[[@as string?]]
    if not action then return end
    local fn, err = load(action)
    if not fn then
        runtime.warn("Error loading string-based action: " .. err)
        return
    end
    local ok, err = pcall(fn, event)
    if not ok then
        runtime.warn("Error running string-based action: " .. err)
    end
end)


---@class ui.ui_events_module
return {
    register = register,
    eval_handler = eval_handler
}
