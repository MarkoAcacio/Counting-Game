local RoundSystem = {}

local d = require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Directory"))


-- Folders
local LobbyFolder = workspace:WaitForChild("Lobby")
local MapsFolder = workspace:WaitForChild("Maps") -- Placeholder rn

-- Modules
local PlayerModule = require(d.Modules:WaitForChild("PlayerModule"))
local GameModule = require(d.Modules:WaitForChild("GameModule"))
local DataManager = require(d.ServerScriptService:WaitForChild("Data"):WaitForChild("DataManager"))

-- Variables & Functions
local mapSpawn = MapsFolder:WaitForChild("MapSpawn")
local LobbySpawn = LobbyFolder:WaitForChild("SpawnLocation")

local WaitForPlayers  -- Checks if 2 Players or more. If not, It will wait.
local PlayerLeave
local PlayerWin

local Last2Standing
local StartIntermission
local sendEvent
local SortFinalStand
local EndEarly

-- Config
local mapNames = {
	"map1",
	"map2",
}

local defaultRoundTime = 20

local Intermission = 8
local RoundTimer = defaultRoundTime
local WinTimer = 10

RoundSystem.pastAlivePlayers = 0
RoundSystem.AllowTeleport = true -- True in first start of round.
RoundSystem.isRoundMusicActive = false
RoundSystem.WinningPlayers = {}


local decrementTime = 5
local finalRound = false

local mapPos = CFrame.new(-89.676, -796.322, 0)


---------------------------------------------------------------------------------------------------------------------------------------------

function RoundSystem:Init()
	
	local playerCount = WaitForPlayers()  -- Connect To UI
	if playerCount then
		RoundSystem:StartGame()
	else
		warn("Error | CheckPlayerCount")
	end
end

---------------------------------------------------------------------------------------------------------------------------------------------

local function playMusic(type, music)
	for _, player in pairs(game.Players:GetPlayers()) do
		if type == "Music" then
			print("Firing Music Event: ", music)
			d.MusicEvent:FireClient(player, music)
		elseif type == "SFX" then
			print("Firing SFX Event: ", music)
			d.SFXEvent:FireClient(player, music)
		end
	end
end

local function HandleWinnerRewards()
	for _, player in ipairs(PlayerModule:GetAlivePlayers()) do
		
		player.Character:scaleTo(4)
		
		d.SFXEvent:FireClient(player, "WinSFX")
		d.MusicEvent:FireClient(player, "Winner")
		
		table.insert(RoundSystem.WinningPlayers, player)

		local highlight = Instance.new("Highlight")
		highlight.FillColor = Color3.fromRGB(255, 213, 44)
		highlight.FillTransparency = 0.7
		highlight.Parent = player.Character
	end
end

--[[

NOTE: This Section is already coded in Hiearchy. StartGame, Intermission, In-Round, Win, then repeat loop.

	The Self.Active is a variable to check if something is active. It doesn't really matter just a double check for the loops.

]]

local function clearMap()
	for _, child in ipairs(MapsFolder:GetChildren()) do
		for _, mapName in ipairs(mapNames) do
			if child.Name == mapName then
				child:Destroy() -- DESTROY MAP
			end
		end
	end
	
	if MapsFolder:FindFirstChild("Particle") then
		MapsFolder:WaitForChild("Particle"):Destroy()
	end
end

local function DistributeReward(winningPlayers)
	if winningPlayers then
		for _, player in ipairs(winningPlayers) do
			DataManager.AddWins(player, 1)
			DataManager.AddCoins(player, 5)
			d.NotificationEvent:FireClient(player, 5) -- Coins only 
		end
		return {}
	end
end

function RoundSystem:StartGame()
	playMusic("Music", "BGM")
	
	self.WinningPlayers = DistributeReward(self.WinningPlayers)
	clearMap()
	
	local playerCount = WaitForPlayers()  -- Connect To UI
	if playerCount then
		RoundSystem.AllowTeleport = true -- Set to true at every start of a new game.
		self.isRoundMusicActive = false -- Set to false at every start of game to allow music playing.
		self:StartIntermission()
		GameModule:HandleCounting()
	else
		warn("Error | CheckPlayerCount")
	end
	
end


---------------------------------------- Intermission --------------------------------------------

