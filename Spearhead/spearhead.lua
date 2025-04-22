--[[
        Spearhead Compile Time: 2025-04-22T12:42:03.734573
    ]]
do --spearhead_db.lua

---@class DatabaseTables
---@field AllZoneNames Array<string> All Zone Names
---@field StageZoneNames Array<string> All Stage Zone Names
---@field StageZones table<string, StageZoneData> table<StageZoneName, StageZoneData>
---@field MissionZones Array<string> All Mission Zone Names
---@field RandomMissionZones Array<string> All Random mission names
---@field StageZonesByNumber table<string, Array<string>> Stage zones grouped by index number
---@field AllFarpZones Array<string>
---@field FarpIdsInFarpZones table<string, Array<integer>> farp pad Id's in farp zones.
---@field CapRoutes Array<string> All Cap route zone names
---@field CapDataPerStageNumber table<integer, CapData> table<StageNumber, table>
---@field CarrierRouteZones Array<string> All Carrier routes zones
---@field BlueSams Array<string> All blue sam zones
---@field DescriptionsByMission table<string,string> table<ZoneName, Description>
---@field AirbaseDataPerAirfield table<string, AirbaseData>
---@field BlueSamDataPerZone table<string, BlueSamData>
---@field MissionZoneData table<string, MissionZoneData>
---@field FarpZoneData table<string,FarpZoneData>

---@class CapData
---@field routes Array<CapRoute>
---@field current integer

---@class CapRoute 
---@field point1 Vec3
---@field point2 Vec3?

---@class StageZoneData
---@field StageZoneName string
---@field AirbaseNames Array<string>
---@field FarpZones Array<string>
---@field MissionZones Array<string>
---@field RandomMissionZones Array<string>
---@field StageIndex string
---@field BlueSamZones Array<string>
---@field MiscGroups Array<string>

---@class AirbaseData
---@field CapGroups Array<string>
---@field RedGroups Array<string>
---@field BlueGroups Array<string>

---@class BlueSamData
---@field Groups Array<string>

---@class MissionZoneData
---@field Groups Array<string>

---@class MissionData
---@field Groups Array<string>

---@class FarpZoneData
---@field Groups Array<string>

---@class Database
---@field private _tables DatabaseTables
---@field private _logger Logger 
local Database = {}

---comment
---@param Logger table
---@return Database
function Database.New(Logger, debug)
    
    ---@type DatabaseTables
    local tables = {
        AllZoneNames = {},
        BlueSams = {},
        CapRoutes = {},
        CapDataPerStageNumber = {},
        CarrierRouteZones = {},
        DescriptionsByMission = {},
        FarpIdsInFarpZones = {},
        MissionZones = {},
        StageZoneNames = {},
        RandomMissionZones = {},
        StageZones = {},
        StageZonesByNumber = {},
        AllFarpZones = {},
        AirbaseDataPerAirfield = {},
        BlueSamDataPerZone = {},
        MissionZoneData = {},
        FarpZoneData = {}
    }

    Database.__index = Database
    local self = setmetatable({}, Database)

    self._logger = Logger
    self._tables = tables

    Logger:debug("Initiating tables")

    do -- INIT ZONE TABLES
        for zone_ind, zone_data in pairs(Spearhead.DcsUtil.__trigger_zones) do
            local zone_name = zone_data.name
            local split_string = Spearhead.Util.split_string(zone_name, "_")
            table.insert(self._tables.AllZoneNames, zone_name)

            if string.lower(split_string[1]) == "missionstage" then
                table.insert(self._tables.StageZoneNames, zone_name)
                if split_string[2] then
                    local stringified = tostring(split_string[2]) or "unknown"
                    if self._tables.StageZonesByNumber[stringified] == nil then
                        self._tables.StageZonesByNumber[stringified] = {}
                    end
                    table.insert(self._tables.StageZonesByNumber[stringified], zone_name)

                    ---@type StageZoneData
                    local stageData = {
                        StageZoneName = zone_name,
                        StageIndex = stringified,
                        AirbaseNames = {},
                        BlueSamZones = {},
                        FarpZones = {},
                        MissionZones = {},
                        RandomMissionZones = {},
                        MiscGroups = {}
                    }
                    self._tables.StageZones[zone_name] = zone_data
                end
            end

            if string.lower(split_string[1]) == "waitingstage" then
                table.insert(self._tables.StageZoneNames, zone_name)
            end

            if string.lower(split_string[1]) == "mission" then
                table.insert(self._tables.MissionZones, zone_name)
            end

            if string.lower(split_string[1]) == "randommission" then
                table.insert(self._tables.RandomMissionZones, zone_name)
            end

            if string.lower(split_string[1]) == "farp" then
                table.insert(self._tables.AllFarpZones, zone_name)
            end

            if string.lower(split_string[1]) == "caproute" then
                table.insert(self._tables.CapRoutes, zone_name)
            end

            if string.lower(split_string[1]) == "carrierroute" then
                table.insert(self._tables.CarrierRouteZones, zone_name)
            end

            if string.lower(split_string[1]) == "bluesam" then
                table.insert(self._tables.BlueSams, zone_name)
            end
        end
    end

    Logger:debug("initiated zone tables, continuing with descriptions")
    do --load markers
        if env.mission.drawings and env.mission.drawings.layers then
            for i, layer in pairs(env.mission.drawings.layers) do
                if string.lower(layer.name) == "author" then
                    for key, layer_object in pairs(layer.objects) do

                        if Spearhead.Util.startswith(layer_object.name,  "stagebriefing", true) then
                            --[[
                                TODO: Stage Briefings
                            ]]
                        else
                            local inZone = Spearhead.DcsUtil.isPositionInZones(layer_object.mapX, layer_object.mapY, self._tables.MissionZones)
                            if Spearhead.Util.tableLength(inZone) >= 1 then
                                local name = inZone[1]
                                if name ~= nil then
                                    self._tables.DescriptionsByMission[name] = layer_object.text
                                end
                            end

                            local inZone = Spearhead.DcsUtil.isPositionInZones(layer_object.mapX, layer_object.mapY,
                                self._tables.RandomMissionZones)
                            if Spearhead.Util.tableLength(inZone) >= 1 then
                                local name = inZone[1]
                                if name ~= nil then
                                    self._tables.DescriptionsByMission[name] = layer_object.text
                                end
                            end
                        end

                        
                    end
                end
            end
        end
    end

    for _, stageZoneName in pairs(self._tables.StageZoneNames) do
        local stageData = self._tables.StageZones[stageZoneName]
        if stageData then

            -- fill blue sams
            for _, blueSamStageName in pairs(self._tables.BlueSams) do
                if Spearhead.DcsUtil.isZoneInZone(blueSamStageName, stageZoneName) == true then
                    table.insert(stageData.BlueSamZones, blueSamStageName)
                end
            end

            -- fill missions
            for key, missionZone in pairs(self._tables.MissionZones) do
                if Spearhead.DcsUtil.isZoneInZone(missionZone, stageZoneName) == true then
                    table.insert(stageData.MissionZones, missionZone)
                end
            end

            -- fill random missions
            for key, missionZone in pairs(self._tables.RandomMissionZones) do
                if Spearhead.DcsUtil.isZoneInZone(missionZone, stageZoneName) == true then
                    table.insert(stageData.RandomMissionZones, missionZone)
                end
            end

            -- fill airbases
            for _, airbase in pairs(world.getAirbases()) do
                local point = airbase:getPoint()
                
                if Spearhead.DcsUtil.isPositionInZone(point.x, point.z, stageZoneName)  == true then
                    if airbase:getDesc().category == 0 then
                        table.insert(stageData.AirbaseNames, airbase:getName())
                    elseif airbase:getDesc().category == 1 then
                        -- farp
                        --[[
                            TODO: FARP ZONES FILL
                        ]]
                    end
                end
            end

            --- fill farp zones
            for _, farpZoneName in pairs(self._tables.AllFarpZones) do
                if Spearhead.DcsUtil.isZoneInZone(farpZoneName, stageZoneName) then
                    table.insert(stageData.FarpZones, farpZoneName)
                end
            end

            Logger:info("initiated the database with amount of zones: ")
            Logger:info("Stages:            " .. Spearhead.Util.tableLength(self._tables.StageZones))
            Logger:info("Total Missions:    " .. Spearhead.Util.tableLength(self._tables.MissionZoneData))
            Logger:info("Random Missions:   " .. Spearhead.Util.tableLength(self._tables.RandomMissionZones))
            Logger:info("Farps:             " .. Spearhead.Util.tableLength(self._tables.AllFarpZones))
            Logger:info("Airbases:          " .. Spearhead.Util.tableLength(self._tables.AirbaseDataPerAirfield))

            for _, missionZone in pairs(self._tables.MissionZones) do
                if self._tables.DescriptionsByMission[missionZone] == nil then
                    Spearhead.AddMissionEditorWarning("Mission with zonename: " ..
                    missionZone .. " does not have a briefing")
                end
            end

            for _, missionZone in pairs(self._tables.RandomMissionZones) do
                if self._tables.DescriptionsByMission[missionZone] == nil then
                    Spearhead.AddMissionEditorWarning("Mission with zonename: " ..
                    missionZone .. " does not have a briefing")
                end
            end

        end
    end
    
    local is_group_taken = {}
    do
        local all_groups = Spearhead.DcsUtil.getAllGroupNames()
        for _, value in pairs(all_groups) do
            is_group_taken[value] = false
        end
    end

    local getAvailableGroups = function()
        local result = {}
        for name, value in pairs(is_group_taken) do
            if value == false then
                table.insert(result, name)
            end
        end
        return result
    end

    local getAvailableCAPGroups = function()
        local result = {}
        for name, value in pairs(is_group_taken) do
            if value == false and Spearhead.Util.startswith(name, "CAP") then
                table.insert(result, name)
            end
        end
        return result
    end

    ---@private
    ---@param baseName string
    ---@return AirbaseData
    function Database:getOrCreateAirbaseData(baseName)
        local baseData = self._tables.AirbaseDataPerAirfield[baseName]
        if baseData == nil then
            baseData = {
                CapGroups = {},
                RedGroups = {},
                BlueGroups = {}
            }
            self._tables.AirbaseDataPerAirfield[baseName] = baseData
        end
        return baseData
    end

    ---@private
    function Database:loadCapUnits()
        local all_groups = getAvailableCAPGroups()
        local airbases = world.getAirbases()
        for _, airbase in pairs(airbases) do
            local baseId = airbase:getID()
            local point = airbase:getPoint()
            local zone = Spearhead.DcsUtil.getAirbaseZoneById(baseId) or { x = point.x, z = point.z, radius = 4000 }

            local baseData = self:getOrCreateAirbaseData(airbase:getName())
            local groups = Spearhead.DcsUtil.areGroupsInCustomZone(all_groups, zone)
            for _, groupName in pairs(groups) do
                is_group_taken[groupName] = true
                table.insert(baseData.CapGroups, groupName)
            end

            self._tables.AirbaseDataPerAirfield[airbase:getName()] = baseData
        end
    end

    ---@private
    function Database:loadBlueSamUnits()
        local all_groups = Spearhead.DcsUtil.getAllGroupNames()
        for _, blueSamZone in pairs(self._tables.BlueSams) do
            self._tables.BlueSamDataPerZone[blueSamZone] = {
                Groups = {}
            }
            local groups = Spearhead.DcsUtil.getGroupsInZone(all_groups, blueSamZone)
            for _, groupName in pairs(groups) do
                is_group_taken[groupName] = true
                table.insert(self._tables.BlueSamDataPerZone[blueSamZone].Groups, groupName)
            end
        end
    end

    ---@private
    function Database:loadMissionzoneUnits()
        local all_groups = getAvailableGroups()
        for _, missionZoneName in pairs(self._tables.MissionZones) do
            self._tables.MissionZoneData[missionZoneName] = {
                Groups = {}
            }

            local groups = Spearhead.DcsUtil.getGroupsInZone(all_groups, missionZoneName)
            for _, groupName in pairs(groups) do
                is_group_taken[groupName] = true
                table.insert(self._tables.MissionZoneData[missionZoneName].Groups, groupName)
            end
        end
    end

    ---@private
    function Database:loadRandomMissionzoneUnits()
        local all_groups = getAvailableGroups()
        for _, missionZoneName in pairs(self._tables.RandomMissionZones) do
            self._tables.MissionZoneData[missionZoneName] = {
                Groups = {}
            }
            local groups = Spearhead.DcsUtil.getGroupsInZone(all_groups, missionZoneName)
            for _, groupName in pairs(groups) do
                is_group_taken[groupName] = true
                table.insert(self._tables.MissionZoneData[missionZoneName].Groups, groupName)
            end
        end
    end

    ---@private
    function Database:loadFarpGroups()
        local all_groups = getAvailableGroups()
        for _, farpZone in pairs(self._tables.AllFarpZones) do
            self._tables.FarpZoneData[farpZone] = {
                Groups = {}
            }

            local groups = Spearhead.DcsUtil.getGroupsInZone(all_groups, farpZone)
            for _, groupName in pairs(groups) do
                is_group_taken[groupName] = true
                table.insert(self._tables.FarpZoneData[farpZone].Groups, groupName)
            end
        end
    end

    function Database:loadAirbaseGroups()

        local all_groups = getAvailableGroups()
        for _, stageZone in pairs(self._tables.StageZones) do
            
            for _, baseName in pairs(stageZone.AirbaseNames) do
                local base = Airbase.getByName(baseName)

                if base then
                    local basedata = self:getOrCreateAirbaseData(baseName)
                    local baseId = base:getID()
                    local point = base:getPoint()
                    local airbaseZone = Spearhead.DcsUtil.getAirbaseZoneById(baseId) or { x = point.x, z = point.z, radius = 4000 }

                    if airbaseZone and base:getDesc().category == Airbase.Category.AIRDROME then
                        local groups = Spearhead.DcsUtil.areGroupsInCustomZone(all_groups, airbaseZone)
                        for _, groupName in pairs(groups) do
                            if Spearhead.DcsUtil.IsGroupStatic(groupName) == true then
                                local object = StaticObject.getByName(groupName)
                                if object then
                                    if object:getCoalition() == coalition.side.RED then
                                        table.insert(basedata.RedGroups, groupName)
                                        is_group_taken[groupName] = true
                                    elseif object:getCoalition() == coalition.side.BLUE then
                                        table.insert(basedata.BlueGroups, groupName)
                                        is_group_taken[groupName] = true
                                    end
                                end
                            else
                                local group = Group.getByName(groupName)
                                if group then
                                    if group:getCoalition() == coalition.side.RED then
                                        table.insert(basedata.RedGroups, groupName)
                                        is_group_taken[groupName] = true
                                    elseif group:getCoalition() == coalition.side.BLUE then
                                        table.insert(basedata.BlueGroups, groupName)
                                        is_group_taken[groupName] = true
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    ---@private
    function Database:loadMiscGroupsInStages()
        local all_groups = getAvailableGroups()
        for _, stageZone in pairs(self._tables.StageZones) do
            stageZone.MiscGroups = {}

            local groups = Spearhead.DcsUtil.getGroupsInZone(all_groups, stageZone.StageZoneName)
            for _, groupName in pairs(groups) do
                if Spearhead.DcsUtil.IsGroupStatic(groupName) == true then
                    local object = StaticObject.getByName(groupName)
                    if object and object:getCoalition() ~= coalition.side.NEUTRAL then
                        is_group_taken[groupName] = true
                        table.insert(stageZone.MiscGroups, groupName)
                    end
                else
                    local group = Group.getByName(groupName)
                    if group and group:getCoalition() ~= coalition.side.NEUTRAL then
                        is_group_taken[groupName] = true
                        table.insert(stageZone.MiscGroups, groupName)
                    end
                end
            end
        end
    end

    self:loadCapUnits()
    self:loadBlueSamUnits()
    self:loadMissionzoneUnits()
    self:loadRandomMissionzoneUnits()
    self:loadFarpGroups()
    self:loadAirbaseGroups()
    self:loadMiscGroupsInStages()

   
    for _, zoneData in pairs(self._tables.StageZones) do

        local number = zoneData.StageIndex

        for _, cap_route_zone in pairs(self._tables.CapRoutes) do
            if Spearhead.DcsUtil.isZoneInZone(cap_route_zone, zoneData.StageZoneName) == true then
                local zone = Spearhead.DcsUtil.getZoneByName(cap_route_zone)
                if zone then
                    
                    ---@type CapData
                    local capData = self._tables.CapDataPerStageNumber[number]
                    if capData == nil then
                        capData = {
                            routes = {},
                            current = 0
                        }
                        self._tables.CapDataPerStageNumber[number] = capData
                    end
                    

                    if zone.zone_type == Spearhead.DcsUtil.ZoneType.Cilinder then
                        table.insert(capData.routes, { point1 = { x = zone.x, z = zone.z }, point2 = nil })
                    else
                        local function getDist(a, b)
                            return math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
                        end

                        local biggest = nil
                        local biggestA = nil
                        local biggestB = nil

                        for i = 1, 3 do
                            for ii = i + 1, 4 do
                                local a = zone.verts[i]
                                local b = zone.verts[ii]
                                local dist = getDist(a, b)

                                if biggest == nil or dist > biggest then
                                    biggestA = a
                                    biggestB = b
                                    biggest = dist
                                end
                            end
                        end

                        if biggestA and biggestB then
                            table.insert(capData.routes,
                                {
                                    point1 = { x = biggestA.x, z = biggestA.z },
                                    point2 = { x = biggestB.x, z = biggestB.z }
                                })
                        end
                    end
                end
            end
        end
    end

    return self

end


function Database:GetDescriptionForMission(missionZoneName)
    return self._tables.DescriptionsByMission[missionZoneName]
end

function Database:getCapRouteInZone(stageNumber, baseId)
    local stageNumber = tostring(stageNumber) or "nothing"
    local routeData = self._tables.CapDataPerStageNumber[stageNumber]
    if routeData then
        local count = Spearhead.Util.tableLength(routeData.routes)
        if count > 0 then
            routeData.current = routeData.current + 1
            if count < routeData.current then
                routeData.current = 1
            end
            return routeData.routes[routeData.current]
        end
    end
    do
        local function GetClosestPointOnCircle(pC, radius, p)
            local vX = p.x - pC.x;
            local vY = p.z - pC.z;
            local magV = math.sqrt(vX * vX + vY * vY);
            local aX = pC.x + vX / magV * radius;
            local aY = pC.z + vY / magV * radius;
            return { x = aX, z = aY }
        end
        local stageZoneName = Spearhead.Util.randomFromList(self._tables.StageZonesByNumber[stageNumber]) or
        "none"
        local stagezone = Spearhead.DcsUtil.getZoneByName(stageZoneName)
        if stagezone then
            local base = Spearhead.DcsUtil.getAirbaseById(baseId)
            if base then
                local closest = nil
                if stagezone.zone_type == Spearhead.DcsUtil.ZoneType.Cilinder then
                    closest = GetClosestPointOnCircle({ x = stagezone.x, z = stagezone.z }, stagezone.radius,
                        base:getPoint())
                else
                    local function getDist(a, b)
                        return math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
                    end

                    local closestDistance = -1
                    for _, vert in pairs(stagezone.verts) do
                        local distance = getDist(vert, base:getPoint())
                        if closestDistance == -1 or distance < closestDistance then
                            closestDistance = distance
                            closest = vert
                        end
                    end
                end

                if math.random(1, 2) % 2 == 0 then
                    return { point1 = closest, point2 = { x = stagezone.x, z = stagezone.z } }
                else
                    return { point1 = { x = stagezone.x, z = stagezone.z }, point2 = closest }
                end
            end
        end
    end
end


---@return table result a  list of stage zone names
function Database:getStagezoneNames()
    return self._tables.AllZoneNames
end

function Database:getCarrierRouteZones()
    return self._tables.CarrierRouteZones
end

---@return Array<string>
function Database:getMissionsForStage(stagename)
    local stageZone = self._tables.StageZones[stagename]
    if not stageZone then return {} end
    return stageZone.MissionZones
end

---@return Array<string>
function Database:getRandomMissionsForStage(stagename)
    local stageZone = self._tables.StageZones[stagename]
    if not stageZone then return {} end
    return stageZone.RandomMissionZones
end

---@return Array<string>?
function Database:getGroupsForMissionZone(missionZoneName)
    local missionZoneData = self._tables.MissionZoneData[missionZoneName]
    if not missionZoneData then return nil end
    return missionZoneData.Groups
end

---@return string?
function Database:getMissionBriefingForMissionZone(missionZoneName)
    return self._tables.DescriptionsByMission[missionZoneName]
end

---@param self table
---@param stageName string
---@return table result airbase Names
function Database:getAirbaseIdsInStage(stageName)
    return self.tables.airbasesPerStage[stageName] or {}
end


---@param airbaseName string
---@return Array<string>?
function Database:getCapGroupsAtAirbase(airbaseName)
    local airbaseData = self._tables.AirbaseDataPerAirfield[airbaseName]
    if not airbaseData then return nil end
    return airbaseData.CapGroups
end

---@param stageName string
---@return Array<string>
function Database:getBlueSamsInStage(stageName)
    local stageData = self._tables.StageZones[stageName]
    if not stageData then return {} end
    return stageData.BlueSamZones
end

---@param samZone string
---@return Array<string>
function Database:getBlueSamGroupsInZone(samZone)
    local blueSamData = self._tables.BlueSamDataPerZone[samZone]
    if not blueSamData then return {} end
    return blueSamData.Groups
