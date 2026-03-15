local GlobalMusic = {}
local d = require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Directory"))
local initialized = false
local isLoaded = false
local conn = {}

local EmoteConfigs = {
	["LowCortisol"] = {start = 31, stop = 47.5, fade = 1.5},
	["67"] = {start = 0., stop = 2, fade = 0.5},
	["Default"] = {start = 0, stop = 15, fade = 1.2} 
}

-- Track active loops per player
local activeLoops = {}

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
		sound.Volume = 0
		sound.RollOffMaxDistance = 100
		sound.RollOffMode = Enum.RollOffMode.Linear
		sound:Play()

		d.TweenService:Create(sound, TweenInfo.new(fadeTime), {Volume = 0.5}):Play()

		task.delay(endTime - startTime - fadeTime, function()
			-- Check if still active before looping
			if sound and sound.Parent == parent and activeLoops[player] then
				createAndFade()
				local outTween = d.TweenService:Create(sound, TweenInfo.new(fadeTime), {Volume = 0})
				outTween:Play()
				outTween.Completed:Wait()
				sound:Destroy()
			end
		end)
	end
	createAndFade()
end

------------------------------------------------------------------------------------------------------------------

function GlobalMusic:Init()

	if initialized then return end
	initialized = true

	task.spawn(function()
		d.ContentProvider:PreloadAsync({d.MusicFolder, d.SFXFolder})
		isLoaded = true
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

function GlobalMusic:PlayMusic(hrp, musicType : string, player)
	local EmoteMusicFolder = d.MusicFolder:WaitForChild("EmoteMusic")

	-- Stop any existing music
	stopPlayerMusic(hrp)

	if musicType == "STOP" then return end

	-- Find the sound
	local soundTemplate = EmoteMusicFolder:FindFirstChild(musicType)
	if soundTemplate and soundTemplate:IsA("Sound") then
		-- Mark as active
		activeLoops[player] = true
		
		
		
		d.EmoteSound:FireAllClients(hrp, soundTemplate)
		
		

		-- Setup detection
		setupStateDetection(player, hrp)

		-- Get config
		local config = EmoteConfigs[musicType] or EmoteConfigs["Default"]
		playLoopSection(soundTemplate, hrp, config.start, config.stop, config.fade, player)
		print("Playing Emote:", musicType, "with custom timings")
	else
		warn("No sound found for:", musicType)
	end
end

function GlobalMusic:PlayDeathSFX(hrp, musicType : string, player)
	local DeathMusicFolder = d.SFXFolder:WaitForChild("DeathFX")

	-- Stop any existing music
	stopPlayerMusic(hrp)

	if musicType == "STOP" then return end

	-- Find the sound
	local soundTemplate = DeathMusicFolder:FindFirstChild(musicType)
	if soundTemplate and soundTemplate:IsA("Sound") then

		-- Setup detection
		local sound = soundTemplate:Clone()
		sound.Name = "DeathSound"
		sound.Parent = hrp
		sound.Volume = 1
		sound.RollOffMaxDistance = 40
		sound.RollOffMode = Enum.RollOffMode.Linear
		sound:Play()
		
		print("Playing Death SFX")
	else
		warn("No sound found for:", musicType)
	end
end


return GlobalMusic