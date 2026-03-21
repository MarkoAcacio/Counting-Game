local EmoteModule = {}

local d = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Directory"))

local InventoryUI = require(d.Modules.InventoryUI)
local GuiModule = require(d.Modules:WaitForChild("GuiModule"))
local TweenUtils = require(d.Modules:WaitForChild("TweenUtils"))

local getWheel
local currentEmote = nil
local currentCountAnim = nil -- NEW: Track current count animation
local countLock = false

EmoteModule.CurrentEmotes = {
	Emote1 = {animID = 0, animName = "Emote"},
	Emote2 = {animID = 0, animName = "Emote"},
	Emote3 = {animID = 0, animName = "Emote"},
	Emote4 = {animID = 0, animName = "Emote"},
}

EmoteModule.EmoteButtons = {}
EmoteModule.PreviewEmotes = {}
EmoteModule.ButtonConn = {}
EmoteModule.VerifyConn = nil
EmoteModule.PlayingEmote = nil

local conn = {}
local initialized = false
local trackCache = {}
local countTrackCache = {} -- NEW: Separate cache for count animations

------------------------------------------------------------------------------------------------------------

local function cleanUp()
	for _, conn in ipairs(conn) do
		conn:Disconnect()
	end

	for _, Emotes in ipairs(EmoteModule.PreviewEmotes) do
		Emotes:Stop()
	end

	for _, EmoteButtons in ipairs(EmoteModule.EmoteButtons) do
		EmoteButtons:Destroy()
	end

	for id, track in pairs(trackCache) do
		track:Stop()
		track:Destroy()
	end
	trackCache = {}

	-- NEW: Clean count animation cache
	for id, track in pairs(countTrackCache) do
		track:Stop()
		track:Destroy()
	end
	countTrackCache = {}
end

game.Players.PlayerRemoving:Connect(function(player)
	-- Clean up any cached tracks for this player
	for key, track in pairs(countTrackCache) do
		if key:find(player.Name) then
			track:Destroy()
			countTrackCache[key] = nil
		end
	end
end)



local cameraConn = nil

local function cameraFollow(start)
	local camera = workspace.CurrentCamera
	local char = d.localPlayer.Character
	if not char then return end

	local torso = char:FindFirstChild("Head")
	local humanoid = char:FindFirstChild("Humanoid")

	if not start then
		if cameraConn then cameraConn:Disconnect() cameraConn = nil end
		-- Reset focus back to normal
		camera.CameraSubject = humanoid
		return
	end

	-- Switch the camera's pivot point to the animated Torso
	camera.CameraSubject = torso
end



