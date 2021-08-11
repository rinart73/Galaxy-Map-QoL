local gmqol_initUI -- extended client function


if onClient() then


gmqol_initUI = MapCommands.initUI
function MapCommands.initUI(...)
    gmqol_initUI(...)

    if shipList then
        shipList.shipsContainer.layer = 3
        shipList.ordersContainer.layer = 3
        shipList.contextMenuContainer.layer = 3
    end
end


end