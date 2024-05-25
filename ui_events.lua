-- Stateless event handling based on flib's handler system.
local is_runtime = false

---@type ui.Handler[]
local handlers = {}

local function desyncable()
    if is_runtime then
        error("This function is not available at runtime.")
    end
end

---@alias ui.Handler fun(event: ui.GUIEvent)

---@param func ui.Handler
---@return integer
local function register(func)
    desyncable()
    table.insert(handlers, func)
    return #handlers
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
    desyncable()

    ---@param event_data ui.GUIEvent
    return function(event_data)
        if not (event_data.element and event_data.element.valid) then return end
        local element = event_data.element
        ---@cast element -nil
        local target = element.tags and element.tags.handlers and element.tags.handlers[name]
        if not target then return end
        if type(target) == "function" then error("Somehow stored a function on LuaGuiElement.tags and didn't crash. Still invalid - try uie.reg(fn).") end
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


---@class ui.ui_events_module
return {
    desyncable = desyncable,
    is_runtime = function() return is_runtime end,
    register = register,
}
