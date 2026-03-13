local GuiModule = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

-- Folders
local EventsFolder = ReplicatedStorage:WaitForChild("Events")
local ModulesFolder = ReplicatedStorage:WaitForChild("Modules")

-- Modules
local MusicModule = require(ModulesFolder:WaitForChild("MusicModule"))
local d = require(ModulesFolder:WaitForChild("Directory"))

-- Variables & Functions & Events
local localPlayer = Players.LocalPlayer
local RoundEvent = EventsFolder:WaitForChild("RoundEvent")

local HandleRoundUI
local HandleButtonUI
local HandleData
local HandleNewRound
local HandleCaseChestUI
local HandleCaseChestName
local DailyRewardsUI
local LastStandAnimation

local roundConnection = nil

local connections = {}

local ButtonEvent = EventsFolder:WaitForChild("ButtonEvent")
local ChestEvent = EventsFolder:WaitForChild("ChestEvent")

GuiModule.FramesValue = {DF = false, IF = false, SF = false}

local lastRoundState = 0  -- tracks the previous round state
local animPlay = false
local finishAnim = false

-- Configas

local UiText = {
	Waiting = "Waiting For Players...",
	Intermission = "Intermission: ",
	InRound = "Time Left: ",
	Eliminated = "Players Eliminated: ",
	Win = "Winner: ",
	NewInRound = "New Round Starting: ",
	LoadingRound = "Loading...",
	LastStand = "Last Stand! CLICK AS FAST AS YOU CAN : " ,
	ChestCooldown = "Available In | "
}




local ChestCasesFolder = workspace:WaitForChild("Lobby"):WaitForChild("Models"):WaitForChild("Chest_Cases")

--[[

NOTES: 
	- RoundData has state & timer. ( RoundData.State | RoundData.Time )
	- State is 1 for intermission, 2 for round.
	
]]

local clicked = false
local playedIntro = false

---------------------------------------------------------------------------------------------------------------------------------------------

local function GetGui()
	local screenGui = localPlayer:WaitForChild("PlayerGui"):WaitForChild("UI"):WaitForChild("ScreenGui")
	screenGui.ResetOnSpawn = false
	local roundFrame = screenGui:WaitForChild("RoundFrame")
	local buttonFrame = screenGui:WaitForChild("ButtonFrame")
	local countButton = buttonFrame:WaitForChild("CountButton")
	local finalStandButton = buttonFrame:WaitForChild("FinalStandButton")
	local roundLabel = roundFrame:WaitForChild("RoundLabel")
	local leftFrame = screenGui:WaitForChild("LeftFrame")
	local LastStandFrame = screenGui:WaitForChild("LastStand")
	local CurrencyFrame = screenGui:WaitForChild("CurrencyFrame")
	local EmoteWheel = screenGui:WaitForChild("EmoteWheel")

	return screenGui, roundFrame, buttonFrame, countButton, roundLabel, leftFrame, finalStandButton, LastStandFrame, CurrencyFrame, EmoteWheel
end



function GuiModule:Init()  -- Makes a Listener ONCE
	
	if roundConnection then
		roundConnection:Disconnect()
	end
	self:ChatVIP()
	self:HandleButtonListeners()
	self:SetupTweens()

	
	RoundEvent.OnClientEvent:Connect(function(RoundData, PlayersDict)
		local playerData = PlayersDict[tostring(localPlayer.UserId)]
		HandleRoundUI(RoundData, playerData)
	end)
	
	d.CurrencyEvent.OnClientEvent:Connect(function(CurrencyTable)
		self:SetCurrencyValues(CurrencyTable)
	end)
	
	ChestEvent.OnClientEvent:Connect(function(cooldown) -- CHEST UI
		HandleCaseChestUI(cooldown)
	end)
end


-- ROUNDTYPE 1 : Normal Round
-- ROUNDTYPE 2 : Final Stand

