package.path = package.path .. ";data/scripts/lib/?.lua"

-- namespace GalaxyMapQoL
GalaxyMapQoL = {}

local Azimuth, config, data, allianceIcons, allianceIconsCount, allianceIndex, isAllianceDataSynced -- server
local icons = {"empty", "adopt", "alliance", "anchor", "bag", "bug-report", "cattle", "checkmark", "clockwise-rotation", "cog", "crew", "cross-mark", "diamonds", "domino-mask", "electric", "fighter", "look-at", "flying-flag", "halt", "health-normal", "hourglass", "inventory", "move", "round-star", "select", "shield", "trash-can", "unchecked", "vortex"} -- server

if onClient() then


GalaxyMapQoL = include("galaxymapqolclient")


else -- onServer


include("callable")
Azimuth = include("azimuthlib-basic")

data = { playerIcons = {}, playerIconsCount = 0 }
allianceIcons = {}
allianceIconsCount = 0
allianceIndex = -1
isAllianceDataSynced = false

function GalaxyMapQoL.initialize()
    local configOptions = {
      _version = { default = "1.0", comment = "Config version. Don't touch." },
      IconsPerPlayer = { default = 75, min = 0, format = "floor", comment = "How many icons player can have" },
      IconsPerAlliance = { default = 200, min = 0, format = "floor", comment = "How many icons alliance can have" },
    }
    local isModified
    config, isModified = Azimuth.loadConfig("GalaxyMapQoL", configOptions)
    if isModified then
        Azimuth.saveConfig("GalaxyMapQoL", config, configOptions)
    end

    local arr = {}
    for i = 1, #icons do
        arr[icons[i]] = true
    end
    icons = arr
    
    GalaxyMapQoL.requestAllianceData()
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

function GalaxyMapQoL.requestAllianceData()
    -- sync alliance icons
    local player = Player()
    if player.alliance then
        if allianceIndex ~= player.allianceIndex then
            local server = Server()
            local otherPlayer, status, syncedData
            for _, playerIndex in pairs({player.alliance:getMembers()}) do
                if playerIndex ~= player.index and server:isOnline(playerIndex) then
                    otherPlayer = Player(playerIndex)
                    if otherPlayer then
                        status, syncedData = otherPlayer:invokeFunction("galaxymapqol.lua", "getAllianceData")
                        if status ~= 0 then
                            eprint("[ERROR][GalaxyMapQoL]: requestAllianceData - player status", status)
                        else
                            break
                        end
                    end
                end
            end
            if syncedData then
                allianceIcons = syncedData.allianceIcons
                allianceIconsCount = syncedData.allianceIconsCount
            else -- load from disk
                syncedData = Azimuth.loadConfig("AllianceData_"..player.alliance.index, { allianceIcons = { default = {} }, allianceIconsCount = { default = 0 } }, false, "GalaxyMapQoL")
                allianceIcons = syncedData.allianceIcons
                allianceIconsCount = syncedData.allianceIconsCount
                -- fix icon errors from previous versions
                local iconsAmount = 0
                for key, sector in pairs(allianceIcons) do
                    if sector[3] then
                        iconsAmount = iconsAmount + 1
                    else -- remove
                        allianceIcons[key] = nil
                    end
                end
                if allianceIconsCount ~= iconsAmount then
                    allianceIconsCount = iconsAmoun
                    Azimuth.saveConfig("AllianceData_"..player.alliance.index, { allianceIcons = allianceIcons, allianceIconsCount = allianceIconsCount }, nil, false, "GalaxyMapQoL")
                end
            end
            allianceIndex = player.allianceIndex
            isAllianceDataSynced = false -- need to resync with client
        end
    end
end
callable(GalaxyMapQoL, "requestAllianceData")

function GalaxyMapQoL.getAllianceData()
    if allianceIndex == Player().allianceIndex then
        return { allianceIcons = allianceIcons, allianceIconsCount = allianceIconsCount }
    end
end

function GalaxyMapQoL.setAllianceData(sector, count)
    if sector[3] then -- change/add
        allianceIcons[sector[1].."_"..sector[2]] = sector
    else
        allianceIcons[sector[1].."_"..sector[2]] = nil -- remove
    end
    allianceIconsCount = count
    isAllianceDataSynced = false
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
            if data.playerIconsCount >= config.IconsPerPlayer then
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
        local sector = allianceIcons[x_y]
        if not icon then -- remove
            if sector then
                allianceIcons[x_y] = nil
                allianceIconsCount = allianceIconsCount - 1
            end
        elseif sector then -- change
            allianceIcons[x_y] = { x, y, icon, color }
        else -- add
            if allianceIconsCount >= config.IconsPerAlliance then
                player:sendChatMessage("", 1, "Maximum amount of icons reached"%_t)
                return
            end
            allianceIcons[x_y] = { x, y, icon, color }
            allianceIconsCount = allianceIconsCount + 1
        end
        if allianceIcons[x_y] then
            invokeClientFunction(player, "sync", false, nil, allianceIcons[x_y])
        else
            invokeClientFunction(player, "sync", false, nil, {x, y})
        end
        -- send updated data to other online players
        local server = Server()
        local otherPlayer, status
        for _, playerIndex in pairs({player.alliance:getMembers()}) do
            if playerIndex ~= player.index and server:isOnline(playerIndex) then
                otherPlayer = Player(playerIndex)
                if otherPlayer then
                    if allianceIcons[x_y] then
                        status = otherPlayer:invokeFunction("galaxymapqol.lua", "setAllianceData", allianceIcons[x_y], allianceIconsCount)
                    else
                        status = otherPlayer:invokeFunction("galaxymapqol.lua", "setAllianceData", {x, y}, allianceIconsCount)
                    end
                    if status ~= 0 then
                        eprint("[ERROR][GalaxyMapQoL]: setSectorIcon - player status", status)
                    end
                end
            end
        end
        -- save data
        Azimuth.saveConfig("AllianceData_"..player.alliance.index, { allianceIcons = allianceIcons, allianceIconsCount = allianceIconsCount }, nil, false, "GalaxyMapQoL")
    end
end
callable(GalaxyMapQoL, "setSectorIcon")


end