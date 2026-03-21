local DailyRewardServer = {}

local d = require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Directory"))

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SSS = game:GetService("ServerScriptService")

-- Folders
local EventsFolder = ReplicatedStorage:WaitForChild("Events")

-- Events
local DailyEvent = EventsFolder:WaitForChild("DailyEvent")
local DataManager = require(SSS:WaitForChild("Data"):WaitForChild("DataManager"))
local InventoryHandler = require(d.Modules:WaitForChild("InventoryHandler"))

local _24Hours = 0--86400

local FetchDailyRewardFrame
local HandleReward

------------------------------------------------------------------------------------------------------------------

function DailyRewardServer:Init(player)
	local lastClaim = DataManager.getDailyRewardTime(player)
	local currentDay = DataManager.getDay(player)
	local claimStatus = DataManager.getClaimed(player)
	local cooldown = _24Hours - (os.time() - lastClaim)
	
	print(currentDay)

	if cooldown < 0 then cooldown = 0 end
	
	if currentDay == 0 then
		DataManager.setClaimed(player, false)
	end

	if cooldown <= 0 and claimStatus == true and currentDay ~= 0 then
		local nextDay = (currentDay % 7) + 1
		DataManager.setDay(player, nextDay)
		DataManager.setClaimed(player, false)

		currentDay = nextDay
		claimStatus = false
		cooldown = 0

		print("Auto-advanced " .. player.Name .. " to Day " .. nextDay)
	end

	DailyEvent:FireClient(player, currentDay, "update", cooldown, claimStatus)
end



-- HANDLE GIVING OF REWARD IN SERVER
DailyEvent.OnServerEvent:Connect(function(Player, Day)
	DailyRewardServer:isClaimable(Player, Day)
end)

------------------------------------------------------------------------------------------------------------------

-- THIS IS THE PROBLEM, THIS SHOULD BE THE NEXT FRAME, NOT CURRENT FRAME.

function DailyRewardServer:isClaimable(Player, Day)
	local lastClaim = DataManager.getDailyRewardTime(Player)
	local currentDay = DataManager.getDay(Player)
	local claimStatus = DataManager.getClaimed(Player)
	local cooldown = _24Hours - (os.time() - lastClaim)

	-- Check if cooldown has expired (new day available)
	if cooldown <= 0 and claimStatus == true and currentDay > 0 then
		-- Advance to next day
		print("WADAHSDHADS")
		local nextDay = (currentDay % 7) + 1
		DataManager.setDay(Player, nextDay)
		DataManager.setClaimed(Player, false)
		DataManager.setDailyRewardTime(Player, os.time())
		currentDay = nextDay
		claimStatus = false
	end
	
	if currentDay == 0 and tonumber(Day) == 1 then
		HandleReward(Player, Day, _24Hours)
		return
	end

	-- Only allow claiming if clicked day matches current day and not claimed
	if tonumber(Day) == currentDay and claimStatus == false then
		HandleReward(Player, Day, _24Hours)
	else
		warn("Cannot claim Day " .. Day .. ". Current day is " .. currentDay .. ", Claimed: " .. tostring(claimStatus))
	end
end

------------------------------------------------------------------------------------------------------------------
local currentCase = "PremiumCase"  -- Current Case Banner
HandleReward = function(Player, Day, cooldownTime)
	local claimStatus = DataManager.getClaimed(Player)

	print(Day)

	if claimStatus == true then 
		warn("Already claimed today!")
		return 
	end

	local dayNum = tonumber(Day)
	local rewards = {30, 80, 120, 250, 350, 500, 0} -- 0 for Day 7 ( CASES )
	
	if dayNum == 0  then
		DataManager.setClaimed(Player, false)
		DailyEvent:FireClient(Player, Day, "claimed", _24Hours, true)
		return
	end

	if dayNum >= 1 and dayNum <= 7 then
		if dayNum  < 7 then
			DataManager.AddCoins(Player, rewards[dayNum])
			InventoryHandler:UpdateInventory(Player)
		end

		-- Set claimed to true first
		DataManager.setClaimed(Player, true)
		DataManager.setDailyRewardTime(Player, os.time())

		-- For Day 7, reset to Day 1, otherwise stay on current day
		if dayNum == 7 then
			local caseData = {
				caseName = currentCase,
				caseIncrement = 3
			}
			InventoryHandler:AddToInventory(Player, "case", caseData)
			DataManager.setDay(Player, 0) -- Reset to Day 1
		else
			DataManager.setDay(Player, dayNum)
			print("DAY " .. Day .. " Reward : " .. rewards[dayNum] .. "C")
		end

		-- Send claimed event
		DailyEvent:FireClient(Player, Day, "claimed", _24Hours, true)

		-- If Day 7, also send an update to refresh the entire UI
		if dayNum == 7 then
			task.wait(0.1) -- Small delay to let claimed animation finish
			DailyEvent:FireClient(Player, 0, "update", _24Hours, true)
		end
	end
end

------------------------------------------------------------------------------------------------------------------

return DailyRewardServer
