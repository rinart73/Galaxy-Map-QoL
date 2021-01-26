package.path = package.path .. ";data/scripts/lib/?.lua"

local Azimuth = include("azimuthlib-basic")

local configOptions = {
  ["_version"] = {"1.0", comment = "Config version. Don't touch."},
  ["ConsoleLogLevel"] = {2, round = -1, min = 0, max = 4, comment = "0 - Disable, 1 - Errors, 2 - Warnings, 3 - Info, 4 - Debug."},
  ["FileLogLevel"] = {2, round = -1, min = 0, max = 4, comment = "0 - Disable, 1 - Errors, 2 - Warnings, 3 - Info, 4 - Debug."},
  ["IconsPerPlayer"] = {75, round = -1, min = 0, comment = "How many icons player can have"},
  ["IconsPerAlliance"] = {200, round = -1, min = 0, comment = "How many icons alliance can have"},
  ["HazardZoneRequestInterval"] = {60, round = -1, min = 0, comment = "Minimal interval in seconds between war zone data requests made by player."}
}
local Config, isModified = Azimuth.loadConfig("GalaxyMapQoL", configOptions)
if isModified then
    Azimuth.saveConfig("GalaxyMapQoL", Config, configOptions)
end
configOptions = nil
local Log = Azimuth.logs("GalaxyMapQoL", Config.ConsoleLogLevel, Config.FileLogLevel)

return {Azimuth, Config, Log}