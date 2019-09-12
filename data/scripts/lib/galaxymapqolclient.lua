package.path = package.path .. ";data/scripts/lib/?.lua"
include("galaxy")
local PassageMap = include("passagemap")
include("azimuthlib-uicolorpicker")
include("azimuthlib-uiproportionalsplitter")
include("azimuthlib-uirectangle")
local Azimuth = include("azimuthlib-basic")

GalaxyMapQoL = {}

local editIconBtn, iconsFactionComboBox, showDistanceComboBox, legendRows, editIconWindow, coordinatesLabel, editIconScrollFrame, colorSelector, colorPictures, colorPicker, iconSelector -- UI
-- client
local config, customNamespace, sectorsPlayer, sectorsAlliance, isServerUsed, isEditIconShown, iconsFactionBoxHasAlliance, iconPictures, selectedIcon, editedX, editedY, materialDistances, distToCenter, selectedColorIndex
local icons = {"empty", "adopt", "alliance", "anchor", "bag", "bug-report", "cattle", "checkmark", "clockwise-rotation", "cog", "crew", "cross-mark", "diamonds", "domino-mask", "electric", "fighter", "look-at", "flying-flag", "halt", "health-normal", "hourglass", "inventory", "move", "round-star", "select", "shield", "trash-can", "unchecked", "vortex"}
local passageMap = PassageMap(Seed(GameSettings().seed))
local distColor = ColorInt(0xff999999)
local bossDistances = {
  { min = 380, max = 430, name = "Boss Swoks ${num}"%_t % {num = ""}, color = ColorARGB(0.7, 1, 0, 0) },
  { min = 280, max = 340, name = "The AI"%_t, color = ColorARGB(0.7, 0, 1, 0) },
  { min = 150, max = 240, name = "Mobile Energy Lab"%_t, color = ColorARGB(0.7, 0.5, 0.5, 1), noDrawMin = true },
  { min = 150, max = 180, name = "The 4", color = ColorARGB(0.7, 1, 1, 0), minExtraColor = ColorARGB(0.7, 0.5, 0.5, 1) }
}
local galaxyMapQoL_updateClient -- extended functions

function GalaxyMapQoL.initialize()
    -- load config
    local defaultColors = {
      ColorInt(0xffffffff):toInt(), -- white
      ColorInt(0xffA0A0A0):toInt(), -- gray
      ColorInt(0xffff0000):toInt(), -- red
      ColorInt(0xffFF7F00):toInt(), -- orange
      ColorInt(0xffffff00):toInt(), -- yellow
      ColorInt(0xff00FF00):toInt(), -- green
      ColorInt(0xff00FFFF):toInt(), -- cyan
      ColorInt(0xff007FFF):toInt(), -- light blue
      ColorInt(0xff7F00FF):toInt(), -- purple
      ColorInt(0xffFF00FF):toInt() -- magenta
    }
    local configOptions = {
      _version = { default = "1.1", comment = "Don't touch this file" },
      playerIcons = { default = {} },
      colors = { default = defaultColors }
    }
    local isModified
    config, isModified = Azimuth.loadConfig("GalaxyMapQoL", configOptions, true, true)
    if isModified then
        Azimuth.saveConfig("GalaxyMapQoL", config, configOptions, true, true)
    end
    for i = 1, 10 do
        config.colors[i] = ColorInt(config.colors[i])
    end

    -- calculating material distances
    local maxCoords = Balancing_GetMaxCoordinates()
    local beltSize = Balancing_GetMaterialBeltSize()
    local existanceThreshold = Balancing_GetMaterialExistanceThreshold()
    materialDistances = {}
    for i = 1, NumMaterials() - 1 do
        local beltRadius = Balancing_GetMaterialBeltRadius(i)
        materialDistances[i] = (beltRadius + beltSize * (1 + existanceThreshold)) * maxCoords
    end

    GalaxyMapQoL.initUI()

    local player = Player()
    player:registerCallback("onShowGalaxyMap", "galaxyMapQoL_onShowGalaxyMap")
    player:registerCallback("onHideGalaxyMap", "galaxyMapQoL_onHideGalaxyMap")
    player:registerCallback("onSelectMapCoordinates", "galaxyMapQoL_onEditIconBtnPressed")
    player:registerCallback("onMapRenderAfterLayers", "galaxyMapQoL_onMapRenderAfterLayers")

    if not customNamespace then
        invokeServerFunction("sync", true)
    end
