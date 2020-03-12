package.path = package.path .. ";data/scripts/lib/?.lua"
local Azimuth, Config, Log = unpack(include("galaxymapqolinit"))

local allianceData = {}
local warZoneData = {}
local restoreHappened = false

local function loadAllianceData(allianceIndex)
    if not allianceData[allianceIndex] then -- load data
        local data = Azimuth.loadConfig("AllianceData_"..allianceIndex, { allianceIcons = { default = {} }, allianceIconsCount = { default = 0 } }, false, "GalaxyMapQoL")
        -- fix icon errors from previous versions
        local iconsAmount = 0
        for key, sector in pairs(data.allianceIcons) do
            if sector[3] then
                iconsAmount = iconsAmount + 1
            else -- remove
                data.allianceIcons[key] = nil
            end
        end
        data.allianceIconsCount = iconsAmount
        data.lastUpdated = appTime() -- force update
        allianceData[allianceIndex] = data
    end
end

-- PREDEFINED --

function initialize()
    Log:Debug("Galaxy script initialized")
end

function getUpdateInterval()
    return 60
end

function update(timeStep)
    local now = appTime()
    for allianceIndex, data in pairs(allianceData) do
        if data.lastUsed + 300 < now then -- unload data that wasn't accessed for 5 minutes
            Log:Debug("Unloading alliance %i (unused for 5 minutes)", allianceIndex)
            Azimuth.saveConfig("AllianceData_"..allianceIndex, { allianceIcons = data.allianceIcons, allianceIconsCount = data.allianceIconsCount }, nil, false, "GalaxyMapQoL")

            allianceData[allianceIndex] = nil
        end
    end
end

function secure()
    for allianceIndex, data in pairs(allianceData) do
        Log:Debug("Unloading alliance %i (shutdown)", allianceIndex)
        Azimuth.saveConfig("AllianceData_"..allianceIndex, { allianceIcons = data.allianceIcons, allianceIconsCount = data.allianceIconsCount }, nil, false, "GalaxyMapQoL")
    end
    return { warZones = warZoneData }
end

function restore(data)
    if data and data.warZones then
        -- apply new data that came before restore
        for k, v in pairs(warZoneData) do
            if v then
                data.warZones[k] = v
            else
                data.warZones[k] = nil
            end
        end
        warZoneData = data.warZones
    else -- clear unlikely false-s on the first launch
        for k, v in pairs(warZoneData) do
            if not v then
                warZoneData[k] = nil
            end
        end
    end
    restoreHappened = true
end

-- FUNCTIONS --

function getAllianceData(allianceIndex, lastRequest)
    loadAllianceData(allianceIndex)

    local data = allianceData[allianceIndex]
    data.lastUsed = appTime()

    Log:Debug("Galaxy - getAllianceData: %f > %f", data.lastUpdated, lastRequest)
    if data.lastUpdated > lastRequest then
        return data.allianceIcons, data.lastUsed
    end
    return false, data.lastUsed -- no updates since the last request
end

function setAllianceData(playerIndex, allianceIndex, x, y, icon, color, lastRequest)
    loadAllianceData(allianceIndex)
    
    local data = allianceData[allianceIndex]
    local x_y = x.."_"..y
    local sector = data.allianceIcons[x_y]
    if not icon then -- remove
        if sector then
            data.allianceIcons[x_y] = nil
            data.allianceIconsCount = data.allianceIconsCount - 1
        end
    elseif sector then -- change
        data.allianceIcons[x_y] = { x, y, icon, color }
    else -- add
        if data.allianceIconsCount >= Config.IconsPerAlliance then
            Player(playerIndex):sendChatMessage("", 1, "Maximum amount of icons reached"%_t)
            return
        end
        data.allianceIcons[x_y] = { x, y, icon, color }
        data.allianceIconsCount = data.allianceIconsCount + 1
    end
    local updatesAvailable = false
    if data.lastUpdated > lastRequest then -- updates from other players are available
        updatesAvailable = true
    end
    data.lastUsed = appTime()
    data.lastUpdated = data.lastUsed
    if not updatesAvailable then
        lastRequest = data.lastUpdated -- no need to fetch the whole map just to get your own updates
    end

    if data.allianceIcons[x_y] then
        return true, lastRequest
    else
        return false, lastRequest
    end
end

function getWarZoneData()
    return warZoneData
end

function setWarZoneData(x, y, state)
    Log:Debug("Galaxy - setWarZoneData: (%i:%i) -> %s", x, y, tostring(state == true))
    if state == true then
        warZoneData[x..'_'..y] = {x, y}
    else
        if restoreHappened then
            warZoneData[x..'_'..y] = nil
        else -- before restore happened
            warZoneData[x..'_'..y] = false
        end
    end
end