function RoundSystem:StartIntermission()
	self.IntermissionActive = true 
	local Timer = Intermission or 15
	
	local randomMap = math.random(1, #d.MapTemplateFolder:GetChildren())
	local map = d.MapTemplateFolder:GetChildren()[randomMap]:Clone()
	map.Parent = MapsFolder
	map:PivotTo(mapPos)
	
	PlayerModule:RagdollAction("restrict")
	PlayerModule:RagdollAction("delete")

	RoundTimer = defaultRoundTime
	
	task.spawn(function()
		while Timer > 0 and self.IntermissionActive do
			-- Update UI
			
			sendEvent(1, Timer)
			PlayerModule:SetPlaying()
			task.wait(1)
			Timer -= 1
		end
		
		self.IntermissionActive = false
		self:StartRound()  -- START ROUND
		
	end)
	
end

---------------------------------------- StartRound --------------------------------------------

-- 1 tp map, 2 tp spawn
local function teleportPlayers(action)
	for _, player in ipairs(PlayerModule:GetAlivePlayers()) do
		local character = player.Character
		if character then
			if action == 1 then
				character:PivotTo(mapSpawn.CFrame)
			elseif action == 2 then
				character:PivotTo(LobbySpawn.CFrame)

			end
		end
	end
end


-- @isSurvive | returns true or false. manages decrease if everyone survive. else, none.
function RoundSystem:StartRound(isSurvive)
	self.RoundActive = true
	
	PlayerModule:RagdollAction("allow")
	PlayerModule:RagdollAction("delete")
	
	if isSurvive then  -- DECREASES ROUNDTIMER IF EVERYONE SURVIVES
		RoundTimer -= decrementTime
	end
	
	if RoundTimer == 0 then
		RoundSystem:FinalStand()
		return 
	end

	local Timer = RoundTimer or 5
	
	local alivePlayers = PlayerModule:GetAlivePlayers()
	self.pastAlivePlayers = #alivePlayers

	PlayerModule.Checked = false
	local firedNewRound = false
	
	local animTime = 10
			-- Handle animation
	while animTime > 0 and self.RoundActive do
		sendEvent(7, animTime, false)
			
		task.wait(1)
		animTime -= 1
	end
	
	-- Allow Teleport ONCE and turn it off.
	if self.AllowTeleport == true then teleportPlayers(1) end
	self.AllowTeleport = false
	
	-- HANDLE RESET ETC.
	
	if self.isRoundMusicActive == false then print("Playing Music Function") playMusic("Music", "Round") self.isRoundMusicActive = true end -- Play music only when the var is false.
	
		task.spawn(function()
			while Timer > 0 and self.RoundActive do
				-- Update UI
				-- Check if how many players survive, then fire round event again.
				sendEvent(2, Timer, firedNewRound)
				firedNewRound = true

				-- CHECK IF ALIVE & PLAYING PLAYERS HAVE CLICKED THE BUTTON!
				local status = PlayerModule:checkCountedPlayers()
				local alivePlayers = PlayerModule:GetAlivePlayers()
				

				if status and Timer > 4 then  -- When everyone has counted.
					Timer = 4
				end
				
				if #alivePlayers <= 1 and status and Timer > 4 then  -- End when there's only 1 player left and EVERYONE has clicked.
					Timer = 4
				end

				task.wait(1)
				Timer -= 1
			end

		self.RoundActive = false
		self:determineRoundOptions()
	end)
end


---------------------------------------- StartNewRound --------------------------------------------

-- @Type |  determines if to start LastStand, or new round.
-- @isComplete | returns true or false. manages decrease if everyone survive. else, none.
function RoundSystem:StartingNewInRound(type, isSurvive)
	self.NewInRound = true
	local Timer = 8
	
	PlayerModule:RagdollAction("delete")
	
	-- HANDLE RESET ETC.
	task.spawn(function()
		while Timer > 0 and self.NewInRound do
			-- Update UI
			-- Check if how many players survive, then fire round event again.
			sendEvent(3, Timer)

			task.wait(1)
			Timer -= 1
		end

		if type == 1 then  -- new round
			self.NewInRound = false
			self:StartRound(isSurvive)
		elseif type == 2 then  -- Last Stand
			self:FinalStand()
		end

	end)
end


---------------------------------------- Eliminating Players --------------------------------------------

function RoundSystem:EliminatingPlayers()
	self.EliminatingPlayers = true
	local Timer = WinTimer or 5
	-- HANDLE RESET ETC.
	
	task.spawn(function()
		while Timer > 0 and self.EliminatingPlayers do
			-- Update UI
			-- Check if how many players survive, then fire round event again.
			sendEvent(4, Timer)
			task.wait(1)
			Timer -= 1
		end
		------------------ ROUND END ----------------------

		self.EliminatingPlayers = false
		GameModule:CheckClicks()
		self:determineRoundOptions()
	end)
end


---------------------------------------- Celebrate Winners --------------------------------------------

-- roundStatus - 1 = Normal, 2 = Last Stand
function RoundSystem:CelebrateWinners(roundStatus)
	self.CelebrateWinnersActive = true
	local Timer = WinTimer or 10
	local winners = nil
	
	PlayerModule:RagdollAction("delete")
	
	if roundStatus == 1 then
		winners = PlayerModule:GetAlivePlayers()
		HandleWinnerRewards()
		
	elseif roundStatus == 2 then
		winners = PlayerModule:GetAlivePlayers()
		HandleWinnerRewards()
	end
	
	playMusic("SFX", "Win")
	playMusic("Music", "Winner")
	
	local confetti = d.Templates:WaitForChild("Particle"):Clone()
	confetti.Parent = workspace.Maps
	
	task.spawn(function()
		while Timer > 0 and self.CelebrateWinnersActive do
			-- Update UI
			sendEvent(5, Timer)
			-- Run Counting GameModule TO REWARD
			
			if roundStatus == 2 then
				print("WINNERS: ", winners)
			end
			
			task.wait(1)
			Timer -= 1
		end
		self.CelebrateWinnersActive = false
		
		PlayerModule:ResetPlayerScale()
		teleportPlayers(2)
		GameModule:ResetGame()
		self:StartGame()
	end)
end


----------------------------------------- Last / Final Stand --------------------------------------------

function RoundSystem:FinalStand()
	self.FinalStandActive = true 
	local Timer = 20 
	local AlivePlayers

	PlayerModule:RagdollAction("delete")

	task.spawn(function()
		sendEvent(6, Timer)
		task.wait(5.3)

		while Timer > 0 and self.FinalStandActive do
			-- 1. Get current count of alive players
			local currentAlive = PlayerModule:GetAlivePlayers()
			AlivePlayers = #currentAlive

			-- 2. NEW CHECK: If only 1 player left, stop the timer and skip elimination
			if AlivePlayers <= 1 then
				self.FinalStandActive = false
				break
			end

			sendEvent(6, Timer)
			task.wait(1)
			Timer -= 1
		end

		self.FinalStandActive = false

		-- 3. FINAL VALIDATION: Check again after loop ends
		local finalAlive = PlayerModule:GetAlivePlayers()

		if #finalAlive == 1 then
			-- Only one person survived the clicking madness or everyone else reset/left
			print("Lone survivor found in Final Stand!")
			RoundSystem:CelebrateWinners(2)
			return
		elseif #finalAlive == 0 then
			-- Everyone died/left
			RoundSystem:determineRoundOptions()
			return
		end

		-- 4. Normal Elimination Logic (Runs only if 2+ players are still here)
		local sortedPlayers = SortFinalStand()
		local highestCount = 0
		if #sortedPlayers > 0 then
			highestCount = sortedPlayers[1].count 
		end

		for index, playerData in ipairs(sortedPlayers) do
			local player = playerData.player
			local count = playerData.count

			local data = PlayerModule.Players[player]
			if data and data.Alive then
				if count < highestCount then
					-- Eliminate those who didn't click enough
					data.Alive = false
					data.Counted = true
				else
					-- Tie or Top Player
					data.Alive = true
					data.Counted = true
				end
			end
		end

		-- Run the death sequence for those set to Alive = false
		PlayerModule:EliminatePlayers()

		-- Final transition
		local remaining = #PlayerModule:GetAlivePlayers()
		if remaining >= 1 then
			RoundSystem:CelebrateWinners(2)
		else
			RoundSystem:determineRoundOptions()
		end
	end)
end



SortFinalStand = function()
	local sortedData = {}

	for player, data in pairs(GameModule.finalStandClicks) do
		table.insert(sortedData, {player = player, count = data.count})
	end

	table.sort(sortedData, function(a, b)
		return a.count > b.count  -- highest first
	end)
	
	return sortedData
end


------------------------------------------------------------------GETTERS & SETTERS----------------------------------------------------------

function RoundSystem:IsIntermissionActive()
	return self.IntermissionActive
end

function RoundSystem:IsRoundActive()
	return self.RoundActive
end

function RoundSystem:IsCelebrateWinners()
	return self.CelebrateWinnersActive
end


---------------------------------------------------------------------------------------------------------------------------------------------

function RoundSystem:determineRoundOptions()
	local prev = self.pastAlivePlayers
	GameModule:CheckClicks() -- Check If Player hasn't Clicked yet. & Also check if player is last to click.
	
	local aliveCount = #PlayerModule:GetAlivePlayers()
	
	if aliveCount == 1 then  -- WINNER
		
		RoundSystem:CelebrateWinners(1)  -- Normal Win
		GameModule:ResetGame()
		print("Player Won!")
		
	elseif aliveCount == 2 then  -- LAST STAND
		
		GameModule:ResetRound()
		self:StartingNewInRound(2, false)
		
	elseif aliveCount >= 3 then  -- NORMAL ROUND
		-- Restart Round
		print("Restarting Round")
		
		GameModule:ResetRound()
		
		d.RoundEvent:FireAllClients({
			State = 0,
			newRound = true,
			Time = 0
		}, PlayerModule:ClientData())
		
		if prev == aliveCount then
			self:StartingNewInRound(1, true)
		else
			self:StartingNewInRound(1, false)
		end
	else
		self.IntermissionActive = false
		self.RoundActive = false
		self.NewInRound = false
		self.EliminatingPlayers = false
		self.CelebrateWinnersActive = false
		self.FinalStandActive = false

		GameModule:ResetGame()

		task.wait(0.5)
		
		self:StartGame()
		d.RoundEvent:FireAllClients({State = 1, newRound = false, Time = 0}, PlayerModule:ClientData())
		warn("No Alive Players Found Restarting GameLoop... | DetermineRoundOptions @RoundSystem")		
	end 
end



sendEvent = function(action : number, Timer : number, firedNewRound : boolean)
	if action == 1 then  -- INtermission
		PlayerModule:SetPlayersAlive()
		d.RoundEvent:FireAllClients({
			State = 1,
			Time = Timer
		}, PlayerModule:ClientData())
	elseif action == 67 then  -- WAITING FOR PLAYERS
		d.RoundEvent:FireAllClients({
			State = 67,
			Time = Timer,
			newRound = not firedNewRound 
		}, PlayerModule:ClientData())
	elseif action == 2 then  -- round
		d.RoundEvent:FireAllClients({
			State = 2,
			Time = Timer,
			newRound = not firedNewRound 
		}, PlayerModule:ClientData())
	elseif action == 3 then -- inround
		d.RoundEvent:FireAllClients({
			State = 3,
			Time = Timer,
		}, PlayerModule:ClientData())
	elseif action == 4 then -- eliminate
		d.RoundEvent:FireAllClients({
			State = 4,
			Time = Timer
		}, PlayerModule:ClientData())
	elseif action == 5 then  -- winners
		d.RoundEvent:FireAllClients({
			State = 5, 
			Time = Timer
		}, PlayerModule:ClientData())
		
	elseif action == 6 then  -- Final stand
		d.RoundEvent:FireAllClients({
			State = 6,
			Time = Timer
		}, PlayerModule:ClientData())
	elseif action == 7 then  -- Final stand
		d.RoundEvent:FireAllClients({
			State = 7,
			Time = Timer
		}, PlayerModule:ClientData())
	else
		
	end
end

WaitForPlayers = function()
	sendEvent(67, nil)
	while true do
		local count = 0
		for player, data in pairs(PlayerModule.Players) do
				count += 1
		end

		if count >= 3 then
			break
		end
		sendEvent(67, nil)
		task.wait(1)
		print("Waiting for players...")
		
	end

	return true
end

---------------------------------------------------------------------------------------------------------------------------------------------

return RoundSystem
