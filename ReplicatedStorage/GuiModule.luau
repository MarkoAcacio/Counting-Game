local GuiModule = {}

local d = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Directory"))

-- Services

-- Folders
local EventsFolder = d.ReplicatedStorage:WaitForChild("Events")
local ModulesFolder = d.ReplicatedStorage:WaitForChild("Modules")
local TweenUtils = require(d.Modules:WaitForChild("TweenUtils"))

-- Modules
local MusicModule = require(ModulesFolder:WaitForChild("MusicModule"))
local d = require(ModulesFolder:WaitForChild("Directory"))

-- Variables & Functions & Events


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
local clicked = false
local playedIntro = false

-- Configas

local UiText = {
	Waiting = "Waiting For Players...",
	Intermission = "Intermission: ",
	InRound = "Time Left: ",
	Eliminated = "Players Eliminated: ",
	Win = "🎊 Winners : ",
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

---------------------------------------------------------------------------------------------------------------------------------------------

local function GetGui()
	local screenGui = d.localPlayer:WaitForChild("PlayerGui"):WaitForChild("UI"):WaitForChild("ScreenGui")
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

local function resetStates()
	clicked = false
	playedIntro = false
	animPlay = false
	finishAnim = false
	lastRoundState = 0
end


function GuiModule:Init()  -- Makes a Listener ONCE

	-- Reset states on init (important for respawns)
	resetStates()

	if roundConnection then
		roundConnection:Disconnect()
	end
	self:ChatVIP()
	self:HandleButtonListeners()


	d.RoundEvent.OnClientEvent:Connect(function(RoundData, PlayersDict)
		local playerData = PlayersDict[tostring(d.localPlayer.UserId)]
		HandleRoundUI(RoundData, playerData)
	end)

	d.CurrencyEvent.OnClientEvent:Connect(function(CurrencyTable)
		self:SetCurrencyValues(CurrencyTable)
	end)

	ChestEvent.OnClientEvent:Connect(function(cooldown) -- CHEST UI
		HandleCaseChestUI(cooldown)
	end)

	-- NEW: Reset states when player respawns
	d.localPlayer.CharacterAdded:Connect(function()
		resetStates()
	end)
end

-- ROUNDTYPE 1 : Normal Round
-- ROUNDTYPE 2 : Final Stand

function GuiModule:HandleButtonListeners()
	local ScreenGui,RoundFrame, ButtonFrame, CountButton, RoundLabel, leftFrame, finalStandButton, LastStandFrame ,CurrencyFrame, EmoteWheel = GetGui()

	local CountText = CountButton:WaitForChild("Text")

	d.DisableClick.OnClientEvent:Connect(function(p : Player)
		if p == d.localPlayer then
			CountButton.Interactable = false
		end
	end)

	CountButton.MouseButton1Click:Connect(function() -- NORMAL ROUND
		if clicked then return end
		finalStandButton.Visible = false
		finalStandButton.Interactable = false

		clicked = true
		CountText.Interactable = false
		ButtonEvent:FireServer(1) 

		CountText.Text = "CLICKED"
	end)

	finalStandButton.MouseButton1Click:Connect(function()  -- FINAL STAND
		TweenUtils:ShakeButton(finalStandButton)
		ButtonEvent:FireServer(2)
		task.wait(0.1)
	end)

end

-- Fixed VIP Chat System
local TextChatService = game:GetService("TextChatService")

function GuiModule:ChatVIP()
	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local properties = Instance.new("TextChatMessageProperties")

		if message.TextSource then
			local player = game.Players:GetPlayerByUserId(message.TextSource.UserId)

			-- Check if player exists and has the VIP attribute
			if player then
				local isVIP = player:GetAttribute("IsVIP")

				if isVIP == true then
					properties.PrefixText = "<font color='#FFD700'>[⭐ VIP]</font> " .. message.PrefixText
				end
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

	local RoundUIStroke = RoundLabel:FindFirstChild("UIStroke")
	local CountText = CountButton:WaitForChild("Text")

	-- Detect new InRound
	if RoundData.State == 2 and RoundData.newRound or RoundData.State == 6 then
		clicked = false  -- reset debounce at the start of the round
	end

	if RoundData.State == 0  then
		clicked = false
		ButtonFrame.Visible = false
		RoundLabel.Text = UiText.LoadingRound
	elseif RoundData.State == 67 then  -- WAITING FOR PLAYERS
		clicked = false
		ButtonFrame.Visible = false
		RoundLabel.Text = UiText.Waiting
	elseif RoundData.State == 69 then  -- Disable Button for the player.
		clicked = false
		ButtonFrame.Visible = false
		RoundLabel.Text = UiText.Waiting
	elseif RoundData.State == 1 then
		finishAnim = false
		animPlay = false
		clicked = false
		RoundLabel.Text = UiText.Intermission .. RoundData.Time
	elseif RoundData.State == 2 then
		RoundLabel.TextTransparency = 0
		RoundUIStroke.Transparency = 0
		RoundLabel.Text = UiText.InRound .. RoundData.Time

		if PlayersData and PlayersData.Alive and not PlayersData.Counted and PlayersData.isPlaying then
			HandleButtonUI(CountButton, ButtonFrame, finalStandButton,"normalRound")
		end

	elseif RoundData.State == 3 then
		RoundLabel.Text = UiText.NewInRound .. RoundData.Time
		ButtonFrame.Visible = false
	elseif RoundData.State == 4 then
		RoundLabel.Text = UiText.Eliminated .. RoundData.Time
		ButtonFrame.Visible = false
	elseif RoundData.State == 5 then

		local names = {}
		for _, player in pairs(RoundData.winners) do
			table.insert(names, player.Name)
		end

		RoundLabel.Text = UiText.Win .. table.concat(names, ", ")

		ButtonFrame.Visible = false
	elseif RoundData.State == 6 then
		RoundLabel.Text = UiText.LastStand .. RoundData.Time
		ButtonFrame.Visible = false

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
		RoundUIStroke.Transparency = 1
		if RoundData.Time <= 10 then
			if not playedIntro then
				playedIntro = true
				GuiModule:IntroAnim(ScreenGui)
			end
		end

	else
		warn("Error | RoundData.State")
	end

	-- Remember this state for the next update
	lastRoundState = RoundData.State
end

---------------------------------------------------------------------------------------------------------------------------------------------

HandleButtonUI = function(CountButton, ButtonFrame, finalStandButton, Action : string)
	if clicked then return end

	TweenUtils:TweenButton(CountButton)
	local CountText = CountButton:FindFirstChild("Text")

	ButtonFrame.Visible = true

	if Action == "normalRound" then

		finalStandButton.Visible = false
		finalStandButton.Interactable = false

		CountButton.Visible = true
		CountButton.Interactable = true
		CountText.Text = "Count"
		CountText.TextColor3 = Color3.fromRGB(255, 255, 255)

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


local function TweenOutLastStand(mainText, InfoTxt, LSF)


	local LSF_T = d.TweenService:Create(
		LSF,
		TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{
			BackgroundTransparency = 1,
		}
	)

	local mainOut = d.TweenService:Create(
		mainText,
		TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{
			Position = UDim2.new(0.5, 0, -4, 0),
		}
	)

	local infoOut = d.TweenService:Create(
		InfoTxt,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{
			Position = UDim2.new(0.5, 0, 4, 0),
		}
	)

	mainOut:Play()
	task.wait(0.35)
	infoOut:Play()
	mainOut.Completed:Wait()
	LSF_T:Play()
	TweenUtils.BG_Blur(false, 0)
	infoOut.Completed:Wait()
	LSF.Visible = false
	mainText.Parent.Visible = false


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
		UDim2.new(0.5, 0, 0.668, 0), -- D2
		UDim2.new(0.5, 0, 0.83, 0)  -- D3
	}

	local TweenOutPos = {
		UDim2.new(0.5, 0,0.45, 0),  -- ModeName
		UDim2.new(0.5, 0,0.58, 0), -- D1
		UDim2.new(0.5, 0,0.75, 0), -- D2
		UDim2.new(0.5, 0,0.86, 0)  -- D3
	}

	local oldPos = {	
		UDim2.new(0.5, 0,-2.35, 0),  -- ModeName
		UDim2.new(-2.5, 0,-0.536, 0), -- D1
		UDim2.new(1.5, 0,0.636, 0), -- D2
		UDim2.new(-0.5, 0,0.751, 0)  -- D3
	}

	local function TweenToPos()

		local TweenFrame = d.TweenService:Create(ModeFrame, T_INFO, {Transparency = 0.4})
		TweenFrame:Play()
		TweenFrame.Completed:Wait()

		for i, obj in ipairs(UITable) do
			local tween = d.TweenService:Create(obj, T_INFO, {Position = POSITIONS[i]})
			tween:Play()
			tween.Completed:Wait()	
		end
	end

	local function TweenOutScale1()
		for i, obj in ipairs(UITable) do
			if obj:FindFirstChild("UIScale") then
				local enlarge = d.TweenService:Create(obj.UIScale, T_INFO, {Scale = 1.2})
				enlarge:Play()
			end
		end
	end


	local function TweenOut()
		for i, obj in ipairs(UITable) do
			if obj:FindFirstChild("UIScale") then
				local tween = d.TweenService:Create(obj.UIScale, T_INFO, {Scale = 0})
				local tween1 = d.TweenService:Create(obj.UIStroke, T_INFO, {Transparency = 1})
				tween:Play()
				tween1:Play()
			end

			local tween = d.TweenService:Create(obj, T_INFO, {Position = TweenOutPos[i], TextTransparency = 1})
			tween:Play()
		end
	end	

	local function TweenOrig()
		local TweenFrame = d.TweenService:Create(ModeFrame, T_INFO, {Transparency = 1})
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

	TweenUtils:TweenButton(emoteBtn)

	local CoinsFolder = CurrencyFrame:WaitForChild("Coins")
	local WinsFolder = CurrencyFrame:WaitForChild("Wins")

	CoinsFolder:WaitForChild("CoinValue").Text = CurrencyTable.Coins
	WinsFolder:WaitForChild("WinValue").Text = CurrencyTable.Wins

	emoteBtn.MouseButton1Click:Connect(function()

		if self.isClicked then return end
		self.isClicked = true

		if not self.emoteDB then self:TweenEmotes(EmoteWheel, "open") MusicModule:PlaySFX("Click") TweenUtils.BG_Blur(true, 15) task.wait(0.5)  self.emoteDB = true self.isClicked = false return end
		if self.emoteDB then self:TweenEmotes(EmoteWheel, "close") MusicModule:PlaySFX("Click") TweenUtils.BG_Blur(false, 0) task.wait(0.5) self.emoteDB = false self.isClicked = false end
	end)

