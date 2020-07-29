package.path = package.path .. ";data/scripts/lib/?.lua"

-- namespace GalaxyMapQoL
GalaxyMapQoL = {}

local Azimuth, Config, Log, Integration, data, allianceIcons, allianceIndex, allianceLastRequest, isAllianceDataSynced, warZoneTimestamp -- server
local icons = {"empty", "adopt", "alliance", "anchor", "bag", "bug-report", "cattle", "checkmark", "clockwise-rotation", "cog", "crew", "cross-mark", "diamonds", "domino-mask", "electric", "fighter", "look-at", "flying-flag", "halt", "health-normal", "hourglass", "inventory", "move", "round-star", "select", "shield", "trash-can", "unchecked", "vortex"} -- server

if onClient() then


GalaxyMapQoL = include("galaxymapqolclient")


else -- onServer


include("callable")
Azimuth, Config, Log = unpack(include("galaxymapqolinit"))
Integration = include("GalaxyMapQoLIntegration")

data = { playerIcons = {}, playerIconsCount = 0 }
allianceIcons = {}
allianceIndex = -1
allianceLastRequest = -1
isAllianceDataSynced = false
warZoneTimestamp = -1 -- last time player requested war zone data

function GalaxyMapQoL.initialize()
    local arr = {}
    -- custom icons
    for i = 1, #Integration do
        arr[Integration[i]] = true
    end
    -- reformat icons
    for i = 1, #icons do
        arr[icons[i]] = true
    end
    icons = arr
end

function GalaxyMapQoL.secure()
    return data
end

function GalaxyMapQoL.restore(_data)
    if _data then
        data = _data
    end
end

function GalaxyMapQoL.sync(isInit)
    if isInit then
        invokeClientFunction(Player(), "sync", true, data.playerIcons)
    else -- alliance data
        GalaxyMapQoL.requestAllianceData()
        if not isAllianceDataSynced then
            invokeClientFunction(Player(), "sync", true, nil, allianceIcons)
            isAllianceDataSynced = true
        end
    end
end
callable(GalaxyMapQoL, "sync")

function GalaxyMapQoL.syncWarZones()
    local now = appTime()
    local player = Player()
    if Server().players == 1 or warZoneTimestamp + Config.HazardZoneRequestInterval <= now then
        warZoneTimestamp = now
        local status, syncedData = Galaxy():invokeFunction("galaxymapqol.lua", "getWarZoneData")
        if status ~= 0 or syncedData == nil then
            Log:Error("syncWarZones failed: %s, %s", tostring(status), tostring(syncedData == nil))
        else
            local knownWarzones = {}
            local uniqueSectors = {}
            local x_y
            for i, vec in ipairs({player:getKnownSectorCoordinates()}) do
                x_y = vec.x..'_'..vec.y
                if syncedData[x_y] then
                    knownWarzones[#knownWarzones+1] = {vec.x, vec.y}
                    uniqueSectors[x_y] = true
                end
            end
            if player.alliance then
                for i, vec in ipairs({player.alliance:getKnownSectorCoordinates()}) do
                    x_y = vec.x..'_'..vec.y
                    if syncedData[x_y] and not uniqueSectors[x_y] then
                        knownWarzones[#knownWarzones+1] = {vec.x, vec.y}
                    end
                end
            end
            Log:Debug("syncWarZones: %s", knownWarzones)
            invokeClientFunction(player, "syncWarZones", knownWarzones)
        end
    else
        Log:Debug("syncWarZones - request ignored due to the time restrictions")
    end
end
callable(GalaxyMapQoL, "syncWarZones")

function GalaxyMapQoL.requestAllianceData()
    -- sync alliance icons
    local player = Player()
    if allianceIndex ~= player.allianceIndex then -- if player changed alliance, force update
        allianceLastRequest = -1
        allianceIndex = player.allianceIndex
    elseif Server().players == 1 then -- no delay in singleplayer
        allianceLastRequest = -1
    end
    if player.alliance then
        local status, syncedData, newTimestamp = Galaxy():invokeFunction("galaxymapqol.lua", "getAllianceData", player.allianceIndex, allianceLastRequest)
        if status ~= 0 or syncedData == nil or newTimestamp == nil then
            Log:Error("requestAllianceData failed: %s, %s, %s", tostring(status), tostring(syncedData == nil), tostring(newTimestamp))
            isAllianceDataSynced = true
        else
            allianceLastRequest = newTimestamp
            if syncedData ~= false then
                Log:Debug("requestAllianceData: %s, %f", syncedData, allianceLastRequest)
                allianceIcons = syncedData
                isAllianceDataSynced = false
            else
                Log:Debug("requestAllianceData: false, %f", allianceLastRequest)
            end
        end
    end
end

function GalaxyMapQoL.setSectorIcon(isAlliance, x, y, icon, color)
    x = tonumber(x)
    y = tonumber(y)
    if x == nil or y == nil or x < -499 or x > 500 or y < -499 or y > 500
      or (icon ~= nil and type(icon) ~= "string")
      or (color ~= nil and type(color) ~= "number") then
        return
    end
    local player = Player()
    if icon then
        if not icons[icon] then
            player:sendChatMessage("", 1, "Incorrect icon"%_t)
            return
        end
        -- fixing color
        if not color then
            color = ColorRGB(1, 1, 1):toInt()
        end
        color = ColorInt(color)
        color.a = 1
        if color.value < 0.5 then
            color.value = 0.5
        end
        color = color:toInt()
    end

    local x_y = x.."_"..y
    if not isAlliance then
        local sector = data.playerIcons[x_y]
        if not icon then -- remove
            if sector then
                data.playerIcons[x_y] = nil
                data.playerIconsCount = data.playerIconsCount - 1
            end
        elseif sector then -- change
            data.playerIcons[x_y] = { x, y, icon, color }
        else -- add
            if data.playerIconsCount >= Config.IconsPerPlayer then
                player:sendChatMessage("", 1, "Maximum amount of icons reached"%_t)
                return
            end
            data.playerIcons[x_y] = { x, y, icon, color }
            data.playerIconsCount = data.playerIconsCount + 1
        end
        if data.playerIcons[x_y] then
            invokeClientFunction(player, "sync", false, data.playerIcons[x_y])
        else
            invokeClientFunction(player, "sync", false, {x, y})
        end
    else -- Alliance
        if not player.alliance then return end
        if not player.alliance:hasPrivilege(player.index, AlliancePrivilege.EditMap) then
            player:sendChatMessage("", 1, "You don't have permission to do that in the name of your alliance."%_t)
            return
        end
        local status, hasIcon, newTimestamp = Galaxy():invokeFunction("galaxymapqol.lua", "setAllianceData", player.index, player.allianceIndex, x, y, icon, color, allianceLastRequest)
        if status ~= 0 or newTimestamp == nil then
            Log:Error("setSectorIcon (alliance) failed: %s, %s, %s", tostring(status), tostring(hasIcon), tostring(newTimestamp))
        elseif hasIcon ~= nil then
            allianceLastRequest = newTimestamp
            Log:Debug("setSectorIcon (alliance): %s, %f", tostring(hasIcon), allianceLastRequest)
            if hasIcon then
                invokeClientFunction(player, "sync", false, nil, {x, y, icon, color})
            else
                invokeClientFunction(player, "sync", false, nil, {x, y})
            end
        end
    end
end
callable(GalaxyMapQoL, "setSectorIcon")


end