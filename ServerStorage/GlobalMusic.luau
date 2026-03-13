local GlobalMusic = {}

local d = require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Directory"))

local initialized = false
local isLoaded = false

local conn = {}

local EmoteConfigs = {
	["LowCortisol"] = {start = 31, stop = 47.5, fade = 1.5},
	["67"] = {start = 0., stop = 2, fade = 0.5},
	-- ["Default"] is used if the emote name isn't in this list
	["Default"] = {start = 0, stop = 15, fade = 1.2} 
}

------------------------------------------------------------------------------------------------------------------
local function playLoopSection(soundTemplate, parent, startTime, endTime, fadeTime)
	local function createAndFade()
		-- We check if the parent still exists to stop the recursion loop
		if not parent or not parent.Parent then return end 

		local sound = soundTemplate:Clone()
		sound.Name = "EmoteSound"
		sound.Parent = parent
		sound.TimePosition = startTime

		sound.Volume = 0
		sound.RollOffMaxDistance = 30  -- Completely silent at 60 studs
		sound.RollOffMode = Enum.RollOffMode.Linear -- Predictable fading
		sound:Play()
		d.TweenService:Create(sound, TweenInfo.new(fadeTime), {Volume = 0.5}):Play()

		task.delay(endTime - startTime - fadeTime, function()
			-- Check if the sound is still the 'active' one before looping
			if sound and sound.Parent == parent then
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

-- GET MUSIC TYPE
function GlobalMusic:Init()

	print("init global music")
	
	if initialized then return end
	initialized = true

	task.spawn(function()
		d.ContentProvider:PreloadAsync({d.MusicFolder, d.SFXFolder})
		isLoaded = true
	end)

	d.MusicEvent.OnServerEvent:Connect(function(player, musicType : string, action)
		print(musicType)
		repeat task.wait() until isLoaded == true
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		
		if action == "play" then
			GlobalMusic:PlayMusic(hrp, musicType)
		elseif action == "stop" then
			GlobalMusic:PlayMusic(hrp, "STOP")
		end
	end)

end



function GlobalMusic:PlayMusic(hrp, musicType : string)
	local EmoteMusicFolder = d.MusicFolder:WaitForChild("EmoteMusic")

	-- 1. Kill all current sounds
	for _, child in ipairs(hrp:GetChildren()) do
		if child.Name == "EmoteSound" then
			child:Destroy()
		end
	end

	if musicType == "STOP" then return end

	-- 2. Find the sound
	local soundTemplate = EmoteMusicFolder:FindFirstChild(musicType)

	if soundTemplate and soundTemplate:IsA("Sound") then
		-- 3. Get specs from config, or use "Default" if not specified
		local config = EmoteConfigs[musicType] or EmoteConfigs["Default"]

		playLoopSection(soundTemplate, hrp, config.start, config.stop, config.fade)
		print("Playing Emote:", musicType, "with custom timings")
	else
		warn("No sound found for:", musicType)
	end
end



return GlobalMusic
