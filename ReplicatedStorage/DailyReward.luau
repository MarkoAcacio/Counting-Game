local DailyReward = {}

local d = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Directory"))



-- Modules
local MusicModule = require(d.Modules:WaitForChild("MusicModule"))
local GuiModule = require(d.Modules:WaitForChild("GuiModule"))


-- Configs
local ClaimColor = Color3.fromRGB(60, 229, 48)

local FetchDailyRewardFrame
local formatTime

local cd = -1
local initialized = false
local connections = {} -- store connections for cleanup

------------------------------------------------------------------------------------------------------------------

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
	end))
end

BindMainButtons()

------------------------------------------------------------------------------------------------------------------

d.DailyEvent.OnClientEvent:Connect(function(Day, status : string, cooldownTime : number, claimedStatus : boolean)

	if status == "update" then
		DailyReward:UpdateUI(Day, framesTable, claimedStatus)

		-- FIXED: Only start timer if player has claimed current day
		if claimedStatus and cooldownTime > 0 then
			DailyReward:UpdateTimerUI(Day, framesTable, cooldownTime)
		end
	elseif status == "claimed" then
		DailyReward:HandleClaimed(framesTable, Day)
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
					MusicModule:PlaySFX("Claim")
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
	end))
end

------------------------------------------------------------------------------------------------------------------

function DailyReward:HandleClaimed(FrameTable, Day)
	local dayNumber = tonumber(Day)
	if not dayNumber then return end

	local ClaimedFrame = FrameTable[dayNumber]
	if not ClaimedFrame then return end

	local TextButton = ClaimedFrame:WaitForChild("TextButton")
	local StatusLabel = TextButton:FindFirstChild("_Text") -- Using FindFirstChild for safety
	local ClaimedBG = ClaimedFrame:WaitForChild("Claimed")

	-- 1. INSTANT VISUAL UPDATE
	if StatusLabel then
		StatusLabel.Text = "CLAIMED"
		StatusLabel.TextColor3 = Color3.fromRGB(27, 175, 32) -- Your green color
	else
		-- Fallback if the label is actually the button's own text
		TextButton.Text = "CLAIMED"
	end

	TextButton:SetAttribute("isLocked", true)
	TextButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
	ClaimedBG.Visible = true

	-- 2. Determine and Start Timer for Next Day
	local nextIndex = (dayNumber % #FrameTable) + 1
	local DEFAULT_COOLDOWN = 86400 

	self:UpdateTimerUI(dayNumber, FrameTable, DEFAULT_COOLDOWN)
end
------------------------------------------------------------------------------------------------------------------

function DailyReward:UpdateUI(Day, framesTable, claimedStatus)
	-- Iterate through all 7 day frames
	for index, frame in ipairs(framesTable) do
		local TextButton = frame:WaitForChild("TextButton")
		local _Text = TextButton._Text
		local Veil = frame:WaitForChild("Veil")
		-- 1. Reference the new Claimed image/frame from your hierarchy
		local ClaimedBG = frame:WaitForChild("Claimed") 

		if index < Day then
			-- 2. Past days - already claimed
			_Text.Text = "CLAIMED"
			TextButton:SetAttribute("isLocked", true)

			-- Grey out the button
			_Text.TextColor3 = Color3.fromRGB(27, 175, 32) 

			Veil.Visible = false
			-- 3. Make the Claimed image visible
			ClaimedBG.Visible = true 

		elseif index == Day then
			-- Current day
			if claimedStatus then
				-- Player already claimed today, lock it and show claimed status
				_Text.Text = "CLAIMED"
				_Text:SetAttribute("isLocked", true)
				_Text.TextColor3 = Color3.fromRGB(27, 175, 32) 

				Veil.Visible = false
				ClaimedBG.Visible = true -- Show claimed image
			else
				-- Player hasn't claimed today, allow claiming
				_Text.Text = "CLAIM"
				TextButton:SetAttribute("isLocked", false)

				Veil.Visible = false
				ClaimedBG.Visible = false -- Hide claimed image
			end

		else
			-- Future days (locked)
			_Text.Text = "LOCKED"
			TextButton:SetAttribute("isLocked", true)
			_Text.TextColor3 = Color3.fromRGB(229, 50, 19) -- Red

			Veil.Visible = true -- Keep veil (with countdown) visible
			ClaimedBG.Visible = false -- Hide claimed image
		end
	end
end

local activeTimer = nil -- Variable at the top of your script to track the thread

function DailyReward:UpdateTimerUI(Day, FrameTable, cooldownTime)
	local dayNumber = tonumber(Day)
	local nextIndex = (dayNumber % #FrameTable) + 1
	local nextDayFrame = FrameTable[nextIndex]

	local Veil = nextDayFrame:WaitForChild("Veil")
	local cooldownText = Veil:WaitForChild("cooldownText")
	local nextDayButton = nextDayFrame:WaitForChild("TextButton")

	Veil.Visible = true
	nextDayButton.Text = "LOCKED"
	nextDayButton:SetAttribute("isLocked", true)
	nextDayButton.BackgroundColor3 = Color3.fromRGB(229, 50, 19)

	-- Cancel any existing timer thread to prevent speed-up bugs
	if activeTimer then task.cancel(activeTimer) end

	activeTimer = task.spawn(function()
		while cooldownTime > 0 do
			cooldownText.Text = formatTime(cooldownTime)
			task.wait(1)
			cooldownTime -= 1
			cd = cooldownTime
		end

		-- Cooldown Finished!
		cd = 0
		nextDayButton.Text = "CLAIM"
		nextDayButton:SetAttribute("isLocked", false)
		nextDayButton.BackgroundColor3 = ClaimColor
		nextDayButton.UIStroke.Color = ClaimColor
		Veil.Visible = false
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