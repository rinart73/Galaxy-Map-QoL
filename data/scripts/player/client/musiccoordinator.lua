-- While my mod has nothing to do with music, this approach allows it to work even without server installation (but without alliance icons)
local galaxyMapQoL_client

local galaxyMapQoL_initialize = MusicCoordinator.initialize
function MusicCoordinator.initialize(...)
    galaxyMapQoL_initialize(...)

    for _, path in pairs(Player():getScripts()) do
        path = path:gsub("\\", "/")
        if string.find(path, "data/scripts/player/map/galaxymapqol.lua") then
            return -- Server has the mod, don't use this file
        end
    end
    -- Server doesn't have the mod, load clientside script
    galaxyMapQoL_client = include("galaxymapqolclient")
    galaxyMapQoL_client.initOtherNamespace(MusicCoordinator)
end