local DailyRewardServer = {}

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

local _24Hours = 86400

local FetchDailyRewardFrame
local HandleReward

------------------------------------------------------------------------------------------------------------------

function DailyRewardServer:Init(player)
	local cooldown = DailyRewardServer:GetTime(player)
	DailyEvent:FireClient(player, DataManager.getDay(player), "update", cooldown, DataManager.getClaimed(player))
end

function DailyRewardServer:GetTime(player)
	local lastClaim = DataManager.getDailyRewardTime(player)
	local cooldown = _24Hours - (os.time() - lastClaim) or 0
	
	return cooldown
end

-- HANDLE GIVING OF REWARD IN SERVER
DailyEvent.OnServerEvent:Connect(function(Player, Day)
	DailyRewardServer:isClaimable(Player, Day)
end)

------------------------------------------------------------------------------------------------------------------

-- THIS IS THE PROBLEM, THIS SHOULD BE THE NEXT FRAME, NOT CURRENT FRAME.

function DailyRewardServer:isClaimable(Player, Day)
	local lastClaim = DataManager.getDailyRewardTime(Player)
	local nextDay = DataManager.getDay(Player) + 1
	local cooldown = _24Hours - (os.time() - lastClaim) or 0
	
	
	if tonumber(Day) == DataManager.getDay(Player) then
		HandleReward(Player, Day, cooldown)
	end
	
	if cooldown <= 0 then
		DataManager.setDailyRewardTime(Player, os.time())
		DataManager.setClaimed(Player, false)
		HandleReward(Player, Day, cooldown)
		
	end
	
	return true
end


------------------------------------------------------------------------------------------------------------------

HandleReward = function(Player,Day, cooldownTime)
	print("HandleReward")
	print("Day : ", Day)
	print("Cooldown : ", cooldownTime)
	
	local claimStatus = DataManager.getClaimed(Player)
	
	--print("Player : ", Player)
	if Day == "1" and claimStatus == false then
		DataManager.AddCoins(Player, 10)
		DataManager.setDay(Player, 1)
		DataManager.setClaimed(Player, true)
		print("Sending Event -> Local")
		DailyEvent:FireClient(Player, Day, "claimed", cooldownTime)
		print("DAY 1 Reward : 10C")
	elseif Day == "2" and claimStatus == false	then
		DataManager.AddCoins(Player, 30)
		DataManager.setDay(Player, 2)
		DataManager.setClaimed(Player, true)
		print("Sending Event -> Local")
		DailyEvent:FireClient(Player, Day, "claimed", cooldownTime)
		print("DAY 2 Reward : 30C")
	elseif Day == "3" and claimStatus == false then
		DataManager.AddCoins(Player, 80)
		DataManager.setDay(Player, 3)
		DataManager.setClaimed(Player, true)
		print("Sending Event -> Local")
		DailyEvent:FireClient(Player, Day, "claimed", cooldownTime)
		print("DAY 3 Reward : 80C")
	elseif Day == "4" and claimStatus == false then
		DataManager.AddCoins(Player, 120)
		DataManager.setDay(Player, 4)
		DataManager.setClaimed(Player, true)
		DailyEvent:FireClient(Player, Day, "claimed", cooldownTime)
		print("DAY 4 Reward : 120C")
	elseif Day == "5" and claimStatus == false then
		DataManager.AddCoins(Player, 200)
		DataManager.setDay(Player, 5)
		DataManager.setClaimed(Player, true)
		DailyEvent:FireClient(Player, Day, "claimed", cooldownTime)
		print("DAY 5 Reward : 200C")
	elseif Day == "6" and claimStatus == false then
		DataManager.AddCoins(Player, 300)
		DataManager.setDay(Player, 6)
		DataManager.setClaimed(Player, true)
		DailyEvent:FireClient(Player, Day, "claimed", cooldownTime)
		print("DAY 6 Reward : 300C")
	elseif Day == "7" and claimStatus == false then
		DailyEvent:FireClient(Player, Day, "claimed", cooldownTime)
		
		-- WHEN CLAIM, RESET UI!
		DataManager.setDay(Player, 1)
		DataManager.setClaimed(Player, true)
		print("DAY 7 Reward : EMOTE")
	end
end

------------------------------------------------------------------------------------------------------------------

return DailyRewardServer