end

function GalaxyMapQoL.initUI()
    local map = GalaxyMap()
    local container = map:createContainer()
    editIconBtn = container:createButton(Rect(460, 10, 660, 40), "Edit icon"%_t, "galaxyMapQoL_onEditIconBtnPressed")

    iconsFactionComboBox = container:createComboBox(Rect(460, 50, 660, 75), "galaxyMapQoL_onIconsFactionBoxChanged")
    iconsFactionComboBox:addEntry("Hide icons"%_t)
    iconsFactionComboBox:addEntry("Player"%_t)
    iconsFactionComboBox:setSelectedIndexNoCallback(1)

    showDistanceComboBox = container:createComboBox(Rect(460, 85, 660, 110), "galaxyMapQoL_onShowDistanceBoxChanged")
    showDistanceComboBox:addEntry("Show range"%_t)
    showDistanceComboBox:addEntry("Resources"%_t)
    showDistanceComboBox:addEntry("Bosses"%_t)

    local lister = UIVerticalLister(Rect(670, 10, 770, 10), 5, 0)
    local partitions, picture, label
    legendRows = {}
    for i = 1, #materialDistances do
        partitions = UIVerticalProportionalSplitter(lister:placeCenter(vec2(lister.inner.width, 18)), 5, 0, {18, 0.5})
        picture = container:createPicture(partitions[1], "data/textures/icons/galaxymapqol/ui-filled.png")
        label = container:createLabel(partitions[2].lower, "", 12)
        picture.visible = false
        label.visible = false
        legendRows[i] = { picture = picture, label = label }
    end

    -- edit icon window
    editIconWindow = map:createWindow(Rect(670, 10, 970, 300))
    editIconWindow.visible = false
    partitions = UIHorizontalProportionalSplitter(Rect(editIconWindow.size), 10, 10, {15, 20, 24, 0.5, 25})

    coordinatesLabel = editIconWindow:createLabel(partitions[1], "", 14)
    coordinatesLabel.centered = true

    local partition = partitions[2]
    local offset = (partition.width - 275) / 2
    local vPartitions = UIVerticalMultiSplitter(Rect(partition.lower.x + offset, partition.lower.y, partition.upper.x - offset, partition.upper.y), 5, 0, 10)
    colorPictures = {}
    local color
    for i = 0, 10 do
        partition = vPartitions:partition(i)
        UIRectangle(editIconWindow, Rect(partition.lower + vec2(1, 1), partition.upper - vec2(1, 1)), ColorRGB(0, 0, 0))
        picture = editIconWindow:createPicture(Rect(partition.lower + vec2(2, 2), partition.upper - vec2(2, 2)), "data/textures/ui/azimuthlib/fill.png")
        if i == 0 then
            color = ColorRGB(0, 0.5, 0)
        else
            color = config.colors[i]
        end
        picture.color = color
        colorPictures[i+1] = { picture = picture, color = color }
    end
    partition = vPartitions:partition(0)
    colorSelector = UIRectangle(editIconWindow, Rect(partition.lower - vec2(1, 1), partition.upper + vec2(1, 1)), ColorRGB(1, 1, 1), 2)
    selectedColorIndex = 1

    local btn = editIconWindow:createButton(partitions[3], "Edit selected color"%_t, "galaxyMapQoL_onEditSelectedColorBtnPressed")
    btn.maxTextSize = 14

    partition = partitions[4]
    editIconScrollFrame = editIconWindow:createScrollFrame(partition)
    lister = UIVerticalLister(Rect(vec2(1, 1), vec2(partition.width - 21, partition.height)), 0, 2)
    local rows = math.ceil(#icons / 8)
    local splitter, picture
    iconPictures = {}
    local i = 1
    for y = 1, rows do
        splitter = UIVerticalMultiSplitter(lister:placeCenter(vec2(lister.inner.width, 32)), 2, 0, 7)
        splitter.marginBottom = 2
        for x = 0, 7 do
            partition = splitter:partition(x)
            picture = editIconScrollFrame:createPicture(Rect(partition.lower + vec2(2, 2), partition.upper - vec2(2, 2)), "data/textures/icons/galaxymapqol/"..icons[i]..".png")
            picture.flipped = true -- unflip pictures, because they're flipped by default for some reason
            iconPictures[i] = picture
            i = i + 1
            if i > #icons then break end
        end
        if i > #icons then break end
    end
    iconSelector = UIRectangle(editIconScrollFrame, Rect(), ColorRGB(1, 1, 1), 2)
    iconSelector.rect = Rect(iconPictures[1].lower - vec2(3, 3), iconPictures[1].upper + vec2(3, 3))

    splitter = UIVerticalSplitter(partitions[5], 10, 0, 0.5)
    btn = editIconWindow:createButton(splitter.left, "Apply"%_t, "galaxyMapQoL_onEditIconApplyBtnPressed")
    btn.maxTextSize = 14
    btn = editIconWindow:createButton(splitter.right, "Cancel"%_t, "galaxyMapQoL_onEditIconCancelBtnPressed")
    btn.maxTextSize = 14

    -- color picker
    if not customNamespace then
        colorPicker = UIColorPicker(GalaxyMapQoL, map)
    else
        colorPicker = UIColorPicker(customNamespace, map)
    end
end

function GalaxyMapQoL.getUpdateInterval()
    if isEditIconShown or colorPicker.visible then return end -- every tick
    return 0.5
end

function GalaxyMapQoL.updateClient(timeStep)
    if isEditIconShown then
        colorPicker:update(timeStep)

        local mouse = Mouse()
        if not colorPicker.visible and mouse:mouseDown(MouseButton.Left) then
            local pos = mouse.position
            -- select color
            for i, pair in ipairs(colorPictures) do
                if pair.picture.mouseOver then
                    GalaxyMapQoL.selectColor(i)
                    break
                end
            end
            -- select icon
            if pos.x >= editIconScrollFrame.lower.x and pos.x <= editIconScrollFrame.upper.x and pos.y >= editIconScrollFrame.lower.y and pos.y <= editIconScrollFrame.upper.y then
                local picture
                for i = 1, #icons do
                    picture = iconPictures[i]
                    if pos.x >= picture.lower.x and pos.x <= picture.upper.x and pos.y >= picture.lower.y and pos.y <= picture.upper.y then
                        GalaxyMapQoL.selectIcon(i)
                        break
                    end
                end
            end
        end
    end
end

function GalaxyMapQoL.sync(isFullSync, playerData, allianceData)
    if playerData then
        if isFullSync then
            isServerUsed = true
            sectorsPlayer = playerData
            if not sectorsAlliance then
                sectorsAlliance = {}
            end
        else -- partial sync
            if #playerData == 2 then -- remove
                sectorsPlayer[playerData[1].."_"..playerData[2]] = nil
            else
                sectorsPlayer[playerData[1].."_"..playerData[2]] = playerData
            end
        end
    else
        if isFullSync then
            sectorsAlliance = allianceData
        else
            if #allianceData == 2 then -- remove
                sectorsAlliance[allianceData[1].."_"..allianceData[2]] = nil
            else
                sectorsAlliance[allianceData[1].."_"..allianceData[2]] = allianceData
            end
        end
    end
end

function GalaxyMapQoL.galaxyMapQoL_onShowGalaxyMap()
    if not isServerUsed and not sectorsPlayer then -- mod isn't installed on server side, using local storage
        sectorsPlayer = config.playerIcons
        sectorsAlliance = {}
    end

    -- add/remove 'Alliance' from faction combo box
    local alliance = Player().alliance
    if isServerUsed and alliance and not iconsFactionBoxHasAlliance then
        iconsFactionComboBox:addEntry("Alliance"%_t)
        iconsFactionBoxHasAlliance = true
    elseif not alliance and iconsFactionBoxHasAlliance then
        local prevIndex = iconsFactionComboBox.selectedIndex
        iconsFactionComboBox:clear()
        iconsFactionComboBox:addEntry("Hide icons"%_t)
        iconsFactionComboBox:addEntry("Player"%_t)
        iconsFactionComboBox:setSelectedIndexNoCallback(prevIndex == 2 and 1 or prevIndex)
        sectorsAlliance = {}
        iconsFactionBoxHasAlliance = false
    end
    -- enable/disable 'edit icons' button
    GalaxyMapQoL.galaxyMapQoL_onIconsFactionBoxChanged()

    if isServerUsed and alliance then
        invokeServerFunction("sync") -- sync data
    end
end

function GalaxyMapQoL.galaxyMapQoL_onHideGalaxyMap()
    isEditIconShown = false

    config.colors = {}
    for i = 1, 10 do
        config.colors[i] = colorPictures[i+1].color:toInt()
    end
    Azimuth.saveConfig("GalaxyMapQoL", config, { _version = {comment = "Don't touch this file"} }, true, true)
end

function GalaxyMapQoL.galaxyMapQoL_onMapRenderAfterLayers()
    local map = GalaxyMap()
    -- draw icons
    local iconFaction = iconsFactionComboBox.selectedIndex
    if iconFaction ~= 0 then
        local half = map:getCoordinatesScreenPosition(ivec2(0, 0))
        half = map:getCoordinatesScreenPosition(ivec2(1, 0)) - half
        half = half * 0.5
        local topX, bottomY = map:getCoordinatesAtScreenPosition(vec2(0, 0))
        local bottomX, topY = map:getCoordinatesAtScreenPosition(getResolution())

        local renderer = UIRenderer()
        local sectors = iconFaction == 1 and sectorsPlayer or sectorsAlliance
        local sx, sy
        for _, sector in pairs(sectors) do
            if sector[1] >= topX and sector[1] <= bottomX and sector[2] >= topY and sector[2] <= bottomY then
                sx, sy = map:getCoordinatesScreenPosition(ivec2(sector[1], sector[2]))
                renderer:renderIcon(vec2(sx - half, sy - half), vec2(sx + half, sy + half), ColorInt(sector[4]), "data/textures/icons/galaxymapqol/"..sector[3]..".png")
            end
        end
        
        -- draw distances
        local showDistance = showDistanceComboBox.selectedIndex
        if showDistance == 1 then -- materials
            local color
            for i, dist in ipairs(materialDistances) do
                color = Material(i).color
                color.a = 0.7
                GalaxyMapQoL.drawCircle(renderer, materialDistances[i], color, 1)
            end
        elseif showDistance == 2 then -- bosses
            for _, boss in ipairs(bossDistances) do
                if not boss.noDrawMin then
                    if not boss.minExtraColor then
                        GalaxyMapQoL.drawCircle(renderer, boss.min, boss.color, 1)
                    else
                        GalaxyMapQoL.drawCircle(renderer, boss.min, boss.color, 1, boss.minExtraColor, 5)
                    end
                end
                GalaxyMapQoL.drawCircle(renderer, boss.max, boss.color, 1)
            end
        end
        
        renderer:display()
    end
    -- draw distance to center
    local x, y = map:getHoveredCoordinates()
    if x then
        if not distToCenter or distToCenter.x ~= x or distToCenter.y ~= y then
            local passable = passageMap:passable(x, y)
            distToCenter = { x = x, y = y, passable = passable }
            if passable then
                local dx = 0
                if x < 0 then dx = dx + 6 end
                if y < 0 then dx = dx + 6 end
                dx = dx + (string.len(tostring(math.abs(x))) - 1) * 10
                dx = dx + (string.len(tostring(math.abs(y))) - 1) * 10
                distToCenter.dx = dx
                distToCenter.text = "(dist: ${num})"%_t % {num = tonumber(string.format("%.4f", math.sqrt(x*x + y*y)))}
            end
        end
        if distToCenter.passable then
            local mx, my = map:getCoordinatesScreenPosition(ivec2(x, y))
            drawText(distToCenter.text, mx + 68 + distToCenter.dx, my - 15, distColor, 13, 0, 0, 1)
        end
    end
end

function GalaxyMapQoL.galaxyMapQoL_onEditIconBtnPressed(_, isCallback)
    if isCallback and colorPicker.visible then return end

    if (isCallback and editIconWindow.visible) or (not isCallback and not editIconWindow.visible) then
        local iconFaction = iconsFactionComboBox.selectedIndex
        local sectors = iconFaction == 1 and sectorsPlayer or sectorsAlliance
        editedX, editedY = GalaxyMap():getSelectedCoordinates()
        coordinatesLabel.caption = editedX .. " : " .. editedY
        local sector = sectors[editedX.."_"..editedY]
        if sector then
            local iconIndex = 1
            for i = 2, #icons do
                if sector[3] == icons[i] then
                    iconIndex = i
                    break
                end
            end
            local color = ColorInt(sector[4])
            colorPictures[1].picture.color = color
            colorPictures[1].color = color
            GalaxyMapQoL.selectIcon(iconIndex)
            GalaxyMapQoL.selectColor(1)
        else
            GalaxyMapQoL.selectIcon(1)
        end
    end
    if not isCallback then
        editIconWindow.visible = not editIconWindow.visible
        isEditIconShown = editIconWindow.visible
    end
end

function GalaxyMapQoL.galaxyMapQoL_onIconsFactionBoxChanged()
    editIconWindow.visible = false -- hide window
    local iconFaction = iconsFactionComboBox.selectedIndex
    if iconFaction == 0 then
        editIconBtn.active = false
    elseif iconFaction == 2 then
        local player = Player()
        local alliance = player.alliance
        if not alliance or not alliance:hasPrivilege(player.index, AlliancePrivilege.EditMap) then
            editIconBtn.active = false
        else
            editIconBtn.active = true
        end
    else
        editIconBtn.active = true
    end
end

function GalaxyMapQoL.galaxyMapQoL_onShowDistanceBoxChanged()
    local showDistance = showDistanceComboBox.selectedIndex
    if showDistance == 0 then -- hide legend
        for _, row in ipairs(legendRows) do
            row.picture.visible = false
            row.label.visible = false
        end
    elseif showDistance == 1 then -- materials
        local material, color
        for i, row in ipairs(legendRows) do
            material = Material(i)
            color = material.color
            color.a = 0.7
            row.picture.color = color
            row.label.caption = material.name.." - "..math.floor(materialDistances[i])
            row.picture.visible = true
            row.label.visible = true
        end
    else -- bosses
        local row
        for i, boss in ipairs(bossDistances) do
            row = legendRows[i]
            row.picture.color = boss.color
            row.label.caption = boss.name.." - "..boss.min.."-"..boss.max
            row.picture.visible = true
            row.label.visible = true
        end
        for i = #bossDistances+1, #legendRows do
            row = legendRows[i]
            row.picture.visible = false
            row.label.visible = false
        end
    end
end

function GalaxyMapQoL.galaxyMapQoL_onEditSelectedColorBtnPressed()
    colorPicker:show(nil, nil, "HSV", colorPictures[selectedColorIndex].color, "galaxyMapQoL_onColorPickerApplyBtnPressed", nil, 0.5, 1)
    local res = getResolution()
    local newPos = editIconWindow.position + vec2(editIconWindow.width + 10, 40)
    if newPos.x + 410 <= res.x then
        colorPicker.position = newPos
    end
end

function GalaxyMapQoL.galaxyMapQoL_onColorPickerApplyBtnPressed(color)
    local colorPicture = colorPictures[selectedColorIndex]
    colorPicture.picture.color = color
    colorPicture.color = color
    GalaxyMapQoL.selectColor(selectedColorIndex)
end

function GalaxyMapQoL.galaxyMapQoL_onEditIconApplyBtnPressed()
    if colorPicker.visible then return end

    local iconFaction = iconsFactionComboBox.selectedIndex
    if selectedIcon == 1 then -- remove icon
        if isServerUsed then
            invokeServerFunction("setSectorIcon", iconFaction == 2, editedX, editedY)
        else
            sectorsPlayer[editedX.."_"..editedY] = nil
        end
    else -- add/change icon
        if isServerUsed then
            invokeServerFunction("setSectorIcon", iconFaction == 2, editedX, editedY, icons[selectedIcon], colorPictures[selectedColorIndex].color:toInt())
        else
            sectorsPlayer[editedX.."_"..editedY] = { editedX, editedY, icons[selectedIcon], colorPictures[selectedColorIndex].color:toInt() }
        end
    end
end

function GalaxyMapQoL.galaxyMapQoL_onEditIconCancelBtnPressed()
    colorPicker:hide()
    editIconWindow.visible = false
    isEditIconShown = false
end

function GalaxyMapQoL.selectColor(index)
    selectedColorIndex = index
    local colorPicture = colorPictures[index]
    colorSelector.position = colorPicture.picture.position - vec2(3, 3)
    iconPictures[selectedIcon].color = colorPicture.color
end

function GalaxyMapQoL.selectIcon(index)
    if selectedIcon then -- reset prev icon color
        iconPictures[selectedIcon].color = ColorRGB(1, 1, 1)
    end
    selectedIcon = index
    local iconPicture = iconPictures[selectedIcon]
    iconPicture.color = colorPictures[selectedColorIndex].color
    iconSelector.position = iconPicture.lower - vec2(3, 3)
end

function GalaxyMapQoL.drawCircle(renderer, radius, color, layer, color2, colorSwitchStep)
    local map = GalaxyMap()
    local side = map:getCoordinatesScreenPosition(ivec2(0, 0))
    side = map:getCoordinatesScreenPosition(ivec2(1, 0)) - side
    local ex = math.floor(radius)
    local bx, by = -ex, 0
    local sx, sy = map:getCoordinatesScreenPosition(ivec2(bx --[[+ centerX]], by --[[+ centerY]]))
    local cx1, cy1, cx2, cy2, tcy1, tcy2
    local y, k
    local x1, y1, ak = -ex, 0, 0
    local x2, y2 = -ex, 0
    local py = 0
    local tempColor
    if not color2 then
        color2 = color
    end
    local switchColor = 0
    for x = -ex, 1 do
        y = math.floor(math.sqrt(radius * radius - x * x))
        k = x ~= 0 and y / x or 0
        if k == ak and x <= 0 then -- set new ending coordinates
            x2, y2 = x, y
        elseif py ~= y or x >= 0 then -- draw line
            if x1 ~= x2 or y1 ~= y2 then
                cx1 = sx + (x1 - bx) * side
                cy1 = sy + (by - y1) * side
                cx2 = sx + (x2 - bx) * side
                cy2 = sy + (by - y2) * side
                tcy1 = cy1
                tcy2 = cy2
                -- top left
                renderer:renderLine(vec2(cx1, cy1), vec2(cx2, cy2), color, layer)
                -- bottom left
                cy1 = sy + (by + y1) * side
                cy2 = sy + (by + y2) * side
                renderer:renderLine(vec2(cx1, cy1), vec2(cx2, cy2), color2, layer)
                -- bottom right
                cx1 = sx + (-x1 - bx) * side
                cx2 = sx + (-x2 - bx) * side
                renderer:renderLine(vec2(cx1, cy1), vec2(cx2, cy2), color, layer)
                -- top right
                cy1 = tcy1
                cy2 = tcy2
                renderer:renderLine(vec2(cx1, cy1), vec2(cx2, cy2), color2, layer)
                -- switch colors
                if colorSwitchStep then
                    if switchColor == colorSwitchStep then
                        tempColor = color
                        color = color2
                        color2 = tempColor
                        switchColor = 0
                    else
                        switchColor = switchColor + 1
                    end
                end
            end
            x1, y1 = x2, y2
            x2, y2 = x, y
            ak = k
        end
        py = y
    end
end

function GalaxyMapQoL.initOtherNamespace(namespace)
    customNamespace = namespace

    -- skip 'getUpdateInterval' to not interfere with other mods
    galaxyMapQoL_updateClient = namespace.updateClient
    namespace.updateClient = function(...)
        if galaxyMapQoL_updateClient then galaxyMapQoL_updateClient(...) end
        GalaxyMapQoL.updateClient(...)
    end
    -- skip 'sync' because there will be no server response
    namespace.galaxyMapQoL_onShowGalaxyMap = GalaxyMapQoL.galaxyMapQoL_onShowGalaxyMap
    namespace.galaxyMapQoL_onHideGalaxyMap = GalaxyMapQoL.galaxyMapQoL_onHideGalaxyMap
    namespace.galaxyMapQoL_onMapRenderAfterLayers = GalaxyMapQoL.galaxyMapQoL_onMapRenderAfterLayers
    namespace.galaxyMapQoL_onEditIconBtnPressed = GalaxyMapQoL.galaxyMapQoL_onEditIconBtnPressed
    namespace.galaxyMapQoL_onIconsFactionBoxChanged = GalaxyMapQoL.galaxyMapQoL_onIconsFactionBoxChanged
    namespace.galaxyMapQoL_onShowDistanceBoxChanged = GalaxyMapQoL.galaxyMapQoL_onShowDistanceBoxChanged
    namespace.galaxyMapQoL_onEditSelectedColorBtnPressed = GalaxyMapQoL.galaxyMapQoL_onEditSelectedColorBtnPressed
    namespace.galaxyMapQoL_onColorPickerApplyBtnPressed = GalaxyMapQoL.galaxyMapQoL_onColorPickerApplyBtnPressed
    namespace.galaxyMapQoL_onEditIconApplyBtnPressed = GalaxyMapQoL.galaxyMapQoL_onEditIconApplyBtnPressed
    namespace.galaxyMapQoL_onEditIconCancelBtnPressed = GalaxyMapQoL.galaxyMapQoL_onEditIconCancelBtnPressed

    GalaxyMapQoL.initialize()
end

return GalaxyMapQoL