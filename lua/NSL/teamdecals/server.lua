-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/teamdecals/server.lua
-- - Dragon

local decalEntities = { }

local function LookupDecalLocations()
	local mapName = string.lower(Shared.GetMapName())
	local locations = GetNSLConfigValue("LogoLocations")
	if locations and locations[mapName] then
		return locations[mapName]
	end
	return nil
end

local function UpdateNonTechPointDecalData(techPoints, decalLocations)
	local techPointLocations = { }
	for _, techPoint in ipairs(techPoints) do
		table.insert(techPointLocations, string.lower(techPoint:GetLocationName()))
	end
	for loc, data in pairs(decalLocations) do
		if loc and data then
			if not table.contains(techPointLocations, loc) then
				if not data.decal then
					data.decal = GetNSLConfigValue("LeagueDecal")
				end
				if not data.angles then
					data.angles = Angles(0,0,0)
				end
			end
		end
	end
end

local function UpdateTechPointDecalData(techPoints, decalLocations)
	local team1decal = GetDecalNameforTeamId(GetNSLTeamID(1)) and GetNSLTeamID(1) or nil
	local team2decal = GetDecalNameforTeamId(GetNSLTeamID(2)) and GetNSLTeamID(2) or nil
	--Build transfer table of TP Locations to current Decal
	for _, techPoint in ipairs(techPoints) do
		if techPoint:GetAttached() then
			if decalLocations[string.lower(techPoint:GetLocationName())] then
				if techPoint.occupiedTeam == 1 then
					decalLocations[string.lower(techPoint:GetLocationName())].decal = team1decal
				else
					decalLocations[string.lower(techPoint:GetLocationName())].decal = team2decal
				end
				decalLocations[string.lower(techPoint:GetLocationName())].active = decalLocations[string.lower(techPoint:GetLocationName())].decal and true or false
			end
		else
			if decalLocations[string.lower(techPoint:GetLocationName())] then
				decalLocations[string.lower(techPoint:GetLocationName())].active = false
			end
		end
	end
end

local function GetNSLDecalLocations()
	local decalLocations = LookupDecalLocations()
	if decalLocations then
		-- Map has decal location data
		local techPoints = EntityListToTable(Shared.GetEntitiesWithClassname("TechPoint"))
		UpdateTechPointDecalData(techPoints, decalLocations)
		UpdateNonTechPointDecalData(techPoints, decalLocations)
	end
	return decalLocations
end

local function ConvertTabletoOrigin(t)
	if t and type(t) == "table" and #t == 3 then
		return Vector(t[1], t[2], t[3])
	end
	return nil
end

local function ConvertTabletoAngles(t)
	if t and type(t) == "table" and #t == 3 then
		return Angles((t[1] / 180) * math.pi, (t[2] / 180) * math.pi , (t[3] / 180) * math.pi)
	end
	return nil
end


local function UpdateOrCreateAllNSLDecals()
	local validMode = (GetNSLMode() == kNSLPluginConfigs.PCW or GetNSLMode() == kNSLPluginConfigs.OFFICIAL)
	local decalLocations = GetNSLDecalLocations()
	if decalLocations then
		for loc, data in pairs(decalLocations) do
			if loc and data then
				local origin = ConvertTabletoOrigin(data.origin)
				local angles = ConvertTabletoAngles(data.angles)
				if origin then
					if decalEntities[loc] then
						decalEntities[loc]:SetDecal(data.decal)
						decalEntities[loc]:SetActive(data.active and validMode)
					else
						decalEntities[loc] = Server.CreateEntity("nsldecal", {origin = origin, angles = angles})
						decalEntities[loc]:SetDecal(data.decal)
						decalEntities[loc]:SetActive(data.active and validMode)
					end
				end
			end
		end
	end
end

local function UpdateAllNSLDecals(teamData, teamScore)
	UpdateOrCreateAllNSLDecals()
end

table.insert(gTeamNamesUpdatedFunctions, UpdateAllNSLDecals)

local function OnDecalConfigLoaded(config)
	if (config == "complete" or config == "reload") and GetNSLModEnabled() then
		UpdateOrCreateAllNSLDecals()
	end
end

table.insert(gConfigLoadedFunctions, OnDecalConfigLoaded)

--Detect TP Changes
local originalTechPointOnAttached
originalTechPointOnAttached = Class_ReplaceMethod("TechPoint", "OnAttached", 
	function(self, entity)
		originalTechPointOnAttached(self, entity)
		if Shared.GetTime() > 5 then
			UpdateOrCreateAllNSLDecals()
		end
	end
)

local originalTechPointClearAttached
originalTechPointClearAttached = Class_ReplaceMethod("TechPoint", "ClearAttached", 
	function(self)
		originalTechPointClearAttached(self)
		if Shared.GetTime() > 5 then
			UpdateOrCreateAllNSLDecals()
		end
	end
)