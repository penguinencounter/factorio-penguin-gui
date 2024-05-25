local function block(something, maxdepth, indn)
    maxdepth = maxdepth or 3
    local maxindn = maxdepth * 4
    indn = indn or 0
    if maxindn > 0 and indn >= maxindn then
        return "..."
    end
    local indent = string.rep(" ", indn)
    if type(something) == "table" then
        local result = "{"
        for k, v in pairs(something) do
            result = result .. "\n" .. indent .. "    " .. tostring(k) .. " = " .. block(v, maxdepth, indn + 4) .. ","
        end
        return result .. "\n" .. indent .. "}"
    else
        return '[' .. type(something) .. '] ' .. tostring(something)
    end
end

return {
    block = block
}