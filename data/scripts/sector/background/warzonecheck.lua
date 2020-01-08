local galaxyMapQoL_declareWarZone, galaxyMapQoL_undeclareWarZone, galaxyMapQoL_onRestoredFromDisk -- server, extended functions


if onServer() then


galaxyMapQoL_declareWarZone = WarZoneCheck.declareWarZone
function WarZoneCheck.declareWarZone(...)
    local sector = Sector()
    if not sector:getValue("war_zone") then
        local sx, sy = sector:getCoordinates()
        local status = Galaxy():invokeFunction("galaxymapqol.lua", "setWarZoneData", sx, sy, true)
        if status ~= 0 then
            eprint("[ERROR][GalaxyMapQoL]: declareWarZone - failed to call setWarZoneData: "..status)
        end
    end

    galaxyMapQoL_declareWarZone(...)
end

galaxyMapQoL_undeclareWarZone = WarZoneCheck.undeclareWarZone
function WarZoneCheck.undeclareWarZone(...)
    local sector = Sector()
    if sector:getValue("war_zone") then
        local sx, sy = sector:getCoordinates()
        local status = Galaxy():invokeFunction("galaxymapqol.lua", "setWarZoneData", sx, sy, false)
        if status ~= 0 then
            eprint("[ERROR][GalaxyMapQoL]: undeclareWarZone - failed to call setWarZoneData: "..status)
        end
    end

    galaxyMapQoL_undeclareWarZone(...)
end

galaxyMapQoL_onRestoredFromDisk = WarZoneCheck.onRestoredFromDisk
function WarZoneCheck.onRestoredFromDisk(...)
    local sector = Sector()
    local sx, sy = sector:getCoordinates()
    local status = Galaxy():invokeFunction("galaxymapqol.lua", "setWarZoneData", sx, sy, sector:getValue("war_zone"))
    if status ~= 0 then
        eprint("[ERROR][GalaxyMapQoL]: onRestoredFromDisk - failed to call setWarZoneData: "..status)
    end

    galaxyMapQoL_onRestoredFromDisk(...)
end


end