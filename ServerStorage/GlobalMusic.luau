local GlobalMusic = {}
local d = require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Directory"))
local initialized = false
local isLoaded = false
local conn = {}

local EmoteConfigs = {
	["LowCortisol"] = {start = 31, stop = 47.5, fade = 1.5},
	["67"] = {start = 1.3, stop = 3, fade = 0.5},
	["Default"] = {start = 0, stop = 15, fade = 1.2} 
}

local nonLoopedEmotes = {"Yay"}
local loopedCount = {"Menacing"}

-- Track active loops per player
local activeLoops = {}
GlobalMusic.ClickPlayback = 0.9
GlobalMusic.FinalStandPlayback = {} -- Track playback speed per player for Final Stand

------------------------------------------------------------------------------------------------------------------


local function stopPlayerMusic(hrp)
	-- Kill all current sounds
	for _, child in ipairs(hrp:GetChildren()) do
		if child.Name == "EmoteSound" then
			child:Destroy()
		end
	end

	-- Stop the loop for this player
	local player = game.Players:GetPlayerFromCharacter(hrp.Parent)
	if player then
		activeLoops[player] = false
	end
end

local function setupStateDetection(player, hrp)
	local humanoid = hrp.Parent:FindFirstChild("Humanoid")
	if not humanoid then return end

	-- Disconnect old connections for this player
	if conn[player] then
		for _, connection in pairs(conn[player]) do
			connection:Disconnect()
		end
	end

	conn[player] = {}

	-- Stop music when state changes to non-idle states
	table.insert(conn[player], humanoid.StateChanged:Connect(function(oldState, newState)
		-- Stop music on jump, fall, fling, etc
		if newState == Enum.HumanoidStateType.Jumping 
			or newState == Enum.HumanoidStateType.Freefall
			or newState == Enum.HumanoidStateType.Running
			or newState == Enum.HumanoidStateType.Flying
			or newState == Enum.HumanoidStateType.Ragdoll then
			stopPlayerMusic(hrp)
		end
	end))

	-- Also stop if player moves significantly
	local lastPosition = hrp.Position
	table.insert(conn[player], hrp:GetPropertyChangedSignal("Position"):Connect(function()
		local currentPosition = hrp.Position
		local distance = (currentPosition - lastPosition).Magnitude

		-- If moved more than 2 studs, stop music
		if distance > 2 then
			stopPlayerMusic(hrp)
		end

		lastPosition = currentPosition
	end))
end

local function playLoopSection(soundTemplate, parent, startTime, endTime, fadeTime, player)
	local function createAndFade()
		-- Check if we should stop looping
		if not parent or not parent.Parent or not activeLoops[player] then 
			return 
		end

		local sound = soundTemplate:Clone()
		sound.Name = "EmoteSound"
		sound.Parent = parent
		sound.TimePosition = startTime
		
		local emoteSoundGroup = game:GetService("SoundService"):FindFirstChild("EmoteSounds")
		if emoteSoundGroup then
			sound.SoundGroup = emoteSoundGroup
		end
		
		local shouldLoop = not table.find(nonLoopedEmotes, soundTemplate.Name)
		if shouldLoop then
			sound.Volume = 0
		else
			sound.Volume = 1
		end
		sound.RollOffMinDistance = 10
		sound.RollOffMaxDistance = 100
		sound.RollOffMode = Enum.RollOffMode.Linear
		
		print("Playing Sound: " .. soundTemplate.Name)
		sound:Play()

		d.TweenService:Create(sound, TweenInfo.new(fadeTime), {Volume = 1}):Play()

		task.delay(endTime - startTime - fadeTime, function()
			
			
			-- Check if still active before looping
			if sound and sound.Parent == parent and activeLoops[player] and shouldLoop then
				createAndFade()
				local outTween = d.TweenService:Create(sound, TweenInfo.new(fadeTime), {Volume = 0})
				outTween:Play()
				outTween.Completed:Wait()
				sound:Destroy()
				
			else
				task.wait(fadeTime) 
				if sound then sound:Destroy() end
				activeLoops[player] = false
			end
		end)
	end
	createAndFade()
