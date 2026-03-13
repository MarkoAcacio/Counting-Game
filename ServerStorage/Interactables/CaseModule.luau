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
local getCaseImage -- Rewards image cosmetic

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

		if playerCoins >= CaseProperties.CoinPrices.NormalCase then
			local fullItemData = getCaseItem(player) -- This now returns the whole table {Name, Rarity, etc}

			DataManager.SubtractCoins(player, CaseProperties.CoinPrices.NormalCase)

			-- When firing the Gacha UI
			local allPrizes = CaseProperties.NormalPrizes -- This is our merged list
			GachaUIEvent:FireClient(player, fullItemData, "NormalCase", ProximityPrompt, allPrizes)

			DataManager.SendCurrencies(player)
			SFXEvent:FireClient(player, "Purchase")
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
		SFXEvent:FireClient(player, "Coin")
		
		if isMember then
			local time = os.time()
			DataManager.setClaim(player, time)
			CaseModule:HandleChestUI(player)
			DataManager.AddCoins(player, CaseProperties.ChestReward * 2)
			DataManager.SendCurrencies(player)
			
		else
			local time = os.time()
			DataManager.setClaim(player, time)
			CaseModule:HandleChestUI(player)
			DataManager.AddCoins(player, CaseProperties.ChestReward)
			DataManager.SendCurrencies(player)
		end
		-- HANDLE REWARDS & TIME FOR GUI HERE
		
	elseif action == "cooldown" then
		ProductEvent:FireClient(player, "case", "SkipChestTimer")
		SFXEvent:FireClient(player, "Error")
	else 
		SFXEvent:FireClient(player, "Error")
		warn("Invalid Action | GetTime")
	end
	
end

getCooldownTime = function(player : Player)   -- RETURNS COOLDOWN TIME 
	local lastClaim = DataManager.getLastClaim(player)
	local cooldown = CaseProperties.RewardCooldown - (os.time() - lastClaim)
	
	return cooldown
end

------------------------------------------------------------------------------------------------------------------------------------


local function GetRarity()
	local rarity = math.random()
	local cumulative = 0
	for _, item in pairs(CaseProperties["Items"]) do
		cumulative += item.Rarity
		if rarity <= cumulative then
			return item
		end
	end
end


local function determineReward(player, prizeTable)
	-- 1. Perform the Weighted Roll
	-- Since NormalPrizes is a combined list, we must ensure the 
	-- cumulative math is based on the TOTAL sum of rarities in that combined list.
	local roll = math.random()
	local cumulative = 0
	local selectedItem = nil

	-- Calculate total sum for safety (especially since we combined 3 lists)
	local totalRarity = 0
	for _, item in ipairs(prizeTable) do
		totalRarity += item.Rarity
	end

	-- Adjust roll to the total sum
	roll *= totalRarity

	for _, itemData in ipairs(prizeTable) do
		cumulative += itemData.Rarity
		if roll <= cumulative then
			selectedItem = itemData
			break
		end
	end

	-- Fallback to first item if roll fails
	if not selectedItem then
		selectedItem = prizeTable[1]
	end

	-- 2. Determine inventory folder based on the item's Type
	-- This must match the folder names in your DataManager Template
	local invType = "emote" 
	if selectedItem.Type == "DeathAnim" then
		invType = "death"
	elseif selectedItem.Type == "CountAnim" then
		invType = "count" -- NEW: Maps to your profile.Data.Inventory.Counts
	end

	-- 3. Add to inventory
	-- This calls your InventoryHandler which handles the DataStore saving
	InventoryHandler:AddToInventory(player, invType, selectedItem)

	return selectedItem
end

getCaseImage = function(player)
	local category = "Images"
	return determineReward(player, category)
end

--[[
==================================================================================================
	UPDATE CASE ITEM TO CATER DIFFERENT CATEGORIES. ( just use random on them. )
==================================================================================================
]]
getCaseItem = function(player)
	-- Uses the merged table (Emotes + DeathAnims) we generated in CaseProperties
	local prizeTable = CaseProperties.NormalPrizes
	return determineReward(player, prizeTable)
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
