-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/tournamentmode/server.lua
-- - Dragon

--NS2 Tournament Mod Server side script

local TournamentModeSettings = { 
	countdownstarted = false, 
	countdownstarttime = 0, 
	countdownstartcount = 0, 
	lastmessage = 0,  
	roundstarted = 0
}

function TournamentModeOnGameEnd()
	GetGamerules():SetTeamsReady(false)
end

local originalNS2GROnCreate
originalNS2GROnCreate = Class_ReplaceMethod("NS2Gamerules", "OnCreate", 
	function(self)
		originalNS2GROnCreate(self)
		if GetNSLModEnabled() then
			GetGamerules():OnTournamentModeEnabled()
		end
	end
)

local originalNS2GRSetGameState
originalNS2GRSetGameState = Class_ReplaceMethod("NS2Gamerules", "SetGameState", 
	function(self, state)
		if self.gameState ~= kGameState.Started and state == kGameState.Started then
			-- Before we set state to started, clear ready flag - so we have to re-ready if game ends
			GetGamerules():SetTeamsReady(false)
		end
		originalNS2GRSetGameState(self, state)
	end
)

--Derrrrrrrp
--Seems weird, but makes game start the same frame as final counter expires.
local originalNS2GRGetPregameLength
originalNS2GRGetPregameLength = Class_ReplaceMethod("NS2Gamerules", "GetPregameLength", 
	function(self)
		if GetNSLModEnabled() then
			return -1
		end
		return originalNS2GRGetPregameLength(self)
	end
)

local function GetRealPlayerCountPerTeam(teamNumber)
	local c = 0
	for _, player in ipairs(GetEntitiesForTeam("Player", teamNumber)) do
        local client = Server.GetOwner(player)
		if client and not client:GetIsVirtual() then
			c = c + 1
		end
    end
	return c
end

local function CheckCanJoinTeam(gameRules, player, teamNumber)
	if (teamNumber == 1 or teamNumber == 2) and GetNSLModEnabled() and GetNSLConfigValue("Limit6PlayerPerTeam") then
		if gameRules:GetGameState() == kGameState.Started then
			local team1Players = GetRealPlayerCountPerTeam(1)
			local team2Players = GetRealPlayerCountPerTeam(2)
			if (teamNumber == 1 and team1Players >= 6) or (teamNumber == 2 and team2Players >= 6) then
				return false
			end
		end
	end
	--block leaving a team for aliens/marines during countdown
	if gameRules:GetCountingDown() and (teamNumber == kTeamReadyRoom or teamNumber == kSpectatorIndex) and (player:GetTeamNumber() == 1 or player:GetTeamNumber() == 2) then
		return false
	end
	return true
end

table.insert(gCanJoinTeamFunctions, CheckCanJoinTeam)

local function ClearTournamentModeState()
	TournamentModeSettings[1] = {ready = false, lastready = 0}
	TournamentModeSettings[2] = {ready = false, lastready = 0}
	TournamentModeSettings.countdownstarted = false
	TournamentModeSettings.countdownstarttime = 0
	TournamentModeSettings.countdownstartcount = 0
	TournamentModeSettings.lastmessage = 0
end

ClearTournamentModeState()

local function CheckCancelGameStart()
	if TournamentModeSettings.countdownstarttime ~= 0 then
		SendAllClientsMessage("TournamentModeGameCancelled", false)
		ClearTournamentModeState()
	end
end

local originalNS2GameRulesOnCommanderLogout
originalNS2GameRulesOnCommanderLogout = Class_ReplaceMethod("NS2Gamerules", "OnCommanderLogout", 
	function(self, commandStructure, oldCommander)
		originalNS2GameRulesOnCommanderLogout(self, commandStructure, oldCommander)
		if oldCommander and GetNSLModEnabled() then
			local teamnum = oldCommander:GetTeamNumber()
			if TournamentModeSettings[teamnum].ready and (GetGamerules():GetGameState() <= kGameState.PreGame) then
				TournamentModeSettings[teamnum].ready = false
				CheckCancelGameStart()
				NSLSendTeamMessage(teamnum, "TournamentModeReadyNoComm", false)
			end
		end
	end
)

local function CheckGameStart()
	if TournamentModeSettings.countdownstarttime < Shared.GetTime() then
		GetGamerules():SetTeamsReady(true)
		ClearTournamentModeState()
		TournamentModeSettings.roundstarted = Shared.GetTime()
	end
end

