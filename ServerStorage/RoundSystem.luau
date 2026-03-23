local RoundSystem = {}

local d = require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Directory"))


-- Folders
local LobbyFolder = workspace:WaitForChild("Lobby")
local MapsFolder = workspace:WaitForChild("Maps") -- Placeholder rn

-- Modules
local PlayerModule = require(d.Modules:WaitForChild("PlayerModule"))
local GameModule = require(d.Modules:WaitForChild("GameModule"))
local DataManager = require(d.ServerScriptService:WaitForChild("Data"):WaitForChild("DataManager"))
local GlobalMusic = require(d.Modules:WaitForChild("GlobalMusic"))

-- Variables & Functions
local LobbySpawn = LobbyFolder:WaitForChild("SpawnLocation")
local gameStartCount = 0

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
	"map3",
	"map4",
	"map5",
	"map6",
}

local defaultRoundTime = 20

local Intermission = 8 --15
local RoundTimer = defaultRoundTime
local WinTimer = 10

RoundSystem.pastAlivePlayers = 0
RoundSystem.AllowTeleport = true -- True in first start of round.
RoundSystem.isRoundMusicActive = false
RoundSystem.WinningPlayers = {}
RoundSystem.CanIntro = true
RoundSystem.CurrentMap = nil


local decrementTime = 5
local finalRound = false

local mapPos = CFrame.new(-89.676, -796.322, 0)

RoundSystem.AFKListener = nil
RoundSystem.AFKState = {}


---------------------------------------------------------------------------------------------------------------------------------------------

function RoundSystem:Init()
	local playerCount = WaitForPlayers()  -- Connect To UI
	
	if playerCount then
		RoundSystem:StartGame()
	else
		warn("Error | CheckPlayerCount")
	end
end

-- Inside your PlayerModule or RoundSystem PlayerRemoving logic
game.Players.PlayerRemoving:Connect(function(player)
	RoundSystem.AFKState[player] = nil
end)


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


local function afkState(alivePlayers, bool : boolean)
	for _, player in ipairs(alivePlayers) do
		d.ToggleAFKEvent:FireClient(player, bool)
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
	
	if #winningPlayers > 1 then
		for _, player in ipairs(winningPlayers) do
			DataManager.AddCoins(player, 50)
			DataManager.SendCurrencies(player)
			d.SFXEvent:FireClient(player, "Coin")
		end
	elseif #winningPlayers == 1 then
		local winner = winningPlayers[1]

		DataManager.AddWins(winner, 1)
		DataManager.AddCoins(winner, 200)
		DataManager.SendCurrencies(winner)
		d.SFXEvent:FireClient(winner, "Coin")	
	end
end


function RoundSystem:PromptGroupJoin()
	gameStartCount += 1

	if gameStartCount % 3 == 0 then
		task.spawn(function()
			for _, player in ipairs(d.PlayerService:GetPlayers()) do
				task.spawn(function()
					local success, isInGroup = pcall(function()
						return player:IsInGroupAsync(228201671) -- Your group ID
					end)

					if success and not isInGroup then
						local promptSuccess, err = pcall(function()
							d.PromptEvent:FireClient(player)
						end)

						if not promptSuccess then
							warn("Failed to prompt group join for " .. player.Name .. ":", err)
						end
					end
				end)
			end
		end)
	end
end