function EmoteModule:Init()

	cleanUp()

	-- Handle Character Setup
	local function onCharAdded(char)
		local hum = char:WaitForChild("Humanoid")
		local hrp = char:WaitForChild("HumanoidRootPart")
		local cam = workspace.CurrentCamera

		-- 1. Immediate Setup
		self:SetupData()
		self:SetupViewports()
		self:SetupButtons()
		self:ChangeEmoteListener()

		-- 2. Reset Camera to Humanoid
		cam.CameraSubject = hum
		cam.CameraType = Enum.CameraType.Custom

		hum.StateChanged:Connect(self.OnStateChange)
	end
	d.localPlayer.CharacterAdded:Connect(onCharAdded)
	if d.localPlayer.Character then onCharAdded(d.localPlayer.Character) end

	-- Listeners (Connected only ONCE)
	d.UserInputService.InputBegan:Connect(function(inp, gpe)
		if gpe then return end
		if inp.KeyCode == Enum.KeyCode.G then
			self:HandleEmoteWheel()
		end
	end)

	-- Death animation listener
	d.DeathEvent.OnClientEvent:Connect(function(deadChar, animID)
		if not deadChar then return end

		-- NEW: Stop count animation for ANY character that dies
		local charName = deadChar.Name
		for cacheKey, track in pairs(countTrackCache) do
			if cacheKey:find(charName) then
				track:Stop(0)
				track:Destroy()
				countTrackCache[cacheKey] = nil
			end
		end

		-- If this is the LocalPlayer dying, fix the camera and stop current count
		if deadChar == game.Players.LocalPlayer.Character then
			local cam = workspace.CurrentCamera
			local head = deadChar:FindFirstChild("Head")

			if head then
				cam.CameraSubject = head
				cam.CameraType = Enum.CameraType.Custom 
			end

			if currentCountAnim then
				currentCountAnim:Stop(0)
				currentCountAnim = nil
			end

			d.MusicEvent:FireServer("STOP", "stop")
		end

		-- Play death animation
		local hum = deadChar:FindFirstChild("Humanoid")
		local animator = hum and hum:FindFirstChild("Animator")

		if animator and animID then
			self:PlayDeathAnimation(animator, animID, deadChar)
		end
	end)
	
	-- NEW: Count animation listener
	d.CountEvent.OnClientEvent:Connect(function(countChar, animID, countName)
		if not animID then
			-- Stop all count animations
			self:StopAllCountAnimations(countName)
			return
		end

		if not countChar then return end

		local hum = countChar:FindFirstChild("Humanoid")
		local animator = hum and hum:FindFirstChild("Animator")

		if animator and animID then
			self:PlayCountAnimation(animator, animID, countChar, countName)
		end
	end)

	d.RunService.RenderStepped:Connect(function()
		if currentEmote and d.localPlayer.Character then
			local hum = d.localPlayer.Character:FindFirstChild("Humanoid")
			if hum and hum.MoveDirection.Magnitude > 0 then
				currentEmote:Stop()
				currentEmote = nil

				cameraFollow(false)

				if self.PlayingEmote then
					d.MusicEvent:FireServer("STOP", "stop")
					self.PlayingEmote = nil
				end
			end
		end
	end)
end



function EmoteModule:PlayCountAnimation(animator, animationID, countChar, countName)
	-- If the round is cleaning up, ignore all incoming "Play" requests
	if countLock then return end 

	local cacheKey = countChar.Name .. "_" .. tostring(animationID)
	local track = countTrackCache[cacheKey]

	-- Only create the track if it doesn't exist OR was destroyed
	if not track or not track.Parent then
		local anim = Instance.new("Animation")
		anim.AnimationId = "rbxassetid://" .. tostring(animationID)

		track = animator:LoadAnimation(anim)
		track.Priority = Enum.AnimationPriority.Action4
		track.Looped = true

		countTrackCache[cacheKey] = track
	end

	-- If the track is already playing, don't restart it from 0 every click
	if not track.IsPlaying then
		track:Play()
	end

	-- NEW: Set currentCountAnim for LOCAL player
	if countChar == d.localPlayer.Character then
		currentCountAnim = track
		d.MusicEvent:FireServer(countName, "play")
	end
end


function EmoteModule:StopAllCountAnimations(countName)
	countLock = true -- Block new tracks immediately

	print("Cleaning up tracks...")
	d.MusicEvent:FireServer(countName, "stop")

	for id, track in pairs(countTrackCache) do
		if track then
			track:Stop(0) -- Stop instantly
			track:Destroy()
		end
	end

	-- Clear the table so references are actually gone
	table.clear(countTrackCache)

	if currentCountAnim then
		currentCountAnim:Stop(0)
		currentCountAnim = nil
	end

	-- Wait for the round transition to finish before allowing animations again
	task.delay(1.5, function()
		countLock = false
	end)
end



