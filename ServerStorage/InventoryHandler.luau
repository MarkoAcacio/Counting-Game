local InventoryHandler = {}

local d = require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Directory"))
local DataManager = require(d.ServerScriptService:WaitForChild("Data"):WaitForChild("DataManager"))

InventoryHandler.connections = {}

-- The amount of case the game has.
local _NumberOfCases = 2

--------------------------------------------------------------------------------------------------------

function InventoryHandler:Init(player)
	self:SetupListeners()
	self:UpdateInventory(player)
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
	if action == "emote" then
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
	
	table.insert(self.connections, d.InventoryEvent.OnServerEvent:Connect(function()
		
	end))
	
	d.EmoteRequest.OnServerInvoke = function(player)
		local inventory = DataManager.GetPlayerInventory(player)

		return inventory.Emotes
	end
end

function InventoryHandler:VerifyOwnership(player : Player, ItemID)
	local inventory = DataManager.GetPlayerInventory(player)
	local hasOwned = false

	if inventory and inventory.Emotes then
		for name, id in pairs(inventory.Emotes) do
			if tostring(id) == tostring(ItemID) then
				hasOwned = true
				break 
			end
		end		
	end

	d.VerifyEvent:FireClient(player, ItemID, hasOwned)
end

--------------------------------------------------------------------------------------------------------

function InventoryHandler:UpdateInventory(player : Player)
	local NumberOfEmotes = 0
	local NumberOfCases = 0
	local inventory = DataManager.GetPlayerInventory(player)
	
	if inventory then
		for _ in pairs(inventory.Emotes) do
			NumberOfEmotes += 1
		end
		NumberOfCases = _NumberOfCases
	end

	
	local data = {
		Inventory = inventory,
		Slots = {emoteSlots = NumberOfEmotes, caseSlots = NumberOfCases},
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
