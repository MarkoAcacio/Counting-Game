local PlayerModule = {}

-- Services
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PlayerService = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GroupService = game:GetService("GroupService")
local PhysicsService = game:GetService("PhysicsService")
local SSS = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")

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
local GlobalMusic = require(ModulesFolder:WaitForChild("GlobalMusic"))

-- Variables & Functions
PlayerModule["Players"] = {}
PlayerModule["Characters"] = {}

local AddRemovePlayer
local InitializedPlayers = {}
PlayerModule.AFKPlayers = {}

---------------------------------------------------------------------------------------------------------------------------------------------

function PlayerModule:Init()

	local d = require(ServerStorage:WaitForChild("Modules"):WaitForChild("Directory"))
	local toggleRemote = d.ToggleAFK

	toggleRemote.OnServerInvoke = function(player)
		if self.Players[player].isPlaying == false then
			return self:ToggleAFK(player)
		else
			warn("Can't AFK in-game")
		end
	end

	PlayerService.PlayerRemoving:Connect(function(player)
		self.AFKPlayers[player] = nil
	end)

	PlayerService.PlayerAdded:Connect(function(player)
		print("PlayerAdded fired:", player.Name)
		PlayerModule:HandlePlayerJoin(player)

		task.spawn(function()
			InventoryHandler:Init(player)
		end)

		player.CharacterAdded:Connect(function(playerCharacter)
			-- CRITICAL: Wait for character to FULLY load before touching anything
			local hum = playerCharacter:WaitForChild("Humanoid")
			local hrp = playerCharacter:WaitForChild("HumanoidRootPart")

			-- Wait for Roblox's spawn animation to finish
			task.wait(0.3)

			-- Now safe to modify character
			local profile = DataManager.WaitForProfile(player)
			if profile then
				player:SetAttribute("EquippedDeath", profile.Data.DeathAnim)
			end

			MusicEvent:FireClient(player, "BGM")
			ParticleHandler:InitParticle(playerCharacter, "Explosion")
			InventoryHandler:IsVIP(player)

			hum.BreakJointsOnDeath = false

			-- Death handling
			hum.Died:Connect(function()
				if playerCharacter:GetAttribute("HasDied") then return end
				playerCharacter:SetAttribute("HasDied", true)

				-- Safety check - ensure character is still in workspace
				if not playerCharacter.Parent or playerCharacter.Parent ~= workspace then
					return
				end

				local inventory = DataManager.GetPlayerInventory(player)
				local equippedDeathName = player:GetAttribute("EquippedDeath")
				local deathData = inventory and inventory.Deaths and inventory.Deaths[equippedDeathName]

				if deathData and deathData.ID then
					d.DeathEvent:FireAllClients(playerCharacter, deathData.ID)
					self:HandleDeathMovement(playerCharacter, equippedDeathName)

					local finished = false
					local connection
					connection = d.DeathEvent.OnServerEvent:Connect(function(firingPlayer)
						if firingPlayer == player then
							finished = true
							connection:Disconnect()
						end
					end)

					local start = tick()
					repeat task.wait() until finished or (tick() - start > 5)
					if connection then connection:Disconnect() end
				else
					ParticleHandler:Show(playerCharacter, "Explosion")
					GlobalMusic:PlayDeathSFX(hrp, "Explode", player)
				end

				if self.Players[player] then
					self.Players[player].Alive = false
					self.Players[player].isPlaying = false

					-- Only ragdoll if character is still in workspace
					if playerCharacter and playerCharacter.Parent == workspace then
						RagdollModule:SetupRagdoll(player, playerCharacter, hum)
					end
				end
			end)

			PlayerModule.HandlePlayerFavorite(player)
			playerCharacter:SetAttribute("Ragdolled", false)

			if not playerCharacter:FindFirstChild("_NoPlayerCollisionApplied") then
				PlayerModule:ApplyNoPlayerCollision(playerCharacter)

				local tag = Instance.new("BoolValue")
				tag.Name = "_NoPlayerCollisionApplied"
				tag.Value = true
				tag.Parent = playerCharacter
			end

			table.insert(self.Characters, playerCharacter)
			PlayerModule:HandleCharacterLoad(playerCharacter)

		end)

	end)

	InitEvent.OnServerEvent:Connect(function(player)
		DailyRewardServer:Init(player)
		CaseModule:HandleChestUI(player)
		DataManager.SendCurrencies(player)

		if InitializedPlayers[player] then return end
		InitializedPlayers[player] = true
	end)

	for _, player in ipairs(PlayerService:GetPlayers()) do
		self:HandlePlayerJoin(player)
		if player.Character then
			self:HandleCharacterLoad(player, player.Character)
		end
	end

