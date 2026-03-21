local DailyReward = {}

local d = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Directory"))



-- Modules
local MusicModule = require(d.Modules:WaitForChild("MusicModule"))
local GuiModule = require(d.Modules:WaitForChild("GuiModule"))
local TweenUtils = require(d.Modules:WaitForChild("TweenUtils"))

-- Configs
local ClaimColor = Color3.fromRGB(60, 229, 48)

local FetchDailyRewardFrame
local formatTime

local cd = -1
local initialized = false
local connections = {} -- store connections for cleanup
local activeTimer = nil -- Variable at the top of your script to track the thread

local animationThreads = {}

------------------------------------------------------------------------------------------------------------------

function DailyReward:InitializeAnimations(framesTable)
	for key, thread in pairs(animationThreads) do
		task.cancel(thread)
	end
	table.clear(animationThreads)

	-- Find Day 7 frame and set up animations
	for index, frame in ipairs(framesTable) do
		if index == 7 then
			local ray = frame:FindFirstChild("ray")
			local caseImage = frame:FindFirstChild("CaseImage")

			if ray then
				animationThreads["raySpin"] = task.spawn(function()
					TweenUtils:SpinUI(ray, 5)
				end)
			end

			if caseImage then
				animationThreads["IdleFloat"] = task.spawn(function()
					TweenUtils:SetIdleFloat(caseImage, 2.3, 0.02)
				end)
			end
		end
	end

end

FetchDailyRewardFrame = function()

	local ScreenGui = d.localPlayer:WaitForChild("PlayerGui"):WaitForChild("UI"):WaitForChild("ScreenGui")
	ScreenGui.ResetOnSpawn = false

	local framesTable = {}

	local SF = ScreenGui:WaitForChild("ShopUI")
	local IF = ScreenGui:WaitForChild("Inventory")

	local leftFrame = ScreenGui:WaitForChild("LeftFrame")
	local DailyRewardFrame = ScreenGui:WaitForChild("DailyRewards")
	local ExitButton = DailyRewardFrame:WaitForChild("Exit")

	for _, Frames in pairs(DailyRewardFrame:WaitForChild("UI"):GetChildren()) do
		if Frames:IsA("Frame") then
			table.insert(framesTable, Frames)
		end
	end

	table.sort(framesTable, function(a, b)
		return a.Name < b.Name
	end)

	return DailyRewardFrame, ExitButton, framesTable, leftFrame, SF, IF
end

local DailyRewardFrame, ExitButton, framesTable, leftFrame, SF, IF = FetchDailyRewardFrame()

------------------------------------------------------------------------------------------------------------------


function DailyReward:DisconnectConnections()
	for _, conn in ipairs(connections) do
		conn:Disconnect()
	end
	table.clear(connections)
end

function DailyReward:Init()
	
	if initialized then
		initialized = false
	end
	initialized = true

	self:DisconnectConnections()

	DailyRewardFrame, ExitButton, framesTable, leftFrame, SF, IF = FetchDailyRewardFrame()

	DailyReward:HandleButtonListeners(framesTable, SF, IF)

	-- NEW: Initialize animations once
	DailyReward:InitializeAnimations(framesTable)
end
------------------------------------------------------------------------------------------------------------------


local function BindMainButtons()
	for _, conn in ipairs(connections) do
		conn:Disconnect()
	end
	table.clear(connections)

	table.insert(connections, leftFrame.DailyRewards.MouseButton1Click:Connect(function()
		DailyRewardFrame.Visible = true
	end))

	table.insert(connections, ExitButton.MouseButton1Click:Connect(function()
		DailyRewardFrame.Visible = false
		TweenUtils.BG_Blur(false, 0)
	end))
end

BindMainButtons()

------------------------------------------------------------------------------------------------------------------

