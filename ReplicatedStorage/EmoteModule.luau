local EmoteModule = {}

local d = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Directory"))

local InventoryUI = require(d.Modules.InventoryUI)
local GuiModule = require(d.Modules:WaitForChild("GuiModule"))

local getWheel
local currentEmote = nil

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

local conn = {}
local initialized = false
local trackCache = {}

-- Folders

-- Config

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
end


function EmoteModule:Init()

	cleanUp()

	-- Handle Character Setup
	local function onCharAdded(char)
		local hum = char:WaitForChild("Humanoid")
		-- Update Directory references if needed
		print("Reloading EmoteModule")
		self:SetupData()
		self:SetupViewports()
		self:SetupButtons()

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

	d.RunService.RenderStepped:Connect(function()
		if currentEmote and d.localPlayer.Character then
			local hum = d.localPlayer.Character:FindFirstChild("Humanoid")
			if hum and hum.MoveDirection.Magnitude > 0 then
				currentEmote:Stop()
				currentEmote = nil
			end
		end
	end)
end


function EmoteModule:ChangeEmoteListener()  -- For inventory not saves etc.
	
	table.insert(conn, d.EmoteChange.Event:Connect(function()
		local data = InventoryUI.EquipEmote
		
		self.CurrentEmotes[data.slotName].animID = data.emoteID
		self.CurrentEmotes[data.slotName].animName = data.emoteName
		
		cleanUp()
		
		self:Init()
		
		print("Resetting")
	end))
	
end


function EmoteModule:SetupData()
	-- Make a request to the server. then update the current emotes.
	
	local data = d.EmoteRequest:InvokeServer()  -- Make connection / listener first then fire server.
		
		local count = 0
		
		if data then
			for key, value in pairs(data) do
				count += 1
				self.CurrentEmotes["Emote"..tostring(count)].animID = value
				self.CurrentEmotes["Emote"..tostring(count)].animName = key
				
			end
		end
end


------------------------------------------------------------------------------------------------------------

function EmoteModule:HandleEmoteWheel()	
	local WheelUi = getWheel()
	
	if GuiModule.isClicked then return end
	GuiModule.isClicked = true
	
	if GuiModule.emoteDB then GuiModule:TweenEmotes(WheelUi, "close") GuiModule.emoteDB = false task.wait(0.5) GuiModule.isClicked = false return end
	
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
			
			local Character = d.localPlayer.Character
			local Humanoid = Character:WaitForChild("Humanoid")
			local Animator = Humanoid:WaitForChild("Animator")
			
			currentEmote = self:PlayEmote(Animator, EmoteId)
			
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


function EmoteModule:PlayEmote(animator, emoteId)
	if currentEmote then
		currentEmote:Stop()
		currentEmote = nil
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
				d.EmoteEvent:FireServer(emoteId)
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
