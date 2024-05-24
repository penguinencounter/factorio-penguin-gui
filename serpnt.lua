local function block(something, indn)
    indn = indn or 0
    local indent = string.rep(" ", indn)
    if type(something) == "table" then
        local result = "{"
        for k, v in pairs(something) do
            result = result .. "\n" .. indent .. "    " .. tostring(k) .. " = " .. block(v, indn + 4) .. ","
        end
        return result .. "\n" .. indent .. "}"
    else
        return tostring(something)
    end
end

return {
    block = block
}