end

------------------------------------------------------------------------------------------------------------------

function GlobalMusic:ResetSound()
	self.ClickPlayback = 0
end


function GlobalMusic:Init()

	if initialized then return end
	initialized = true

	task.spawn(function()
		-- Collect all sound objects from folders
		local soundsToPreload = {}

		-- Get all sounds from MusicFolder
		for _, child in ipairs(d.MusicFolder:GetDescendants()) do
			if child:IsA("Sound") then
				table.insert(soundsToPreload, child)
			end
		end

		-- Get all sounds from SFXFolder
		for _, child in ipairs(d.SFXFolder:GetDescendants()) do
			if child:IsA("Sound") then
				table.insert(soundsToPreload, child)
			end
		end

		-- Preload all collected sounds
		if #soundsToPreload > 0 then
			d.ContentProvider:PreloadAsync(soundsToPreload)
		end

		isLoaded = true
		print("Preloaded", #soundsToPreload, "sound objects")
	end)



	-- Actions : play & stop
	d.MusicEvent.OnServerEvent:Connect(function(player, musicType : string, action)
		print(musicType)
		repeat task.wait() until isLoaded == true

		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not hrp then return end

		if action == "play" then
			GlobalMusic:PlayMusic(hrp, musicType, player)
		elseif action == "stop" then
			GlobalMusic:PlayMusic(hrp, "STOP", player)
		end
	end)
	
	d.MuteEmotes.OnServerEvent:Connect(function(Action : boolean)
		
	end)
	

	-- Clean up when player leaves
	game.Players.PlayerRemoving:Connect(function(player)
		activeLoops[player] = false
		if conn[player] then
			for _, connection in pairs(conn[player]) do
				connection:Disconnect()
			end
			conn[player] = nil
		end
	end)
end


local function AddParticles(player : Player, Name, Action : boolean)
	local _Name = tostring(Name)
	local PF = d.ReplicatedStorage:WaitForChild("Particles")
	
	local PT = {["Menacing"] = PF:FindFirstChild("Menacing")}
	local Head = player.Character:WaitForChild("Head")
	
	if not PT[_Name] and not Action then 
		for _, obj in pairs(Head:GetChildren()) do
			if obj:IsA("ParticleEmitter") then
				obj:Destroy()
				break
			end
		end
		return
	end
	
	if Action then
		for key, obj in pairs(PT) do
			if key == _Name then
				local C = obj:Clone()
				C.Parent = Head
				C.Enabled = true
				break
			end
		end
	else
		for _, obj in pairs(Head:GetChildren()) do
			if obj:IsA("ParticleEmitter") then
				obj:Destroy()
				break
			end
		end
	end
end


function GlobalMusic:PlayMusic(hrp, musicType : string, player)
	if not hrp or not hrp.Parent then 
		warn("GlobalMusic: HRP missing for " .. player.Name)
		return 
	end
	
	local EmoteMusicFolder = d.MusicFolder:WaitForChild("EmoteMusic")

	-- Stop any existing music
	stopPlayerMusic(hrp)

	if musicType == "STOP" then AddParticles(player, musicType, false) return end

	-- Find the sound
	local soundTemplate = EmoteMusicFolder:FindFirstChild(musicType)
	if soundTemplate and soundTemplate:IsA("Sound") then
		-- Mark as active
		activeLoops[player] = true


		
		d.EmoteSound:FireAllClients(hrp, soundTemplate)
		AddParticles(player, musicType, true)
	
		print("Attempting to play " .. musicType)

		-- Setup detection
		if not table.find(loopedCount, musicType) then
			setupStateDetection(player, hrp)
		end

		-- Get config
		local config = EmoteConfigs[musicType] or EmoteConfigs["Default"]
		playLoopSection(soundTemplate, hrp, config.start, config.stop, config.fade, player)
	else
		warn("No sound found for:", musicType)
	end
end

function GlobalMusic:PlayDeathSFX(hrp, musicType : string, player)
	local DeathMusicFolder = d.SFXFolder:WaitForChild("DeathFX")

	-- Stop any existing music
	stopPlayerMusic(hrp)

	if musicType == "STOP" then AddParticles(player, musicType, false) return end

	-- Find the sound
	local soundTemplate = DeathMusicFolder:FindFirstChild(musicType)
	if soundTemplate and soundTemplate:IsA("Sound") then

		-- Setup detection
		local sound = soundTemplate:Clone()
		sound.Name = "DeathSound"
		sound.Parent = hrp
		sound.Volume = 1
		sound.RollOffMinDistance = 20
		sound.RollOffMaxDistance = 100
		sound.RollOffMode = Enum.RollOffMode.Linear
		sound:Play()

		-- Auto cleanup after sound finishes
		task.delay(sound.TimeLength + 0.5, function()
			if sound and sound.Parent then
				sound:Destroy()
			end
		end)

		print("Playing Death SFX")
	else
		warn("No sound found for:", musicType)
	end
end

function GlobalMusic:PlayClick(p : Player)
	if not p or not p.Character then return end
	
	print("Click")

	local hrp = p.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local ClickSound = d.SFXFolder:WaitForChild("GameClick")
	self.ClickPlayback += 0.1

	-- Clone the sound
	local sound = ClickSound:Clone()
	sound.Name = "ClickSound_" .. tick() -- Unique name to prevent conflicts
	sound.Parent = hrp
	sound.Volume = 1.5
	sound.RollOffMinDistance = 25
	sound.RollOffMaxDistance = 100
	sound.PlaybackSpeed = 0.9 + self.ClickPlayback
	sound.Looped = false

	-- Play immediately
	sound:Play()

	-- Auto cleanup after sound finishes
	task.delay(sound.TimeLength / sound.PlaybackSpeed + 0.1, function()
		if sound and sound.Parent then
			sound:Destroy()
		end
	end)
end

function GlobalMusic:PlayElimClick(p : Player)
	if not p or not p.Character then return end

	local hrp = p.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local ClickSound = d.SFXFolder:WaitForChild("Elim_Click")

	-- Clone the sound
	local sound = ClickSound:Clone()
	sound.Name = "ElimSound_" .. tick() -- Unique name to prevent conflicts
	sound.Parent = hrp
	sound.Volume = 1.4
	sound.RollOffMinDistance = 25
	sound.RollOffMaxDistance = 100
	sound.PlaybackSpeed = 1
	sound.Looped = false

	-- Play immediately
	sound:Play()

	-- Auto cleanup after sound finishes
	task.delay(sound.TimeLength + 0.1, function()
		if sound and sound.Parent then
			sound:Destroy()
		end
	end)
end

function GlobalMusic:PlayFinalStandClick(p : Player)
	if not p or not p.Character then return end

	local hrp = p.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Initialize playback for this player if not exists
	if not self.FinalStandPlayback[p] then
		self.FinalStandPlayback[p] = 1
	end
	
	self.FinalStandPlayback[p] += 0.1
	
	local ClickSound = d.SFXFolder:WaitForChild("GameClick")
	
	print("FinalStandClick")

	-- Clone the sound
	local sound = ClickSound:Clone()
	sound.Name = "FinalStandClick_" .. tick() -- Unique name to prevent conflicts
	sound.Parent = hrp
	sound.Volume = 1.4
	sound.RollOffMinDistance = 25
	sound.RollOffMaxDistance = 100
	
	if self.FinalStandPlayback[p] <= 2 then
		sound.PlaybackSpeed = self.FinalStandPlayback[p]
	else sound.PlaybackSpeed = 2 end
	
	sound.Looped = false

	-- Play immediately
	sound:Play()

	-- Auto cleanup after sound finishes
	task.delay(sound.TimeLength / sound.PlaybackSpeed + 0.1, function()
		if sound and sound.Parent then
			sound:Destroy()
		end
	end)
end

function GlobalMusic:ResetFinalStandPlayback(p : Player)
	if p then
		self.FinalStandPlayback[p] = 1
	end
end


return GlobalMusic