function EmoteModule:PlayDeathAnimation(animator, animationID, deadChar)
	-- 1. If the person who died is ME, clean up my local UI/Camera
	if deadChar == d.localPlayer.Character then
		if currentEmote then
			currentEmote:Stop()
			currentEmote = nil
			cameraFollow(false)
		end
		if self.PlayingEmote then
			d.MusicEvent:FireServer("STOP", "stop")
			self.PlayingEmote = nil
		end
		-- Stop count animation when dying
		if currentCountAnim then
			currentCountAnim:Stop()
			currentCountAnim = nil
		end
	end

	-- 2. Load and Play for everyone
	local track = trackCache[animationID]
	if not track or not track.Parent then
		local anim = Instance.new("Animation")
		anim.AnimationId = "rbxassetid://" .. tostring(animationID)
		track = animator:LoadAnimation(anim)
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = false 
		trackCache[animationID] = track
	end

	track:Play()

	-- 3. Only the OWNER of the character signals the server to proceed
	if deadChar == d.localPlayer.Character then
		task.spawn(function()
			track.Stopped:Wait()
			d.DeathEvent:FireServer() -- Tells PlayerModule to Ragdoll
		end)
	end
end



function EmoteModule:RefreshUI()
	-- Clear only UI-specific items
	for _, Emotes in ipairs(self.PreviewEmotes) do
		Emotes:Stop()
	end
	table.clear(self.PreviewEmotes)

	for _, Button in ipairs(self.EmoteButtons) do
		-- Don't Destroy the button if it's part of the UI permanently!
		-- Just disconnect the old events.
	end
	table.clear(self.EmoteButtons)

	-- Rebuild the visuals
	self:SetupViewports()
	self:SetupButtons()
end

function EmoteModule:ChangeEmoteListener()
	table.insert(conn, d.EmoteChange.Event:Connect(function()
		local data = InventoryUI.EquipEmote

		-- 1. Update the data
		if self.CurrentEmotes[data.slotName] then
			self.CurrentEmotes[data.slotName].animID = data.emoteID
			self.CurrentEmotes[data.slotName].animName = data.emoteName
		end

		-- 2. Clean up ONLY the visual connections/previews, NOT the main listeners
		self:RefreshUI() 

		print("Emote Wheel Visuals Reset")
	end))
end



function EmoteModule:SetupData()
	-- This waits for the Server to return the 'EmoteConfig' table
	local data = d.EmoteRequest:InvokeServer() 

	if data and next(data) ~= nil then

		-- Loop through the saved slots (Emote1, Emote2, etc.)
		for slotName, emoteInfo in pairs(data) do
			if self.CurrentEmotes[slotName] then
				-- We use emoteInfo.EmoteID because that's how it's named in your template
				self.CurrentEmotes[slotName].animID = emoteInfo.EmoteID
				self.CurrentEmotes[slotName].animName = emoteInfo.EmoteName
			end
		end
	else
		-- If no data was saved, set default empty slots
		for i = 1, 4 do
			self.CurrentEmotes["Emote"..i] = {animID = 0, animName = "Emote"}
		end
	end
end

------------------------------------------------------------------------------------------------------------

function EmoteModule:HandleEmoteWheel()	
	local WheelUi = getWheel()

	if GuiModule.isClicked then return end
	GuiModule.isClicked = true
	TweenUtils.BG_Blur(true, 15) 

	if GuiModule.emoteDB then GuiModule:TweenEmotes(WheelUi, "close") GuiModule.emoteDB = false TweenUtils.BG_Blur(false, 0)  task.wait(0.5) GuiModule.isClicked = false return end

	GuiModule:TweenEmotes(WheelUi, "open")
	GuiModule.emoteDB = true

	task.wait(0.5)

	GuiModule.isClicked = false

end

------------------------------------------------------------------------------------------------------------

function EmoteModule:SetupViewports()
	local WheelUI = getWheel()
	local EmoteFolder = WheelUI:WaitForChild("Emotes")


	local emotes = EmoteFolder:GetChildren()
	table.sort(emotes, function(a, b)
		return a.Name < b.Name
	end)

	for _, vp in ipairs(emotes) do
		-- HANDLE DUMMY HERE
		local emoteId = self.CurrentEmotes[vp.Name].animID
		local emoteName = self.CurrentEmotes[vp.Name].animName

		local text = vp:WaitForChild("TextLabel")
		text.Text = emoteName

		local Button = vp:WaitForChild("TextButton")

		table.insert(self.EmoteButtons, Button)

		for _, WorldModel in ipairs(vp:GetChildren()) do
			if WorldModel:IsA("WorldModel") then
				local rig = WorldModel:FindFirstChild("Rig")
				if rig then
					local animator = rig:FindFirstChild("Humanoid"):FindFirstChild("Animator")

					task.wait(0.5)

					if emoteId ~= 0  then -- if not default then execute. if default then do nothing
						self:PlayLocalPreview(animator, emoteId)
					end
				end
			end
		end
	end

