//Functions for chat commands
gChatCommands = { }
//Chat functions which could use additional arguments
gArgumentedChatCommands = { }
//Functions on connect
gConnectFunctions = { }
//Team Allowance Checks
gCanJoinTeamFunctions = { }
//Plugin Activation Functions
gPluginStateChange = { }
//Game End Functions
gGameEndFunctions = { }
//Config Loaded Functions
gConfigLoadedFunctions = { }

local function OnClientConnected(client)
	if GetNSLModEnabled() then
		for i = 1, #gConnectFunctions do
			gConnectFunctions[i](client)
		end
	end
end

Event.Hook("ClientConnect", OnClientConnected)

local originalNS2GameRulesGetCanJoinTeamNumber
originalNS2GameRulesGetCanJoinTeamNumber = Class_ReplaceMethod("NS2Gamerules", "GetCanJoinTeamNumber", 
	function(self, teamNumber)
		if GetNSLModEnabled() then
			for i = 1, #gCanJoinTeamFunctions do
				if not gCanJoinTeamFunctions[i](self, teamNumber) then
					return false
				end
			end
		end
		return originalNS2GameRulesGetCanJoinTeamNumber(self, teamNumber)
	end
)

local originalNS2GameRulesEndGame
originalNS2GameRulesEndGame = Class_ReplaceMethod("NS2Gamerules", "EndGame", 
	function(self, winningTeam)
		local value = originalNS2GameRulesEndGame(self, winningTeam)
		for i = 1, #gGameEndFunctions do
			gGameEndFunctions[i](self, winningTeam)
		end
		return value
	end
)

function ProcessSayCommand(player, command)

	if GetNSLModEnabled() then
		local client = Server.GetOwner(player)
		for validCommand, func in pairs(gChatCommands) do
			if string.lower(validCommand) == string.lower(command) then
				func(client)
			end
		end
		for validCommand, func in pairs(gArgumentedChatCommands) do
			if string.lower(string.sub(command, 1, string.len(validCommand))) == string.lower(validCommand) then
				func(client, string.sub(command, string.len(validCommand) + 2))
			end
		end
	end

end

function EstablishConfigDependantSettings()
	for i = 1, #gConfigLoadedFunctions do
		gConfigLoadedFunctions[i]()
	end
end