end

function PlayerModule:HandleDeathMovement(character, deathName)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	if deathName == "Elevate" then
		local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local goal = {CFrame = hrp.CFrame * CFrame.new(0, hrp.Size.Y + 3 , 0)}
		local tween = TweenService:Create(hrp, tweenInfo, goal)
		tween:Play()

	elseif deathName == "Sink" then
		local tweenInfo = TweenInfo.new(1.5, Enum.EasingStyle.Linear)
		local goal = {CFrame = hrp.CFrame * CFrame.new(0, -5, 0)}
		local tween = TweenService:Create(hrp, tweenInfo, goal)
		tween:Play()
	end
end

function PlayerModule.PromptGroupJoin()
	local success, result = pcall(function()
		return GroupService:GetGroupInfoAsync(35096019)
	end)
end

---------------------------------------------------------------------------------------------------------------------------------------------

function PlayerModule:HandlePlayerJoin(player : Player)
	print(player, "Joined")
	AddRemovePlayer(player, "add", self.Players)
end

function PlayerModule:HandlePlayerLeave(player : Player)
	print(player, "Left The Game")
	AddRemovePlayer(player, "remove", self.Players)
end

function PlayerModule:HandleCharacterLoad(character : Model)
	print("CharacterLoaded")
end

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

	pcall(function()
		PhysicsService:RegisterCollisionGroup(GROUP_NAME)
	end)

	PhysicsService:CollisionGroupSetCollidable(GROUP_NAME, GROUP_NAME, false)

	local function setPart(part)
		if part:IsA("BasePart") then
			part.CollisionGroup = GROUP_NAME
		end
	end

	for _, descendant in ipairs(character:GetDescendants()) do
		setPart(descendant)
	end

	character.DescendantAdded:Connect(setPart)
end

function PlayerModule:RemovePlayer(player)
	self.Players[player] = nil
end

function PlayerModule:GetAlivePlayers()
	local alive = {}
	for player, data in pairs(self.Players) do
		if data.Alive and data.isPlaying then
			table.insert(alive, player)
		end
	end
	return alive
end

function PlayerModule:ToggleAFK(player)
	self.AFKPlayers[player] = not self.AFKPlayers[player]
	local isAFK = self.AFKPlayers[player]

	local data = self.Players[player]
	if data then
		if isAFK then
			data.isPlaying = false
			data.Alive = false
		else
			data.isPlaying = false
			data.Alive = false
		end
	end

	print(player.Name .. " AFK: " .. tostring(isAFK))
	return isAFK
end

PlayerModule.Checked = false
function PlayerModule:checkCountedPlayers()
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
		if not data.Alive and data.isPlaying and data.Counted then
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
		local isAFK = self.AFKPlayers[player]

		if data and not isAFK then
			data.Alive = true
			data.Counted = false
			data.isPlaying = true
		else
			data.Alive = false
			data.isPlaying = false
		end
	end
end

function PlayerModule:KillPlayer(player)
	if not player or not player.Character then return end

	local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	humanoid:ChangeState(Enum.HumanoidStateType.Dead)
	humanoid.Health = 0
	humanoid:TakeDamage(humanoid.MaxHealth + 999)

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

AddRemovePlayer = function(player : Player, action : string, PlayersTable)
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