-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/teamdecals/shared.lua
-- - Dragon

local teamDecals = { }
local globalDecals = { }

local function ScanTeamDecalFiles(leagueName)

	local leagueDecalFiles = { }
	Shared.GetMatchingFileNames( string.format("materials/teamlogos/%s/*.material", leagueName), true, leagueDecalFiles )
	teamDecals[leagueName] = { }
	for _, decalFile in ipairs(leagueDecalFiles) do
		local _, _, decal = string.find(decalFile, string.format("materials/teamlogos/%s/*/(.*).material$", leagueName) )
		local decalTable = { }
		local i = 1
		for str in string.gmatch(decal, "([^/]+)") do
			decalTable[i] = str
			i = i + 1
		end
		if #decalTable == 2 then
			teamDecals[leagueName][decalTable[1]] = decalFile
		end
	end
	local decalFiles = { }
	Shared.GetMatchingFileNames( "materials/teamlogos/*.material", true, decalFiles )
	for _, decalFile in ipairs(leagueDecalFiles) do
		if not table.contains(leagueDecalFiles, decalFile) then
			local _, _, decal = string.find(decalFile, "materials/teamlogos/*/(.*).material$" )
			local decalTable = { }
			local i = 1
			for str in string.gmatch(decal, "([^/]+)") do
				decalTable[i] = str
				i = i + 1
			end
			if #decalTable == 2 then
				globalDecals[decalTable[1]] = decalFile
			end
		end
	end
end
	
function GetDecalNameforTeamId(teamId)
	local gameInfo = GetGameInfoEntity()
	if not gameInfo then return nil end
	local leagueName = gameInfo:GetLeagueName()
	if not teamDecals[leagueName] then
		ScanTeamDecalFiles(leagueName)
	end
	return teamDecals[leagueName][tostring(teamId)] and teamDecals[leagueName][tostring(teamId)] or globalDecals[tostring(teamId)]
end

class 'NSLDecal' (Entity)

NSLDecal.kMapName = "nsldecal"

local kMaxDecalNameLength = 20
local kNSLDecalModel = PrecacheAsset("models/teamlogos/nsllogos.model")
PrecacheAsset("materials/teamlogos/teamlogos.surface_shader")
local kOverrideDecalRender = false

local networkVars =
{
    decal_name = string.format("string (%d)", kMaxDecalNameLength),
	active = "boolean"
}

function NSLDecal:OnCreate()

    Entity.OnCreate(self)

	self:SetPropagate(Entity.Propagate_Always)
    self:SetUpdates(false)
	
	self.yaw = 0
	self.pitch = 0
	self.roll = 0
	self.active = false
	self.decal_name = ""
	
end

local function ClearRenderModel(self)

    if self._renderModel then
        Client.DestroyRenderModel(self._renderModel)
    end
    self._renderModel = nil
    
end

-- Bypass destruction on reset
function NSLDecal:GetIsMapEntity()
    return true
end

function NSLDecal:OnDestroy()
    ClearRenderModel(self)
end

function NSLDecal:SetActive(active)
    self.active = active
end

function NSLDecal:SetYawPitchRoll(yaw, pitch, roll)
    self.yaw = yaw
	self.pitch = pitch
	self.roll = roll
end

function NSLDecal:SetDecal(decal)
	if decal then
    	self.decal_name = string.sub(decal, 1, kMaxDecalNameLength)
    end
end

if Client then

    function NSLDecal:OnUpdateRender()

        PROFILE("NSLDecal:OnUpdateRender")
		
		if self.overrideDecalRender then return end
		local player = Client.GetLocalPlayer()
        if player and player:GetTeamNumber() == kSpectatorIndex then

			if self.decal_name ~= self.rendereddecal_name or not self.active then
				ClearRenderModel(self)
			end

			if not self._renderModel and self.active and self.decal_name ~= "" then
				
				self._renderModel = Client.CreateRenderModel(RenderScene.Zone_Default)
				self._renderMaterial = Client.CreateRenderMaterial()
				self._renderModel:SetModel(kNSLDecalModel)
				self._renderMaterial:SetMaterial(GetDecalNameforTeamId(self.decal_name))
				self._renderModel:AddMaterial(self._renderMaterial)
				local coords = self:GetCoords()
				coords:Scale(4)
				self._renderModel:SetCoords(coords)
				self.rendereddecal_name = self.decal_name
				
			end
			
		else
			ClearRenderModel(self)
			self.overrideDecalRender = true
		end
		
    end
	
	local function OnLocalPlayerChanged()
		local player = Client.GetLocalPlayer()
		if player and player:GetTeamNumber() == kSpectatorIndex then
			-- Reset the NSLDecal entities so they render again
			for _, nsd in ientitylist(Shared.GetEntitiesWithClassname("NSLDecal")) do
				nsd.overrideDecalRender = false
			end
		end
	end
	
	Event.Hook("LocalPlayerChanged", OnLocalPlayerChanged)
    
end

Shared.LinkClassToMap("NSLDecal", NSLDecal.kMapName, networkVars)