d.DailyEvent.OnClientEvent:Connect(function(Day, status : string, cooldownTime : number, claimedStatus : boolean)

	if status == "update" then
		-- CANCEL the active timer before updating UI
		if activeTimer then 
			task.cancel(activeTimer)
			activeTimer = nil
			print("Cancelled active timer")
		end

		DailyReward:UpdateUI(Day, framesTable, claimedStatus)

		-- Start timer on NEXT day only if current day is claimed
		local daynumber = tonumber(Day)
		if  claimedStatus and cooldownTime > 0 then
			local dayNumber = tonumber(Day)
			local nextDayIndex = (dayNumber % #framesTable) + 1
			DailyReward:UpdateTimerUI(nextDayIndex, framesTable, cooldownTime)
		end

	elseif status == "claimed" then
		DailyReward:HandleClaimed(framesTable, Day, cooldownTime)
	end

end)
------------------------------------------------------------------------------------------------------------------

d.localPlayer.CharacterAdded:Connect(function()

	local playerGui = d.localPlayer:WaitForChild("PlayerGui")
	local ui = playerGui:WaitForChild("UI")
	local screenGui = ui:WaitForChild("ScreenGui")

	cd = -1
	initialized = false

	DailyReward:Init()

	task.wait(1.5)

	d.InitEvent:FireServer()
end)

------------------------------------------------------------------------------------------------------------------
function DailyReward:HandleButtonListeners(framesTable, SF, IF)
	self:DisconnectConnections()

	-- Tween configs for day buttons
	local hoverInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local clickInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

	for i, frames in ipairs(framesTable) do
		local button = frames:WaitForChild("TextButton")
		if button then
			local normalSize = button.Size
			local hoverSize = UDim2.new(normalSize.X.Scale * 1.05, 0, normalSize.Y.Scale * 1.05, 0)
			local clickSize = UDim2.new(normalSize.X.Scale * 0.95, 0, normalSize.Y.Scale * 0.95, 0)

			-- Click handler
			table.insert(connections, button.MouseButton1Click:Connect(function()
				if button:GetAttribute("isLocked") == false then
					MusicModule:PlaySFX("Coin")
					d.DailyEvent:FireServer(frames.Name)
				else
					warn("LOCKED")
					MusicModule:PlaySFX("Error")
				end
			end))

			-- Hover effects
			table.insert(connections, button.MouseEnter:Connect(function()
				if button:GetAttribute("isLocked") == false then
					MusicModule:PlaySFX("Hover")
					d.TweenService:Create(button, hoverInfo, {Size = hoverSize}):Play()
				end
			end))

			table.insert(connections, button.MouseLeave:Connect(function()
				d.TweenService:Create(button, hoverInfo, {Size = normalSize}):Play()
			end))

			-- Click down/up effects
			table.insert(connections, button.MouseButton1Down:Connect(function()
				if button:GetAttribute("isLocked") == false then
					d.TweenService:Create(button, clickInfo, {Size = clickSize}):Play()
				end
			end))

			table.insert(connections, button.MouseButton1Up:Connect(function()
				d.TweenService:Create(button, clickInfo, {Size = normalSize}):Play()
			end))
		end
	end

	---------HOVER EFFECTS FOR MAIN DAILY REWARDS BUTTON---------

	--------- UI ELEMENTS & SIZES ---------
	local DailyRewardsBtn = leftFrame.DailyRewards
	local normalSize = DailyRewardsBtn.Size
	local hoverSize = UDim2.new(normalSize.X.Scale * 1.1, 0, normalSize.Y.Scale * 1.1, 0)
	local clickSize = UDim2.new(normalSize.X.Scale * 0.9, 0, normalSize.Y.Scale * 0.9, 0)

	local sizeTween = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local clickInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	local isHovering = false -- Track hover state for the release return

	--------- HOVER LOGIC ---------
	table.insert(connections, DailyRewardsBtn.MouseEnter:Connect(function()
		isHovering = true
		MusicModule:PlaySFX("Hover")
		d.TweenService:Create(DailyRewardsBtn, sizeTween, {Size = hoverSize}):Play()
	end))

	table.insert(connections, DailyRewardsBtn.MouseLeave:Connect(function()
		isHovering = false
		d.TweenService:Create(DailyRewardsBtn, sizeTween, {Size = normalSize}):Play()
	end))

	--------- CLICK LOGIC ---------
	-- 1. Press Down (Shrink)
	table.insert(connections, DailyRewardsBtn.MouseButton1Down:Connect(function()
		d.TweenService:Create(DailyRewardsBtn, clickInfo, {Size = clickSize}):Play()
	end))

	-- 2. Release (Pop back to Hover or Normal)
	table.insert(connections, DailyRewardsBtn.MouseButton1Up:Connect(function()
		local targetSize = isHovering and hoverSize or normalSize
		d.TweenService:Create(DailyRewardsBtn, clickInfo, {Size = targetSize}):Play()
	end))

	-- 3. The Main Click Action
	table.insert(connections, DailyRewardsBtn.MouseButton1Click:Connect(function()
		MusicModule:PlaySFX("Click")

		local isAlreadyOpen = DailyRewardFrame.Visible
		DailyRewardFrame.Visible = not isAlreadyOpen

		if not isAlreadyOpen then
			TweenUtils.BG_Blur(not isAlreadyOpen, 15)
		else
			TweenUtils.BG_Blur(not isAlreadyOpen, 0)
		end

		SF.Visible = false
		IF.Visible = false

		GuiModule.FramesValue.DF = not isAlreadyOpen
		GuiModule.FramesValue.SF = false
		GuiModule.FramesValue.IF = false
	end))

	-- Exit Button (Clean return to normal)
	table.insert(connections, ExitButton.MouseButton1Click:Connect(function()
		MusicModule:PlaySFX("Click")
		DailyRewardFrame.Visible = false
		TweenUtils.BG_Blur(false, 0)
	end))
end

------------------------------------------------------------------------------------------------------------------

function DailyReward:HandleClaimed(FrameTable, Day, cooldownTime)
	local dayNumber = tonumber(Day)
	print(dayNumber)
	if not dayNumber then return end

	local ClaimedFrame = FrameTable[dayNumber]
	if not ClaimedFrame then return end

	local TextButton = ClaimedFrame:WaitForChild("TextButton")
	local StatusLabel = TextButton:FindFirstChild("_Text")
	local ClaimedBG = ClaimedFrame:WaitForChild("Claimed")

	-- 1. Update the claimed day visuals
	if StatusLabel then
		StatusLabel.Text = "CLAIMED"
		StatusLabel.TextColor3 = Color3.fromRGB(27, 175, 32)
	else
		TextButton.Text = "CLAIMED"
	end

	TextButton:SetAttribute("isLocked", true)
	TextButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
	ClaimedBG.Visible = true

	-- 2. Start timer on the NEXT day
	local nextDayIndex = (dayNumber % #FrameTable) + 1
	self:UpdateTimerUI(nextDayIndex, FrameTable, cooldownTime or 86400)
end
------------------------------------------------------------------------------------------------------------------
function DailyReward:UpdateUI(Day, framesTable, claimedStatus)
	local currentDay = tonumber(Day)

	-- Special case: Day 0 means completed cycle, Day 1 is claimable
	if currentDay == 0 then
		for index, frame in ipairs(framesTable) do
			local TextButton = frame:WaitForChild("TextButton")
			local _Text = TextButton:FindFirstChild("_Text") or TextButton
			local Veil = frame:WaitForChild("Veil")
			local ClaimedBG = frame:WaitForChild("Claimed")

			if index == 1 then
				-- Day 1 is ready to claim to restart the cycle
				_Text.Text = "CLAIM"
				_Text.TextColor3 = Color3.fromRGB(255, 255, 255)
				TextButton:SetAttribute("isLocked", false)
				TextButton.BackgroundColor3 = ClaimColor

				Veil.Visible = false
				ClaimedBG.Visible = false
			else
				-- All other days are locked
				_Text.Text = "LOCKED"
				_Text.TextColor3 = Color3.fromRGB(229, 50, 19)
				TextButton:SetAttribute("isLocked", true)
				TextButton.BackgroundColor3 = Color3.fromRGB(229, 50, 19)

				Veil.Visible = true
				ClaimedBG.Visible = false
			end
		end
		return -- Exit early for Day 0 case
	end

	-- Normal flow for Days 1-7
	for index, frame in ipairs(framesTable) do
		local TextButton = frame:WaitForChild("TextButton")
		local _Text = TextButton:FindFirstChild("_Text") or TextButton
		local Veil = frame:WaitForChild("Veil")
		local ClaimedBG = frame:WaitForChild("Claimed")

		if index < currentDay then
			-- Past days - already claimed
			_Text.Text = "CLAIMED"
			_Text.TextColor3 = Color3.fromRGB(27, 175, 32)
			TextButton:SetAttribute("isLocked", true)
			TextButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)

			Veil.Visible = false
			ClaimedBG.Visible = true

		elseif index == currentDay then
			-- Current day
			if claimedStatus then
				-- Player already claimed today
				_Text.Text = "CLAIMED"
				_Text.TextColor3 = Color3.fromRGB(27, 175, 32)
				TextButton:SetAttribute("isLocked", true)
				TextButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)

				Veil.Visible = false
				ClaimedBG.Visible = true
			else
				-- Player hasn't claimed today
				_Text.Text = "CLAIM"
				_Text.TextColor3 = Color3.fromRGB(255, 255, 255)
				TextButton:SetAttribute("isLocked", false)
				TextButton.BackgroundColor3 = ClaimColor


				Veil.Visible = false
				ClaimedBG.Visible = false
			end

		else
			-- Future days (locked)
			_Text.Text = "LOCKED"
			_Text.TextColor3 = Color3.fromRGB(229, 50, 19)
			TextButton:SetAttribute("isLocked", true)
			TextButton.BackgroundColor3 = Color3.fromRGB(229, 50, 19)

			if TextButton:FindFirstChild("UIStroke") then
				TextButton.UIStroke.Color = Color3.fromRGB(229, 50, 19)
			end

			Veil.Visible = true
			ClaimedBG.Visible = false
		end
	end