end

---@param airbaseName string
---@return Array<string>
function Database:getRedGroupsAtAirbase(airbaseName)
    local airbaseData = self._tables.AirbaseDataPerAirfield[airbaseName]
    if not airbaseData then return {} end
    return airbaseData.RedGroups
end

---@param airbaseName string
---@return Array<string>
function Database:getBlueGroupsAtAirbase(airbaseName)
    local airbaseData = self._tables.AirbaseDataPerAirfield[airbaseName]
    if not airbaseData then return {} end
    return airbaseData.BlueGroups
end

function Database:getMiscGroupsAtStage(stageName)
    local stageZone = self._tables.StageZones[stageName]
    if not stageZone then return {} end
    return stageZone.MiscGroups
end

---comment
---@param self table
---@return integer|nil
function Database:GetNewMissionCode(self)
    local code = nil
    local tries = 0
    while code == nil and tries < 10 do
        local random = math.random(1000, 9999)
        if self.tables.missionCodes[random] == nil then
            code = random
        end
        tries = tries + 1
    end
    return code

    --[[
        TODO: What to do when there's no random possible
    ]]
end



Spearhead.DB = Database

end --spearhead_db.lua
do --spearhead_routeutil.lua
local ROUTE_UTIL = {}
do --setup route util
    ---comment
    ---@param attackHelos boolean
    ---@return table
    local function GetCAPTargetTypes(attackHelos)
        local targetTypes = {
            [1] = "Planes",
        }

        if attackHelos then
            targetTypes[2] = "Helicopters"
        end

        return targetTypes
    end

    ---comment
    ---@param airdromeId number
    ---@param basePoint table { x, z, y } (y == alt)
    ---@param speed number the speed
    ---@return table task
    local RtbTask = function(airdromeId, basePoint, speed)
        if basePoint == nil then
            basePoint = Spearhead.Util.getAirbaseById(airdromeId):getPoint()
        end

        return {
            alt = basePoint.y,
            action = "Landing",
            alt_type = "BARO",
            speed = speed,
            ETA = 0,
            ETA_locked = false,
            x = basePoint.x,
            y = basePoint.z,
            speed_locked = true,
            formation_template = "",
            airdromeId = airdromeId,
            type = "Land",
            task = {
                id = "ComboTask",
                params = {
                    tasks = {}
                }
            }
        }
    end

    ---comment
    ---@param groupName string
    ---@param position table { x, y}
    ---@param altitude number
    ---@param speed number
    ---@param duration number
    ---@param engageHelos boolean
    ---@param pattern string ["Race-Track"|"Circle"]
    ---@return table
    local CapTask = function(groupName, position, altitude, speed, duration, engageHelos, deviationdistance, pattern)
        local durationBefore10 = duration - 600
        if durationBefore10 < 0 then durationBefore10 = 0 end
        local durationAfter10 = 600
        if duration < 600 then
            durationAfter10 = duration
        end

        return {
            alt = altitude,
            action = "Turning Point",
            alt_type = "BARO",
            speed = speed,
            ETA = 0,
            ETA_locked = false,
            x = position.x,
            y = position.z,
            speed_locked = true,
            formation_template = "",
            task = {
                id = "ComboTask",
                params = {
                    tasks = {
                        [1] = {
                            number = 1,
                            auto = false,
                            id = "WrappedAction",
                            enabled = "true",
                            params = {
                                action = {
                                    id = "Script",
                                    params = {
                                        command = "pcall(Spearhead.Events.PublishOnStation, \"" .. groupName .. "\")"
                                    }
                                }
                            }
                        },
                        [2] = {
                            id = 'EngageTargets',
                            params = {
                                maxDist = deviationdistance,
                                maxDistEnabled = deviationdistance >= 0, -- required to check maxDist
                                targetTypes = GetCAPTargetTypes(engageHelos),
                                priority = 0
                            }
                        },
                        [3] = {
                            number = 3,
                            auto = false,
                            id = "ControlledTask",
                            enabled = true,
                            params = {
                                task = {
                                    id = "Orbit",
                                    params = {
                                        altitude = altitude,
                                        pattern = pattern,
                                        speed = speed,
                                    }
                                },
                                stopCondition = {
                                    duration = durationBefore10,
                                    condition = "return Spearhead.DcsUtil.IsBingoFuel(\"" .. groupName .. "\", 0.10)",
                                }
                            }
                        },
                        [4] = {
                            number = 4,
                            auto = false,
                            id = "WrappedAction",
                            enabled = "true",
                            params = {
                                action = {
                                    id = "Script",
                                    params = {
                                        command = "pcall(Spearhead.Events.PublishRTBInTen, \"" .. groupName .. "\")"
                                    }
                                }
                            }
                        },
                        [5] = {
                            number = 5,
                            auto = false,
                            id = "ControlledTask",
                            enabled = true,
                            params = {
                                task = {
                                    id = "Orbit",
                                    params = {
                                        altitude = altitude,
                                        pattern = pattern,
                                        speed = speed,
                                    }
                                },
                                stopCondition = {
                                    duration = durationAfter10,
                                    condition = "return Spearhead.DcsUtil.IsBingoFuel(\"" .. groupName .. "\")",
                                }
                            }
                        },
                        [6] = {
                            number = 6,
                            auto = false,
                            id = "WrappedAction",
                            enabled = "true",
                            params = {
                                action = {
                                    id = "Script",
                                    params = {
                                        command = "pcall(Spearhead.Events.PublishRTB, \"" .. groupName .. "\")"
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    end

    ---comment
    ---@param position table { x, y}
    ---@param altitude number
    ---@param speed number
    ---@param childTasks table
    ---@return table
    local FlyToPointTask = function(position, altitude, speed, childTasks)
        return {
            alt = altitude,
            action = "Turning Point",
            alt_type = "BARO",
            speed = speed,
            ETA = 0,
            ETA_locked = false,
            x = position.x,
            y = position.z,
            speed_locked = true,
            formation_template = "",
            task = {
                id = "ComboTask",
                params = {
                    tasks = childTasks or {}
                }
            }
        }
    end

    ---comment
    ---@param groupName string groupName you're creating this route for
    ---@param airdromeId number airdromeId
    ---@param capPoint table { x, z }
    ---@param altitude number
    ---@param speed number
    ---@param durationOnStation number
    ---@param attackHelos boolean
    ---@param deviationDistance number
    ---@return table route
    ROUTE_UTIL.createCapMission = function(groupName, airdromeId, capPoint, racetrackSecondPoint, altitude, speed,
                                           durationOnStation, attackHelos, deviationDistance)
        local baseName = Spearhead.DcsUtil.getAirbaseName(airdromeId)
        if baseName == nil then
            return {}
        end

        durationOnStation = durationOnStation or 1800
        altitude = altitude or 3000
        speed = speed or 130
        attackHelos = attackHelos or false
        deviationDistance = deviationDistance or 32186

        local base = Airbase.getByName(baseName)
        if base == nil then
            return {}
        end

        local additionalFlyOverTasks = {
            {
                enabled = true,
                auto = false,
                id = "WrappedAction",
                number = 1,
                params = {
                    action = {
                        id = "Option",
                        params = {
                            variantIndex = 2,
                            name = AI.Option.Air.id.FORMATION,
                            formationIndex = 2,
                            value = 131074
                        }
                    }
                }
            }
        }

        local orbitType = "Circle"
        if racetrackSecondPoint then orbitType = "Race-Track" end

        local basePoint = base:getPoint()
        local points = {}
        if racetrackSecondPoint == nil then
            points = {
                [1] = FlyToPointTask(capPoint, altitude, speed, additionalFlyOverTasks),
                [2] = CapTask(groupName, capPoint, altitude, speed, durationOnStation, attackHelos, deviationDistance,
                    orbitType),
                [3] = RtbTask(airdromeId, basePoint, speed)
            }
        else
            points = {
                [1] = FlyToPointTask(capPoint, altitude, speed, additionalFlyOverTasks),
                [2] = CapTask(groupName, capPoint, altitude, speed, durationOnStation, attackHelos, deviationDistance,
                    orbitType),
                [3] = FlyToPointTask(racetrackSecondPoint, altitude, speed, {}),
                [4] = RtbTask(airdromeId, basePoint, speed)
            }
        end

        return {
            id = 'Mission',
            params = {
                airborne = true,
                route = {
                    points = points
                }
            }
        }
    end

    ---Creates an RTB task. The first point is to trigger the TDCS OnRTB Event, the second task will be the actual RTB point
    ---If any of the values are not met it will return nil
    ---@param groupName string
    ---@param airdromeId number
    ---@param speed number
    ---@return table?, string ComboTask
    ROUTE_UTIL.CreateRTBMission = function(groupName, airdromeId, speed)
        --[[
            TODO: Test the creation and pubishing of event and the timing of said event
        ]] --

        local base = Spearhead.DcsUtil.getAirbaseById(airdromeId)
        if base == nil then
            return nil, "No airbase found for ID " .. tostring(airdromeId)
        end

        local group = Group.getByName(groupName)
        local pos;
        local i = 1
        local units = group:getUnits()
        while pos == nil and i <= Spearhead.Util.tableLength(units) do
            local unit = units[i]
            if unit and unit:isExist() == true and unit:inAir() == true then
                pos = unit:getPoint()
            end
            i = i + 1
        end

        speed = speed or 130
        if pos == nil then
            return nil, "Could not find any unit in the air to set the RTB task"
        end

        local additionalFlyOverTasks = {
            {
                enabled = true,
                auto = false,
                id = "WrappedAction",
                number = 1,
                params = {
                    action = {
                        id = "Option",
                        params = {
                            variantIndex = 2,
                            name = AI.Option.Air.id.FORMATION,
                            formationIndex = 2,
                            value = 131074
                        }
                    }
                }
            }
        }

        return {
            id = "Mission",
            params = {
                airborne = true, -- RTB mission generally are given to airborne units
                route = {
                    points = {

                        [1] = {
                            alt = pos.y,
                            action = "Turning Point",
                            alt_type = "BARO",
                            speed = speed,
                            ETA = 0,
                            ETA_locked = false,
                            x = pos.x,
                            y = pos.z,
                            speed_locked = true,
                            formation_template = "",
                            task = {
                                id = "ComboTask",
                                params = {
                                    tasks = {
                                        [1] = {
                                            number = 1,
                                            auto = false,
                                            id = "WrappedAction",
                                            enabled = "true",
                                            params = {
                                                action = {
                                                    id = "Script",
                                                    params = {
                                                        command = "pcall(Spearhead.Events.PublishRTB, \"" ..
                                                            groupName .. "\")"
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        },
                        [2] = FlyToPointTask(base:getPoint(), 600, speed, additionalFlyOverTasks),
                        [3] = RtbTask(airdromeId, base:getPoint(), speed)
                    }
                }
            }
        }, ""
    end

    ROUTE_UTIL.CreateCarrierRacetrack = function(pointA, pointB)
        return {
            id = "Mission",
            params = {
                airborne = false,
                route = {
                    points = {
                        [1] =
                        {
                            ["alt"] = -0,
                            ["type"] = "Turning Point",
                            ["ETA"] = 0,
                            ["alt_type"] = "BARO",
                            ["formation_template"] = "",
                            ["y"] = pointA.z,
                            ["x"] = pointA.x,
                            ["ETA_locked"] = false,
                            ["speed"] = 13.88888,
                            ["action"] = "Turning Point",
                            ["task"] =
                            {
                                ["id"] = "ComboTask",
                                ["params"] =
                                {
                                    ["tasks"] = {},
                                }, -- end of ["params"]
                            }, -- end of ["task"]
                            ["speed_locked"] = true,
                        },
                        [2] =
                        {
                            ["alt"] = -0,
                            ["type"] = "Turning Point",
                            ["ETA"] = -0,
                            ["alt_type"] = "BARO",
                            ["formation_template"] = "",
                            ["y"] = pointB.z,
                            ["x"] = pointB.x,
                            ["ETA_locked"] = false,
                            ["speed"] = 13.88888,
                            ["action"] = "Turning Point",
                            ["task"] =
                            {
                                ["id"] = "ComboTask",
                                ["params"] =
                                {
                                    ["tasks"] =
                                    {
                                        [1] =
                                        {
                                            ["enabled"] = true,
                                            ["auto"] = false,
                                            ["id"] = "GoToWaypoint",
                                            ["number"] = 1,
                                            ["params"] =
                                            {
                                                ["fromWaypointIndex"] = 2,
                                                ["nWaypointIndx"] = 1,
                                            },
                                        },
                                    },
                                },
                            },
                            ["speed_locked"] = true,
                        }
                    }
                }
            }
        }, ""
    end
end

if Spearhead == nil then Spearhead = {} end
Spearhead.RouteUtil = ROUTE_UTIL
end --spearhead_routeutil.lua
do --spearhead_base.lua
--- DEFAULT Values
if Spearhead == nil then Spearhead = {} end

local UTIL = {}
do -- INIT UTIL
    ---splits a string in sub parts by seperator
    ---@param input string
    ---@param seperator string
    ---@return table result list of strings
    function UTIL.split_string(input, seperator)
        if seperator == nil then
            seperator = " "
        end

        local result = {}
        if input == nil then
            return result
        end

        for str in string.gmatch(input, "[^" .. seperator .. "]+") do
            table.insert(result, str)
        end
        return result
    end

    ---comment
    ---@param table any
    ---@return number
    function UTIL.tableLength(table)
        if table == nil then return 0 end

        local count = 0
        for _ in pairs(table) do count = count + 1 end
        return count
    end

    ---Gets a random from the list
    ---@param list table
    function UTIL.randomFromList(list)
        local max = #list

        if max == 0 or max == nil then
            return nil
        end

        local random = math.random(0, max)
        if random == 0 then random = 1 end

        return list[random]
    end

    local function table_print(tt, indent, done)
        done = done or {}
        indent = indent or 0
        if type(tt) == "table" then
            local sb = {}
            for key, value in pairs(tt) do
                table.insert(sb, string.rep(" ", indent)) -- indent it
                if type(value) == "table" and not done[value] then
                    done[value] = true
                    table.insert(sb, key .. " = {\n");
                    table.insert(sb, table_print(value, indent + 2, done))
                    table.insert(sb, string.rep(" ", indent)) -- indent it
                    table.insert(sb, "}\n");
                elseif "number" == type(key) then
                    table.insert(sb, string.format("\"%s\"\n", tostring(value)))
                else
                    table.insert(sb, string.format(
                        "%s = \"%s\"\n", tostring(key), tostring(value)))
                end
            end
            return table.concat(sb)
        else
            return tt .. "\n"
        end
    end

    ---comment
    ---@param str string
    ---@param findable string
    ---@param ignoreCase boolean?
    ---@return boolean
    UTIL.startswith = function(str, findable, ignoreCase)

        if ignoreCase == true then
            return string.lower(str):find('^' .. string.lower(findable)) ~= nil
        end

        return str:find('^' .. findable) ~= nil
    end

    ---comment
    ---@param str string
    ---@param findable string
    ---@return boolean
    UTIL.strContains = function(str, findable)
        return str:find(findable) ~= nil
    end

    ---comment
    ---@param str string
    ---@param findableTable table
    ---@return boolean
    UTIL.startswithAny = function(str, findableTable)
        for key, value in pairs(findableTable) do
            if type(value) == "string" and UTIL.startswith(str, value) then return true end
        end
        return false
    end

    function UTIL.toString(something)
        if something == nil then
            return "nil"
        elseif "table" == type(something) then
            return table_print(something)
        elseif "string" == type(something) then
            return something
        else
            return tostring(something)
        end
    end

    ---comment
    ---@param a table DCS Point vector {x, z , y} 
    ---@param b table DCS Point vector {x, z , y} 
    ---@return number
    function UTIL.VectorDistance(a, b)
        return math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
    end

    ---comment
    ---@param polygon table of pairs { x, z }
    ---@param x number X location
    ---@param z number Y location
    ---@return boolean
    function UTIL.IsPointInPolygon(polygon, x, z)
        local function isInComplexPolygon(polygon, x, z)
            local function getEdges(poly)
                local result = {}
                for i = 1, #poly do
                    local point1 = poly[i]
                    local point2Index = i + 1
                    if point2Index > #poly then point2Index = 1 end
                    local point2 = poly[point2Index]
                    local edge = { x1 = point1.x, z1 = point1.z, x2 = point2.x, z2 = point2.z }
                    table.insert(result, edge)
                end
                return result
            end

            local edges = getEdges(polygon)
            local count = 0;
            for _, edge in pairs(edges) do
                if (x < edge.x1) ~= (x < edge.x2) and z < edge.z1 + ((x - edge.x1) / (edge.x2 - edge.x1)) * (edge.z2 - edge.z1) then
                    count = count + 1
                    -- if (yp < y1) != (yp < y2) and xp < x1 + ((yp-y1)/(y2-y1))*(x2-x1) then
                    --     count = count + 1
                end
            end
            return count % 2 == 1
        end
        return isInComplexPolygon(polygon, x, z)
    end

    ---comment
    ---@param points table points { x, z }
    ---@return table hullPoints { x, z }
    function UTIL.getConvexHull(points)
        if #points == 0 then
            return {}
        end

        local function ccw(a,b,c)
            return (b.z - a.z) * (c.x - a.x) > (b.x - a.x) * (c.z - a.z)
        end

        table.sort(points, function(left,right)
            return left.z < right.z
        end)

        local hull = {}
        -- lower hull
        for _,point in pairs(points) do
            while #hull >= 2 and not ccw(hull[#hull-1], hull[#hull], point) do
                table.remove(hull,#hull)
            end
            table.insert(hull,point)
        end

        -- upper hull
        local t = #hull + 1
        for i=#points, 1, -1 do
            local point = points[i]
            while #hull >= t and not ccw(hull[#hull-1], hull[#hull], point) do
                table.remove(hull,#hull)
            end
            table.insert(hull,point)
        end
        table.remove(hull,#hull)
        return hull
    end

    function UTIL.enlargeConvexHull(points, meters)

        local allpoints = {} 
        
        for _, point in pairs(points) do
            table.insert(allpoints, point)
            table.insert(allpoints, { x = point.x + meters, z = point.z, y= 0 })
            table.insert(allpoints, { x = point.x - meters, z = point.z, y= 0 })
            table.insert(allpoints, { x = point.x, z = point.z + meters, y= 0 })
            table.insert(allpoints, { x = point.x, z = point.z - meters, y= 0 })

            table.insert(allpoints, { x = point.x + math.cos(math.rad(45)) * meters, z = point.z + math.sin(math.rad(45)) * meters, y= 0 })
            table.insert(allpoints, { x = point.x - math.cos(math.rad(45)) * meters, z = point.z - math.sin(math.rad(45)) * meters, y= 0 })
            table.insert(allpoints, { x = point.x - math.cos(math.rad(45)) * meters, z = point.z + math.sin(math.rad(45)) * meters, y= 0 })
            table.insert(allpoints, { x = point.x + math.cos(math.rad(45)) * meters, z = point.z - math.sin(math.rad(45)) * meters, y= 0 })

        end

        return UTIL.getConvexHull(allpoints)
    end
end
Spearhead.Util = UTIL

---DCS UTIL Takes inspiration from MIST but only takes the things it needs, changes for DCS updates and different vision for advanced mission scripting stuff.
---It also adds functions that make the other TDCS scripts easier without taking too much "control" away like MOOSE can sometimes.
local DCS_UTIL = {}
do     -- INIT DCS_UTIL
    do -- local databases
        --[[
            groupdata = {
                category,
                country_id,
                group_template
            }
        ]] --
        DCS_UTIL.__miz_groups = {}
        DCS_UTIL.__groupNames = {}
        DCS_UTIL.__blueGroupNames = {}
        DCS_UTIL.__redGroupNames = {}
        --[[
            zone = {
                name,

                zone_type,
                x,
                z,
                radius
                verts,

            }
        ]] --
        DCS_UTIL.__trigger_zones = {}
    end

    DCS_UTIL.Coalition =
    {
        NEUTRAL = 0,
        RED = 1,
        BLUE = 2
    }

    DCS_UTIL.ZoneType = {
        Cilinder = 0,
        Polygon = 2
    }

    DCS_UTIL.GroupCategory = {
        AIRPLANE   = 0,
        HELICOPTER = 1,
        GROUND     = 2,
        SHIP       = 3,
        TRAIN      = 4,
        STATIC     = 5 --CUSTOM CATEGORY
    }

    DCS_UTIL.__airbaseNamesById = {}
    --[[
        zone = {
            name,
            zone_type,
            x,
            z,
            radius
            verts,

        }
    ]] --
    DCS_UTIL.__airbaseZonesById = {}

    DCS_UTIL.__airportsStartingCoalition = {}
    DCS_UTIL.__warehouseStartingCoalition = {}
    function DCS_UTIL.__INIT()
        do     -- INITS ALL TABLES WITH DATA THAT's from the MIZ environment
            do -- init group tables
                for coalition_name, coalition_data in pairs(env.mission.coalition) do
                    local coalition_nr = DCS_UTIL.stringToCoalition(coalition_name)
                    if coalition_data.country then
                        for country_index, country_data in pairs(coalition_data.country) do
                            for category_name, categorydata in pairs(country_data) do
                                local category_id = DCS_UTIL.stringToGroupCategory(category_name)
                                if category_id ~= nil and type(categorydata) == "table" and categorydata.group ~= nil and type(categorydata.group) == "table" then
                                    for group_index, group in pairs(categorydata.group) do
                                        local name = group.name
                                        if category_id == DCS_UTIL.GroupCategory.STATIC then
                                            local unit = group.units[1]
                                            name = unit.name
                                            local staticObj = {
                                                heading = unit.heading,
                                                name = unit.name,
                                                x = unit.x,
                                                y = unit.y,
                                                type = unit.type,
                                                dead = group.dead
                                            }

                                            if string.lower(unit.category) == "planes" then
                                                staticObj.livery_id = unit.livery_id
                                            end

                                            group = staticObj
                                        end

                                        table.insert(DCS_UTIL.__groupNames, name)
                                        DCS_UTIL.__miz_groups[name] =
                                        {
                                            category = category_id,
                                            country_id = country_data.id,
                                            group_template = group
                                        }

                                        if coalition_nr == 1 then
                                            table.insert(DCS_UTIL.__redGroupNames, name)
                                        elseif coalition_nr == 2 then
                                            table.insert(DCS_UTIL.__blueGroupNames, name)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end

            do --init trigger zones
                for i, trigger_zone in pairs(env.mission.triggers.zones) do

                    -- reorder verts as they are not ordered correctly in the ME
                    verts = {}
                    if Spearhead.Util.tableLength(trigger_zone.verticies) >=4 then
                        table.insert(verts, { x = trigger_zone.verticies[4].x , z = trigger_zone.verticies[4].y })
                        table.insert(verts, { x = trigger_zone.verticies[3].x , z = trigger_zone.verticies[3].y })
                        table.insert(verts, { x = trigger_zone.verticies[2].x , z = trigger_zone.verticies[2].y })
                        table.insert(verts, { x = trigger_zone.verticies[1].x , z = trigger_zone.verticies[1].y })
                    end
                    
                    local zone = {
                        name = trigger_zone.name,
                        zone_type = trigger_zone.type,
                        x = trigger_zone.x,
                        z = trigger_zone.y,
                        radius = trigger_zone.radius,
                        verts = verts
                    }

                    DCS_UTIL.__trigger_zones[zone.name] = zone
                end
            end

            do -- init airports and warehouses
                if env.warehouses.airports then
                    for warehouse_id, value in pairs(env.warehouses.airports) do
                        if warehouse_id ~= nil then
                            warehouse_id = tostring(warehouse_id) or "nil"
                            local coalitionNumber = DCS_UTIL.stringToCoalition(value.coalition)
                            DCS_UTIL.__airportsStartingCoalition[warehouse_id] = coalitionNumber
                        end
                    end
                end

                if env.warehouses.warehouses then
                    DCS_UTIL.__warehouseStartingCoalition[-1] = "placeholder"
                    for warehouse_id, value in pairs(env.warehouses.warehouses) do
                        if warehouse_id ~= nil then
                            warehouse_id = tostring(warehouse_id) or "nil"
                            local coalitionNumber = DCS_UTIL.stringToCoalition(value.coalition)
                            DCS_UTIL.__warehouseStartingCoalition[warehouse_id] = coalitionNumber
                        end
                    end
                end
            end

            do -- fill airbaseNames and zones 
                local airbases = world.getAirbases()
                if airbases then
                    for _, airbase in pairs(airbases) do
                        local name = airbase:getName()
                        local id = tostring(airbase:getID())

                        if name and id then
                            DCS_UTIL.__airbaseNamesById[id] = name

                            local relevantPoints = {}
                            for _, x in pairs(airbase:getRunways()) do
                                if x.position and x.position.x and x.position.z then
                                    table.insert(relevantPoints, { x = x.position.x, z = x.position.z, y=0})
                                end
                            end

                            for _, x in pairs(airbase:getParking()) do
                                if x.vTerminalPos and x.vTerminalPos.x and x.vTerminalPos.z then
                                    table.insert(relevantPoints, { x = x.vTerminalPos.x, z = x.vTerminalPos.z,  y=0})
                                end
                            end
                            
                            local points = UTIL.getConvexHull(relevantPoints)
                            local enlargedPoints = UTIL.enlargeConvexHull(points, 750)

                            DCS_UTIL.__airbaseZonesById[id] = {
                                name = name,
                                zone_type = DCS_UTIL.ZoneType.Polygon,
                                verts = enlargedPoints
                            }
                        end
                    end
                end
            end
        end
    end

    ---maps the coalition name to the DCS coalition integer
    ---@param input string the name
    ---@return integer
    function DCS_UTIL.stringToCoalition(input)
        --[[
            coalition.side = {
                NEUTRAL = 0
                RED = 1
                BLUE = 2
            }
        ]] --
        local input = string.lower(input)
        if input == 'neutrals' or input == "neutral" or input == "0" then
            return DCS_UTIL.Coalition.NEUTRAL
        end

        if input == 'red' or input == "1" then
            return DCS_UTIL.Coalition.RED
        end

        if input == 'blue' or input == "2" then
            return DCS_UTIL.Coalition.BLUE
        end

        return -1
    end

    ---checks if the groupname is a static group
    ---@param groupName any
    function DCS_UTIL.IsGroupStatic(groupName)
        if DCS_UTIL.__miz_groups[groupName] then
            return DCS_UTIL.__miz_groups[groupName].category == 5;
        end

        return StaticObject.getByName(groupName) ~= nil
    end

    ---destroy the given group
    ---@param groupName string 
    function DCS_UTIL.DestroyGroup(groupName)
        if DCS_UTIL.IsGroupStatic(groupName) then
            local object = StaticObject.getByName(groupName)
            if object ~= nil then
                object:destroy()
            end
        else
            local group = Group.getByName(groupName)
            if group and group:isExist() then
                group:destroy()
            end
        end
    end

    ---destroy the given unit
    function DCS_UTIL.DestroyUnit(unitName)
        if DCS_UTIL.IsGroupStatic(unitName) == true then
            local object = StaticObject.getByName(unitName)
            if object ~= nil then
                object:destroy()
            end
        else
            local unit = Unit.getByName(unitName)
            if unit and unit:isExist() then
                unit:destroy()
            end
        end
    end


    --- takes a list of units and returns all the units that are in any of the zones
    ---@param unit_names table unit names
    ---@param zone_names table zone names
    ---@return table unit list of objects { unit = UNIT, zone_name = zoneName}
    function DCS_UTIL.getUnitsInZones(unit_names, zone_names)
        local units = {}
        local zones = {}

        for k = 1, #unit_names do
            local unit = Unit.getByName(unit_names[k]) or StaticObject.getByName(unit_names[k])
            if unit and unit:isExist() == true then
                units[#units + 1] = unit
            end
        end

        for index, zone_name in pairs(zone_names) do
            local zone = DCS_UTIL.__trigger_zones[zone_name]
            if zone then
                zones[#zones + 1] = zone
            end
        end

        local in_zone_units = {}
        for units_ind = 1, #units do
            local lUnit = units[units_ind]
            local unit_pos = lUnit:getPosition().p
            local lCat = Object.getCategory(lUnit)
            for zone_name, zone in pairs(zones) do
                if unit_pos and ((lCat == 1 and lUnit:isActive() == true) or lCat ~= 1) then -- it is a unit and is active or it is not a unit
                    if zone.zone_type == DCS_UTIL.ZoneType.Polygon and zone.verts then
                        if UTIL.IsPointInPolygon(zone.verts, unit_pos.x, unit_pos.z) == true then
                            in_zone_units[#in_zone_units + 1] = { unit = lUnit, zone_name = zone.name }
                        end
                    else
                        if (((unit_pos.x - zone.x) ^ 2 + (unit_pos.z - zone.z) ^ 2) ^ 0.5 <= zone.radius) then
                            in_zone_units[#in_zone_units + 1] = { unit = lUnit, zone_name = zone.name }
                        end
                    end
                end
            end
        end
        return in_zone_units
    end

    --- takes a list of groups and returns all the group leaders that are in any of the zones
    ---@param group_names table unit names
    ---@param zone_name string zone names
    ---@return table groupnames list of group names
    function DCS_UTIL.getGroupsInZone(group_names, zone_name)
        local zone = DCS_UTIL.__trigger_zones[zone_name]
        if zone == nil then
            return {}
        end

        -- MAP Just for mapping sake
        local custom_zone = {
            x = zone.x,
            z = zone.z,
            zone_type = zone.zone_type,
            radius = zone.radius,
            verts = zone.verts
        }

        return DCS_UTIL.areGroupsInCustomZone(group_names, custom_zone)
    end

    --- takes a x, y poistion and checks if it is inside any of the zones
    ---@param group_names table North South position
    ---@param zone table { x, z, zonetype,  radius, verts }
    ---@return table groupnames list of groups that are in the zone
    function DCS_UTIL.areGroupsInCustomZone(group_names, zone)
        local units = {}
        if Spearhead.Util.tableLength(group_names) < 1 then return {} end

        for k = 1, #group_names do
            local entry = nil
            local group = Group.getByName(group_names[k])
            if group ~= nil then
                entry = { unit = group:getUnit(1), groupname = group_names[k] }
            else
                entry = { unit = StaticObject.getByName(group_names[k]), groupname = group_names[k] }
            end

            if entry and entry.unit and entry.unit:isExist() == true then
                units[#units + 1] = entry
            end
        end

        local result_groups = {}
        for _, entry in pairs(units) do
            local pos = entry.unit:getPoint()
            if zone.zone_type == DCS_UTIL.ZoneType.Polygon and zone.verts then
                if UTIL.IsPointInPolygon(zone.verts, pos.x, pos.z) == true then
                    table.insert(result_groups, entry.groupname)
                end
            else
                if (((pos.x - zone.x) ^ 2 + (pos.z - zone.z) ^ 2) ^ 0.5 <= zone.radius) then
                    table.insert(result_groups, entry.groupname)
                end
            end
        end
        return result_groups
    end

    --- takes a x, y poistion and checks if it is inside any of the zones
    ---@param x number North South position
    ---@param z number West East position
    ---@param zone_names table zone names
    ---@return table zones list of objects { zone_name = zoneName}
    function DCS_UTIL.isPositionInZones(x, z, zone_names)
        local zones = {}
        for index, zone_name in pairs(zone_names) do
            local zone = DCS_UTIL.__trigger_zones[zone_name]
            if zone then
                zones[#zones + 1] = zone
            end
        end

        local result_zones = {}
        for zone_name, zone in pairs(zones) do
            if zone.zone_type == DCS_UTIL.ZoneType.Polygon and zone.verts then
                if UTIL.IsPointInPolygon(zone.verts, x, z) == true then
                    result_zones[#result_zones + 1] = zone.name
                end
            else
                if (((x - zone.x) ^ 2 + (z - zone.z) ^ 2) ^ 0.5 <= zone.radius) then
                    result_zones[#result_zones + 1] = zone.name
                end
            end
        end
        return result_zones
    end

    --- takes a x, y poistion and checks if it is inside any of the zones
    ---@param x number North South position
    ---@param z number West East position
    ---@param zone_name string zone name
    ---@return boolean result
    function DCS_UTIL.isPositionInZone(x, z, zone_name)
        local zone = DCS_UTIL.__trigger_zones[zone_name]
        if zone.zone_type == DCS_UTIL.ZoneType.Polygon and zone.verts then
            if UTIL.IsPointInPolygon(zone.verts, x, z) == true then
                return true
            end
        else
            if (((x - zone.x) ^ 2 + (z - zone.z) ^ 2) ^ 0.5 <= zone.radius) then
                return true
            end
        end
        return false
    end

    --- takes a x, y poistion and checks if it is inside any of the zones
    ---@param zone_name string
    ---@param parent_zone_name string
    ---@return boolean result
    function DCS_UTIL.isZoneInZone(zone_name, parent_zone_name)
        local zoneA = DCS_UTIL.__trigger_zones[zone_name]
        local zoneB = DCS_UTIL.__trigger_zones[parent_zone_name]

        if zoneB.zone_type == DCS_UTIL.ZoneType.Polygon and zoneB.verts then
            if UTIL.IsPointInPolygon(zoneB.verts, zoneA.x, zoneA.z) == true then
                return true
            end
        else
            if (((zoneA.x - zoneB.x) ^ 2 + (zoneA.z - zoneB.z) ^ 2) ^ 0.5 <= zoneB.radius) then
                return true
            end
        end
        return false
    end

    --- takes a x, y poistion and checks if it is inside any of the zones
    ---@param x number North South position
    ---@param z number West East position
    ---@param zone table { x, z, zonetype,  radius }
    ---@return boolean result
    function DCS_UTIL.isPositionInCustomZone(x, z, zone)
        if zone.zone_type == DCS_UTIL.ZoneType.Polygon and zone.verts then
            if UTIL.IsPointInPolygon(zone.verts, x, z) == true then
                return true
            end
        else
            if (((x - zone.x) ^ 2 + (z - zone.z) ^ 2) ^ 0.5 <= zone.radius) then
                return true
            end
        end
        return false
    end

    ---comment
    ---@param zone_name any
    ---@return table? zone { name,b zone_type, x, z, radius, verts }
    function DCS_UTIL.getZoneByName(zone_name)
        if zone_name == nil then return nil end
        return DCS_UTIL.__trigger_zones[zone_name]
    end

    ---comment
    ---@param airbaseId any
    ---@return table? zone { name,b zone_type, x, z, radius, verts }
    function DCS_UTIL.getAirbaseZoneById(airbaseId)
        local string = tostring(airbaseId)
        if string == nil then return nil end
        return DCS_UTIL.__airbaseZonesById[string]
    end



    ---maps the category name to the DCS group category
    ---@param input string the name
    ---@return integer?
    function DCS_UTIL.stringToGroupCategory(input)
        input = string.lower(input)
        if input == 'airplane' or input == 'plane' then
            return DCS_UTIL.GroupCategory.AIRPLANE
        end
        if input == 'helicopter' then
            return DCS_UTIL.GroupCategory.HELICOPTER
        end
        if input == 'ground' or input == 'vehicle' then
            return DCS_UTIL.GroupCategory.GROUND
        end
        if input == 'ship' then
            return DCS_UTIL.GroupCategory.SHIP
        end
        if input == 'train' then
            return DCS_UTIL.GroupCategory.TRAIN
        end
        if input == "static" then
            return DCS_UTIL.GroupCategory.STATIC
        end
        return nil;
    end

    --- get the group config as per start of the mission
    --- group = {
    ---     category,
    ---     country_id,
    ---     group_template
    --- }
    ---@param groupname string groupName you're looking for
    function DCS_UTIL.GetMizGroupOrDefault(groupname, default)
        local group = DCS_UTIL.__miz_groups[groupname]
        if group == nil then
            return default
        end
        return group
    end

    ---comment Get all group names. Can be a LOT
    ---Includes statics
    ---@return table groups
    function DCS_UTIL.getAllGroupNames()
        return DCS_UTIL.__groupNames
    end

    ---comment Get all BLUE group names. Can be a LOT
    ---Includes statics
    ---@return table groups
    function DCS_UTIL.getAllBlueGroupNames()
        return DCS_UTIL.__blueGroupNames
    end

    ---comment Get all RED group names. Can be a LOT
    ---Includes statics
    ---@return table groups
    function DCS_UTIL.getAllRedGroupNames()
        return DCS_UTIL.__redGroupNames
    end

    ---comment Get all units that are players
    ---@return table units
    function DCS_UTIL.getAllPlayerUnits()
        local units = {}
        for i = 0,2 do
            local players = coalition.getPlayers(i)
            for key, unit in pairs(players) do
                units[#units + 1] = unit
            end
        end
        return units
    end

    ---get base name from ID
    ---@param baseId number
    ---@return string? name
    function DCS_UTIL.getAirbaseName(baseId)
        local stringified = tostring(baseId)
        return DCS_UTIL.__airbaseNamesById[stringified]
    end

    ---get base from id
    ---@param baseId number
    ---@return table? table
    function DCS_UTIL.getAirbaseById(baseId)
        local name = DCS_UTIL.getAirbaseName(baseId)
        if name == nil then return nil end
        return Airbase.getByName(name)
    end

    ---Get the starting coalition of a farp or airbase
    ---@return number? coalition
    function DCS_UTIL.getStartingCoalition(baseId)
        if baseId == nil then
            return nil
        end

        --STRING based dictionary otherwise it'll be a string/collapsed array
        baseId = tostring(baseId) or "nil"

        local result = DCS_UTIL.__airportsStartingCoalition[baseId]
        if result == nil then
            result = DCS_UTIL.__warehouseStartingCoalition[baseId]
        end
        return result
    end

    ---Spawn an corpse
    ---@param countryId number countryId
    ---@param unitType string
    ---@param location table { z, y, z}
    ---@param heading number
    function DCS_UTIL.SpawnCorpse(countryId, unitName, unitType, location, heading)
        local name = "dead_" .. unitName

        local staticObj = {
            ["heading"] = heading,
            --["shape_name"] = "stolovaya",
            ["type"] = unitType,
            ["name"] = name,
            ["y"] = location.z,
            ["x"] = location.x,
            ["dead"] = true,
        }

        coalition.addStaticObject(countryId, staticObj)
    end

    function DCS_UTIL.CleanCorpse(unitName)
        local unitName = "dead_" .. unitName

        local object = StaticObject.getByName(unitName)

        if object then
            object:destroy()
        end
    end

    --- spawns the units as specified in the mission file itself
    --- location and route can be nil and will then use default route
    ---@param groupName string
    ---@param location table? vector 3 data. { x , z, alt }
    ---@param route table? route of the group. If nil wil be the default route.
    ---@param uncontrolled boolean? Sets the group to be uncontrolled on spawn
    ---@return table? new_group the Group class that was spawned
    ---@return boolean? isStatic whether the group is a static or not
    function DCS_UTIL.SpawnGroupTemplate(groupName, location, route, uncontrolled)
        if groupName == nil then
            return nil, nil
        end

        local template = DCS_UTIL.GetMizGroupOrDefault(groupName, nil)
        if template == nil then
            return nil, nil
        end
        if template.category == DCS_UTIL.GroupCategory.STATIC then
            --TODO: Implement location and route stuff
            local spawn_template = template.group_template
            return coalition.addStaticObject(template.country_id, spawn_template), true
        else
            local spawn_template = template.group_template
            if location ~= nil then
                local x_offset
                if location.x ~= nil then x_offset = spawn_template.x - location.x end

                local y_offset
                if location.z ~= nil then y_offset = spawn_template.y - location.z end

                spawn_template.x = location.x
                spawn_template.y = location.z

                for i, unit in pairs(spawn_template.units) do
                    unit.x = unit.x - x_offset
                    unit.y = unit.y - y_offset
                    unit.alt = location.alt
                end
            end

            if route ~= nil then
                spawn_template.route = route
            end

            if uncontrolled ~= nil then
                spawn_template.uncontrolled = uncontrolled
            end
            local new_group = coalition.addGroup(template.country_id, template.category, spawn_template)
            return new_group, false
        end
    end

    function DCS_UTIL.IsBingoFuel(groupName, offset)
        if offset == nil then offset = 0 end
        local bingoSetting = 0.20
        bingoSetting = bingoSetting + offset

        local group = Group.getByName(groupName)
        if group then
            for _, unit in pairs(group:getUnits()) do
                if unit and unit:isExist() == true and unit:inAir() == true and unit:getFuel() < bingoSetting then
                    return true
                end
            end
        end
        
        return false
    end

    DCS_UTIL.__INIT();
end
Spearhead.DcsUtil = DCS_UTIL

local LOGGER = {}
do
    

    local PreFix = "Spearhead"

    --- @class Logger
    --- @field debug fun(self:Logger, text:string)
    --- @field info fun(self:Logger, text:string)
    --- @field warn fun(self:Logger, text:string)
    --- @field error fun(self:Logger, text:string)

    ---comment
    ---@param logger_name any
    ---@param logLevel LogLevel
    ---@return Logger
    function LOGGER:new(logger_name, logLevel)
        local o = {}
        setmetatable(o, { __index = self })
        o.LoggerName = logger_name or "(loggername not set)"
        o.LogLevel = logLevel or "INFO"

        ---comment
        ---@param self table self logger
        ---@param message any the message
        o.info = function(self, message)
            if message == nil then
                return
            end
            message = UTIL.toString(message)

            if self.LogLevel == "INFO" or self.LogLevel == "DEBUG" then
                env.info("[" .. PreFix .. "]" .. "[" .. self.LoggerName .. "] " .. message)
            end
        end

        ---comment
        ---@param message string
        o.warn = function(self, message)
            if message == nil then
                return
            end
            message = UTIL.toString(message)

            if self.LogLevel == "INFO" or self.LogLevel == "DEBUG" or self.LogLevel == "WARN" then
                env.info("[" .. PreFix .. "]" .. "[" .. self.LoggerName .. "] " .. message)
            end
        end

        ---comment
        ---@param self table -- logger
        ---@param message any -- the message
        o.error = function(self, message)
            if message == nil then
                return
            end

            message = UTIL.toString(message)

            if self.LogLevel == "INFO" or self.LogLevel == "DEBUG" or self.LogLevel == "WARN" or self.logLevel == "ERROR" then
                env.info("[" .. PreFix .. "]" .. "[" .. self.LoggerName .. "] " .. message)
            end
        end

        ---write debug
        ---@param self table
        ---@param message any the message
        o.debug = function(self, message)
            if message == nil then
                return
            end

            message = UTIL.toString(message)
            if self.LogLevel == "DEBUG" then
                env.info("[" .. PreFix .. "]" .. "[" .. self.LoggerName .. "][DEBUG] " .. message)
            end
        end


        return o
    end
end
Spearhead.LoggerTemplate = LOGGER

Spearhead.MissionEditingWarnings = {}
function Spearhead.AddMissionEditorWarning(warningMessage)
    table.insert(Spearhead.MissionEditingWarnings, warningMessage or "skip")
end

local loadDone = false
Spearhead.LoadingDone = function()
    if loadDone == true then
        return
    end

    local warningLogger = Spearhead.LoggerTemplate:new("MISSIONPARSER", "INFO")
    if Spearhead.Util.tableLength(Spearhead.MissionEditingWarnings) > 0 then
        for key, message in pairs(Spearhead.MissionEditingWarnings) do
            warningLogger:warn(message)
        end
    else
        warningLogger:info("No issues detected")
    end

    loadDone = true
end

end --spearhead_base.lua
do --spearhead_events.lua

local SpearheadEvents = {}
do

    ---@type Logger
    local logger = nil

    ---@param logLevel LogLevel
    SpearheadEvents.Init = function(logLevel)
        logger = Spearhead.LoggerTemplate:new("Events", logLevel)
    end


    local warn = function(text)
        if logger then
            logger:warn(text)
        end
    end

    local logError = function(text)
        if logger then logger:error(text) end
    end

    local logDebug = function(text)
        if logger then logger:debug(text) end
    end

    ---@class OnStageChangedListener
    ---@field OnStageNumberChanged fun(self:OnStageChangedListener, number:integer)

    do -- STAGE NUMBER CHANGED
        local OnStageNumberChangedListeners = {}
        local OnStageNumberChangedHandlers = {}
        ---Add a stage zone number changed listener
        ---@param listener OnStageChangedListener object with function OnStageNumberChanged(self, number)
        SpearheadEvents.AddStageNumberChangedListener = function(listener)
            table.insert(OnStageNumberChangedListeners, listener)
        end

        ---Add a stage zone number changed listener
        ---@param handler function function(number)
        SpearheadEvents.AddStageNumberChangedHandler = function(handler)
            if type(handler) ~= "function" then
                warn("Event handler not of type function, did you mean to use listener?")
                return
            end
            table.insert(OnStageNumberChangedHandlers, handler)
        end

        ---@param newStageNumber number
        SpearheadEvents.PublishStageNumberChanged = function(newStageNumber)
            pcall(function ()
                Spearhead.classes.persistence.Persistence.SetActiveStage(newStageNumber)
            end)

            for _, callable in pairs(OnStageNumberChangedListeners) do
                local succ, err = pcall(function()
                    callable:OnStageNumberChanged(newStageNumber)
                end)
                if err then
                    logError(err)
                end
            end

            for _, callable in pairs(OnStageNumberChangedHandlers) do
                local succ, err = pcall(callable, newStageNumber)
                if err then
                    logError(err)
                end
            end

            Spearhead.StageNumber = newStageNumber
        end
    end

   

    local onLandEventListeners = {}
    ---Add an event listener to a specific unit
    ---@param unitName string to call when the unit lands
    ---@param landListener table table with function OnUnitLanded(self, initiatorUnit, airbase)
    SpearheadEvents.addOnUnitLandEventListener = function(unitName, landListener)
        if type(landListener) ~= "table" then
            warn("Event handler not of type table/object")
            return
        end

        if onLandEventListeners[unitName] == nil then
            onLandEventListeners[unitName] = {}
        end
        table.insert(onLandEventListeners[unitName], landListener)
    end

    ---@class OnUnitLostListener
    ---@field OnUnitLost fun(self:OnUnitLostListener, unit:table)

    ---@type table<string,Array<OnUnitLostListener>>
    local OnUnitLostListeners = {}
    ---This listener gets fired for any event that can indicate a loss of a unit.
    ---Such as: Eject, Crash, Dead, Unit_Lost,
    ---@param unitName any
    ---@param unitLostListener OnUnitLostListener 
    SpearheadEvents.addOnUnitLostEventListener = function(unitName, unitLostListener)
        if type(unitLostListener) ~= "table" then
            warn("Unit lost Event listener not of type table/object")
            return
        end

        if OnUnitLostListeners[unitName] == nil then
            OnUnitLostListeners[unitName] = {}
        end

        table.insert(OnUnitLostListeners[unitName], unitLostListener)
    end

    do -- ON RTB
        local OnGroupRTBListeners = {}
        ---Adds a function to the events listener that triggers when a group publishes themselves RTB.
        ---This is only available when a ROUTE is created via the Spearhead.RouteUtil
        ---@param groupName string the groupname to expect
        ---@param handlingObject table object with OnGroupRTB(self, groupName)
        SpearheadEvents.addOnGroupRTBListener = function(groupName, handlingObject)
            if type(handlingObject) ~= "table" then
                warn("Event handler not of type table/object")
                return
            end

            if OnGroupRTBListeners[groupName] == nil then
                OnGroupRTBListeners[groupName] = {}
            end

            table.insert(OnGroupRTBListeners[groupName], handlingObject)
        end

        ---Publish the Group to RTB
        ---@param groupName string
        SpearheadEvents.PublishRTB = function(groupName)
            if groupName ~= nil then
                if OnGroupRTBListeners[groupName] then
                    for _, callable in pairs(OnGroupRTBListeners[groupName]) do
                        local succ, err = pcall(function()
                            callable:OnGroupRTB(groupName)
                        end)
                        if err then
                            logError(err)
                        end
                    end
                end
            end
        end

        local OnGroupRTBInTenListeners = {}
        ---Adds a function to the events listener that triggers when a group publishes themselves RTB.
        ---This is only available when a ROUTE is created via the Spearhead.RouteUtil
        ---@param groupName string the groupname to expect
        ---@param handlingObject table object with OnGroupRTBInTen(self, groupName)
        SpearheadEvents.addOnGroupRTBInTenListener = function(groupName, handlingObject)
            if type(handlingObject) ~= "table" then
                warn("Event handler not of type table/object")
                return
            end

            if OnGroupRTBInTenListeners[groupName] == nil then
                OnGroupRTBInTenListeners[groupName] = {}
            end

            table.insert(OnGroupRTBInTenListeners[groupName], handlingObject)
        end

        ---Publish the Group is RTB
        ---@param groupName string
        SpearheadEvents.PublishRTBInTen = function(groupName)
            if groupName ~= nil then
                if OnGroupRTBInTenListeners[groupName] then
                    for _, callable in pairs(OnGroupRTBInTenListeners[groupName]) do
                        local succ, err = pcall(function()
                            callable:OnGroupRTBInTen(groupName)
                        end)
                        if err then
                            logError(err)
                        end
                    end
                end
            end
        end
    end

    do -- ON Station
        local OnGroupOnStationListeners = {}
        ---Adds a function to the events listener that triggers when a group publishes themselves RTB.
        ---This is only available when a ROUTE is created via the Spearhead.RouteUtil
        ---@param groupName string the groupname to expect
        SpearheadEvents.addOnGroupOnStationListener = function(groupName, handlingObject)
            if type(handlingObject) ~= "table" then
                warn("Event handler not of type table/object")
                return
            end

            if OnGroupOnStationListeners[groupName] == nil then
                OnGroupOnStationListeners[groupName] = {}
            end

            table.insert(OnGroupOnStationListeners[groupName], handlingObject)
        end

        ---Publish the Group to RTB
        ---@param groupName string
        SpearheadEvents.PublishOnStation = function(groupName)
            if groupName ~= nil then
                if OnGroupOnStationListeners[groupName] then
                    for _, callable in pairs(OnGroupOnStationListeners[groupName]) do
                        local succ, err = pcall(function()
                            callable:OnGroupOnStation(groupName)
                        end)
                        if err then
                            logError(err)
                        end
                    end
                end
            end
        end
    end

    do -- PLAYER ENTER UNIT
        local playerEnterUnitListeners = {}
        ---comment
        ---@param listener table object with OnPlayerEntersUnit(self, unit)
        SpearheadEvents.AddOnPlayerEnterUnitListener = function(listener)
            if type(listener) ~= "table" then
                warn("Unit lost Event listener not of type table/object")
                return
            end

            table.insert(playerEnterUnitListeners, listener)
        end

        SpearheadEvents.TriggerPlayerEntersUnit = function(unit)
            if unit ~= nil then
                if playerEnterUnitListeners then
                    for _, callable in pairs(playerEnterUnitListeners) do
                        local succ, err = pcall(function()
                            callable:OnPlayerEntersUnit(unit)
                        end)
                        if err then
                            logError(err)
                        end
                    end
                end
            end
        end
    end

    do -- Ejection events
    
        local unitEjectListeners = {}
        SpearheadEvents.AddOnUnitEjectedListener = function(listener)
            if type(listener) ~= "table" then
                warn("Unit lost Event listener not of type table/object")
                return
            end

            table.insert(unitEjectListeners, listener)
        end

    end

    local e = {}
    function e:onEvent(event)
        if event.id == world.event.S_EVENT_LAND or event.id == world.event.S_EVENT_RUNWAY_TOUCH then
            local unit = event.initiator
            local airbase = event.place
            if unit ~= nil then
                local name = unit:getName()
                if onLandEventListeners[name] then
                    for _, callable in pairs(onLandEventListeners[name]) do
                        local succ, err = pcall(function()
                            callable:OnUnitLanded(unit, airbase)
                        end)
                        if err then
                            logError(err)
                        end
                    end
                end
            end
        end

        if event.id == world.event.S_EVENT_DEAD or
            event.id == world.event.S_EVENT_CRASH or
            event.id == world.event.S_EVENT_EJECTION or
            event.id == world.event.S_EVENT_UNIT_LOST then
            local object = event.initiator

            if object and object.getName then
                logDebug("Receiving death event from: " .. object:getName())
            end
            
            if object and object.getName and OnUnitLostListeners[object:getName()] then
                for _, callable in pairs(OnUnitLostListeners[object:getName()]) do
                    local succ, err = pcall(function()
                        callable:OnUnitLost(object)
                    end)

                    if err then
                        logError(err)
                    end
                end
            end
        end

        if event.id == world.event.S_EVENT_EJECTION then
            
        end

        if event.id == world.event.S_EVENT_MISSION_END then
            Spearhead.classes.persistence.Persistence.UpdateNow()
        end

        local AI_GROUPS = {}

        local function CheckAndTriggerSpawnAsync(unit, time)
            local function isPlayer(unit)
                if unit == nil then return false, "unit is nil" end
                if unit.getGroup == nil then return false, 'no get group function in unit object, most likely static' end

                if unit:isExist() ~= true then return false, "unit does not exist" end
                local group = unit:getGroup()
                if group ~= nil then
                    if Spearhead.DcsUtil.IsGroupStatic(group:getName()) == true then
                        return false
                    end

                    if AI_GROUPS[group:getName()] == true then
                        return false
                    end

                    local players = Spearhead.DcsUtil.getAllPlayerUnits()
                    local unitName = unit:getName()
                    for i, unit in pairs(players) do
                        if unit:getName() == unitName then
                            return true
                        end
                    end
                    AI_GROUPS[group:getName()] = true
                end
                return false, "unit is nil or does not exist"
            end

            if isPlayer(unit) == true then
                local groupId = unit:getGroup():getID()
                SpearheadEvents.AddCommandsToGroup(groupId)
                SpearheadEvents.TriggerPlayerEntersUnit(unit)
            end

            return nil
        end

        if event.id == world.event.S_EVENT_BIRTH then
            timer.scheduleFunction(CheckAndTriggerSpawnAsync, event.initiator, timer.getTime() + 3)
        end
    end

    world.addEventHandler(e)
end

if Spearhead == nil then Spearhead = {} end
Spearhead.Events = SpearheadEvents
end --spearhead_events.lua
do --GlobalFleetManager.lua


local GlobalFleetManager = {}

local fleetGroups = {}

GlobalFleetManager.start = function(database)

    local logger = Spearhead.LoggerTemplate:new("CARRIERFLEET", "INFO")

    local all_groups = Spearhead.DcsUtil.getAllGroupNames()
    for _, groupName in pairs(all_groups) do
        if Spearhead.Util.startswith(string.lower(groupName), "carriergroup" ) == true then
            logger:info("Registering " .. groupName .. " as a managed fleet")
            local carrierGroup = Spearhead.internal.FleetGroup:new(groupName, database, logger)
            table.insert(fleetGroups, carrierGroup)
        end
    end
end

if not Spearhead.internal then Spearhead.internal = {} end
Spearhead.internal.GlobalFleetManager = GlobalFleetManager
end --GlobalFleetManager.lua
do --FleetGroup.lua
local FleetGroup = {}

function FleetGroup:new(fleetGroupName, database, logger)
    local o = {}

    setmetatable(o, { __index = self })

    o.fleetGroupName = fleetGroupName
    o.logger = logger

    local split_name = Spearhead.Util.split_string(fleetGroupName, "_")
    if Spearhead.Util.tableLength(split_name) < 2 then
        Spearhead.AddMissionEditorWarning("CARRIERGROUP should have at least 2 parts. CARRIERGROUP_<fleetname>")
        return nil
    end
    o.fleetNameIdentifier = split_name[2]

    o.targetZonePerStage = {}
    o.currentTargetZone = nil
    o.pointsPerZone = {}

    do --INIT
        local carrierRouteZones = database:getCarrierRouteZones()
        for _, zoneName in pairs(carrierRouteZones) do
            if Spearhead.Util.strContains(string.lower(zoneName), "_".. string.lower(o.fleetNameIdentifier) .. "_" ) == true then
                local zone = Spearhead.DcsUtil.getZoneByName(zoneName)
                if zone and zone.zone_type == Spearhead.DcsUtil.ZoneType.Polygon then
                    local split_string = Spearhead.Util.split_string(zoneName, "_")
                    if Spearhead.Util.tableLength(split_string) < 3 then
                        Spearhead.AddMissionEditorWarning(
                            "CARRIERROUTE should at least have 3 parts. Check the documentation for: " .. zoneName)
                    else
                        local function GetTwoFurthestPoints(zone)
                            local function getDist(a, b)
                                return math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
                            end

                            local biggest = nil
                            local biggestA = nil
                            local biggestB = nil

                            for i = 1, 3 do
                                for ii = i + 1, 4 do
                                    local a = zone.verts[i]
                                    local b = zone.verts[ii]
                                    local dist = getDist(a, b)

                                    if biggest == nil or dist > biggest then
                                        biggestA = a
                                        biggestB = b
                                        biggest = dist
                                    end
                                end
                            end
                            return { x = biggestA.x, z = biggestA.z }, { x = biggestB.x, z = biggestB.z }
                        end

                        local function getMinMaxStage(namePart)
                            if namePart == nil then
                                return nil, nil
                            end

                            if Spearhead.Util.startswith(namePart, "%[") == true then
                                namePart = Spearhead.Util.split_string(namePart, "[")[1]
                            end

                            if Spearhead.Util.strContains(namePart, "%]") == true then
                                namePart = Spearhead.Util.split_string(namePart, "]")[1]
                            end

                            local split_numbers = Spearhead.Util.split_string(namePart, "-")
                            if Spearhead.Util.tableLength(split_numbers) < 2  then
                                Spearhead.AddMissionEditorWarning("CARRIERROUTE zone stage numbers not in the format _[<number>-<number>]: " .. zoneName)
                                return nil, nil
                            end

                            local first = tonumber(split_numbers[1])
                            local second = tonumber(split_numbers[2])

                            if first == nil or second == nil  then
                                Spearhead.AddMissionEditorWarning("CARRIERROUTE zone stage numbers not in the format _[<number>-<number>]: " .. zoneName)
                                return nil, nil
                            end
                            return first, second
                        end

                        local pointA, pointB = GetTwoFurthestPoints(zone)
                        local first, second = getMinMaxStage(split_string[3])
                        if first ~= nil and second ~= nil then
                            for i = first, second do
                                o.targetZonePerStage[tostring(i)] = zoneName
                            end
                            o.pointsPerZone[zoneName] = { pointA = pointA, pointB = pointB }
                        else
                            Spearhead.AddMissionEditorWarning("CARRIERROUTE zone stage numbers not in the format _[<number>-<number>]: " .. zoneName)
                        end
                    end
                else
                    Spearhead.AddMissionEditorWarning("CARRIERROUTE cannot be a cilinder: " .. zoneName)
                end
            end
        end
    end

    local SetTaskAsync = function(input, time)
        local targetZone = input.targetZone
        local task = input.task
        local groupName = input.groupName
        local logger = input.logger

        local group = Group.getByName(groupName)
        if group then
            logger:info("Sending " .. fleetGroupName .. " to " .. targetZone)
            group:getController():setTask(task)
        end
    end

    o.OnStageNumberChanged = function(self, number)
        local targetZone = self.targetZonePerStage[tostring(number)]
        if targetZone and targetZone ~= self.currentTargetZone then
            local points = self.pointsPerZone[targetZone]
            local task  = Spearhead.RouteUtil.CreateCarrierRacetrack(points.pointA, points.pointB)
            timer.scheduleFunction(SetTaskAsync, { task = task, targetZone = targetZone,  groupName = self.fleetGroupName, logger = self.logger }, timer.getTime() + 5)
        end
    end

    Spearhead.Events.AddStageNumberChangedListener(o)
    return o
end

if not Spearhead.internal then Spearhead.internal = {} end
Spearhead.internal.FleetGroup = FleetGroup

end --FleetGroup.lua
do --StageConfig.lua

--- @class StageConfig
--- @field isEnabled boolean
--- @field isDrawStagesEnabled boolean
--- @field isAutoStages boolean
--- @field startingStage integer
--- @field maxMissionsPerStage integer
--- @field logLevel LogLevel


local StageConfig = {};

---comment
---@return StageConfig
function StageConfig:new()

    if SpearheadConfig == nil then SpearheadConfig = {} end
    if SpearheadConfig.StageConfig == nil then SpearheadConfig.StageConfig = {} end

    ---@type StageConfig
    local o = {
        isEnabled = SpearheadConfig.StageConfig.enabled or true,
        isDrawStagesEnabled = SpearheadConfig.StageConfig.drawStages or true,
        isAutoStages = SpearheadConfig.StageConfig.autoStages or true,
        startingStage = SpearheadConfig.StageConfig.startingStage or 1,
        maxMissionsPerStage = SpearheadConfig.StageConfig.maxMissionStage or 10,
        logLevel = "INFO"
    }

    if SpearheadConfig.StageConfig.debugEnabled == true then
        o.logLevel = "DEBUG"
    end

    setmetatable(o, { __index = self })

    return o;
end

if not Spearhead.internal then Spearhead.internal = {} end
if not Spearhead.internal.configuration then Spearhead.internal.configuration = {} end
Spearhead.internal.configuration.StageConfig = StageConfig;
end --StageConfig.lua
do --CapConfig.lua


local CapConfig = {};
function CapConfig:new()
    local o = {}
    setmetatable(o, { __index = self })

    if SpearheadConfig == nil then SpearheadConfig = {} end
    if SpearheadConfig.CapConfig == nil then SpearheadConfig.CapConfig = {} end

    local enabled = SpearheadConfig.CapConfig.enabled
    if enabled == nil then enabled = true end
    ---@return boolean
    o.isEnabled = function(self) return enabled == true end

    local minSpeed = (tonumber(SpearheadConfig.CapConfig.minSpeed) or 400) * 0.514444
    ---@return number
    o.getMinSpeed = function(self) return minSpeed end

    local maxSpeed = (tonumber(SpearheadConfig.CapConfig.maxSpeed) or 400) * 0.514444
    ---@return number
    o.getMaxSpeed = function(self) return maxSpeed end

    local minAlt = (tonumber(SpearheadConfig.CapConfig.minAlt) or 18000) * 0.3048
    ---@return number
    o.getMinAlt = function(self) return minAlt end

    local maxAlt = (tonumber(SpearheadConfig.CapConfig.maxAlt) or 28000) * 0.3048
    ---@return number
    o.getMaxAlt = function(self) return maxAlt end

    local minDurationOnStation  = 1200
    ---@return number
    o.getMinDurationOnStation = function(self) return minDurationOnStation end

    local maxDurationOnStation = 2700
    ---@return number
    o.getmaxDurationOnStation = function(self) return maxDurationOnStation end

    local maxDeviationRange = 20 * 1852;
     ---@return number
    o.getMaxDeviationRange = function(self) return maxDeviationRange end

    local rearmDelay = tonumber(SpearheadConfig.CapConfig.rearmDelay) or 600
    ---@return number
    o.getRearmDelay = function(self) return rearmDelay end

    local deathDelay = tonumber(SpearheadConfig.CapConfig.deathDelay) or 1800
    ---@return number
    o.getDeathDelay = function(self) return deathDelay end
    o.logLevel  = "INFO"

    return o;
end

if not Spearhead.internal then Spearhead.internal = {} end
if not Spearhead.internal.configuration then Spearhead.internal.configuration = {} end
Spearhead.internal.configuration.CapConfig = CapConfig;
end --CapConfig.lua
do --aliases.lua



do -- mission aliases

    --- @alias MissionPriority
    --- | "primary"
    --- | "secondary"

    --- @alias missionType
    --- | "nil"
    --- | "STRIKE"
    --- | "BAI"
    --- | "DEAD"
    --- | "SAM"

    --- @alias MissionState
    --- | "NEW"
    --- | "ACTIVE"
    --- | "COMPLETED"

    --- @alias LogLevel
    --- | "DEBUG"
    --- | "INFO"
    --- | "WARN"
    --- | "ERROR"
    --- | "NONE"



    ---@class Array<T>: { [integer]: T }

    --- @class Position
    --- @field x number x position (Top-Down on Map)
    --- @field y number y altitude 
    --- @field z number z position (Left-Right on Map)

end


end --aliases.lua
do --GlobalStageManager.lua


local StagesByName = {}

---@type table<string, Array<Stage>>
local StagesByIndex = {}

---@type table<string, Array<Stage>>
local SideStageByIndex = {}

---@type table<string, Array<WaitingStage>>
local WaitingStagesByIndex = {}

local currentStage = -99


GlobalStageManager = {}

---comment
---@param database Database
---@param stageConfig StageConfig
---@return nil
function GlobalStageManager:NewAndStart(database, stageConfig)
    local logger = Spearhead.LoggerTemplate:new("StageManager", stageConfig.logLevel)
    logger:info("Using Stage Log Level: " .. stageConfig.logLevel)
    local o = {}
    setmetatable(o, { __index = self })

    o.logger = logger
    if stageConfig.isAutoStages ~= true then
        logger:warn("Spearhead will not automatically progress stages due to the given settings. If you manually have implemented this, please ignore this message")
    end

    ---@type OnStageChangedListener
    local OnStageNumberChangedListener = {
        OnStageNumberChanged = function (self, number)
            currentStage = number
        end
    }

    Spearhead.Events.AddStageNumberChangedListener(OnStageNumberChangedListener)

    ---@type StageCompleteListener
    local OnStageCompleteListener = {
        OnStageComplete = function(self, stage)
            logger:debug("Receiving stage complete event from: " .. stage.zoneName)

            local anyIncomplete = false
            logger:debug("Checking stages for index: " .. tostring(currentStage))
            for index, stage in pairs(StagesByIndex[tostring(currentStage)]) do
                if stage:IsComplete() == false then
                    anyIncomplete = true
                    logger:debug("Need to wait for Stage " .. stage.zoneName .. " to be completed")
                else
                    logger:debug("Stage verified to be completed:  " .. stage.zoneName)
                end
            end

            if anyIncomplete == false and stageConfig.isAutoStages == true then

                -- CHECK WAITING STAGES 
                local nextStage = currentStage + 1
                
                if WaitingStagesByIndex[tostring(nextStage)] then
                    for _, waitingStage in pairs(WaitingStagesByIndex[tostring(nextStage)]) do
                        if waitingStage:IsActive() == false then
                            waitingStage:ActivateStage()
                        end
                    end
                end
                
                local anyWaiting = false
                if WaitingStagesByIndex[tostring(nextStage)] then
                    for _, waitingStage in pairs(WaitingStagesByIndex[tostring(nextStage)]) do
                        if waitingStage:IsComplete() == false then
                            anyWaiting = true
                        end
                    end
                end

                if anyWaiting == false then
                    logger:debug("Setting next stage to: " .. tostring(currentStage + 1))
                    Spearhead.Events.PublishStageNumberChanged(currentStage + 1)
                end
            end
        end
    }

    for _, stageName in pairs(database:getStagezoneNames()) do

        if Spearhead.Util.startswith(stageName, "missionstage", true) then
            local valid = true
            local split = Spearhead.Util.split_string(stageName, "_")
            if Spearhead.Util.tableLength(split) < 2 then
                Spearhead.AddMissionEditorWarning("Stage zone with name " .. stageName .. " does not have a order number or valid format")
                valid = false
            end

            if Spearhead.Util.tableLength(split) < 3 then
                Spearhead.AddMissionEditorWarning("Stage zone with name " .. stageName .. " does not have a stage name")
                valid = false
            end

            local orderNumber = nil 
            local isSideStage = false
            if valid == true then
                local orderNumberString = string.lower(split[2])
                if Spearhead.Util.startswith(orderNumberString, "x") == true then
                    isSideStage = true

                    local orderNumberString = string.gsub(orderNumberString, "x", "")
                    orderNumber = tonumber(orderNumberString)
                else
                    orderNumber = tonumber(split[2])
                end

                if orderNumber == nil then
                    Spearhead.AddMissionEditorWarning("Stage zone with name " .. stageName .. " does not have a valid order number : " .. split[2])
                    valid = false
                end
            end
                
            local stageDisplayName = split[3]
            local stagelogger = Spearhead.LoggerTemplate:new(stageName, stageConfig.logLevel)
            if valid == true and orderNumber then

                ---@type StageInitData
                local initData = {
                    stageDisplayName = stageDisplayName,
                    stageNumber =  orderNumber,
                    stageZoneName = stageName,
                }

                if isSideStage == true then
                    local stage = Spearhead.classes.stageClasses.Stages.ExtraStage.New(database, stageConfig, stagelogger, initData)
                    stage:AddStageCompleteListener(OnStageCompleteListener)

                    if SideStageByIndex[tostring(orderNumber)] == nil then SideStageByIndex[tostring(orderNumber)] = {} end
                    table.insert(SideStageByIndex[tostring(orderNumber)], stage) 
                else 
                    local stage = Spearhead.classes.stageClasses.Stages.PrimaryStage.New(database, stageConfig, stagelogger, initData)
                    stage:AddStageCompleteListener(OnStageCompleteListener)
                    
                    if StagesByIndex[tostring(orderNumber)] == nil then StagesByIndex[tostring(orderNumber)] = {} end
                    table.insert(StagesByIndex[tostring(orderNumber)], stage) 
                end 
            end
        end

        if Spearhead.Util.startswith(stageName, "waitingstage", true) then
            local valid = true

            local split = Spearhead.Util.split_string(stageName, "_")

            if Spearhead.Util.tableLength(split) < 3 then
                Spearhead.AddMissionEditorWarning("Stage zone with name " .. stageName .. " does not have a order number or valid format")
                valid = false
            end

            if valid == true then
                local stageIndexString = split[2]
                local stageIndex = tonumber(stageIndexString)

                if not stageIndex then
                    Spearhead.AddMissionEditorWarning("Stage zone with name " .. stageName .. " does not have a valid order number")
                    valid = false
                end

                local waitingSecondsString = split[3]
                local waitingSeconds = tonumber(waitingSecondsString)
                if not waitingSeconds then
                    Spearhead.AddMissionEditorWarning("Waiting Stage zone with name " .. stageName .. " does not have a valid amount of seconds parameter")
                    valid = false
                end

                if valid == true then 
                    local stagelogger = Spearhead.LoggerTemplate:new(stageName, stageConfig.logLevel)

                    ---@type WaitingStageInitData
                    local initData = {
                        stageDisplayName = "Waiting Stage " .. stageIndex,
                        stageNumber =  stageIndex or -99,
                        stageZoneName = stageName,
                        waitingSeconds = waitingSeconds --[[@as integer]]
                    }
                    local waitingStage = Spearhead.classes.stageClasses.Stages.WaitingStage.New(database, stageConfig, stagelogger, initData)

                    if WaitingStagesByIndex[tostring(stageIndex)] == nil then
                        WaitingStagesByIndex[tostring(stageIndex)] = {}
                    end
                    table.insert(WaitingStagesByIndex[tostring(stageIndex)], waitingStage)

                    waitingStage:AddStageCompleteListener(OnStageCompleteListener)
                end
            end
        end
    end

    return o
end

---comment
---@param stageNumber number
---@return boolean | nil
GlobalStageManager.isStageComplete = function (stageNumber)

    local stageIndex = tostring(stageNumber)

    if StagesByIndex[stageIndex] == nil then return nil end
    
    for _, stage in ipairs(StagesByIndex[stageIndex]) do
        if stage:IsComplete() == false then
            return false
        end
    end

    return true
end

if not Spearhead.internal then Spearhead.internal = {} end
Spearhead.internal.GlobalStageManager = GlobalStageManager

end --GlobalStageManager.lua
do --SpearheadGroup.lua



---@class SpearheadGroup : OnUnitLostListener
---@field groupName string
---@field private isStatic boolean
---@field private isSpawned boolean
local SpearheadGroup = {}

function SpearheadGroup.New(groupName)

    SpearheadGroup.__index = SpearheadGroup

    local o = {}
    local self = setmetatable(o, SpearheadGroup)

    self.isStatic = Spearhead.DcsUtil.IsGroupStatic(groupName) == true
    self.groupName = groupName
    self.isSpawned = false
    return self
end

function SpearheadGroup:SpawnCorpsesOnly()

    if self.isSpawned == true then return end

    local group = Spearhead.DcsUtil.SpawnGroupTemplate(self.groupName)
    if group then
        for _, unit in pairs(group:getUnits()) do
            local deathState = Spearhead.classes.persistence.Persistence.UnitDeadState(unit:getName())

            if deathState and deathState.isDead == true then
                Spearhead.DcsUtil.DestroyUnit(self.groupName, unit:getName())
                Spearhead.DcsUtil.SpawnCorpse(deathState.country_id, unit:getName(), deathState.type, deathState.pos, deathState.heading)
            end
        end
    end

    self.isSpawned = true

end

function SpearheadGroup:Spawn()

    if self.isSpawned == true then return end

    local group = Spearhead.DcsUtil.SpawnGroupTemplate(self.groupName)
    if group then
        for _, unit in pairs(group:getUnits()) do
            local deathState = Spearhead.classes.persistence.Persistence.UnitDeadState(unit:getName())

            if deathState and deathState.isDead == true then
                Spearhead.DcsUtil.DestroyUnit(self.groupName, unit:getName())
                Spearhead.DcsUtil.SpawnCorpse(deathState.country_id, unit:getName(), deathState.type, deathState.pos, deathState.heading)
            else
                Spearhead.Events.addOnUnitLostEventListener(unit:getName(), self)
            end

            Spearhead.Events.addOnUnitLostEventListener(unit:getName(), self)
        end
    end

    self.isSpawned = true
end

function SpearheadGroup:Destroy()
    self.isSpawned = false
    Spearhead.DcsUtil.DestroyGroup(self.groupName)
end

---comment
---@return integer
function SpearheadGroup:GetCoalition()
    if self.isStatic == true then
        local object = StaticObject.getByName(self.groupName)
        return object:getCoalition()
    else
        local group = Group.getByName(self.groupName)
        return group:getCoalition()
    end
end

function SpearheadGroup:OnUnitLost(object)
    local name = object:getName()
    local pos = object:getPoint()
    local type = object:getDesc().typeName
    local position = object:getPosition()
    local heading = math.atan2(position.x.z, position.x.x)
    local country_id = object:getCountry()
    Spearhead.classes.persistence.Persistence.UnitKilled(name, pos, heading, type, country_id)
end

---comment
---@return table result list of objects
function SpearheadGroup:GetUnits()

    local result = {}
    if self.isStatic == true then
        local staticObject = StaticObject.getByName(self.groupName)
        if staticObject then 
            table.insert(result, staticObject)
        end
    else
        local group = Group.getByName(self.groupName)
        for _, unit in pairs(group:getUnits()) do
            table.insert(result, unit)
        end 
    end
    return result
end

if not Spearhead.classes then Spearhead.classes = {} end
if not Spearhead.classes.stageClasses then Spearhead.classes.stageClasses = {} end
if not Spearhead.classes.stageClasses.Groups then Spearhead.classes.stageClasses.Groups = {} end
Spearhead.classes.stageClasses.Groups.SpearheadGroup = SpearheadGroup

end --SpearheadGroup.lua
do --ExtraStage.lua

---@class ExtraStage : Stage
local ExtraStage = {}

---comment
---@param database Database
---@param stageConfig StageConfig
---@param logger any
---@param initData StageInitData
---@return ExtraStage
function ExtraStage.New(database, stageConfig, logger, initData)

    -- "Import"
    local Stage = Spearhead.classes.stageClasses.Stages.BaseStage.Stage
    setmetatable(ExtraStage, Stage)

    ExtraStage.__index = ExtraStage
    local self = Stage.New(database, stageConfig, logger, initData, "secondary") --[[@as ExtraStage]]
    setmetatable(self, ExtraStage)

    self.OnPostBlueActivated = function (selfStage)
        selfStage:MarkStage("GRAY")
    end
    
    self.OnPostStageComplete = function (selfStage)
        self:ActivateBlueStage()
    end

    return self
end

---comment
---@param self Stage
---@param number integer
function ExtraStage:OnStageNumberChanged(number)

    self._activeStage = number
    if Spearhead.capInfo.IsCapActiveWhenZoneIsActive(self.zoneName, number) == true then
        self:PreActivate()
    end

    if number == self.stageNumber then
        self:ActivateStage()
    end

    if self._isComplete == true then
        self:ActivateBlueStage()
    end

end


if not Spearhead.classes then Spearhead.classes = {} end
if not Spearhead.classes.stageClasses then Spearhead.classes.stageClasses = {} end
if not Spearhead.classes.stageClasses.Stages then Spearhead.classes.stageClasses.Stages = {} end
Spearhead.classes.stageClasses.Stages.ExtraStage = ExtraStage



end --ExtraStage.lua
do --PrimaryStage.lua

---@class PrimaryStage : Stage
local PrimaryStage = {}

---comment
---@param database Database
---@param stageConfig StageConfig
---@param logger any
---@param initData StageInitData
---@return PrimaryStage
function PrimaryStage.New(database, stageConfig, logger, initData)

    -- "Import"
    local Stage = Spearhead.classes.stageClasses.Stages.BaseStage.Stage
    setmetatable(PrimaryStage, Stage)
    PrimaryStage.__index = PrimaryStage
    setmetatable(PrimaryStage, {__index = Stage}) 
    
    local o = Stage.New(database, stageConfig, logger, initData, "primary") --[[@as PrimaryStage]]
    return o 
end

if not Spearhead.classes then Spearhead.classes = {} end
if not Spearhead.classes.stageClasses then Spearhead.classes.stageClasses = {} end
if not Spearhead.classes.stageClasses.Stages then Spearhead.classes.stageClasses.Stages = {} end
Spearhead.classes.stageClasses.Stages.PrimaryStage = PrimaryStage



end --PrimaryStage.lua
do --WaitingStage.lua

---@class WaitingStage : Stage
---@field private _waitTimeSeconds integer
---@field private _startTime number
local WaitingStage = {}


---@class WaitingStageInitData : StageInitData
---@field waitingSeconds integer
local WaitingStageInitData = {}

---comment
---@param database Database
---@param stageConfig StageConfig
---@param logger any
---@param initData WaitingStageInitData
---@return WaitingStage
function WaitingStage.New(database, stageConfig, logger, initData)

    -- "Import"
    local Stage = Spearhead.classes.stageClasses.Stages.BaseStage.Stage
    setmetatable(WaitingStage, Stage)
    WaitingStage.__index = WaitingStage
    setmetatable(WaitingStage, {__index = Stage}) 
    
    local self = Stage.New(database, stageConfig, logger, initData, "primary") --[[@as WaitingStage]]
    setmetatable(self, WaitingStage)

    self._waitTimeSeconds = 5
    if initData.waitingSeconds and initData.waitingSeconds > 5 then self._waitTimeSeconds  = initData.waitingSeconds end
    self._startTime = nil

    self.CheckContinuousAsync = function (self, time)
        if self:IsComplete() then
            self:NotifyComplete()
            return nil
        end

        return time + 2
    end

    return self
end


function WaitingStage:ActivateStage()

    self._logger:info("Starting Waiting Stage '" .. self.zoneName .. "' which will complete in about " .. self._waitTimeSeconds .. " seconds")

    self._isActive = true
    self._startTime = timer.getTime()
    timer.scheduleFunction(self.CheckContinuousAsync, self, self._startTime + self._waitTimeSeconds)
end

function WaitingStage:IsComplete() 
    if timer.getTime() > (self._startTime + self._waitTimeSeconds) then return true end
    return false
end

function WaitingStage:OnStageNumberChanged()
    self._logger:debug("Waiting Stage OnStageNumberChanged override")
end

function WaitingStage:MarkStage(stageColor)
    self._logger:debug("Waiting Stage MarkStage override")
end

function WaitingStage:GetExpectedTime()
    return self._startTime + self._waitTimeSeconds    
end

if not Spearhead.classes then Spearhead.classes = {} end
if not Spearhead.classes.stageClasses then Spearhead.classes.stageClasses = {} end
if not Spearhead.classes.stageClasses.Stages then Spearhead.classes.stageClasses.Stages = {} end
Spearhead.classes.stageClasses.Stages.WaitingStage = WaitingStage



end --WaitingStage.lua
do --Stage.lua

---@alias StageColor
---| "RED"
---| "BLUE"
---| "GRAY"

--- @class StageData
--- @field missionsByCode table<string, Mission>
--- @field missions Array<Mission>
--- @field sams Array<Mission>
--- @field blueSams Array<BlueSam>
--- @field airbases Array<StageBase>
--- @field miscGroups Array<SpearheadGroup>
--- @field maxMissions integer

--- @class StageInitData
--- @field stageZoneName string
--- @field stageNumber integer
--- @field stageDisplayName string


--- @class StageCompleteListener
--- @field OnStageComplete fun(self:StageCompleteListener, stage:Stage)

--- @class Stage : MissionCompleteListener, OnStageChangedListener
--- @field zoneName string
--- @field stageName string
--- @field stageNumber number
--- @field protected _isActive boolean
--- @field protected _isComplete boolean
--- @field protected _missionPriority MissionPriority
--- @field protected _database Database
--- @field protected _db StageData
--- @field protected _logger Logger
--- @field protected _preActivated boolean
--- @field protected _activeStage integer
--- @field protected _stageConfig StageConfig
--- @field protected _stageDrawingId integer
--- @field protected _spawnedGroups Array<string>
--- @field protected _stageCompleteListeners Array<StageCompleteListener>
--- @field protected CheckContinuousAsync fun(self:Stage, time:number) : number?
--- @field protected OnPostStageComplete fun(self:Stage)?
--- @field protected OnPostBlueActivated fun(self:Stage)?
local Stage = {}

local stageDrawingId = 100

---comment
---@param database Database
---@param stageConfig StageConfig
---@param logger any
---@param initData StageInitData
---@param missionPriority MissionPriority
---@return Stage
function Stage.New(database, stageConfig, logger, initData, missionPriority)

    local SpearheadGroup = Spearhead.classes.stageClasses.Groups.SpearheadGroup

    Stage.__index = Stage
    local o = {}
    local self = setmetatable(o, Stage)

    self.zoneName = initData.stageZoneName
    self.stageNumber = initData.stageNumber
    self._isActive = false
    self._isComplete = false
    self.stageName = initData.stageDisplayName
    
    self.OnPostStageComplete = nil
    self.OnPostBlueActivated = nil

    self._database = database
    self._logger = logger
    self._db = {
        missionsByCode = {},
        missions = {},
        sams ={},
        blueSams = {},
        airbases ={},
        miscGroups = {},
        maxMissions = stageConfig.maxMissionsPerStage
    }
    self._activeStage = -99
    self._preActivated = false
    self._stageConfig = stageConfig or {}
    self._stageDrawingId = stageDrawingId + 1
    self._spawnedGroups = {}
    self._missionPriority = missionPriority
    self._stageCompleteListeners = {}

    stageDrawingId = stageDrawingId + 1

    self._logger:info("Initiating new Stage with name: " .. self.zoneName)

    ---comment
    ---@param self Stage
    ---@param time number?
    self.CheckContinuousAsync = function (self, time)
        
        self:CheckAndUpdateSelf()
        if self:IsComplete() == true then
            self:NotifyComplete()
            return nil
        end

        return time + 20
    end

    do -- load tables
        local missionZones = database:getMissionsForStage(self.zoneName)
        for _, missionZone in pairs(missionZones) do
            local mission = Spearhead.classes.stageClasses.Missions.Mission.New(missionZone, self._missionPriority, database, logger)
            if mission then
                self._db.missionsByCode[mission.code] = mission
                if mission.missionType == "SAM" then
                    table.insert(self._db.sams, mission)
                else
                    table.insert(self._db.missions, mission)
                end
            end
        end

        local randomMissionNames = database:getRandomMissionsForStage(self.zoneName)
        local randomMissionByName = {}
        for _, missionZoneName in pairs(randomMissionNames) do
            local mission = Spearhead.classes.stageClasses.Missions.Mission.New(missionZoneName, "primary", database, logger)
            if mission then
                if randomMissionByName[mission.name] == nil then
                    randomMissionByName[mission.name] = {}
                end
                table.insert(randomMissionByName[mission.name], mission)
            end
        end

        for _, missions in pairs(randomMissionByName) do
            local mission = Spearhead.Util.randomFromList(missions)
            if mission then
                self._db.missionsByCode[mission.code] = mission
                if mission.missionType == "SAM" then
                    table.insert(self._db.sams, mission)
                else
                    table.insert(self._db.missions, mission)
                end
            end
        end

        for _, mission in pairs(self._db.missionsByCode) do
            mission:AddMissionCompleteListener(self)
        end

        local airbaseIds = database:getAirbaseIdsInStage(self.zoneName)
        if airbaseIds ~= nil and type(airbaseIds) == "table" then
            for _, airbaseId in pairs(airbaseIds) do
                local airbase = Spearhead.classes.stageClasses.SpecialZones.StageBase.New(database, logger, airbaseId)
                table.insert(self._db.airbases, airbase)
            end
        end

        for _, samZoneName in pairs(database:getBlueSamsInStage(self.zoneName)) do
            local blueSam =  Spearhead.classes.stageClasses.SpecialZones.BlueSam:new(database, logger, samZoneName)
            table.insert(self._db.blueSams, blueSam)
        end

        local miscGroups = database:getMiscGroupsAtStage(self.zoneName)
        for _, groupName in pairs(miscGroups) do
            local miscGroup = SpearheadGroup.New(groupName)

            table.insert(self._db.miscGroups, miscGroup)
            Spearhead.DcsUtil.DestroyGroup(groupName)
        end
    end

    Spearhead.Events.AddStageNumberChangedListener(self)
        
    return self
end

---@return boolean
function Stage:IsComplete()
    if self._isComplete == true then return true end

    for i, mission in pairs(self._db.sams) do
        local state = mission:GetState()
        if state == "ACTIVE" or state == "NEW" then
            return false
        end
    end

    for i, mission in pairs(self._db.missions) do
        local state = mission:GetState()
        if state == "ACTIVE" or state == "NEW" then
            return false
        end
    end

    self._isComplete = true
    return true
end

---@return boolean
function Stage:IsActive()
    return self._isActive == true
end

---comment
function Stage:CheckAndUpdateSelf()
    self._logger:debug("Checking on Stage: " .. self.zoneName)

    local activeCount = 0
    local dbTables = self:GetStageTables()

    local availableMissions = {}
    for _, mission in pairs(dbTables.missionsByCode) do
        local state = mission:GetState()

        if state == "ACTIVE" then
            activeCount = activeCount + 1
        end

        if state == "NEW" then
            table.insert(availableMissions, mission)
        end
    end

    local max = dbTables.maxMissions
    local availableMissionsCount = Spearhead.Util.tableLength(availableMissions)
    if activeCount < max and availableMissionsCount > 0  then
        for i = activeCount+1, max do
            if availableMissionsCount == 0 then
                i = max+1 --exits this loop
            else
                local index = math.random(1, availableMissionsCount)

                ---@type Mission
                local mission = table.remove(availableMissions, index)
                if mission then
                    mission:SpawnActive()
                    activeCount = activeCount + 1;
                end
                availableMissionsCount = availableMissionsCount - 1
            end
        end
    end
end

---private use only
function Stage:NotifyComplete()

    self._logger:info("Stage complete: " .. self.stageName)

    for _, listener in pairs(self._stageCompleteListeners) do
        pcall(function()
            listener:OnStageComplete(self)
        end)
    end

    if self.OnPostStageComplete then
        timer.scheduleFunction(self.OnPostStageComplete, self, timer.getTime() + 3)
    end
end

---@param listener StageCompleteListener
function Stage:AddStageCompleteListener(listener)
    table.insert(self._stageCompleteListeners, listener)
end

---Activates all SAMS, Airbase units etc all at once.
function Stage:PreActivate()
    if self._preActivated == false then
        self._preActivated = true
        for key, mission in pairs(self._db.sams) do
            if mission then
                mission:SpawnActive()
            end
        end

        for _, airbase in pairs(self._db.airbases) do
            airbase:ActivateRedStage()
        end
    end
end

---@param stageColor StageColor
function Stage:MarkStage(stageColor)
    local fillColor = {1, 0, 0, 0.1}
    local line ={ 1, 0,0, 1 }

    if stageColor == "RED" then
        fillColor = {1, 0, 0, 0.1}
        line ={ 1, 0,0, 1 }
    elseif stageColor =="BLUE" then
        fillColor = {0, 0, 1, 0.1}
        line ={ 0, 0,1, 1 }
    elseif stageColor == "GRAY" then
        fillColor = {80/255, 80/255, 80/255, 0.15}
        line ={ 80/255, 80/255,80/255, 1 }
    end

    local zone = Spearhead.DcsUtil.getZoneByName(self.zoneName)
    if zone and self._stageConfig.isDrawStagesEnabled == true then
        self._logger:debug("drawing stage: " .. self.zoneName)
        if zone.zone_type == Spearhead.DcsUtil.ZoneType.Cilinder then
            trigger.action.circleToAll(-1, self._stageDrawingId, {x = zone.x, y = 0 , z = zone.z}, zone.radius, {0,0,0,0}, {0,0,0,0},4, true)
        else
            --trigger.action.circleToAll(-1, self.stageDrawingId, {x = zone.x, y = 0 , z = zone.z}, zone.radius, { 1, 0,0, 1 }, {1,0,0,1},4, true)
            trigger.action.quadToAll( -1, self._stageDrawingId,  zone.verts[1], zone.verts[2], zone.verts[3],  zone.verts[4], {0,0,0,0}, {0,0,0,0}, 4, true)
        end

        trigger.action.setMarkupColorFill(self._stageDrawingId, fillColor)
        trigger.action.setMarkupColor(self._stageDrawingId, line)
    end
end

function Stage:ActivateStage()
    self._isActive = true;

    pcall(function()
        self:MarkStage("RED")
    end)

    self:PreActivate()
    
    self._logger:debug("Activating Misc groups for zone. Count: " .. Spearhead.Util.tableLength(self._db.miscGroups))
    for _, miscGroup in pairs(self._db.miscGroups) do
        miscGroup:Spawn()
    end

    for _, mission in pairs(self._db.missions) do
        if mission.missionType == "DEAD" then
            mission:SpawnActive()
        end
    end

    timer.scheduleFunction(self.CheckContinuousAsync, self, timer.getTime() + 3)
end

---Private usage only
---@return StageData
function Stage:GetStageTables()
    return self._db
end

---comment
---@param self Stage
---@param number integer
function Stage:OnStageNumberChanged(number)

    if self._activeStage == number then --only activate once for a stage
        return
    end

    local previousActive = self._activeStage
    self._activeStage = number
    if Spearhead.capInfo.IsCapActiveWhenZoneIsActive(self.zoneName, number) == true then
        self:PreActivate()
    end

    if number == self.stageNumber then
        self:ActivateStage()
    end

    if previousActive <= self.stageNumber then
        if number > self.stageNumber then
            self:ActivateBlueStage()
        end
    end
end

function Stage:GetBriefing()
    return "Briefing For "
end

---@param self Stage
---@param mission Mission
Stage.OnMissionComplete = function(self, mission)
    self:CheckAndUpdateSelf()
end


---private use only
function Stage:ActivateBlueGroups()

    for _, blueSam in pairs(self._db.blueSams) do
        blueSam:Activate()
    end

    for _, airbase in pairs(self._db.airbases) do
        airbase:ActivateBlueStage()
    end

    if self.OnPostBlueActivated then
        pcall(function()
            self:OnPostBlueActivated()
        end)
    end
end

function Stage:ActivateBlueStage()

    self._logger:debug("Setting stage '" .. Spearhead.Util.toString(self.zoneName) .. "' to blue")
    
    for _, mission in pairs(self._db.missions) do
        mission:SpawnPersistedState()
    end

    for _, mission in pairs(self._db.sams) do
        mission:SpawnPersistedState()
    end

    for _, miscGroup in pairs(self._db.miscGroups) do
        miscGroup:Spawn()
    end

    ---@param self Stage
    local ActivateBlueAsync = function(self)
        pcall(function()
            self:MarkStage("BLUE")
        end)

        self:ActivateBlueGroups()

        return nil
    end

    timer.scheduleFunction(ActivateBlueAsync, self, timer.getTime() + 3)
end

if not Spearhead.classes then Spearhead.classes = {} end
if not Spearhead.classes.stageClasses then Spearhead.classes.stageClasses = {} end
if not Spearhead.classes.stageClasses.Stages then Spearhead.classes.stageClasses.Stages = {} end
if not Spearhead.classes.stageClasses.Stages.BaseStage then Spearhead.classes.stageClasses.Stages.BaseStage = {} end
Spearhead.classes.stageClasses.Stages.BaseStage.Stage = Stage







end --Stage.lua
do --StageBase.lua


---@class StageBase 
---@field private _database Database
---@field private _logger Logger
---@field private _red_groups Array<SpearheadGroup>
---@field private _blue_groups Array<SpearheadGroup>
---@field private _cleanup_units table<string, boolean>
---@field private _airbase table?
---@field private _initialSide number?
local StageBase = {}

---comment
---@param databaseManager table
---@param logger table
---@param airbaseId integer
---@return StageBase
function StageBase.New(databaseManager, logger, airbaseId)

    StageBase.__index = StageBase
    local self = setmetatable({}, StageBase)

    self._database = databaseManager
    self._logger = logger

    self._red_groups = {}
    self._blue_groups = {}
    self._cleanup_units = {}

    self._airbase = Spearhead.DcsUtil.getAirbaseById(airbaseId)
    self._initialSide = Spearhead.DcsUtil.getStartingCoalition(airbaseId)

    do --init
        local redUnitsPos = {}
        local blueUnitsPos = {}

        do -- fill tables
            local redGroups = databaseManager:getRedGroupsAtAirbase(airbaseId)
            if redGroups then
            for _, groupName in pairs(redGroups) do
                local shGroup = Spearhead.classes.stageClasses.Groups.SpearheadGroup.New(groupName)
                table.insert(self._red_groups, shGroup)

                for _, unit in shGroup:GetUnits() do
                    redUnitsPos[unit:getName()] = unit:getPoint()
                end

                shGroup:Destroy()
            end
            end

            local blueGroups = databaseManager:getBlueGroupsAtAirbase(airbaseId)
            if blueGroups then
            for _, groupName in pairs(blueGroups) do
                local shGroup = Spearhead.classes.stageClasses.Groups.SpearheadGroup.New(groupName)
                table.insert(self._blue_groups, shGroup)

                for _, unit in shGroup:GetUnits() do
                    blueUnitsPos[unit:getName()] = unit:getPoint()
                end

                shGroup:Destroy()
            end
            end
        end

        do -- check cleanup requirements
            -- Checks is any of the units are withing range (5m) of another unit. 
            -- If so, make sure to add them to the cleanup list.
        
            local cleanup_distance = 5

            for blueUnitName, blueUnitPos in pairs(blueUnitsPos) do
                for redUnitName, redUnitPos in pairs(redUnitsPos) do
                    local distance = Spearhead.Util.VectorDistance(blueUnitPos, redUnitPos)
                    env.info("distance: " .. tostring(distance))
                    if distance <= cleanup_distance then
                        self._cleanup_units[redUnitName] = true
                    end
                end
            end
        end
    end

    return self
end  

---@private
function StageBase:SpawnRedUnits()

    ---comment
    ---@param groups Array<SpearheadGroup>
    local spawnAsync = function(groups)
        for _, group in pairs(groups) do
            group:Spawn()
        end

        return nil
    end

    timer.scheduleFunction(spawnAsync, self._red_groups, timer.getTime() + 3)
end

---@private
function StageBase:CleanRedUnits()
    for _, value in pairs(self._red_groups) do
        value:SpawnCorpsesOnly()
    end

    for _, unitName in pairs(self._cleanup_units) do
        Spearhead.DcsUtil.DestroyUnit(unitName)
        Spearhead.DcsUtil.CleanCorpse(unitName)
    end

end

---@private
function StageBase:SpawnBlueUnits()

    ---comment
    ---@param groups Array<SpearheadGroup>
    local spawnAsync = function(groups)
        for _, group in pairs(groups) do
            group:Spawn()
        end

        return nil
    end

    timer.scheduleFunction(spawnAsync, self._blue_groups, timer.getTime() + 3)
end

function StageBase:ActivateRedStage()
    if self._initialSide == 2 and self._airbase then
        self._airbase:setCoalition(1)
        self._airbase:autoCapture(false)
    end
    self:SpawnRedUnits()
end

function StageBase:ActivateBlueStage()
    if self._initialSide == 2 and self._airbase then
        self._airbase:setCoalition(2)
    end

    self:CleanRedUnits()
    self:SpawnBlueUnits()

end


if Spearhead == nil then Spearhead = {} end
if Spearhead.classes == nil then Spearhead.classes = {} end
if Spearhead.classes.stageClasses == nil then Spearhead.classes.stageClasses = {} end
if Spearhead.classes.stageClasses.SpecialZones == nil then Spearhead.classes.stageClasses.SpecialZones = {} end
Spearhead.classes.stageClasses.SpecialZones.StageBase = StageBase




end --StageBase.lua
do --BlueSam.lua

---@class BlueSam
---@field Activate fun(self: BlueSam)
---@field private _database Database
---@field private _logger Logger
---@field private _zoneName string
---@field private _blueGroups Array<SpearheadGroup>
---@field private _cleanupUnits table<string, boolean>
local BlueSam = {}

function BlueSam.New(database, logger, zoneName)
    BlueSam.__index = BlueSam
    local self = setmetatable({}, BlueSam)

    self._database = database
    self._logger = logger
    self._zoneName = zoneName

    self._blueGroups = {}
    self._cleanupUnits = {}

    do
        local groups = database:getBlueSamGroupsInZone(zoneName)

        local blueUnitsPos = {}
        local redUnitsPos = {}

        for _, groupName in pairs(groups) do
            local SpearheadGroup = Spearhead.classes.stageClasses.Groups.SpearheadGroup.New(groupName)
            if SpearheadGroup then
                
                if SpearheadGroup:GetCoalition() == 2 then
                    table.insert(self._blueGroups, SpearheadGroup)
                end


                for _, unit in pairs(SpearheadGroup:GetUnits()) do
                    if SpearheadGroup:GetCoalition() == 1 then
                        table.insert(blueUnitsPos, unit:getPoint())
                    elseif SpearheadGroup:GetCoalition() == 2 then
                        table.insert(redUnitsPos, unit:getPoint())
                    end
                end

            end
            SpearheadGroup:Destroy()
        end

        do -- check cleanup requirements
            -- Checks is any of the units are withing range (5m) of another unit. 
            -- If so, make sure to add them to the cleanup list.
        
            local cleanup_distance = 5
            for blueUnitName, blueUnitPos in pairs(blueUnitsPos) do
                for redUnitName, redUnitPos in pairs(redUnitsPos) do
                    local distance = Spearhead.Util.VectorDistance(blueUnitPos, redUnitPos)
                    env.info("distance: " .. tostring(distance))
                    if distance <= cleanup_distance then
                        self._cleanupUnits[redUnitName] = true
                    end
                end
            end
        end
    end

    return self
end

function BlueSam:Activate()
    for unitName, needsCleanup in pairs(self._cleanupUnits) do
        if needsCleanup == true then
            Spearhead.DcsUtil.DestroyUnit(unitName)
        else
            local deathState = Spearhead.classes.persistence.Persistence.UnitDeadState(unitName)
            if deathState and deathState.isDead == true then
                Spearhead.DcsUtil.SpawnCorpse(deathState.country_id, unitName, deathState.type, deathState.pos, deathState.heading)
            end
        end
    end

    for _, group in pairs(self._blueGroups) do
        group:Spawn()
    end
end


if Spearhead == nil then Spearhead = {} end
if Spearhead.classes == nil then Spearhead.classes = {} end
if Spearhead.classes.stageClasses == nil then Spearhead.classes.stageClasses = {} end
if Spearhead.classes.stageClasses.SpecialZones == nil then Spearhead.classes.stageClasses.SpecialZones = {} end
Spearhead.classes.stageClasses.Missions.SpecialZones = BlueSam

end --BlueSam.lua
do --MissionCommandsHelper.lua

local MissionCommandsHelper = {}
do
    ---@type table<string, Mission>
    local missionsByCode = {}

    ---@type table<string, boolean>
    local enabledByCode = {}

    local updateNeeded = false

    ---Add a mission to the F10 commands menu
    ---@param mission Mission
    MissionCommandsHelper.AddMissionToCommands = function (mission)
        missionsByCode[tostring(mission.code)] = mission
        enabledByCode[tostring(mission.code)] = true
        updateNeeded = true
    end

    ---Removes a mission from the F10 commands menu
    ---@param mission Mission
    MissionCommandsHelper.RemoveMissionToCommands = function (mission)
        enabledByCode[tostring(mission.code)] = false
        updateNeeded = true
    end

    local folderNames = {
        primary = "Primary Missions",
        secondary = "Secondary Missions"
    }

    ---Add Base Folder
    ---@param groupId integer
    local addMissionFolders = function(groupId)
        missionCommands.addSubMenuForGroup(groupId, folderNames.primary)
        missionCommands.addSubMenuForGroup(groupId, folderNames.secondary)
    end

    ---Add Mission Folder
    ---@param groupId integer
    local removeMissionFolders = function(groupId)
        missionCommands.removeItemForGroup(groupId , { folderNames.primary } )
        missionCommands.removeItemForGroup(groupId , { folderNames.secondary } )
    end

    local missionBriefingRequested = function(args)
        ---@type Mission
        local mission = args.mission
        local groupID = args.groupId

        mission:ShowBriefing(groupID)
    end

    ---comment
    ---@param groupId integer
    ---@param mission Mission
    local addMissionCommands = function(groupId, mission)

        local path = nil

        if mission.priority == "primary" then
            path = { [1] = folderNames.primary }
        elseif mission.priority == "secondary" then
            path = { [1] = folderNames.secondary }
        end

        if path then
            local missionFolderName = "[" .. mission.code .. "]" .. mission.name
            missionCommands.addSubMenuForGroup(groupId, missionFolderName, path)
            table.insert(path, missionFolderName)
            missionCommands.addCommandForGroup(groupId, "Briefing" , path , missionBriefingRequested, { groupId = groupId, mission = mission })
        end
    end

    local updateCommandsForGroup = function(group)
        local groupID = group:getID()

        -- Cleanup mission folder
        removeMissionFolders(groupID)

        -- Add mission folders
        addMissionFolders(groupID)

        for code, enabled in pairs(enabledByCode) do
            if enabled == true then
                local mission = missionsByCode[code]
                if mission then
                    addMissionCommands(groupID, mission)
                end
            end
        end
    end

    local UpdateContinuous = function(none, time)
        if updateNeeded == false then
            return time + 15
        end

        for _, unit in pairs(Spearhead.DcsUtil.getAllPlayerUnits()) do
            if unit and unit:isExist() then
                local group = unit:getGroup()
                if group then
                    updateCommandsForGroup(group)
                end
            end
        end

        updateNeeded = false
        return time + 15
    end

    timer.scheduleFunction(UpdateContinuous, {}, timer.getTime() + 10)

    do -- Player enter unit listener
        local onPlayerEnterUnit = function(unit)
            if unit then
                local group = unit:getGroup()
                if group then updateCommandsForGroup(group) end
            end
        end

        local OnPlayerEnterUnitListener = {
            OnPlayerEntersUnit = function (self, unit)
                onPlayerEnterUnit(unit)
            end,
        }
        Spearhead.Events.AddOnPlayerEnterUnitListener(OnPlayerEnterUnitListener)
    end
end

if Spearhead == nil then Spearhead = {} end
if Spearhead.classes == nil then Spearhead.classes = {} end
if Spearhead.classes.stageClasses == nil then Spearhead.classes.stageClasses = {} end
if Spearhead.classes.stageClasses.helpers == nil then Spearhead.classes.stageClasses.helpers = {} end
Spearhead.classes.stageClasses.helpers.MissionCommandsHelper = MissionCommandsHelper

end --MissionCommandsHelper.lua
do --Mission.lua


---@class Mission : OnUnitLostListener
---@field name string 
---@field missionType missionType 
---@field code string
---@field priority MissionPriority
---@field private _state MissionState
---@field private _zoneName string
---@field private _database Database
---@field private _logger Logger 
---@field private _missionBriefing string
---@field private _missionGroups MissionGroups
---@field private _completeListeners Array<MissionCompleteListener> 
local Mission = {}



--- @class MissionCompleteListener 
--- @field OnMissionComplete fun(self: any, mission:Mission)

--- @class MissionGroups 
--- @field hasTargets boolean
--- @field groups Array<SpearheadGroup>
--- @field unitsAlive table<string, table<string, boolean>>
--- @field targetsAlive table<string, table<string, boolean>>
--- @field groupNamesPerunit table<string,string>

MINIMAL_UNITS_ALIVE_RATIO = 0.21

---comment
---@param zoneName string
---@param priority MissionPriority
---@param database Database
---@param logger Logger
---@return Mission? 
function Mission.New(zoneName, priority,  database, logger)

    local function ParseZoneName(input)
        local split_name = Spearhead.Util.split_string(input, "_")
        local split_length = Spearhead.Util.tableLength(split_name)
        if Spearhead.Util.startswith(input, "RANDOMMISSION") == true and split_length < 4 then
            Spearhead.AddMissionEditorWarning("Random Mission with zonename " .. input .. " not in right format")
            return nil
        elseif split_length < 3 then
            Spearhead.AddMissionEditorWarning("Mission with zonename" .. input .. " not in right format")
            return nil
        end

        ---@type missionType
        local parsedType = "nil"

        local inputType = string.lower(split_name[2])
        if inputType == "dead" then parsedType = "DEAD" end
        if inputType == "strike" then parsedType = "STRIKE" end
        if inputType == "bai" then parsedType = "BAI" end
        if inputType == "sam" then parsedType = "SAM" end

        if parsedType == "nil" then
            Spearhead.AddMissionEditorWarning("Mission with zonename '" .. input .. "' has an unsupported type '" .. (type or "nil" ))
            return nil
        end
        local name = split_name[3]
        return {
            missionName = name,
            type = parsedType
        }
    end

    local parsed = ParseZoneName(zoneName)

    if parsed == nil then return end

    Mission.__index = Mission
    local o = {}
    local self = setmetatable(o, Mission)
    
    self._zoneName = zoneName
    self.name = parsed.missionName
    self.missionType = parsed.type
    self.code = tostring(database:GetNewMissionCode())
    self.priority = priority
    self._state = "NEW"

    self._logger = logger
    self._database = database
    self._completeListeners = {}

    self._missionBriefing = database:getMissionBriefingForMissionZone(zoneName)
    self._missionGroups = {
        groups = {},
        unitsAlive = {},
        targetsAlive = {},
        hasTargets = false,
        groupNamesPerunit = {}
    }

    local SpearheadGroup = Spearhead.classes.stageClasses.Groups.SpearheadGroup
    local groupNames = database:getGroupsForMissionZone(zoneName)
    for _, groupName in pairs(groupNames) do
        
        local spearheadGroup = SpearheadGroup.New(groupName)
        table.insert(self._missionGroups.groups, spearheadGroup)

        local isGroupTarget =Spearhead.Util.startswith(string.lower(groupName), "tgt_")
        for _, unit in pairs(spearheadGroup:GetUnits())do
            local unitName = unit:getName()
            local isUnitTarget = Spearhead.Util.startswith(string.lower(unitName), "tgt_")

            if self._missionGroups.unitsAlive[groupName] == nil then 
                self._missionGroups.unitsAlive[groupName] = {}
            end

            self._missionGroups.unitsAlive[groupName][unitName] = true
            self._missionGroups.groupNamesPerunit[unitName] = groupName

            if isGroupTarget == true or isUnitTarget == true then
                self._missionGroups.hasTargets = true

                if self._missionGroups.targetsAlive[groupName] == nil then
                    self._missionGroups.targetsAlive[groupName] = {}
                end

                self._missionGroups.targetsAlive[groupName][unitName] = true
            end

            Spearhead.Events.addOnUnitLostEventListener(unitName, self)
        end

        Spearhead.DcsUtil.DestroyGroup(groupName)
    end

    return self
end

---comment
---@return MissionState
function Mission:GetState()
    return self._state
end

function Mission:SpawnPersistedState()
    for _, group in pairs(self._missionGroups.groups) do
        group:SpawnCorpsesOnly()
    end
end

function Mission:SpawnActive()

    self._logger:info("Activating " .. self.name)

    self._state = "ACTIVE"
    for _, group in pairs(self._missionGroups.groups) do
        group:Spawn()
    end

    Spearhead.classes.stageClasses.helpers.MissionCommandsHelper.AddMissionToCommands(self)

    self:StartCheckingContinuous()
end

---@private
function Mission:StartCheckingContinuous()
    ---comment
    ---@param mission Mission
    ---@param time any
    ---@return unknown
    local Check = function (mission, time)
        mission:UpdateState(true, true)

        if mission:GetState() == "COMPLETED" then
            return nil
        end
        return time + 30
    end
    timer.scheduleFunction(Check, self, timer.getTime() + 30)
end

---@private
---@return string?
function Mission:ToStateString()
    if self._missionGroups.hasTargets == true then
        local dead = 0
        local total = 0
        if self._missionGroups.targetsAlive then
            for _, group in pairs(self._missionGroups.targetsAlive) do
                for _, isAlive in pairs(group) do
                    total = total + 1
                    if isAlive == false then
                        dead = dead + 1
                    end
                end
            end
        end
        
        if total > 0 then
            local completionPercentage = math.floor((dead / total) * 100)
            return "Targets Destroyed: " .. completionPercentage .. "%"
        end
    else
        local dead = 0
        local total = 0
        if self._missionGroups.unitsAlive then
            for _, group in pairs(self._missionGroups.unitsAlive) do
                for _, isAlive in pairs(group) do
                    total = total + 1
                    if isAlive == false then
                        dead = dead + 1
                    end
                end
            end
        end
       
        if total > 0 then
            local completionPercentage = math.floor((dead / total) * 100)
            return "Units Destroyed: " .. completionPercentage .. "%"
        end
    end
end

---comment
---@param groupId integer
function Mission:ShowBriefing(groupId)

    local stateString = self:ToStateString()

    if self._missionBriefing == nil or self._missionBriefing == ""  then self._missionBriefing = "No briefing available" end
    local text = "Mission [" .. self.code .. "] ".. self.name .. "\n \n" .. self._missionBriefing .. " \n \n" .. stateString
    trigger.action.outTextForGroup(groupId, text, 30);
end


---@param checkHealth boolean
---@param messageIfDone boolean
function Mission:UpdateState(checkHealth, messageIfDone)
    if checkHealth == nil then checkHealth = false end
    if messageIfDone == false then messageIfDone = true end

    if self._state == "COMPLETED" then
        return
    end

    if checkHealth == true then
        local function unitAliveState(unitName)
            local staticObject = StaticObject.getByName(unitName)
            if staticObject then
                if staticObject:isExist() == true then
                    local life0 = staticObject:getDesc().life
                    if staticObject:getLife() / life0 < 0.3 then
                        self._logger:debug("exploding unit")
                        trigger.action.explosion(staticObject:getPoint(), 100)
                        return false
                    end
                    return true
                else
                    return false
                end
            else
                local unit = Unit.getByName(unitName)

                local alive = unit ~= nil and unit:isExist() == true
                if alive == true then
                    if unit:getLife() / unit:getLife0() < 0.2 then
                        self._logger:debug("exploding unit")
                        trigger.action.explosion(unit:getPoint(), 100)
                        return false
                    end
                    return true
                else
                    return false
                end
            end
        end

        for groupName, unitNameDict in pairs(self._missionGroups.unitsAlive) do
            for unitName, isAlive in pairs(unitNameDict) do
                if isAlive == true then
                    self._missionGroups.unitsAlive[groupName][unitName] = unitAliveState(unitName)
                end
            end
        end

        for groupName, unitNameDict in pairs(self._missionGroups.targetsAlive) do
            for unitName, isAlive in pairs(unitNameDict) do
                if isAlive == true then
                    self._missionGroups.targetsAlive[groupName][unitName] = unitAliveState(unitName)
                end
            end
        end
    end

    if self._missionGroups.hasTargets == true then
        
        local anyTargetAlive = function()
            for _, units in pairs(self._missionGroups.targetsAlive) do
                for _, isAlive in pairs(units) do
                    if isAlive == true then
                        return true
                    end
                end
            end
            return false
        end
        
        if anyTargetAlive() ~= true then
            self._state = "COMPLETED"
        end
    else
        local function CountAliveGroups()
            local aliveGroups = 0

            for _, group in pairs(self._missionGroups.unitsAlive) do
                local groupTotal = 0
                local groupDeath = 0
                for _, isAlive in pairs(group) do
                    if isAlive ~= true then
                        groupDeath = groupDeath + 1
                    end
                    groupTotal = groupTotal + 1
                end

                local aliveRatio = (groupTotal - groupDeath) / groupTotal
                if aliveRatio >= MINIMAL_UNITS_ALIVE_RATIO then
                    aliveGroups = aliveGroups + 1
                end
            end

            return aliveGroups
        end

        if CountAliveGroups() == 0 then
            self._state = "COMPLETED"
        end
    end

    ---comment
    ---@param mission Mission
    local NotifyMissionComplete = function(mission)
        mission:NotifyMissionComplete()
        return nil
    end
    if self._state == "COMPLETED" then
        timer.scheduleFunction(NotifyMissionComplete, self, timer.getTime() + 3)
    end
end

---private usage advised
function Mission:NotifyMissionComplete()
    Spearhead.classes.stageClasses.helpers.MissionCommandsHelper.RemoveMissionToCommands(self)
    self._logger:info("Mission Completed: " .. self._zoneName)
    trigger.action.outText("Mission " .. self.name .. " [" .. self.code .. "] was completed succesfully" , 20)

    for _, listener in pairs(self._completeListeners) do
        pcall(function() 
            listener:OnMissionComplete(self)
        end)
    end
end


---@param listener MissionCompleteListener Object that implements "OnMissionComplete(self, mission)"
function Mission:AddMissionCompleteListener(listener)
    if type(listener) ~= "table" then
        return
    end
    table.insert(self._completeListeners, listener)
end

function Mission:OnUnitLost(object)
    --[[
        OnUnit lost event
    ]]--
    self._logger:debug("Getting on unit lost event")

    local category = Object.getCategory(object)
    if category == Object.Category.UNIT then
        local unitName = object:getName()
        self._logger:debug("UnitName:" .. unitName)

        local groupName = self._missionGroups.groupNamesPerunit[unitName]
        self._missionGroups.unitsAlive[groupName][unitName] = false

        if self._missionGroups.targetsAlive[groupName] and self._missionGroups.targetsAlive[groupName][unitName] then
            self._missionGroups.targetsAlive[groupName][unitName] = false
        end
    elseif category == Object.Category.STATIC  then
        local name = object:getName()
        self._missionGroups.unitsAlive[name][name] = false

        self._logger:debug("Name " .. name)

        if self._missionGroups.targetsAlive[name] and self._missionGroups.targetsAlive[name][name] then
            self._missionGroups.targetsAlive[name][name] = false
        end
    end
    self:UpdateState(false, true)
end

if not Spearhead.classes then Spearhead.classes = {} end
if not Spearhead.classes.stageClasses then Spearhead.classes.stageClasses = {} end
if not Spearhead.classes.stageClasses.Missions then Spearhead.classes.stageClasses.Missions = {} end
Spearhead.classes.stageClasses.Missions.Mission = Mission



end --Mission.lua
do --CapAirbase.lua

local CapBase = {}

---comment
---@param airbaseId number
---@param database table
---@param logger table
---@param capConfig table
---@param stageConfig table
---@return table
function CapBase:new(airbaseId, database, logger, capConfig, stageConfig)
    local o  = {}
    setmetatable(o, { __index = self })

    o.groupNames = database:getCapGroupsAtAirbase(airbaseId)
    o.database  = database
    o.airbaseId = airbaseId
    o.logger = logger
    o.activeStage = 0
    o.capConfig = capConfig
    o.activeCapStages = (stageConfig or {}).capActiveStages or 10

    o.lastStatesByName = {}
    o.groupsByName = {}
    o.PrimaryGroups = {}
    o.BackupGroups = {}

    local CheckReschedulingAsync = function(self, time)
        self:CheckAndScheduleCAP()
    end

    o.OnGroupStateUpdated = function (self, capGroup)
        --[[
            There is no update needed for INTRANSIT, ONSTATION or REARMING as the PREVIOUS state already was checked and nothing changes in the actual overal state.
        ]]--
        if  capGroup.state == Spearhead.internal.CapGroup.GroupState.INTRANSIT 
            or capGroup.state == Spearhead.internal.CapGroup.GroupState.ONSTATION 
            or capGroup.state == Spearhead.internal.CapGroup.GroupState.REARMING
        then
            return
        end
        timer.scheduleFunction(CheckReschedulingAsync, self, timer.getTime() + 1)
    end

    for key, name in pairs(o.groupNames) do
        local capGroup = Spearhead.internal.CapGroup:new(name, airbaseId, logger, database, capConfig)
        if capGroup then
            o.groupsByName[name] = capGroup

            if capGroup.isBackup ==true then
                table.insert(o.BackupGroups, capGroup)
            else
                table.insert(o.PrimaryGroups, capGroup)
            end

            capGroup:AddOnStateUpdatedListener(o)
        end
    end
    logger:info("Airbase with Id '" .. airbaseId .. "' has a total of " .. Spearhead.Util.tableLength(o.groupsByName) .. "cap flights registered")

    o.SpawnIfApplicable = function(self)
        self.logger:debug("Check spawns for airbase " .. self.airbaseId )
        for groupName, capGroup in pairs(self.groupsByName) do
            
            local activeStage = tostring(self.activeStage)
            local targetStage = capGroup:GetTargetZone(activeStage)

            if targetStage ~= nil and capGroup.state == Spearhead.internal.CapGroup.GroupState.UNSPAWNED then
                capGroup:SpawnOnTheRamp()
            end
        end
    end

    o.CheckAndScheduleCAP = function (self)

        self.logger:debug("Check taskings for airbase " .. self.airbaseId )
        
        local countPerStage = {}
        local requiredPerStage = {}

        --Count back up groups that are active or reassign to the new zone if that's needed
        for _, backupGroup in pairs(self.BackupGroups) do
            if backupGroup.state == Spearhead.internal.CapGroup.GroupState.INTRANSIT or backupGroup.state == Spearhead.internal.CapGroup.GroupState.ONSTATION then
                local supposedTargetStage = backupGroup:GetTargetZone(self.activeStage)
                if supposedTargetStage then
                    if supposedTargetStage ~= backupGroup.assignedStageNumber then
                        backupGroup:SendToStage(supposedTargetStage)
                    end
    
                    if countPerStage[supposedTargetStage] == nil then
                        countPerStage[supposedTargetStage] = 0
                    end
                    countPerStage[supposedTargetStage] = countPerStage[supposedTargetStage] + 1
                else
                    backupGroup:SendRTBAndDespawn()
                end
            elseif backupGroup.state == Spearhead.internal.CapGroup.GroupState.RTBINTEN and backupGroup:GetTargetZone(self.activeStage) ~= backupGroup.assignedStageNumber then
                backupGroup:SendRTB()
            end
        end

        --Schedule or reassign primary units if applicable
        for _, primaryGroup in pairs(self.PrimaryGroups) do
            local supposedTargetStage = primaryGroup:GetTargetZone(self.activeStage)
            if supposedTargetStage then
                if requiredPerStage[supposedTargetStage] == nil then
                    requiredPerStage[supposedTargetStage] = 0
                end

                if countPerStage[supposedTargetStage] == nil
                 then
                    countPerStage[supposedTargetStage] = 0
                end

                requiredPerStage[supposedTargetStage] =  requiredPerStage[supposedTargetStage] + 1

                if primaryGroup.state == Spearhead.internal.CapGroup.GroupState.READYONRAMP then
                    if countPerStage[supposedTargetStage] < requiredPerStage[supposedTargetStage] then
                        primaryGroup:SendToStage(supposedTargetStage)
                        countPerStage[supposedTargetStage] = countPerStage[supposedTargetStage] + 1
                    end
                elseif primaryGroup.state == Spearhead.internal.CapGroup.GroupState.INTRANSIT or primaryGroup.state == Spearhead.internal.CapGroup.GroupState.ONSTATION then
                    if supposedTargetStage ~= primaryGroup.assignedStageNumber then
                        if countPerStage[supposedTargetStage] < requiredPerStage[supposedTargetStage] then
                            primaryGroup:SendToStage(supposedTargetStage)
                        else
                            countPerStage[supposedTargetStage] = countPerStage[supposedTargetStage] + 1
                            primaryGroup:SendRTB()
                        end
                    end
                    countPerStage[supposedTargetStage] = countPerStage[supposedTargetStage] + 1
                elseif primaryGroup.state == Spearhead.internal.CapGroup.GroupState.RTBINTEN and primaryGroup:GetTargetZone(self.activeStage) ~= primaryGroup.assignedStageNumber then
                    primaryGroup:SendRTB()
                end
            else
                primaryGroup:SendRTBAndDespawn()
            end
        end

        for _, backupGroup in pairs(self.BackupGroups) do
            if backupGroup.state == Spearhead.internal.CapGroup.GroupState.READYONRAMP then
                local supposedTargetStage = backupGroup:GetTargetZone(self.activeStage)
                if supposedTargetStage then
                    if countPerStage[supposedTargetStage] == nil then
                        countPerStage[supposedTargetStage] = 0
                    end
    
                    if countPerStage[supposedTargetStage] < requiredPerStage[supposedTargetStage] then
                        backupGroup:SendToStage(supposedTargetStage)
                        countPerStage[supposedTargetStage] = countPerStage[supposedTargetStage] + 1
                    end
                else
                    backupGroup:SendRTBAndDespawn()
                end
            end
        end
    end

    o.OnStageNumberChanged = function (self, number)
        self.activeStage = number
        self:SpawnIfApplicable()
        timer.scheduleFunction(CheckReschedulingAsync, self, timer.getTime() + 5)
    end

    ---Check if any CAP is active when a certain stage is active
    ---@param self table
    ---@param stageNumber number
    ---@return boolean
    o.IsBaseActiveWhenStageIsActive = function (self, stageNumber)
        for _, group in pairs(self.PrimaryGroups) do
            local target = group:GetTargetZone(stageNumber)
            if target ~= nil then
                return true
            end
        end
        return false
    end

    Spearhead.Events.AddStageNumberChangedListener(o)
    return o
end

if not Spearhead.internal then Spearhead.internal = {} end
Spearhead.internal.CapAirbase = CapBase
end --CapAirbase.lua
do --GlobalCapManager.lua
local GlobalCapManager = {}
do
    local airbasesPerStage = {}
    local allAirbasesByName = {}
    local activeAirbasesPerActiveStage = {}
    local unitsPerzonePerStage = {}

    local initiated = false

    function GlobalCapManager.start(database, capConfig, stageConfig)
        if initiated == true then return end

        local logger = Spearhead.LoggerTemplate:new("AirbaseManager", capConfig.logLevel)

        local zones = database:getStagezoneNames()
        if zones then
            for key, stageName in pairs(zones) do
                if airbasesPerStage[stageName] == nil then
                    airbasesPerStage[stageName] = {}
                end

                local airbaseIds = database:getAirbaseIdsInStage(stageName)
                if airbaseIds then
                    for _, id in pairs(airbaseIds) do
                        local airbaseName = Spearhead.DcsUtil.getAirbaseName(id)
                        if airbaseName then
                            local airbaseSpecificLogger = Spearhead.LoggerTemplate:new("CAP_" .. airbaseName, capConfig.logLevel)
                            local airbase = Spearhead.internal.CapAirbase:new(id, database, airbaseSpecificLogger, capConfig, stageConfig)
                            if airbase then
                                table.insert(airbasesPerStage[stageName], airbase)
                                allAirbasesByName[airbaseName] = airbase
                            end
                        end
                    end
                end
            end
        end

        logger:info("Initiated " .. Spearhead.Util.tableLength(allAirbasesByName) .. " airbases for cap")
        initiated = true

        local InfoFunctions = {}

        ---returns if there is CAP active 
        ---@param zoneName any
        ---@param activeZoneNumber number
        ---@return boolean
        InfoFunctions.IsCapActiveWhenZoneIsActive = function(zoneName, activeZoneNumber)
            for _, airbase in pairs(airbasesPerStage[zoneName]) do
                if airbase:IsBaseActiveWhenStageIsActive(activeZoneNumber) == true then
                    return true
                end
            end
            return false
        end

        Spearhead.capInfo = InfoFunctions
    end
end

if not Spearhead.internal then Spearhead.internal = {} end
Spearhead.internal.GlobalCapManager = GlobalCapManager

end --GlobalCapManager.lua
do --AirGroup.lua


---@class AirGroup
---@field groupName string
---@field groupState GroupState 
local AirGroup = {}

---@alias GroupState
---| "UnSpawned"
---| "ReadOnTheRamp
---| "InTransit"
---| "OnStation"
---| "RtbInTen"
---| "Rtb"
---| "Dead"
---| "Rearming"


---@alias AirGroupType
---| "CAP"

---| "CAS"
---| "SEAD"
---| "INTERCEPT"
---| ""


---@class GroupNameData
---@field type AirGroupType
---@field isBackup boolean
---@field zonesConfig table<string, string>

local function parseGroupName(groupName)

    local split_string = Spearhead.Util.split_string(groupName, "_")
    local partCount = Spearhead.Util.tableLength(split_string)
    
    if partCount >= 3 then

        ---@type boolean
        local isBackup = false

        do -- config
        
        
        end

    else
        Spearhead.AddMissionEditorWarning("CAP Group with name: " .. groupName .. "should have at least 3 parts, but has " .. partCount)
        return nil
    end


end


---comment
---@generic T: AirGroup
---@param o T
---@param groupName string
---@return T
function AirGroup.New(o, groupName)
    AirGroup.__index = AirGroup
    local o = o or {}
    local self = setmetatable(o, AirGroup)

    self.groupName = groupName
    self.groupState = "UnSpawned"



    return self
end


end --AirGroup.lua
do --CapGroup.lua


local CapHelper = {}
do
    ---comment
    ---@param groupName string
    ---@return table?
    CapHelper.ParseGroupName = function(groupName)
        local split_string = Spearhead.Util.split_string(groupName, "_")
        local partCount = Spearhead.Util.tableLength(split_string)
        if partCount >= 3 then
            local result = {}
            result.zonesConfig = {}

            -- CAP_[1-5]5|[6]6|[7]7_Sukhoi
            -- CAP_[1-5,7]A|[6]7_Sukhoi

            local configPart = split_string[2]
            local first = configPart:sub(1, 1)
            if first == "A" then
                result.isBackup = false
                configPart = string.sub(configPart, 2, #configPart)
            elseif first == "B" then
                configPart = string.sub(configPart, 2, #configPart)
                result.isBackup = true
            elseif first == "[" then
                result.isBackup = false
            else
                Spearhead.AddMissionEditorWarning("Could not parse the CAP config for group: " .. groupName)
                return nil
            end

            local subsplit = Spearhead.Util.split_string(configPart, "|")
            if subsplit then
                for key, value in pairs(subsplit) do
                    local keySplit = Spearhead.Util.split_string(value, "]")
                    local targetZone = keySplit[2]
                    local allActives = string.sub(keySplit[1], 2, #keySplit[1])
                    local commaSeperated = Spearhead.Util.split_string(allActives, ",")
                    for _, value in pairs(commaSeperated) do
                        local dashSeperated = Spearhead.Util.split_string(value, "-")
                        if Spearhead.Util.tableLength(dashSeperated) > 1 then
                            local from = tonumber(dashSeperated[1])
                            local till = tonumber(dashSeperated[2])

                            for i = from, till do
                                if targetZone == "A" then
                                    result.zonesConfig[tostring(i)] = tostring(i)
                                else
                                    result.zonesConfig[tostring(i)] = tostring(targetZone)
                                end
                            end
                        else
                            if targetZone == "A" then
                                result.zonesConfig[tostring(dashSeperated[1])] = tostring(dashSeperated[1])
                            else
                                result.zonesConfig[tostring(dashSeperated[1])] = tostring(targetZone)
                            end
                        end
                    end
                end
            end
            return result
        else
            Spearhead.AddMissionEditorWarning("CAP Group with name: " .. groupName .. "should have at least 3 parts, but has " .. partCount)
            return nil
        end
    end
end

---comment
---@param input table { groupName, task, logger }
---@param time number
---@return nil
local function setTaskAsync(input, time)
    local task = input.task
    local groupName = input.groupName
    local group = Group.getByName(groupName)

    if task then
        group:getController():setTask(task)
        if input.logger ~= nil then
            input.logger:debug("task set succesfully to group " .. groupName)
        end
    end
    return nil
end

local CapGroup = {}

CapGroup.GroupState = {
    UNSPAWNED = 0,
    READYONRAMP = 1,
    INTRANSIT = 2,
    ONSTATION = 3,
    RTBINTEN = 4,
    RTB = 5,
    DEAD = 6,
    REARMING = 7
}

local function SetReadyOnRampAsync(self, time)
    self:SetState(CapGroup.GroupState.READYONRAMP)
end

---comment
---@param groupName string
---@param airbaseId number
---@param logger table logger dependency injection
---@param database table database  dependency injection
---@param capConfig table config dependency injection
---@return table? o
function CapGroup:new(groupName, airbaseId, logger, database, capConfig)
    local o = {}
    setmetatable(o, { __index = self })

    local RESPAWN_AFTER_TOUCHDOWN_SECONDS = 180

    Spearhead.DcsUtil.DestroyGroup(groupName)

    -- initials
    o.groupName = groupName
    o.airbaseId = airbaseId
    o.logger = logger
    o.database = database

    local parsed = CapHelper.ParseGroupName(groupName)
    if parsed == nil then return nil end
    o.capZonesConfig = parsed.zonesConfig
    o.isBackup = parsed.isBackup

    --vars
    o.assignedStageNumber = nil
    
    o.state = CapGroup.GroupState.UNSPAWNED
    o.aliveUnits = {}
    o.landedUnits = {}
    o.unitCount = 0
    o.onStationSince = 0
    o.currentCapTaskingDuration = 0
    o.markedForDespawn = false

    --config
    o.capConfig = capConfig

    ---comment
    ---@param self table
    ---@param currentActive number
    ---@return table
    o.GetTargetZone = function (self, currentActive)
        return self.capZonesConfig[tostring(currentActive)]
    end

    o.SetState = function(self, state)
        self.state = state
        self:PublishUnitUpdatedEvent()
    end

    o.StartRearm = function(self)
        self:SpawnOnTheRamp()
        self:SetState(CapGroup.GroupState.REARMING)
        timer.scheduleFunction(SetReadyOnRampAsync, self, timer.getTime() + self.capConfig:getRearmDelay() - RESPAWN_AFTER_TOUCHDOWN_SECONDS)
    end

    o.SpawnOnTheRamp = function(self)
        self.markedForDespawn = false
        self.logger:debug("Spawning group " .. self.groupName)
        self.aliveUnits = {}
        self.landedUnits = {}
        self.onStationSince = 0

        local group = Spearhead.DcsUtil.SpawnGroupTemplate(self.groupName, nil, nil, true)
        if group then
            self.unitCount = group:getInitialSize()

            if self.state == CapGroup.GroupState.UNSPAWNED then
                self:SetState(CapGroup.GroupState.READYONRAMP)
            end

            for _, unit in pairs(group:getUnits()) do
                local name = unit:getName()
                self.aliveUnits[name] = true
                self.landedUnits[name] = false
            end
        end
    end

    o.Despawn = function(self)
        self.logger:debug("Despawning group " .. self.groupName)
        Spearhead.DcsUtil.DestroyGroup(self.groupName)
        self:SetState(CapGroup.GroupState.UNSPAWNED)
    end

    o.SendRTB = function(self)
        local group = Group.getByName(self.groupName)
        if group and group:isExist() then
            local speed = math.random(self.capConfig:getMinSpeed(), self.capConfig:getMaxSpeed())
            local rtbTask, errormessage = Spearhead.RouteUtil.CreateRTBMission(self.groupName, self.airbaseId, speed)
            if rtbTask then
                timer.scheduleFunction(setTaskAsync, { task = rtbTask, groupName = self.groupName, logger = self.logger }, timer.getTime() + 3)
            else
                self.logger:error("No RTB task could be created for group: " .. self.groupName .. " due to " .. errormessage)
                if self.markedForDespawn == true then
                    self:Despawn()
                end
            end
        end
    end

    o.SendRTBAndDespawn = function(self)
        self.markedForDespawn = true
        o.SendRTB(self)
    end

    ---Starts and send this group to perform CAP at a stage
    ---@param self any
    ---@param stageZoneNumber string
    o.SendToStage = function(self, stageZoneNumber)
        if self.state == CapGroup.GroupState.DEAD or self.state == CapGroup.GroupState.RTB then
            return --Can't task a unit that's dead or RTB
        end

        self.assignedStageNumber = stageZoneNumber
        local group = Group.getByName(self.groupName)
        if group and group:isExist() then
            self.logger:debug("Sending group out " .. self.groupName)
            local controller = group:getController()
            local capPoints = database:getCapRouteInZone(stageZoneNumber, self.airbaseId)

            local altitude = math.random(self.capConfig:getMinAlt(), self.capConfig:getMaxAlt())
            local speed = math.random(self.capConfig:getMinSpeed(), self.capConfig:getMaxSpeed())
            local attackHelos = false
            local deviationDistance = self.capConfig:getMaxDeviationRange()
            local capTask
            if self.state == CapGroup.GroupState.ONRAMP or self.onStationSince == 0 then
                controller:setCommand({
                    id = 'Start',
                    params = {}
                })
                local duration = math.random(self.capConfig:getMinDurationOnStation(), self.capConfig:getmaxDurationOnStation())
                self.currentCapTaskingDuration = duration

                
                capTask = Spearhead.RouteUtil.createCapMission(self.groupName, self.airbaseId, capPoints.point1, capPoints.point2, altitude, speed, duration, attackHelos, deviationDistance)
            else
                local duration = self.currentCapTaskingDuration - (timer.getTime() - o.onStationSince)
                capTask = Spearhead.RouteUtil.createCapMission(self.groupName, self.airbaseId, capPoints.point1, capPoints.point2, altitude, speed, duration, attackHelos, deviationDistance)
            end

            if capTask then
                timer.scheduleFunction(setTaskAsync,
                    { task = capTask, groupName = self.groupName, logger = self.logger }, timer.getTime() + 3)
            end
            self:SetState(CapGroup.GroupState.INTRANSIT)
        end
    end

    ---Starts and send a unit to another airbase
    ---@param self table
    ---@param airdomeId any
    o.SendToAirbase = function(self, airdomeId)
        self.airbaseId = airdomeId
        local speed = math.random(self.capConfig:getMinSpeed(), self.capConfig:getMaxSpeed())
        local rtbTask = Spearhead.RouteUtil.CreateRTBMission(self.groupName, airdomeId, speed)
        local group = Group.getByName(self.groupName)
        local controller = group:getController()
        controller:setCommand({
            id = 'Start',
            params = {}
        })
        timer.scheduleFunction(setTaskAsync, { task = rtbTask, groupName = self.groupName, logger = self.logger },
            timer.getTime() + 5)
    end

    o.OnGroupRTB = function(self, groupName)
        if groupName == self.groupName then
            self.logger:debug("Setting group " ..
            groupName ..
            " to state RTB after a total of " ..
            timer.getTime() - self.onStationSince .. "s of the " .. self.currentCapTaskingDuration .. "s")
            self:SetState(CapGroup.GroupState.RTB)
        end
    end

    o.OnGroupRTBInTen = function(self, groupName)
        if groupName == self.groupName then
            self:SetState(CapGroup.GroupState.RTBINTEN)
        end
    end

    o.OnGroupOnStation = function(self, groupName)
        if groupName == self.groupName then
            self.onStationSince = timer.getTime()
            self.logger:debug("Setting group " .. groupName .. " to state Onstation")
            self:SetState(CapGroup.GroupState.ONSTATION)
        end
    end

    ---comment
    ---@param self table
    ---@param proActive boolean Will check all units in group for aliveness
    o.UpdateState = function(self, proActive)
        local landed = false
        local landedCount = 0
        for name, landedBool in pairs(self.landedUnits) do
            if landedBool == true then
                landedCount = landedCount + 1
                landed = true
            end
        end

        local deadCount = 0
        for name, isAlive in pairs(self.aliveUnits) do
            if isAlive == false then
                deadCount = deadCount + 1
            end
        end

        local function DelayedStartRearm(input, time)
            local capGroup = input.self
            capGroup:StartRearm()
        end

        if landedCount + deadCount == self.unitCount then
            if landed then
                if self.markedForDespawn == true then
                    self:Despawn()
                else
                    timer.scheduleFunction(DelayedStartRearm, { self = self }, timer.getTime() + RESPAWN_AFTER_TOUCHDOWN_SECONDS)
                end
            else
                if self.markedForDespawn == true then
                    self:Despawn()
                else
                    local delay = self.capConfig:getDeathDelay() - self.capConfig:getRearmDelay() + RESPAWN_AFTER_TOUCHDOWN_SECONDS
                    timer.scheduleFunction(DelayedStartRearm, { self = self }, timer.getTime() + delay)
                end
            end
        end
    end

    o.eventListeners = {}
    ---comment
    ---@param self table
    ---@param listener table object with  function OnGroupStateUpdated(capGroupTable)
    o.AddOnStateUpdatedListener = function(self, listener)
        if type(listener) ~= "table" then
            self.logger:error("Listener not of type table for AddOnStateUpdatedListener")
            return
        end

        if listener.OnGroupStateUpdated == nil then
            self.logger:error("Listener does not implement OnGroupStateUpdated")
            return
        end
        table.insert(self.eventListeners, listener)
    end

    o.PublishUnitUpdatedEvent = function(self)
        for _, callable in pairs(self.eventListeners) do
            local _, error = pcall(function()
                callable:OnGroupStateUpdated(self)
            end)
            if error then
                self.logger:error(error)
            end
        end
    end

    o.OnUnitLanded = function(self, initiatorUnit, airbase)
        if airbase then
            local airdomeId = airbase:getID()
            self.airbaseId = airdomeId
        end
        local name = initiatorUnit:getName()
        self.logger:debug("Received unit land event for unit " .. name .. " of group " .. self.groupName)

        self.landedUnits[name] = true
        self:UpdateState(false)
    end

    o.OnUnitLost = function(self, initiatorUnit)
        self.logger:debug("Received unit lost event for group " .. self.groupName)
        if initiatorUnit then
            self.aliveUnits[initiatorUnit:getName()] = false
        end
        self:UpdateState(false)
    end

    Spearhead.Events.addOnGroupRTBListener(o.groupName, o)
    Spearhead.Events.addOnGroupRTBInTenListener(o.groupName, o)
    Spearhead.Events.addOnGroupOnStationListener(o.groupName, o)
    local units = Group.getByName(groupName):getUnits()
    for key, unit in pairs(units) do
        Spearhead.Events.addOnUnitLandEventListener(unit:getName(), o)
        Spearhead.Events.addOnUnitLostEventListener(unit:getName(), o)
    end
    return o
end

if not Spearhead.internal then Spearhead.internal = {} end
Spearhead.internal.CapGroup = CapGroup

end --CapGroup.lua
do --Persistence.lua

local Persistence = {}
do
    ---@class PersistentData
    ---@field dead_units table<string, DeathState>
    ---@field activeStage integer|nil

    ---@class DeathState 
    ---@field isDead boolean
    ---@field pos Position
    ---@field heading number
    ---@field type string
    ---@field country_id integer


    local persistanceWriteIntervalSeconds = 15
    local enabled = false

    ---@type PersistentData
    local tables = {
        dead_units = {},
        activeStage = nil
    }

    
    local logger = {}

    if SpearheadConfig == nil then SpearheadConfig = {} end
    if SpearheadConfig.Persistence == nil then SpearheadConfig.Persistence = {} end

    local path  = nil
    local updateRequired = false

    local createFileIfNotExists = function()
        if not path then return end

        local f = io.open(path, "r")
        if f == nil then
            f = io.open(path, "w+")
            if f == nil then
                logger:error("Could not create a file")
            else
                f:write("{}")
                f:close()
            end
        else
            f:close()
        end
    end

    local loadTablesFromFile = function()
        if not path then return end

        logger:info("Loading data from persistance file...")
        local f  = io.open(path, "r")
        if f == nil then
            return
        end

        local json = f:read("*a")
        local lua = net.json2lua(json)

        if lua.activeStage then
            logger:info("Found active stage from save: " .. lua.activeStage)
            tables.activeStage = lua.activeStage
        end

        if lua.dead_units then
            logger:debug("Found saved dead units")
            for name, deadState in pairs(lua.dead_units) do
                logger:debug("Found saved dead unit: " .. name)

                if type(deadState) == "table" then
                    tables.dead_units[name] = {
                        isDead = deadState.isDead == true,
                        pos = deadState.pos,
                        heading = deadState.heading,
                        type = deadState.type,
                        country_id = deadState.country_id
                    }
                end
            end
        end

        f:close()
    end

    local writeToFile = function()
        if not path then return end

        local f = io.open(path, "w+")
        if f == nil then
            error("Could not open file for writing")
            return
        end

        local jsonString = net.lua2json(tables)
        f:write(jsonString)

        if f ~= nil then
            f:close()
        end
    end

    local UpdateContinuous = function(null, time)

        if updateRequired then 
            local status, result = pcall(writeToFile)
            if status == false then
                env.error("[Spearhead][Persistence] Could not write state to file: " .. result)
            end
        end

        return time + persistanceWriteIntervalSeconds
    end

    Persistence.UpdateNow = function()
        if enabled == true then
            writeToFile()
        end
    end

    Persistence.isEnabled = function()
        return enabled
    end


    ---comment
    ---@param persistenceLogger Logger
    Persistence.Init = function(persistenceLogger)
        logger = persistenceLogger

        logger:info("Initiating Persistence Manager")

        if lfs == nil or io == nil then
            env.error("[Spearhead][Persistence] lfs and io seem to be sanitized. Persistence is skipped and disabled")
            return
        end

        path = (SpearheadConfig.Persistence.directory or (lfs.writedir() .. "\\Data" )) .. "\\" .. (SpearheadConfig.Persistence.fileName or "Spearhead_Persistence.json")

        createFileIfNotExists()
        loadTablesFromFile()
        timer.scheduleFunction(UpdateContinuous, nil, timer.getTime() + 120)
        enabled = true
    end

    ---Sets the stage in the persistence table
    ---@param stageNumber number 
    Persistence.SetActiveStage = function(stageNumber)
        tables.activeStage = stageNumber
        updateRequired = true
    end

    ---Get the active stage as in the persistance file
    ---@return integer|nil
    Persistence.GetActiveStage = function()
        if tables.activeStage then
            return tables.activeStage
        end
        return nil
    end

    ---Check if the unit was dead during the last save. Nil if persitance not enabled
    ---@param unitName string name
    ---@return DeathState|nil { isDead, pos = {x,y,z}, heading, type, country_id } 
    Persistence.UnitDeadState = function(unitName)
        if Persistence.isEnabled() == false then
            return nil
        end

        local entry =  tables.dead_units[unitName]
        if entry then
            return entry
        else
            return { isDead = false }
        end
    end

    ---Pass the unit to be saved as "dead"
    ---@param name string
    ---@param position Position { x, y ,z } 
    ---@param heading number
    ---@param type string 
    ---@param country_id number
    Persistence.UnitKilled = function (name, position, heading, type, country_id)
        if enabled == false then return end

        tables.dead_units[name] = { 
            isDead = true, 
            pos = position, 
            heading = heading, 
            type = type, 
            country_id = country_id,
            isCleaned = false
         }
        updateRequired = true
    end
end

if Spearhead == nil then Spearhead = {} end
if Spearhead.classes == nil then Spearhead.classes = {} end
if Spearhead.classes.persistence == nil then Spearhead.classes.persistence = {} end
Spearhead.classes.persistence.Persistence = Persistence
end --Persistence.lua
do --Main

--Single player purpose


local debug = false
local id = net.get_my_player_id()
if id == 0 then
    debug = true
end

local startTime = timer.getTime() * 1000

Spearhead.Events.Init("DEBUG")

local dbLogger = Spearhead.LoggerTemplate:new("database", "INFO")
local standardLogger = Spearhead.LoggerTemplate:new("", "INFO")
local databaseManager = Spearhead.DB:new(dbLogger, debug)

local capConfig = Spearhead.internal.configuration.CapConfig:new();
local stageConfig = Spearhead.internal.configuration.StageConfig:new();

local startingStage = stageConfig.startingStage or 1
if SpearheadConfig and SpearheadConfig.Persistence and SpearheadConfig.Persistence.enabled == true then
    standardLogger:info("Persistence enabled")
    local persistenceLogger = Spearhead.LoggerTemplate:new("Persistence", "INFO")
    Spearhead.classes.persistence.Persistence.Init(persistenceLogger)

    local persistanceStage = Spearhead.classes.persistence.Persistence.GetActiveStage()
    if persistanceStage then
        standardLogger:info("Persistance activated and using persistant active stage: " .. persistanceStage)
        startingStage = persistanceStage
    end
else
    standardLogger:info("Persistence disabled")
end

Spearhead.internal.GlobalCapManager.start(databaseManager, capConfig, stageConfig)
Spearhead.internal.GlobalStageManager:NewAndStart(databaseManager, stageConfig)
Spearhead.internal.GlobalFleetManager.start(databaseManager)

local SetStageDelayed = function(number, time)
    Spearhead.Events.PublishStageNumberChanged(number)
    return nil
end

timer.scheduleFunction(SetStageDelayed, startingStage, timer.getTime() + 3)

env.info(startTime .. "ms / " .. timer.getTime() * 1000 .. "ms")
local duration = (timer.getTime() * 1000) - startTime
standardLogger:info("Spearhead Initialisation duration: " .. tostring(duration) .. "ms")

Spearhead.LoadingDone()

--Check lines of code in directory per file: 
-- Get-ChildItem . -Include *.lua -Recurse | foreach {""+(Get-Content $_).Count + " => " + $_.name }; && GCI . -Include *.lua* -Recurse | foreach{(GC $_).Count} | measure-object -sum |  % Sum  
-- find . -name '*.lua' | xargs wc -l

--- ==================== DEBUG ORDER OR ZONE VEC ===========================
-- local zone = Spearhead.DcsUtil.getZoneByName("MISSIONSTAGE_99")

-- local count  = Spearhead.Util.tableLength(zone.verts)

-- for i = 1, count - 1 do

--     local a = zone.verts[i]
--     local b = zone.verts[i+1]

--     local color = {0,0,0,1}
    
--     color[i] = 1

--     trigger.action.textToAll(-1,  46+i , { x= a.x, y = 0, z = a.z } , color, {0,0,0}, 24 , true , "" .. i )
--     trigger.action.lineToAll(-1 , 56+i , { x= a.x, y = 0, z = a.z } ,  { x = b.x, y = 0, z = b.z } , color , 1, true)

-- end

end --Main
do --Spearhead API





local SpearheadAPI = {}
do

    SpearheadAPI.Stages = {}

    --- Changes the active stage of spearhead.
    --- All other stages will change based on the normal logic. (CAP, BLUE etc.)
    --- @param stageNumber number the stage number you want changed
    --- @return boolean success indicator of success
    --- @return string message error message
    SpearheadAPI.Stages.changeStage = function(stageNumber) 
        if type(stageNumber) ~= "number" then
            return false, "stageNumber " .. stageNumber .. " is not a valid number"
        end

        Spearhead.Events.PublishStageNumberChanged(stageNumber)
        return true, ""
    end

    ---Returns the current stange number
    ---Returns nil when the stagenumber was not set before ever, which means Spearhead was not started.
    ---@return number | nil
    SpearheadAPI.Stages.getCurrentStage = function()
        return Spearhead.StageNumber or nil
    end

    ---returns whether a stage (by index) is complete. 
    ---@param stageNumber number
    ---@return boolean | nil
    ---@return string 
    SpearheadAPI.isStageComplete = function(stageNumber)
        if type(stageNumber) ~= "number" then
            return false, "stageNumber " .. stageNumber .. " is not a valid number"
        end

        local isComplete = Spearhead.internal.GlobalStageManager.isStageComplete(stageNumber)
        if isComplete == nil then
            return nil, "no stage found with number " .. stageNumber
        end

        return isComplete, ""
    end

end


if Spearhead == nil then Spearhead = {} end
Spearhead.API = SpearheadAPI



end --Spearhead API