function GuiModule:HandleButtonListeners()
	local ScreenGui,RoundFrame, ButtonFrame, CountButton, RoundLabel, leftFrame, finalStandButton, LastStandFrame ,CurrencyFrame, EmoteWheel = GetGui()
		
	CountButton.MouseButton1Click:Connect(function() -- NORMAL ROUND
		if clicked then return end
		MusicModule:PlaySFX("Click")
		finalStandButton.Visible = false
		finalStandButton.Interactable = false

		clicked = true
		CountButton.Interactable = false
		ButtonEvent:FireServer(1) 

		CountButton.Text = "Wait..."
		CountButton.BackgroundColor3 = Color3.new(1, 0, 0)
	end)
	
	finalStandButton.MouseButton1Click:Connect(function()  -- FINAL STAND
		MusicModule:PlaySFX("Click")
		ButtonEvent:FireServer(2)
		task.wait(0.1)
	end)
	
	table.insert(connections, CurrencyFrame.AFK.MouseButton1Click:Connect(function()
		-- Final safety check: If a round is active, ignore the click
		local isRoundActive = (lastRoundState ~= 1 and lastRoundState ~= 67 and lastRoundState ~= 0)

		if isRoundActive then
			return -- Silent return since the button shouldn't even be visible
		end

		MusicModule:PlaySFX("Click")

		local success, isAFK = pcall(function()
			return d.ToggleAFK:InvokeServer()
		end)

		if success then
			if isAFK then
				CurrencyFrame.AFK.BackgroundColor3 = Color3.fromRGB(200, 0, 0) -- Red
			else
				CurrencyFrame.AFK.BackgroundColor3 = Color3.fromRGB(60, 229, 48) -- Green
			end
		end
	end))
	
end

-- Add this to your GuiModule script
local TextChatService = game:GetService("TextChatService")

function GuiModule:ChatVIP()
	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local properties = Instance.new("TextChatMessageProperties")

		-- Ensure the message came from a real player
		if message.TextSource then
			local sender = Players:GetPlayerByUserId(message.TextSource.UserId)

			-- CHECK FOR VIP STATUS HERE
			-- Example: Checking a GamePass or a specific Attribute
			local isVIP = sender:GetAttribute("IsVIP") == true 
			-- OR: sender:IsInGroup(12345) 

			if isVIP then
				-- We use Rich Text to color the tag and the name
				properties.PrefixText = "<font color='#FFD700'>[⭐ VIP]</font> " .. message.PrefixText
			end
		end

		return properties
	end
end

---------------------------------------------------------------------------------------------------------------------------------------------

HandleRoundUI = function(RoundData, PlayersData)
	local ScreenGui,RoundFrame, ButtonFrame, CountButton, RoundLabel, leftFrame, finalStandButton, LastStandFrame, CurrencyFrame = GetGui() -- Send the current set of GUI
	
	RoundFrame.Visible = true
	lastRoundState = RoundData.State
	
	-- Detect new InRound
	if RoundData.State == 2 and RoundData.newRound or RoundData.State == 6 then
		clicked = false  -- reset debounce at the start of the round
	end
	
	if RoundData.State == 0  then
		clicked = false
		ButtonFrame.Visible = false
		RoundLabel.Text = UiText.LoadingRound
		CurrencyFrame.AFK.Visible = true
	elseif RoundData.State == 67 then  -- WAITING FOR PLAYERS
		clicked = false
		ButtonFrame.Visible = false
		CurrencyFrame.AFK.Visible = true
		RoundLabel.Text = UiText.Waiting
	elseif RoundData.State == 69 then  -- Disable Button for the player.
		clicked = false
		ButtonFrame.Visible = false
		CurrencyFrame.AFK.Visible = true
		RoundLabel.Text = UiText.Waiting
	elseif RoundData.State == 1 then
		finishAnim = false
		animPlay = false
		clicked = false
		CurrencyFrame.AFK.Visible = true
		RoundLabel.Text = UiText.Intermission .. RoundData.Time
	elseif RoundData.State == 2 then
		RoundLabel.TextTransparency = 0
		RoundLabel.Text = UiText.InRound .. RoundData.Time
		CurrencyFrame.AFK.Visible = false
		
		if PlayersData and PlayersData.Alive and not PlayersData.Counted and PlayersData.isPlaying then
			HandleButtonUI(CountButton, ButtonFrame, finalStandButton,"normalRound")
		end
		
	elseif RoundData.State == 3 then
		RoundLabel.Text = UiText.NewInRound .. RoundData.Time
		ButtonFrame.Visible = false
		CurrencyFrame.AFK.Visible = false
	elseif RoundData.State == 4 then
		RoundLabel.Text = UiText.Eliminated .. RoundData.Time
		ButtonFrame.Visible = false
		CurrencyFrame.AFK.Visible = false
	elseif RoundData.State == 5 then
		RoundLabel.Text = UiText.Win .. RoundData.Time
		
		ButtonFrame.Visible = false
		CurrencyFrame.AFK.Visible = false
	elseif RoundData.State == 6 then
		RoundLabel.Text = UiText.LastStand .. RoundData.Time
		ButtonFrame.Visible = false
		CurrencyFrame.AFK.Visible = false
		
		if animPlay == false then
			animPlay = true
			LastStandAnimation(LastStandFrame)
			finishAnim = true
			wait(1)
		end
		
		if PlayersData and PlayersData.Alive and not PlayersData.Counted and PlayersData.isPlaying and finishAnim == true then
			clicked = false
			HandleButtonUI(CountButton, ButtonFrame, finalStandButton , "lastStand")
		end
		
	elseif RoundData.State == 7 then
		
		RoundLabel.TextTransparency = 1
		if RoundData.Time <= 10 then
			if not playedIntro then
				playedIntro = true
				GuiModule:IntroAnim(ScreenGui)
			end
		end
		CurrencyFrame.AFK.Visible = false
		
	else
		warn("Error | RoundData.State")
	end
	
	-- Remember this state for the next update
	lastRoundState = RoundData.State