local function AnnounceTournamentModeCountDown()

	if TournamentModeSettings.countdownstarted and TournamentModeSettings.countdownstarttime - TournamentModeSettings.countdownstartcount < Shared.GetTime() and TournamentModeSettings.countdownstartcount ~= 0 then
		if TournamentModeSettings.countdownstartcount > 60 then
			if math.fmod(TournamentModeSettings.countdownstartcount, 30) == 0 then
				SendAllClientsMessage("TournamentModeCountdown", false, TournamentModeSettings.countdownstartcount)
			end
		elseif TournamentModeSettings.countdownstartcount > 15 then
			if math.fmod(TournamentModeSettings.countdownstartcount, 15) == 0 then
				SendAllClientsMessage("TournamentModeCountdown", false, TournamentModeSettings.countdownstartcount)
			end
		elseif TournamentModeSettings.countdownstartcount > 5 then
			if math.fmod(TournamentModeSettings.countdownstartcount, 5) == 0 then
				SendAllClientsMessage("TournamentModeCountdown", false, TournamentModeSettings.countdownstartcount)
			end
		elseif TournamentModeSettings.countdownstartcount > 1 then
			SendAllClientsMessage("TournamentModeCountdown", true, TournamentModeSettings.countdownstartcount)
		else
			SendAllClientsMessage("TournamentModeFinalCountdown", true, TournamentModeSettings.countdownstartcount)
		end
		TournamentModeSettings.countdownstartcount = TournamentModeSettings.countdownstartcount - 1
	end
	
end

local function DisplayReadiedTeamAlertMessages(ReadiedTeamNum)
	local notreadyteamname = GetActualTeamName((ReadiedTeamNum == 2 and 1) or 2)
	local readyteamname = GetActualTeamName(ReadiedTeamNum)
	SendAllClientsMessage("TournamentModeTeamReadyAlert", false, readyteamname, notreadyteamname)
	if GetNSLConfigValue("TournamentModeForfeitClock") > 0 then
		if Shared.GetTime() - (TournamentModeSettings[ReadiedTeamNum].lastready + GetNSLConfigValue("TournamentModeForfeitClock")) > 0 then
			SendAllClientsMessage("TournamentModeGameForfeited", false, notreadyteamname, GetNSLConfigValue("TournamentModeForfeitClock"))
			TournamentModeSettings[ReadiedTeamNum].ready = false
			TournamentModeSettings[ReadiedTeamNum].lastready = Shared.GetTime()
		else
			local timeremaining = (TournamentModeSettings[ReadiedTeamNum].lastready + GetNSLConfigValue("TournamentModeForfeitClock")) - Shared.GetTime()
			local unit = "seconds"
			if (timeremaining / 60) > 1 then
				timeremaining = (timeremaining / 60)
				unit = "minutes"
			end
			SendAllClientsMessage("TournamentModeForfeitWarning", false, notreadyteamname, timeremaining, unit)
		end
	end
end

local function MonitorCountDown()

	if not TournamentModeSettings.countdownstarted then
		if TournamentModeSettings.lastmessage + GetNSLConfigValue("TournamentModeAlertDelay") < Shared.GetTime() then
			if TournamentModeSettings[1].ready or TournamentModeSettings[2].ready then
				if TournamentModeSettings[1].ready then
					DisplayReadiedTeamAlertMessages(1)
				else
					DisplayReadiedTeamAlertMessages(2)
				end
			else
				SendAllClientsMessage("TournamentModeReadyAlert", false)
			end
			TournamentModeSettings.lastmessage = Shared.GetTime()
		end
	else
		AnnounceTournamentModeCountDown()
		CheckGameStart()
	end
	
end

local originalNS2GamerulesUpdatePregame
originalNS2GamerulesUpdatePregame = Class_ReplaceMethod("NS2Gamerules", "UpdatePregame", 
	function(self, timePassed)
		if self:GetGameState() <= kGameState.PreGame and not self.teamsReady and GetNSLModEnabled() then
			if GetNSLMode() == kNSLPluginConfigs.CAPTAINS and not GetNSLCaptainsGameStartReady() then
				MonitorCaptainsPreGameCountDown()
			else
				MonitorCountDown()
			end
		else
			originalNS2GamerulesUpdatePregame(self, timePassed)
		end
	end
)

local function TournamentModeOnDisconnect(client)
	if TournamentModeSettings.countdownstarted then
		CheckCancelGameStart()
	end
end

table.insert(gDisconnectFunctions, TournamentModeOnDisconnect)

local function CheckGameCountdownStart()
	if TournamentModeSettings[1].ready and TournamentModeSettings[2].ready then
		TournamentModeSettings.countdownstarted = true
		TournamentModeSettings.countdownstarttime = Shared.GetTime() + GetNSLConfigValue("TournamentModeGameStartDelay")
		TournamentModeSettings.countdownstartcount = GetNSLConfigValue("TournamentModeGameStartDelay")
	end
end

local function OnCommandForceStartRound(client, duration)
	if not client then return end
	local NS2ID = client:GetUserId()
	local duration = math.max(tonumber(duration) or GetNSLConfigValue("TournamentModeGameStartDelay"), 1)
	if GetIsNSLRef(NS2ID) then
		ClearTournamentModeState()
		TournamentModeSettings[1].ready = true
		TournamentModeSettings[2].ready = true
		CheckGameCountdownStart()
		TournamentModeSettings.countdownstarttime = Shared.GetTime() + duration
		TournamentModeSettings.countdownstartcount = duration
		SendClientServerAdminMessage(client, "FORCE_GAME_START")
	end