end

function DailyReward:UpdateTimerUI(dayNumber, FrameTable, cooldownTime)
	-- dayNumber is already the day we want to show the timer on
	local nextDayFrame = FrameTable[dayNumber]
	if not nextDayFrame then return end

	local Veil = nextDayFrame:WaitForChild("Veil")
	local cooldownText = Veil:WaitForChild("cooldownText")
	local nextDayButton = nextDayFrame:WaitForChild("TextButton")
	local nextDayText = nextDayButton:FindFirstChild("_Text") or nextDayButton

	Veil.Visible = true

	if nextDayText then
		nextDayText.Text = "LOCKED"
		nextDayText.TextColor3 = Color3.fromRGB(229, 50, 19)
	end

	nextDayButton:SetAttribute("isLocked", true)
	nextDayButton.BackgroundColor3 = Color3.fromRGB(229, 50, 19)

	-- Cancel any existing timer
	if activeTimer then task.cancel(activeTimer) end

	-- REMOVE 'local' HERE - use the module-level variable
	activeTimer = task.spawn(function()
		while cooldownTime > 0 do
			cooldownText.Text = formatTime(cooldownTime)
			task.wait(1)
			cooldownTime -= 1
			cd = cooldownTime
		end

		-- Cooldown finished - request server update
		cd = 0

		print("Timer finished, requesting server update...")
		d.InitEvent:FireServer()

		activeTimer = nil
	end)
end
------------------------------------------------------------------------------------------------------------------

formatTime = function(seconds)
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = seconds % 60
	return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

------------------------------------------------------------------------------------------------------------------

return DailyReward