end

---------------------------------------------------------------------------------------------------------------------------------------------
 
HandleButtonUI = function(CountButton, ButtonFrame, finalStandButton, Action : string)
	if clicked then return end
	
	ButtonFrame.Visible = true
	
	if Action == "normalRound" then
		
		finalStandButton.Visible = false
		finalStandButton.Interactable = false
		
		CountButton.Visible = true	
		CountButton.Text = "Count"
		CountButton.Interactable = true
		CountButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		CountButton.BackgroundColor3 = Color3.fromRGB(255, 217, 66)  -- yellow
		
	elseif Action == "lastStand" then
		
		CountButton.Visible = false 
		CountButton.Interactable = false
		
		finalStandButton.Visible = true
		finalStandButton.Interactable = true
		
	else
		warn("Invalid Button Action | #160 GuiModule")
		print(Action)
	end
end


---------------------------------------------------------------- CHEST ---------------------------------------------------------------------

local function formatTime(seconds)
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = seconds % 60
	return string.format("%02d:%02d:%02d", hours, minutes, secs)
end



HandleCaseChestUI = function(cooldown)
	for _, model in pairs(ChestCasesFolder:GetChildren()) do
		if model:IsA("Model") then
			local meshPart = model:FindFirstChild("Mesh")
			if meshPart then
				HandleCaseChestName(model.Name, meshPart,cooldown)
			end
		end
	end
end

HandleCaseChestName = function(name, meshPart, cooldown)
	if name == "RewardChest" then
		if cooldown <= 0 then
			meshPart.Bottom.Frame.Status.Text = "CLAIM REWARD"
		elseif cooldown > 0 then
			meshPart.Bottom.Frame.Status.Text = UiText.ChestCooldown .. formatTime(cooldown)
		else
			warn("UI ERROR | GUI MODULE REWARD CHEST")
		end
	end
end


local function TweenOutLastStand(mainText, img, InfoTxt)

	local mainOut = TweenService:Create(
		mainText,
		TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{
			Position = mainText.Position - UDim2.new(0.45, 0, -2, 0),
			TextTransparency = 1
		}
	)
	
	local mainStroke = TweenService:Create(
		mainText.UIStroke,
		TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{
			Transparency = 1
		}
	)

	local imgMoveFade = TweenService:Create(
		img,
		TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.In),
		{
			Position = img.Position + UDim2.new(0.855, 0, -2.3, 0),
			ImageTransparency = 1,
		}
	)

	local infoOut = TweenService:Create(
		InfoTxt,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{
			Position = InfoTxt.Position - UDim2.new(0.5, 0, 2, 0),
			TextTransparency = 1
		}
	)
	
	local infoStroke = TweenService:Create(
		InfoTxt.UIStroke,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{
			Transparency = 1
		}
	)

	mainOut:Play()
	mainStroke:Play()
	imgMoveFade:Play()

	task.wait(0.08)
	infoOut:Play()
	infoStroke:Play()

end


