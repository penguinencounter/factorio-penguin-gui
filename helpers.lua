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

---What's the handlers table named?
local function get_handler_id()
    return "event_handlers/" .. script.mod_name
end

return {
    fill_icon_set = fill_icon_set,
    get_handler_id = get_handler_id
}