end

RegisterNSLConsoleCommand("sv_nslforcestart", OnCommandForceStartRound, "SV_NSLFORCESTART", false,
	{{ Type = "string", Optional = true}})

local function OnCommandCancelRoundStart(client)
	if not client then return end
	local NS2ID = client:GetUserId()
	if GetIsNSLRef(NS2ID) then
		CheckCancelGameStart()
		ClearTournamentModeState()
		SendClientServerAdminMessage(client, "FORCE_GAME_START_ABORT")
	end
end

RegisterNSLConsoleCommand("sv_nslcancelstart", OnCommandCancelRoundStart, "SV_NSLCANCELSTART")

local function ClientReady(client)

	local player = client:GetControllingPlayer()
	local playername = player:GetName()
	local teamnum = player:GetTeamNumber()
	if teamnum == 1 or teamnum == 2 then
		local gamerules = GetGamerules()
		local team1Commander = gamerules.team1:GetCommander()
        local team2Commander = gamerules.team2:GetCommander()
		local team1CommanderRequired = true
		local team2CommanderRequired = true
		if GetServerGameMode and kGameMode then
			--Classic
			if GetServerGameMode() == kGameMode.Classic then
				team2CommanderRequired = false
			elseif GetServerGameMode() == kGameMode.Combat then
				team1CommanderRequired = false
				team2CommanderRequired = false
			end
		end
		if (not team1Commander and teamnum == 1 and team1CommanderRequired) or (not team2Commander and teamnum == 2 and team2CommanderRequired) then
			NSLSendTeamMessage(teamnum, "TournamentModeReadyNoComm", false)
		elseif TournamentModeSettings[teamnum].lastready + 2 < Shared.GetTime() then
			TournamentModeSettings[teamnum].ready = not TournamentModeSettings[teamnum].ready
			TournamentModeSettings[teamnum].lastready = Shared.GetTime()
			SendAllClientsMessage("TournamentModeTeamReady", false, playername, ConditionalValue(TournamentModeSettings[teamnum].ready, "readied", "unreadied"), GetActualTeamName(teamnum))
			CheckGameCountdownStart()
		end	
	end
	if TournamentModeSettings[1].ready == false or TournamentModeSettings[2].ready == false then
		CheckCancelGameStart()
	end
	
end

local function CheckforInProgressGameToCancel(client, gamerules)
	if gamerules:GetGameState() == kGameState.Started and (TournamentModeSettings.roundstarted or 0) + GetNSLConfigValue("TournamentModeRestartDuration") > Shared.GetTime() then
		local player = client:GetControllingPlayer()
		local playername = player:GetName()
		local teamnum = player:GetTeamNumber()
		if (teamnum == 1 or teamnum == 2) then
			gamerules:SetTeamsReady(false)
			SendAllClientsMessage("TournamentModeStartedGameCancelled", false, playername, GetActualTeamName(teamnum))
			if GetIsGamePaused() then
				NSLTriggerUnpause()
			end
		end
	end
end

local function OnCommandReady(client)
	local gamerules = GetGamerules()
	if gamerules and client and GetNSLModEnabled() and not GetIsGamePaused() then
		if gamerules:GetGameState() <= kGameState.PreGame then
			ClientReady(client)
		else
			CheckforInProgressGameToCancel(client, gamerules)
		end
		return true
	end
	return false
end

table.insert(gReadyCommandFunctions, OnCommandReady)

local function ClientNotReady(client)

	local player = client:GetControllingPlayer()
	local playername = player:GetName()
	local teamnum = player:GetTeamNumber()
	if (teamnum == 1 or teamnum == 2) and TournamentModeSettings[teamnum].ready then
		TournamentModeSettings[teamnum].ready = false
		TournamentModeSettings[teamnum].lastready = Shared.GetTime()
		SendAllClientsMessage("TournamentModeTeamReady", false, playername, "unreadied", GetActualTeamName(teamnum))
	end
	if TournamentModeSettings[1].ready == false or TournamentModeSettings[2].ready == false then
		CheckCancelGameStart()
	end
	
end

local function OnCommandNotReady(client)
	local gamerules = GetGamerules()
	if gamerules and client and GetNSLModEnabled() and not GetIsGamePaused() then
		if gamerules:GetGameState() <= kGameState.PreGame then
			ClientNotReady(client)
		else
			CheckforInProgressGameToCancel(client, gamerules)
		end
		return true
	end
	return false
end

table.insert(gNotReadyCommandFunctions, OnCommandNotReady)

local function UpdateTournamentMode(newState)
	if newState == kNSLPluginConfigs.DISABLED then
		GetGamerules():OnTournamentModeDisabled()
		GetGameInfoEntity():SetTournamentMode(false)
	else
		GetGamerules():OnTournamentModeEnabled()
		GetGameInfoEntity():SetTournamentMode(true)		
	end
end

table.insert(gPluginStateChange, UpdateTournamentMode)