function RoundSystem:StartGame()
	self.CanIntro = true
	self:PromptGroupJoin()
	playMusic("Music", "BGM")
	
	DistributeReward(self.WinningPlayers)
	self.WinningPlayers = {}
	
	clearMap()
	
	for _, player in ipairs(d.PlayerService:GetPlayers()) do
		d.ToggleAFKEvent:FireClient(player, true)
	end
	
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

	-- 1. WAIT FOR NON-AFK PLAYERS BEFORE STARTING THE TIMER
	-- This handles cases where people go AFK during the intermission transition
	while true do
		local activeCount = 0
		for _, player in ipairs(game.Players:GetPlayers()) do
			if not PlayerModule.AFKPlayers[player] then
				activeCount += 1
			end
		end

		if activeCount >= 3 then
			break -- Enough players to proceed
		end

		-- If not enough players, send the "Waiting" state to UI and pause
		sendEvent(67, 0) 
		task.wait(1)
	end

	-- 2. SETUP MAP (Only happens once threshold is met)
	local randomMap = math.random(1, #d.MapTemplateFolder:GetChildren())
	local map = d.MapTemplateFolder:GetChildren()[randomMap]:Clone()
	map.Parent = MapsFolder
	self.CurrentMap = map
	
	local currentPivot = map:GetPivot()
	local targetCFrame = CFrame.new(-89.676, currentPivot.Y, 0)
	map:PivotTo(targetCFrame)

	PlayerModule:RagdollAction("restrict")
	PlayerModule:RagdollAction("delete")
	GameModule.CanAnimate = true

	RoundTimer = defaultRoundTime

	-- 3. INTERMISSION LOOP
	task.spawn(function()
		while Timer > 0 and self.IntermissionActive do
			-- RE-CHECK: If players go AFK DURING the countdown
			local currentActive = 0
			for _, p in ipairs(game.Players:GetPlayers()) do
				if not PlayerModule.AFKPlayers[p] then
					currentActive += 1
				end
			end

			if currentActive < 3 then
				-- If someone went AFK and we dropped below 3, reset/pause intermission
				sendEvent(67, 0)
				task.wait(1)
				-- Optional: Reset Timer = 8 if you want the countdown to restart
			else
				-- Normal Countdown
				sendEvent(1, Timer)
				task.wait(1)
				Timer -= 1
			end
		end
		PlayerModule:SetPlaying()
		self.IntermissionActive = false
		local alivePlayers = PlayerModule:GetAlivePlayers()
		afkState(alivePlayers, false)
		self:StartRound()  -- START ROUND
	end)
end

---------------------------------------- StartRound --------------------------------------------

-- Updated teleportPlayers in RoundSystem
local function teleportPlayers(action, targetPlayers)
	local playersToMove = targetPlayers or PlayerModule:GetAlivePlayers()
	local MiddlePoint = RoundSystem.CurrentMap.MiddlePoint

	if action == 1 then
		-- 1. Reset all spawns to "Available" before starting the player loop
		if RoundSystem.CurrentMap and RoundSystem.CurrentMap:FindFirstChild("Spawns") then
			for _, part in ipairs(RoundSystem.CurrentMap.Spawns:GetChildren()) do
				part:SetAttribute("Occupied", false)
			end
		else
			warn("Teleport Error: CurrentMap or Spawns folder missing!")
			return
		end
	end

	for _, player in ipairs(playersToMove) do
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")

		if hrp then
			hrp.Anchored = true

			if action == 1 then
				-- 2. Find the FIRST available spawn
				local selectedSpawn = nil
				local allSpawns = RoundSystem.CurrentMap.Spawns:GetChildren()

				for _, part in ipairs(allSpawns) do
					if part:GetAttribute("Occupied") == false then
						selectedSpawn = part
						part:SetAttribute("Occupied", true) -- Lock it immediately
						break 
					end
				end

				if not selectedSpawn then
					selectedSpawn = allSpawns[math.random(1, #allSpawns)]
				end

				character:PivotTo(selectedSpawn.CFrame + Vector3.new(0, 3, 0))
				local lookAtPos = Vector3.new(MiddlePoint.Position.X, hrp.Position.Y, MiddlePoint.Position.Z)
				hrp.CFrame = CFrame.lookAt(hrp.Position, lookAtPos)

			elseif action == 2 then
				character:PivotTo(LobbySpawn.CFrame)
			end

			task.delay(0.1, function()
				if hrp then hrp.Anchored = false end
			end)
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
	
	

	if self.AllowTeleport == true then teleportPlayers(1) end
	self.AllowTeleport = false

	if self.isRoundMusicActive == false then print("Playing Music Function") playMusic("Music", "Round") self.isRoundMusicActive = true end -- Play music only when the var is false.

	if self.CanIntro then
		local animTime = 10
		while animTime > 0 and self.RoundActive do
			sendEvent(7, animTime, false)
			task.wait(1)
			animTime -= 1
		end
		self.CanIntro = false
	end
	
	-- Allow Teleport ONCE and turn it off.
	
	-- HANDLE RESET ETC.
	
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
	local AlivePlayers = nil
	
	PlayerModule:RagdollAction("delete")
	
	-- HANDLE RESET ETC.
	task.spawn(function()
		while Timer > 0 and self.NewInRound do
			-- Update UI
			-- Check if how many players survive, then fire round event again.
			local currentAlive = PlayerModule:GetAlivePlayers()
			AlivePlayers = #currentAlive

			-- 2. NEW CHECK: If only 1 player left, stop the timer and skip elimination
			if AlivePlayers <= 1 then
				self.NewInRound = false
				break
			end
			
			sendEvent(3, Timer)

			task.wait(1)
			Timer -= 1
		end
		
		local finalAlive = PlayerModule:GetAlivePlayers()

		if #finalAlive == 1 then
			-- Only one person survived the clicking madness or everyone else reset/left
			print("Lone survivor found in Final Stand!")
			RoundSystem:CelebrateWinners(2)
			return
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
	local winners = PlayerModule:GetAlivePlayers() -- These are the people currently winning
	
	PlayerModule:RagdollAction("delete")

	local function giveBadge()
		for _, player in pairs(winners) do
			local success, hasBadge = pcall(function()
				return d.BadgeService:UserHasBadgeAsync(player.UserId, 3948176480295906)
			end)
			
			if success and not hasBadge then
				-- 2. Award the badge
				local awardSuccess, result = pcall(function()
					return d.BadgeService:AwardBadgeAsync(player.UserId, 3948176480295906)
				end)

				if awardSuccess then
					print("Badge awarded to " .. player.Name)
				end
			end
		end
	end
	
	if roundStatus == 1 then
		winners = PlayerModule:GetAlivePlayers()
		HandleWinnerRewards()
		
	elseif roundStatus == 2 then
		winners = PlayerModule:GetAlivePlayers()
		print(winners)
		HandleWinnerRewards()
	end
	
	playMusic("SFX", "Win")
	playMusic("Music", "Winner")
	GameModule:StopAllCountAnimations()
	
	giveBadge()
	
	
	local confetti = d.Templates:WaitForChild("Particle"):Clone()
	confetti.Parent = workspace.Maps
	
	task.spawn(function()
		while Timer > 0 and self.CelebrateWinnersActive do
			sendEvent(5, Timer, nil, winners)
			task.wait(1)
			Timer -= 1
		end

		self.CelebrateWinnersActive = false
		PlayerModule:ResetPlayerScale()
		
		local validWinners = {}
		for _, player in ipairs(winners) do
			-- Check if player still exists, has a character, and the character is valid
			if player and player.Parent and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
				table.insert(validWinners, player)
			end
		end

		-- Only teleport players who are still valid
		if #validWinners > 0 then
			teleportPlayers(2, validWinners)
		else
			warn("No valid winners to teleport back to lobby")
		end

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
		
		local currentAlive = PlayerModule:GetAlivePlayers()
		AlivePlayers = #currentAlive
		if AlivePlayers <= 1 then
			self.FinalStandActive = false
			d.CountEvent:FireAllClients(nil, nil)
		end
		
		if self.FinalStandActive then
			sendEvent(6, Timer)
			task.wait(5.3)
		end

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
	
	GlobalMusic.ClickPlayback = 0.9	
	local aliveCount = #PlayerModule:GetAlivePlayers()
	
	if aliveCount == 1 then  -- WINNER
		
		RoundSystem:CelebrateWinners(1)  -- Normal Win
		GameModule:ResetGame()
		print("Player Won!")
		
	elseif aliveCount == 2 then  -- LAST STAND
		
		GameModule:ResetRound()
		self:FinalStand()
		
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



sendEvent = function(action : number, Timer : number, firedNewRound : boolean?, _winners)
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
			Time = Timer,
			winners = _winners
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
	-- Initial event to show "Waiting for players" UI
	sendEvent(67, nil)

	while true do
		local playingCount = 0

		-- Iterate through all players in the PlayerModule data
		for player, data in pairs(PlayerModule.Players) do
			-- Check if the player is NOT AFK (isPlaying should be true)
			-- We check the AFKPlayers table specifically as the "source of truth"
			if not PlayerModule.AFKPlayers[player] then
				playingCount += 1
			end
		end

		-- Threshold check (3 players required to start)
		if playingCount >= 3 then
			print("Player threshold met. Starting game with " .. playingCount .. " players.")
			break
		end

		-- Update UI and wait
		sendEvent(67, nil)
		task.wait(1)
		print("Waiting for non-AFK players... Current count: " .. playingCount)
	end

	return true
end

---------------------------------------------------------------------------------------------------------------------------------------------

return RoundSystem
