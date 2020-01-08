package.path = package.path .. ";data/scripts/lib/?.lua"

local Azimuth = include("azimuthlib-basic")

local configOptions = {
  _version = { default = "1.0", comment = "Config version. Don't touch." },
  ConsoleLogLevel = {default = 2, min = 0, max = 4, format = "floor", comment = "0 - Disable, 1 - Errors, 2 - Warnings, 3 - Info, 4 - Debug."},
  FileLogLevel = {default = 2, min = 0, max = 4, format = "floor", comment = "0 - Disable, 1 - Errors, 2 - Warnings, 3 - Info, 4 - Debug."},
  IconsPerPlayer = { default = 75, min = 0, format = "floor", comment = "How many icons player can have" },
  IconsPerAlliance = { default = 200, min = 0, format = "floor", comment = "How many icons alliance can have" },
  HazardZoneRequestInterval = { default = 60, min = 0, format = "floor", comment = "Minimal interval in seconds between war zone data requests made by player." }
}
local Config, isModified = Azimuth.loadConfig("GalaxyMapQoL", configOptions)
if isModified then
    Azimuth.saveConfig("GalaxyMapQoL", Config, configOptions)
end
configOptions = nil
local Log = Azimuth.logs("GalaxyMapQoL", Config.ConsoleLogLevel, Config.FileLogLevel)

return {Azimuth, Config, Log}