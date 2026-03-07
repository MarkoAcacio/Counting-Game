local CaseModule = {}

-- Services
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local SSS = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Folders
local ModuleFolder = ServerStorage:WaitForChild("Modules")
local InteractablesFolder = ModuleFolder:WaitForChild("Interactables")
local ChestCasesFolder = workspace:WaitForChild("Lobby"):WaitForChild("Models"):WaitForChild("Chest_Cases")
local EventsFolder = ReplicatedStorage:WaitForChild("Events")

-- Modules
local CaseProperties = require(InteractablesFolder:WaitForChild("CaseProperties"))
local DataManager = require(SSS:WaitForChild("Data"):WaitForChild("DataManager"))
local InventoryHandler = require(ModuleFolder:WaitForChild("InventoryHandler"))

-- Events

local SFXEvent = EventsFolder:WaitForChild("SFXEvent")
local MusicEvent = EventsFolder:WaitForChild("MusicEvent")
local GachaUIEvent = EventsFolder:WaitForChild("GachaUI")
local ProductEvent = EventsFolder:WaitForChild("ProductEvent")



-- Variables&Functions
local handleTime -- Get's the time
local handleClaim  -- Claiming for chest
local handleOpen -- Opening for cases
local handlePurchase -- Purchasing for cases
local handleName

local getCaseItem -- Either Emote or Death

local checkPlayerCoins

local isGroupMember
local GroupID = 228201671

local getCooldownTime

-- Events

local ChestEvent = EventsFolder:WaitForChild("ChestEvent")
local startListener




------------------------------------------------------------------------------------------------------------------------------------


function CaseModule:Init()
	startListener()
end

function CaseModule:HandleChestUI(player)
	
	task.spawn(function()
		while player and player.Parent do
			local cooldown = getCooldownTime(player)
			if cooldown <= 0 then
				ChestEvent:fireClient(player, cooldown)
				break
			else
				ChestEvent:fireClient(player, cooldown)
			end
			wait(1)
		end
	end)
	
end

------------------------------------------------------------------------------------------------------------------------------------

startListener = function()
	for _, model in pairs(ChestCasesFolder:GetChildren()) do
		if model:IsA("Model") then
			local meshPart = model:FindFirstChild("Mesh")
			if meshPart then
				local ProximityPrompt = meshPart:FindFirstChild("ProximityPrompt")
				if ProximityPrompt then
					ProximityPrompt.Triggered:Connect(function(player)
						local modelName = model.Name
						handleName(modelName, player, ProximityPrompt)
					end)
				end
			end
		end
	end
end


handleName = function(name:string, player : Player, ProximityPrompt)
	
	if name == "RewardChest" then
		-- if player not cooldown, claim. if cooldown, cooldown.
		
		local cooldown = getCooldownTime(player)
		
		if cooldown <= 0 then
			handleTime("claim", player)
		else
			handleTime("cooldown", player)
		end
		
	elseif name == "NormalCase" then
		
		local playerCoins = checkPlayerCoins(player)
		
		-- CHECK FIRST IF PLAYER HAS NORMAL CASE PENDING OR NO
		
		if playerCoins >= CaseProperties.CoinPrices.NormalCase then
			local caseItem = getCaseItem(player)
			GachaUIEvent:FireClient(player, caseItem, "NormalCase", ProximityPrompt)
			
		elseif playerCoins < CaseProperties.CoinPrices.NormalCase then
			ProductEvent:FireClient(player, "case","NoMoneyNormal")
			SFXEvent:FireClient(player, "Error")
		end
		
	elseif name == "PremiumCase" then
		
	else
		warn("Invalid Case Name")
	end
	
end

------------------------------------------------------------------------------------------------------------------------------------

handleTime = function(action:string, player:Player)
	
	if action == "claim" then
		
		local isMember = isGroupMember(player)
		SFXEvent:FireClient(player, "ReceiveRewardChestCase")
		
		if isMember then
			local time = os.time()
			DataManager.setClaim(player, time)
			CaseModule:HandleChestUI(player)
			DataManager.AddCoins(player, CaseProperties.ChestReward * 2)
			
		else
			local time = os.time()
			DataManager.setClaim(player, time)
			CaseModule:HandleChestUI(player)
			DataManager.AddCoins(player, CaseProperties.ChestReward)
		end
		-- HANDLE REWARDS & TIME FOR GUI HERE
		
	elseif action == "cooldown" then
		ProductEvent:FireClient(player, "case", "SkipChestTimer")
		SFXEvent:FireClient(player, "Error")
	else 
		warn("Invalid Action | GetTime")
	end
	
end

getCooldownTime = function(player : Player)   -- RETURNS COOLDOWN TIME 
	local lastClaim = DataManager.getLastClaim(player)
	local cooldown = CaseProperties.RewardCooldown - (os.time() - lastClaim)
	
	return cooldown
end

------------------------------------------------------------------------------------------------------------------------------------

getCaseItem = function(player)
	
	local category = "Emotes"
	--[[ if math.random() < 0.5 then  -- 50/50 chance
		category = "Emotes"
	else
		category = "Death"
	end ]]--
	

	local items = CaseProperties.Items[category]
	local itemNames = {}
	for itemName, itemID in pairs(items) do
		table.insert(itemNames, itemName)
	end
	
	local selectedItem = itemNames[math.random(1, #itemNames)]
	
	
	local data = {
		EmoteName = selectedItem,
		EmoteID = items[selectedItem]
	}	
	
	InventoryHandler:AddToInventory(player, "emote", data)
	
	return selectedItem
	
end



------------------------------------------------------------------------------------------------------------------------------------

isGroupMember = function(player : Player)
	if player:IsInGroupAsync(GroupID) then
		return true
	else
		return false
	end
end

checkPlayerCoins = function(player : Player)
	return DataManager.GetCoins(player)
end

------------------------------------------------------------------------------------------------------------------------------------

return CaseModule
