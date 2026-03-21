local InventoryHandler = {}

local d = require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Directory"))
local DataManager = require(d.ServerScriptService:WaitForChild("Data").DataManager)

InventoryHandler.connections = {}

-- The amount of case the game has.
local _NumberOfCases = 2
local vipID = 3534903128
local connectionInitialized = false

--------------------------------------------------------------------------------------------------------

function InventoryHandler:IsVIP(player)
	local currentVipStatus = player:GetAttribute("IsVIP")

	if currentVipStatus == nil then
		-- 2. It doesn't exist, so we check ownership and create it
		local success, hasPass = pcall(function()
			return d.MarketplaceService:UserOwnsGamePassAsync(player.UserId, vipID)
		end)

		-- Set the attribute for the first time
		player:SetAttribute("IsVIP", success and hasPass or false)

		if success and hasPass then return true
		else return false
		end
	end
end

function InventoryHandler:Init()
	if connectionInitialized then
		warn("InventoryHandler already initialized")
		return
	end
	
	connectionInitialized = true
	self:SetupListeners()
end

-- Emote | store the emotes that the player obtained.
-- Case | store the amount of cases the player bought.

	--[[
	
		local caseData = {
		caseName = currentCase,
		caseIncrement = nil
	}
	
		local emoteData = {
		EmoteName = selectedItem,
		EmoteID = items[selectedItem]
	}	
	
	]]

function InventoryHandler:AddToInventory(player : Player, action, reward)
	-- Map the action string to the DataManager folder names
	-- Action comes from CaseModule (e.g., "emote", "death", "count")

	if action == "emote" or action == "death" or action == "count" then
		-- reward is now the table: {Name = "...", ID = 123, RarityName = "...", Type = "..."}
		DataManager.AddPlayerInventory(player, action, reward)
		self:UpdateInventory(player)
	elseif action == "case" then
		DataManager.AddPlayerInventory(player, action, reward)
		self:UpdateInventory(player)
	end
end


function InventoryHandler:SetupListeners()
	table.insert(self.connections, d.VerifyEvent.OnServerEvent:Connect(function(player, EmoteID)
		self:VerifyOwnership(player, EmoteID)
	end))

	d.SaveEmoteSlot.OnServerEvent:Connect(function(player, slotName, emoteName, emoteID)
		-- Security: Check if they actually own the emote before saving the slot
		local inventory = DataManager.GetPlayerInventory(player)
		if inventory.Emotes[emoteName] then
			DataManager.SaveEmoteSlot(player, slotName, emoteName, emoteID)
		else
			warn(player.Name .. " tried to equip an unowned emote!")
		end
	end)
	
	d.UpdateInventory.OnServerEvent:Connect(function(player)
		self:UpdateInventory(player)
	end)

	d.EmoteRequest.OnServerInvoke = function(player)
		local profile = DataManager.WaitForProfile(player)

		if profile and profile.Data.EmoteConfig then
			return profile.Data.EmoteConfig -- This sends the SAVED slots
		else
			print("No EmoteConfig found, sending empty table")
			return {} 
		end
	end
	
	d.EquippedRequest.OnServerInvoke = function(player)
		local DeathEquipped, CountEquipped, EmoteConfig = DataManager.GetPlayerEquipped(player)
		
		
		return DeathEquipped, CountEquipped, EmoteConfig
	end
	
	d.CaseOpen.OnServerEvent:Connect(function(player, case)
		local valid = DataManager.subtractCase(player, case)
		
		if valid then
			local CaseModule = require(d.Modules.Interactables.CaseModule)
			CaseModule.OpenPremiumCase(player, 2)
		end
	end)

	-- Equip Death Animation
	d.EquipDeath.OnServerEvent:Connect(function(player, itemName)
		DataManager.EquipDeathAnimation(player, itemName)
	end)

	-- NEW: Equip Count Animation
	d.EquipCount.OnServerEvent:Connect(function(player, itemName)
		DataManager.EquipCountAnimation(player, itemName)
	end)

end

function InventoryHandler:VerifyOwnership(player : Player, ItemID)
	local inventory = DataManager.GetPlayerInventory(player)
	if not inventory then return end

	local hasOwned = false

	-- We check every folder in the inventory
	local foldersToCheck = {"Emotes", "Deaths", "Counts"}

	for _, folderName in ipairs(foldersToCheck) do
		local folder = inventory[folderName]
		if folder then
			for name, data in pairs(folder) do
				-- If data is a table, check .ID. If it's a number, check it directly.
				local savedID = (type(data) == "table" and data.ID) or data
				if tostring(savedID) == tostring(ItemID) then
					hasOwned = true
					break
				end
			end
		end
		if hasOwned then break end
	end

	d.VerifyEvent:FireClient(player, ItemID, hasOwned)
end

--------------------------------------------------------------------------------------------------------

function InventoryHandler:UpdateInventory(player : Player)
	local NumberOfEmotes = 0
	local NumberOfCases = 0
	local NumberOfImages = 0
	local inventory = DataManager.GetPlayerInventory(player)

	if inventory then
		for _ in pairs(inventory.Emotes) do
			NumberOfEmotes += 1
		end
		NumberOfCases = _NumberOfCases
	end


	local data = {
		Inventory = inventory,
		Slots = {emoteSlots = NumberOfEmotes, caseSlots = NumberOfCases, countImages = NumberOfImages},
		totalSlots = NumberOfEmotes + NumberOfCases
	}

	d.InventoryEvent:FireClient(player, data)  -- Sends data to inventory. Note, send again when user purchase.

end

--------------------------------------------------------------------------------------------------------

local function getAmount(data)
	for key, value in pairs(data) do
		if key == "Emotes" then
			return #value
		elseif key == "Cases" then
			return value
		end
	end
end

function InventoryHandler:GetInventory(player : Player)
	local inventory = DataManager.GetPlayerInventory(player)

	return inventory
end

--------------------------------------------------------------------------------------------------------

return InventoryHandler