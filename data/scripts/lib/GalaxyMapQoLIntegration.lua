-- This file allows to add custom icons to Galaxy Map QoL.

local customIcons = {}

local function addIcons(...)
    local arg = table.pack(...)
    for i = 1, arg.n do
        customIcons[#customIcons + 1] = arg[i]
    end
end

--[[ Example:
-- One icon
addIcons("iconname")
-- Multiple icons
addIcons("iconname1", "iconname2", "iconname3")
]]

return customIcons