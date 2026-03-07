local PlayerModule = {}

-- Services
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PlayerService = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GroupService = game:GetService("GroupService")
local PhysicsService = game:GetService("PhysicsService")
local SSS = game:GetService("ServerScriptService")

-- Folders
local EventsFolder = ReplicatedStorage:WaitForChild("Events")
local ClientEventsFolder = ReplicatedStorage:WaitForChild("Events")
local ModulesFolder = ServerStorage:WaitForChild("Modules")
local InteractablesFolder = ModulesFolder:WaitForChild("Interactables")
local RagdollFolder = workspace:WaitForChild("Ragdolls")
local TemplateFolder = ServerStorage:WaitForChild("Templates")

-- EVENTS
local PromptEvent = EventsFolder:WaitForChild("PromptEvent")
local MusicEvent = EventsFolder:WaitForChild("MusicEvent")
local SFXEvent = EventsFolder:WaitForChild("SFXEvent")
local InitEvent = EventsFolder:WaitForChild("InitEvent")
local DailyEvent = EventsFolder:WaitForChild("DailyEvent")
local PlayerUIGift = EventsFolder:WaitForChild("PlayerUIGift")
local DailyEvent = EventsFolder:WaitForChild("DailyEvent")
local TimerEvent = EventsFolder:WaitForChild("TimerEvent")
local EmoteEvent = EventsFolder:WaitForChild("EmoteEvent")

-- Modules
local CaseModule = require(InteractablesFolder:WaitForChild("CaseModule"))
local DailyRewardServer = require(InteractablesFolder:WaitForChild("DailyRewardServer"))
local DataManager = require(SSS:WaitForChild("Data"):WaitForChild("DataManager"))
local RagdollModule = require(ModulesFolder:WaitForChild("Ragdoll"))
local InventoryHandler = require(ModulesFolder:WaitForChild("InventoryHandler"))
local ParticleHandler = require(ModulesFolder:WaitForChild("ParticleHandler"))

-- Add DataModule here next time.

-- Variables & Functions
PlayerModule["Players"] = {}
PlayerModule["Characters"] = {}

local AddRemovePlayer -- Handle Player Join/Leave
local InitializedPlayers = {}


-- Players Table has this following:
-- Alive, timeClick, Counted, isPlaying

---------------------------------------------------------------------------------------------------------------------------------------------

function PlayerModule:Init()

	PlayerService.PlayerAdded:Connect(function(player)  -- Connect Function Once
		print("PlayerAdded fired:", player.Name)
		PlayerModule:HandlePlayerJoin(player)

		task.spawn(function()
			InventoryHandler:Init(player)
		end)

		-- Player Spawn
		player.CharacterAdded:Connect(function(playerCharacter)
			-- Handle Character Here.
			MusicEvent:FireClient(player, "BGM")
			playerCharacter:ScaleTo(1)
			ParticleHandler:InitParticle(playerCharacter, "Explosion") -- Change the 2nd parameter to player's actual particle name

			local hum = playerCharacter:FindFirstChild("Humanoid")
			local hrp = playerCharacter:WaitForChild("HumanoidRootPart")
			hum.BreakJointsOnDeath = false

			-- Player Death
			hum.Died:Connect(function()
				
			ParticleHandler:Show(playerCharacter, "Explosion")				

				if self.Players[player] then
					self.Players[player].Alive = false
					self.Players[player].isPlaying = false

					if playerCharacter:GetAttribute("Ragdolled") == false then
						RagdollModule:SetupRagdoll(player,playerCharacter, hum)
					end
				end
			end)

			PlayerModule.HandlePlayerFavorite(player)
			local VOID_Y = workspace.FallenPartsDestroyHeight or -500

			playerCharacter:SetAttribute("Ragdolled", false)  -- SET ONLY TO FALSE WHEN ROUND IS ACTIVE!

			if not playerCharacter:FindFirstChild("_NoPlayerCollisionApplied") then
				PlayerModule:ApplyNoPlayerCollision(playerCharacter)

				-- Mark that collision was applied
				local tag = Instance.new("BoolValue")
				tag.Name = "_NoPlayerCollisionApplied"
				tag.Value = true
				tag.Parent = playerCharacter
			end

			table.insert(self.Characters, playerCharacter)
			PlayerModule:HandleCharacterLoad(playerCharacter)

			task.spawn(function()
				while playerCharacter.Parent and hum.Health > 0 do
					local HRP = playerCharacter:FindFirstChild("HumanoidRootPart")
					task.wait(0.2)
					if HRP.Position.Y < VOID_Y then
						hum.BreakJointsOnDeath = true
					else
						break
					end
				end
			end)

		end)

	end)


	InitEvent.OnServerEvent:Connect(function(player)
		DailyRewardServer:Init(player)
		CaseModule:HandleChestUI(player)
		DataManager.SendCurrencies(player)

		if InitializedPlayers[player] then return end
		InitializedPlayers[player] = true

	end)

	-- Handle players already in game
	for _, player in ipairs(PlayerService:GetPlayers()) do
		self:HandlePlayerJoin(player)
		if player.Character then
			self:HandleCharacterLoad(player, player.Character)
		end
	end

end

function PlayerModule.PromptGroupJoin()
	local success, result = pcall(function()
		return GroupService:GetGroupInfoAsync(35096019)
	end)

	if success  then

	end

end

---------------------------------------------------------------------------------------------------------------------------------------------

function PlayerModule:HandlePlayerJoin(player : Player)
	print(player, "Joined")
	AddRemovePlayer(player, "add", self.Players)
end

function PlayerModule:HandlePlayerLeave(player : Player)
	print(player, "Left The Game")

	AddRemovePlayer(player, "remove", self.Players)
	-- Save Data