end


local tweenConns = {}
local tweenCache = {}

LastStandAnimation = function(LastStandFrame : Frame)

	local animConn = {}
	MusicModule:PlayMusic("STOP")

	MusicModule:PlayMusic("FinalStand")
	
	local MF = LastStandFrame:WaitForChild("MainFrame")
	local mainText = MF:WaitForChild("mainTxt")
	local InfoTxt = MF:WaitForChild("Info")

	local ParentFrameTween = d.TweenService:Create(
		LastStandFrame,
		TweenInfo.new(0.8, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{BackgroundTransparency = 0.3} 
	)

	local mainTween = d.TweenService:Create(
		mainText,
		TweenInfo.new(0.8, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Position = UDim2.new(0.5, 0, 0.5, 0)}
	)
	
	local InfoTween = d.TweenService:Create(
		InfoTxt, TweenInfo.new(0.8, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Position = UDim2.new(0.5, 0, 0.83, 0)}
	)
	
	MF.Visible = true
	LastStandFrame.Visible = true
	ParentFrameTween:Play()
	TweenUtils.BG_Blur(true, 15)
	ParentFrameTween.Completed:Wait()
	mainTween:Play()
	task.wait(1)
	InfoTween:play()
	wait(3)

	TweenOutLastStand(mainText, InfoTxt, LastStandFrame)

end


---------------------------------------------------------------------------------------------------------------------------------------------

return GuiModule