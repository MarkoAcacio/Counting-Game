local DailyReward = {}

local d = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Directory"))



-- Modules
local MusicModule = require(d.Modules:WaitForChild("MusicModule"))


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

	return DailyRewardFrame, ExitButton, framesTable, leftFrame
end

local DailyRewardFrame, ExitButton, framesTable, leftFrame = FetchDailyRewardFrame()

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

	DailyRewardFrame, ExitButton, framesTable, leftFrame = FetchDailyRewardFrame()

	DailyReward:HandleButtonListeners(framesTable)
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
		DailyReward:UpdateTimerUI(Day, framesTable,cooldownTime)
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
function DailyReward:HandleButtonListeners(framesTable)
	self:DisconnectConnections()

	for i, frames in ipairs(framesTable) do
		local button = frames:WaitForChild("TextButton")
		if button then
			table.insert(connections, button.MouseButton1Click:Connect(function()
				if button:GetAttribute("isLocked") == false then
					d.DailyEvent:FireServer(frames.Name)
				else
					warn("LOCKED")
					MusicModule:PlaySFX("Error")
				end
			end))
		end
	end

	---------HOVER EFFECTS---------
	
	local DailyRewardsBtn = leftFrame.DailyRewards
	local normalSize = DailyRewardsBtn.Size
	local hoverSize = UDim2.new(normalSize.X.Scale * 1.1, 0, normalSize.Y.Scale * 1.1, 0)
	
	local sizeTween = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	
	table.insert(connections, DailyRewardsBtn.MouseEnter:Connect(function()
		local tween = d.TweenService:Create(DailyRewardsBtn, sizeTween, {Size = hoverSize})
		MusicModule:PlaySFX("Hover")
		tween:Play()
	end))
	
	table.insert(connections, DailyRewardsBtn.MouseLeave:Connect(function()
		local tween = d.TweenService:Create(DailyRewardsBtn, sizeTween, {Size = normalSize})
		tween:Play()
	end))
	
	-------------------------------
	table.insert(connections, DailyRewardsBtn.MouseButton1Click:Connect(function()
		MusicModule:PlaySFX("Click")
		DailyRewardFrame.Visible = true
	end))
	
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

	-- 1. Mark the CURRENT day as claimed immediately
	local TextButton = ClaimedFrame:WaitForChild("TextButton")
	TextButton.Text = "CLAIMED"
	TextButton:SetAttribute("isLocked", true)
	TextButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
	TextButton.TextColor3 = Color3.fromRGB(255, 255, 255)

	-- 2. Determine the Next Day
	local nextIndex = dayNumber + 1
	if nextIndex > #FrameTable then
		nextIndex = 1 -- Loop back to Day 1 if they finished the week
	end

	local nextDayFrame = FrameTable[nextIndex]

	-- 3. Start the timer for the NEXT day
	-- We assume the cooldown is 24 hours (86400 seconds) 
	-- or whatever your server default is.
	local DEFAULT_COOLDOWN = 86400 

	-- Call the timer function manually so the player sees it start
	self:UpdateTimerUI(dayNumber, FrameTable, DEFAULT_COOLDOWN)
end
------------------------------------------------------------------------------------------------------------------

function DailyReward:UpdateUI(Day ,framesTable, claimedStatus)
	-- Mark all past days as claimed
	for index, frame in ipairs(framesTable) do
		local TextButton = frame:WaitForChild("TextButton")

		if index < Day then
			TextButton.Text = "CLAIMED"
			TextButton:SetAttribute("isLocked", true)
			TextButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
			TextButton.TextColor3 = Color3.fromRGB(255, 255, 255)
			TextButton.UIStroke.Color = Color3.fromRGB(100, 100, 100)
			frame.Veil.Visible = false
		elseif index == Day then
			-- Current day
			if claimedStatus then
				TextButton.Text = "CLAIMED"
				TextButton:SetAttribute("isLocked", true)
				TextButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
				TextButton.TextColor3 = Color3.fromRGB(255, 255, 255)
				TextButton.UIStroke.Color = Color3.fromRGB(100, 100, 100)
				frame.Veil.Visible = false
			else
				TextButton.Text = "CLAIM"
				TextButton:SetAttribute("isLocked", false)
				TextButton.BackgroundColor3 = Color3.fromRGB(60, 229, 48)
				frame.Veil.Visible = false
			end
		else
			-- Future days (locked)
			TextButton.Text = "LOCKED"
			TextButton:SetAttribute("isLocked", true)
			TextButton.BackgroundColor3 = Color3.fromRGB(229, 50, 19)
			frame.Veil.Visible = true
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