end

function EmoteModule:SetupButtons()

	for _, c in ipairs(self.ButtonConn) do -- Disconnect past buttons before creating new conns.
		c:Disconnect()
	end

	for _, button in ipairs(self.EmoteButtons) do

		table.insert(self.ButtonConn, button.MouseButton1Click:Connect(function()
			local EmoteId = self.CurrentEmotes[button.Parent.Name].animID
			local EmoteName = self.CurrentEmotes[button.Parent.Name].animName
			self.PlayingEmote = EmoteName
			
			TweenUtils.BG_Blur(false, 0) 

			local Character = d.localPlayer.Character
			local Humanoid = Character:WaitForChild("Humanoid")
			local Animator = Humanoid:WaitForChild("Animator")

			d.MusicEvent:FireServer(EmoteName, "play")

			currentEmote = self:PlayEmote(Animator, EmoteId, EmoteName)

			self:HandleEmoteWheel()
		end))
	end
end


function EmoteModule:PlayLocalPreview(animator, emoteId)

	local anim = Instance.new("Animation")
	anim.AnimationId = "rbxassetid://" .. emoteId

	local loadedAnimation = animator:LoadAnimation(anim)
	loadedAnimation.Priority = Enum.AnimationPriority.Action
	loadedAnimation.Looped = true
	loadedAnimation:Play()

	table.insert(self.PreviewEmotes, loadedAnimation)
end



function EmoteModule:PlayEmote(animator, emoteId, EmoteName)
	if currentEmote then
		currentEmote:Stop()
		currentEmote = nil
		cameraFollow(false)
	end

	if self.VerifyConn then
		self.VerifyConn:Disconnect()
		self.VerifyConn = nil
	end

	self.VerifyConn = d.VerifyEvent.OnClientEvent:Connect(function(returnedId, isAllowed)
		if tostring(returnedId) == tostring(emoteId) then
			if isAllowed then
				if self.VerifyConn then
					self.VerifyConn:Disconnect()
					self.VerifyConn = nil
				end

				local track = trackCache[emoteId]

				if not track or not track.Parent then
					local anim = Instance.new("Animation")
					anim.AnimationId = "rbxassetid://" .. emoteId

					track = animator:LoadAnimation(anim)
					track.Priority = Enum.AnimationPriority.Action
					track.Looped = true
					trackCache[emoteId] = track
				end
				track:Play()
				currentEmote = track
				cameraFollow(true)
				d.EmoteEvent:FireServer(emoteId, animator, track)
			end
		end
	end)

	d.VerifyEvent:FireServer(emoteId)
end


function EmoteModule.OnStateChange(oldState, newState)
	local States = {
		Enum.HumanoidStateType.Running,
		Enum.HumanoidStateType.RunningNoPhysics,
		Enum.HumanoidStateType.Jumping,
		Enum.HumanoidStateType.Freefall,
	}

	for _, state in ipairs(States) do
		if newState == state then
			if currentEmote then
				currentEmote:Stop()
				currentEmote = nil

				cameraFollow(false)

			end
			return
		end
	end

end
------------------------------------------------------------------------------------------------------------

getWheel = function()
	local screenGui = d.localPlayer:WaitForChild("PlayerGui"):WaitForChild("UI"):WaitForChild("ScreenGui")
	screenGui.ResetOnSpawn = false
	local EmoteWheel = screenGui:WaitForChild("EmoteWheel")

	return EmoteWheel
end

------------------------------------------------------------------------------------------------------------

return EmoteModule