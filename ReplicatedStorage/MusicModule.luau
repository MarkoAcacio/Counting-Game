local MusicModule = {}

local d = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Directory"))

local groupID = 228201671
local initialized = false
local isLoaded = false

local conn = {}
local music
local sfx

local isMuted = false

local activeEmotes = {}

------------------------------------------------------------------------------------------------------------------

local function fadeIn(sound, duration, volumeGoal)
	if not sound then return end

	sound.Volume = 0
	sound:Play()

	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
	local goal = {Volume = volumeGoal}

	local tween = d.TweenService:Create(sound, tweenInfo, goal)
	tween:Play()
end

local function fadeOut(sound, duration)
	if not sound then return end

	local originalVolume = sound.Volume

	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
	local goal = {Volume = 0}

	local tween = d.TweenService:Create(sound, tweenInfo, goal)
	tween:Play()

	tween.Completed:Wait()
	sound:Stop()
	sound.Volume = originalVolume -- reset for next play
end

------------------------------------------------------------------------------------------------------------------

-- GET MUSIC TYPE
function MusicModule:Init()


	if initialized then return end
	initialized = true

	task.spawn(function()
		d.ContentProvider:PreloadAsync({d.MusicFolder, d.SFXFolder})
		isLoaded = true
	end)
	
	d.MusicEvent.OnClientEvent:Connect(function(musicType : string)
		repeat task.wait() until isLoaded == true
		MusicModule:PlayMusic(musicType)
	end)

	d.SFXEvent.OnClientEvent:Connect(function(sfxType : string)
		MusicModule:PlaySFX(sfxType)
	end)
	
	if d.localPlayer.Character then
		local humanoid = d.Humanoid
		if humanoid then
			humanoid.Died:Connect(function()
				if music then music:Stop() end
				if sfx then sfx:Stop() end
			end)
		end
	end
	
	
end



function MusicModule:ToggleMute()
	isMuted = not isMuted
	
	if music then
		-- If we just muted, fade out current music to 0
		-- If we unmuted, fade back to the standard BGM volume (0.2 in your code)
		local targetVol = isMuted and 0 or 0.2
		d.TweenService:Create(music, TweenInfo.new(0.5), {Volume = targetVol}):Play()
	end

	return isMuted
end


function MusicModule:PlayMusic(musicType : string)
	
	
	
	if musicType == "BGM" then
		if music then fadeOut(music, 1) end
		music = d.MusicFolder:WaitForChild("BGM")
		music.Looped = true
		if music then fadeIn(music, 1, 0.2) end
	elseif musicType == "FinalStand" then
		if music then fadeOut(music, 1) end
		music = d.MusicFolder:WaitForChild("finalstandBGM")
		music.Looped = true
		if music then fadeIn(music, 1, 0.2) end
	elseif musicType == "Round" then
		if music then fadeOut(music, 1) end
		music = d.MusicFolder:WaitForChild("roundBGM")
		music.Looped = true
		print(music)
		if music then fadeIn(music, 1, 0.2) end
	elseif musicType == "Winner" then
		if music then fadeOut(music, 1) end
		music = d.MusicFolder:WaitForChild("WinMusic")
		print(music)
		music.Looped = false
		if music then fadeIn(music, 1, 0.2) end
	elseif musicType == "STOP" then
		if music then fadeOut(music, 1) end
	end
	
end

function MusicModule:PlaySFX(sfxType : string)
	
	repeat task.wait() until isLoaded == true


	if sfxType == "Error" then
		sfx = d.SFXFolder:WaitForChild("error")
		sfx.Volume = 2
		if sfx then sfx:Play() end
	elseif sfxType == "Spin" then
		sfx = d.MusicFolder:WaitForChild("SpinMusic")
		music.Looped = false
		if sfx then sfx:Play() end
	elseif sfxType == "Click" then
		sfx = d.SFXFolder:WaitForChild("Click")
		sfx.Volume = 2
		if sfx then sfx:Play() end
	elseif sfxType == "Click1" then
		sfx = d.SFXFolder:WaitForChild("Click1")
		sfx.Volume = 2.5
		if sfx then sfx:Play() end
	elseif sfxType == "ReceiveRewardChestCase" or sfxType == "SpinFinish" then
		sfx = d.SFXFolder:WaitForChild("chestcaseOpen")
		sfx.Volume = 2
		if sfx then sfx:Play() end
	elseif sfxType == "Whoosh" then
		sfx = d.SFXFolder:WaitForChild("Whoosh")
		sfx.Volume = 2
		if sfx then sfx:Play() end
	elseif sfxType == "Win" then
		sfx = d.SFXFolder:WaitForChild("winSFX")
		sfx.Volume = 2
		if sfx then sfx:Play() end
	elseif sfxType == "Interact" then
		sfx = d.SFXFolder:WaitForChild("Interact")
		sfx.Volume = 2
		if sfx then sfx:Play() end
	elseif sfxType == "Notif" then
		sfx = d.SFXFolder:WaitForChild("notif")
		sfx.Volume = 2
		if sfx then sfx:Play() end
	elseif sfxType == "Whoosh2" then
		sfx = d.SFXFolder:WaitForChild("Whoosh2")
		sfx.Volume = 2
		if sfx then sfx:Play() end
	elseif sfxType == "Dead" then
		sfx = d.SFXFolder:WaitForChild("Dead")
		sfx.Volume = 2
		if sfx then sfx:Play() end
	elseif sfxType == "Hover" then
		sfx = d.SFXFolder:WaitForChild("Hover")
		sfx.Volume = 2
		if sfx then sfx:Play() end
	elseif sfxType == "Coin" then
		sfx = d.SFXFolder:WaitForChild("Coin")
		sfx.Volume = 2
		if sfx then sfx:Play() end
	elseif sfxType == "Purchase" then
		sfx = d.SFXFolder.Purchase
		sfx.Volume = 2
		if sfx then sfx:Play() end
	elseif sfxType == "Purchase2" then
		sfx = d.SFXFolder.Purchase2
		sfx.Volume = 2
		if sfx then sfx:Play() end


		--------- DEATH FX -----------

	-- Note : For the SFXType, always make sure it's the name of what the player currently equipped	
	elseif sfxType == "Explosion" then
		sfx = d.DeathSFXFolder.Explode
		sfx.Volume = 1
	if sfx then sfx:Play() end


	end
	
end



local function playLoopSection(soundTemplate, parent, startTime, endTime, fadeTime, player)
	local function createAndFade()
		-- Check if we should stop looping
		if not parent or not parent.Parent or not activeEmotes[player] then 
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
			if sound and sound.Parent == parent and activeEmotes[player] then
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


function MusicModule:PlayEmoteMusic(hrp : Part?, soundObject : Sound?)

	
end


return MusicModule