function GuiModule:IntroAnim(ScreenGui : ScreenGui)
	
	print("Playing Animation")
	
	local ModeFrame = ScreenGui:WaitForChild("ModeFrame")
	local FrameContainer = ModeFrame:WaitForChild("FrameContainer")
	local DescriptionFolder = FrameContainer:WaitForChild("Description")
	local UITable = {FrameContainer:WaitForChild("ModeName"), DescriptionFolder:WaitForChild("D1"), DescriptionFolder:WaitForChild("D2"), DescriptionFolder:WaitForChild("D3")}
	
	local T_INFO = TweenInfo.new(1.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local SHRINK_INFO = TweenInfo.new(0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

	local POSITIONS = {
		UDim2.new(0.5, 0, 0.35, 0),  -- ModeName
		UDim2.new(0.5, 0, 0.536, 0), -- D1
		UDim2.new(0.5, 0, 0.636, 0), -- D2
		UDim2.new(0.5, 0, 0.751, 0)  -- D3
	}
	
	local TweenOutPos = {
		UDim2.new(0.5, 0,0.45, 0),  -- ModeName
		UDim2.new(0.5, 0,0.58, 0), -- D1
		UDim2.new(0.5, 0,0.658, 0), -- D2
		UDim2.new(0.5, 0,0.788, 0)  -- D3
	}
	
	local oldPos = {	
		UDim2.new(0.5, 0,-2.35, 0),  -- ModeName
		UDim2.new(-2.5, 0,-0.536, 0), -- D1
		UDim2.new(1.5, 0,0.636, 0), -- D2
		UDim2.new(-0.5, 0,0.751, 0)  -- D3
	}
	
	local function TweenToPos()
		
		local TweenFrame = TweenService:Create(ModeFrame, T_INFO, {Transparency = 0.4})
		TweenFrame:Play()
		TweenFrame.Completed:Wait()
		
		for i, obj in ipairs(UITable) do
			local tween = TweenService:Create(obj, T_INFO, {Position = POSITIONS[i]})
			tween:Play()
			tween.Completed:Wait()	
		end
	end
	
	local function TweenOutScale1()
		for i, obj in ipairs(UITable) do
			if obj:FindFirstChild("UIScale") then
				local enlarge = TweenService:Create(obj.UIScale, T_INFO, {Scale = 1.2})
				enlarge:Play()
			end
		end
	end

	
	local function TweenOut()
		for i, obj in ipairs(UITable) do
			if obj:FindFirstChild("UIScale") then
				local tween = TweenService:Create(obj.UIScale, T_INFO, {Scale = 0})
				local tween1 = TweenService:Create(obj.UIStroke, T_INFO, {Transparency = 1})
				tween:Play()
				tween1:Play()
			end
			
			local tween = TweenService:Create(obj, T_INFO, {Position = TweenOutPos[i], TextTransparency = 1})
			tween:Play()
		end
	end	
	
	local function TweenOrig()
		local TweenFrame = TweenService:Create(ModeFrame, T_INFO, {Transparency = 1})
		TweenFrame:Play()
		TweenFrame.Completed:Wait()
		for i, obj in ipairs(UITable) do
			obj.Position = oldPos[i]
			obj.TextTransparency = 0
			if obj:FindFirstChild("UIScale") then
				obj.UIScale.Scale = 1
				obj.UIStroke.Transparency = 0
			end
		end
	end	
	
	TweenToPos()
	task.wait(3)
	TweenOutScale1()
	task.wait(0.5)
	TweenOut()
	task.wait(0.5)
	TweenOrig()
	
	playedIntro = false
		
end

function GuiModule:TweenEmotes(EmoteWheel, action)
	
	local openInfo = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local closeInfo = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	
	if action == "open" then
		EmoteWheel.Visible = true
		local tween = d.TweenService:Create(EmoteWheel, openInfo, {Position = UDim2.new(0.5, 0,0.5, 0), Size = UDim2.new(0.339, 0,0.837, 0)})
		tween:Play()
	elseif action == "close" then
		local tween = d.TweenService:Create(EmoteWheel, openInfo, {Position = UDim2.new(0.5, 0,0.5, 0), Size = UDim2.new(0, 0,0, 0), Visible = false})
		tween:Play()
		task.wait(0)
		EmoteWheel.Visible = false
		
	end
end

-- Sets Coin & Win Values
-- Also handles clicking for emotes.
GuiModule.emoteDB = false
GuiModule.isClicked = false

function GuiModule:SetCurrencyValues(CurrencyTable)
	local ScreenGui,RoundFrame, ButtonFrame, CountButton, RoundLabel, leftFrame, finalStandButton, LastStandFrame ,CurrencyFrame, EmoteWheel = GetGui()
	
	local EmoteFrame = CurrencyFrame:WaitForChild("Emote")
	local emoteBtn = EmoteFrame:WaitForChild("btn")
	
	local CoinsFolder = CurrencyFrame:WaitForChild("Coins")
	local WinsFolder = CurrencyFrame:WaitForChild("Wins")
	
	CoinsFolder:WaitForChild("CoinValue").Text = CurrencyTable.Coins
	WinsFolder:WaitForChild("WinValue").Text = CurrencyTable.Wins
	
	emoteBtn.MouseButton1Click:Connect(function()
		
		if self.isClicked then return end
		self.isClicked = true
		
		if not self.emoteDB then self:TweenEmotes(EmoteWheel, "open") MusicModule:PlaySFX("Click") task.wait(0.5)  self.emoteDB = true self.isClicked = false return end
		if self.emoteDB then self:TweenEmotes(EmoteWheel, "close") MusicModule:PlaySFX("Click") task.wait(0.5) self.emoteDB = false self.isClicked = false end
	end)
	
end


local tweenConns = {}
local tweenCache = {}

local function tweenHover(x)
	
	if not tweenCache[x] then
		tweenCache[x] = x.Size
	end
	
	local normalSize = tweenCache[x]
	local hoverSize = UDim2.new(normalSize.X.Scale * 1.1, 0, normalSize.Y.Scale * 1.1, 0)
	local sizeTween = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	
	return hoverSize, sizeTween, normalSize
end


function GuiModule:SetupTweens()
	local ScreenGui,RoundFrame, ButtonFrame, CountButton, RoundLabel, leftFrame, finalStandButton, LastStandFrame ,CurrencyFrame, EmoteWheel = GetGui()
	
	for _, conn in ipairs(tweenConns) do
		if conn then conn:Disconnect() end
	end
	
	table.clear(tweenConns)
	
	table.insert(tweenConns, CurrencyFrame.Emote.MouseEnter:Connect(function()
		local hoverSize, sizeTween = tweenHover(CurrencyFrame.Emote)
		MusicModule:PlaySFX("Hover")
		local tween = d.TweenService:Create(CurrencyFrame.Emote, sizeTween, {Size = hoverSize})
		tween:Play()
	end))
	
	table.insert(tweenConns, CurrencyFrame.Emote.MouseLeave:Connect(function()
		local _, sizeTween, normalSize = tweenHover(CurrencyFrame.Emote)
		local tween = d.TweenService:Create(CurrencyFrame.Emote, sizeTween, {Size = normalSize})
		tween:Play()
	end))
	
	
end



LastStandAnimation = function(LastStandFrame : Frame)
	
	local animConn = {}
	MusicModule:PlayMusic("STOP")
	
	MusicModule:PlayMusic("FinalStand")
	
	local mainText = LastStandFrame:WaitForChild("mainTxt")
	local img = LastStandFrame:WaitForChild("Img")
	local InfoTxt = LastStandFrame:WaitForChild("Info")
	
	
	local mainTween = TweenService:Create(
		mainText,
		TweenInfo.new(1.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Position = UDim2.new(0.355, 0, 0.5, 0), TextTransparency = 0}
	)
	local mainStroke = TweenService:Create(
		mainText.UIStroke,
		TweenInfo.new(2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{Transparency = 0}
	)

	local imgTween = TweenService:Create(
		img,
		TweenInfo.new(2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{Position = UDim2.new(0.855, 0, 0.475, 0), ImageTransparency = 0}
	)

	local infoTween = TweenService:Create(
		InfoTxt,
		TweenInfo.new(1.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Position = UDim2.new(0.5, 0, 0.721, 0), TextTransparency = 0}
	)
	
	local infoStroke = TweenService:Create(
		InfoTxt.UIStroke,
		TweenInfo.new(1.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Transparency = 0}
	)

	mainTween:Play()
	mainStroke:Play()

	task.wait(0.2)
	imgTween:Play()

	task.wait(1)
	infoTween:Play()
	infoStroke:Play()

	wait(4)
	
	TweenOutLastStand(mainText, img, InfoTxt)

end


---------------------------------------------------------------------------------------------------------------------------------------------

return GuiModule