end

function PlayerModule:HandleCharacterLoad(character : Model)

	-- LOAD SERVER SCRIPTS AGAIN! MAKE SURE TO CHECK\n IF PLAYER IS ALIVE OR NOT OR ROUNDENDED
	print("CharacterLoaded")
end


-- Add player
function PlayerModule:AddPlayer(player)
	self.Players[player] = {
		Alive = true,
		timeClick = nil,
		Counted = false,
		isPlaying = false
	}
end

function PlayerModule:ClientData()
	local clientData = {}

	for player, data in pairs(self.Players) do
		local id = player.UserId
		clientData[tostring(id)] = {
			Alive = data.Alive,
			timeClick = data.timeClick,
			Counted = data.Counted,
			isPlaying = data.isPlaying
		}
	end

	return clientData
end


function PlayerModule:RagdollAction(Action : string)

	if Action == "allow" then
		local alivePlayers = self:GetAlivePlayers()

		for _, player in ipairs(alivePlayers) do
			if player.Character then
				player.Character:SetAttribute("canClone", true)
			end
		end
	elseif Action == "restrict" then
		for player, data in ipairs(self.Players) do
			if player.Character then
				player.Character:SetAttribute("canClone", false)
			end
		end
	elseif Action == "delete" then
		for _, ragdolls in pairs(RagdollFolder:GetChildren()) do
			print("Destroying, ", ragdolls)
			ragdolls:Destroy()
		end
	end
end

function PlayerModule:ApplyNoPlayerCollision(character)
	local GROUP_NAME = "PlayerNoCollide"

	-- Create group safely
	pcall(function()
		PhysicsService:RegisterCollisionGroup(GROUP_NAME)
	end)

	-- Disable collisions within the group
	PhysicsService:CollisionGroupSetCollidable(GROUP_NAME, GROUP_NAME, false)

	-- Function to set group on parts
	local function setPart(part)
		if part:IsA("BasePart") then
			part.CollisionGroup = GROUP_NAME
		end
	end

	-- Apply to existing parts
	for _, descendant in ipairs(character:GetDescendants()) do
		setPart(descendant)
	end

	-- Apply to future parts
	character.DescendantAdded:Connect(setPart)
end


-- Remove player
function PlayerModule:RemovePlayer(player)
	self.Players[player] = nil
end

-- Get alive players
function PlayerModule:GetAlivePlayers()
	local alive = {}
	for player, data in pairs(self.Players) do
		if data.Alive and data.isPlaying then
			table.insert(alive, player)
		end
	end
	return alive
end



PlayerModule.Checked = false
function PlayerModule:checkCountedPlayers() -- Checks if everyone playing, have counted
	local Counted = {}
	for player, data in pairs(self.Players) do
		if data.Counted and data.Alive and data.isPlaying then
			table.insert(Counted, player)
		end
	end

	if #Counted == #self:GetAlivePlayers() then
		if not self.Checked then
			self.Checked = true
			return true
		else
			return false
		end
	end

end

function PlayerModule:ResetPlayerScale()
	for player, data in pairs(self.Players) do
		if player.Character then
			player.Character:ScaleTo(1)
		end
	end
end

function PlayerModule:EliminatePlayers()
	print(self.Players)
	for player, data in pairs(self.Players) do
		if not data.Alive and data.isPlaying and data.Counted then  -- Doesn't kill dead players

			data.isPlaying = false
			self:KillPlayer(player)
		end
	end
end

function PlayerModule:EmoteListener()
	local conn

	if conn then
		conn:Disconnect()
	end

	conn = EmoteEvent.onServerEvent:Connect(function(player, EmoteID, Animator, animInstance)

		anim.AnimationId = "rbxassetid://" .. EmoteID
		local loadedAnimation = Animator:LoadAnimation(animInstance)
		loadedAnimation.Priority = Enum.AnimationPriority.Action
		loadedAnimation:Play()
		loadedAnimation.Looped = true

	end)
end

function PlayerModule:SetPlayersAlive()
	for player, data in pairs(self.Players) do
		if data then
			data.Alive = true
			data.Counted = false
			data.isPlaying = true
		end
	end
end

function PlayerModule:KillPlayer(player)
	if not player or not player.Character then return end

	local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	humanoid:ChangeState(Enum.HumanoidStateType.Dead)

	humanoid.Health = 0
	humanoid:TakeDamage(humanoid.MaxHealth + 999) -- Overkill to ensure 0

	-- If bugged, kill them manually.
	if humanoid.Health > 0 then
		player.Character:BreakJoints()
	end
end

function PlayerModule:SetPlaying()
	for player, data in pairs(self.Players) do
		data.isPlaying = true
	end
end

function PlayerModule.HandlePlayerFavorite(player : Player)
	if DataManager.getPlayerFavorite(player) == false then
		PromptEvent:FireClient(player)
	end

	PromptEvent.OnServerEvent:Connect(function(player)
		DataManager.setPlayerFavorite(player)
	end)
end

---------------------------------------------------------------------------------------------------------------------------------------------

-- PlayersTable - PlayerModule["Players"]
AddRemovePlayer = function(player : Player, action : string, PlayersTable)  -- Handle Adding / Removing Of Player
	if action == "add" then
		if not PlayersTable[player] then
			PlayersTable[player] = {
				Alive = true,
				timeClick = nil,
				Counted = false,
				isPlaying = false
			}
		end
	elseif action == "remove" then
		PlayersTable[player] = nil
	else
		warn("Invalid Action | AddRemovePlayer")
	end

end

---------------------------------------------------------------------------------------------------------------------------------------------


return PlayerModule
