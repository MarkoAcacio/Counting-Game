local ShopHandler = {}

-- Services
local PlayerService = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StarterGui = game:GetService("StarterGui")
local MarketPlaceService = game:GetService("MarketplaceService")
local SSS = game:GetService("ServerScriptService")

-- Folders
local EventsFolder = ReplicatedStorage:WaitForChild("Events")
local ModulesFolder = ServerStorage:WaitForChild("Modules")

-- Events
local PlayerUIGift = EventsFolder:WaitForChild("PlayerUIGift")
local ProductEvent = EventsFolder:WaitForChild("ProductEvent")
local NotificationsEvent = EventsFolder:WaitForChild("NotificationEvent")

-- Modules
local ShopProperties = require(ModulesFolder:WaitForChild("Shop"):WaitForChild("ShopProperties"))
local DataManager = require(SSS:WaitForChild("Data"):WaitForChild("DataManager"))
local InventoryHandler = require(ModulesFolder:WaitForChild("InventoryHandler"))

-- Variables & Functions
ShopHandler.PendingGifts = {}  -- Gifting
ShopHandler.ProcessedReceipts = {} -- Normal Purchases
ShopHandler.EventConnection = nil
ShopHandler.MarketplaceConnection = nil


----------------------------------------------------------------------------------------------------------------------------------------

function ShopHandler:Init()
	self:ConnectEvents()
	self:SetupReceipts()
end

----------------------------------------------------------------------------------------------------------------------------------------

function ShopHandler:ConnectEvents()
	
	if ShopHandler.EventConnection then
		ShopHandler.EventConnection:Disconnect()
	end
	
	ShopHandler.EventConnection = ProductEvent.OnServerEvent:Connect(function(player, action, data)
		
		if action == "Gifting" then
			if data.ReceivingPlayer and data.ProductToGift then
				ShopHandler.PendingGifts[player.UserId] = data
			end
		end
	end)
end


function ShopHandler:SetupReceipts()
	
	MarketPlaceService.ProcessReceipt = function(receiptInfo)
		local purchaseID = receiptInfo.PurchaseId
		local productID = receiptInfo.ProductId
		local buyerID = receiptInfo.PlayerId
	
		local success, err = pcall(function()
			
			if self.ProcessedReceipts[purchaseID] then
				return Enum.ProductPurchaseDecision.PurchaseGranted
			end

			
			local buyer = PlayerService:GetPlayerByUserId(buyerID)
			if not buyer then  -- Player Left
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			
			if self.PendingGifts[buyerID] then
				local ProductToGift = self.PendingGifts[buyerID].ProductToGift
				local receivingPlayer = self.PendingGifts[buyerID].ReceivingPlayer
				local ProductName = self.PendingGifts[buyerID].ProductName
				
				if productID == ProductToGift then
					self:RewardGiftedPlayer(receivingPlayer, ProductName, buyerID)
				end
			else  -- NORMAL PURCHASE
				ShopHandler:RewardPlayer(buyerID, productID)
			end
		end)
		
		if success then
			self.ProcessedReceipts[purchaseID] = true
			return Enum.ProductPurchaseDecision.PurchaseGranted
		else
			warn("Error Processing Receipt | @ShopHandler Module SS, ", err)
			
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		
	end
	
end

----------------------------------------------------------------------------------------------------------------------------------------

function ShopHandler:RewardPlayer(PlayerID, ProductID)
	
	local currentCase = "NormalCase"
	local caseData = {
		caseName = currentCase,
		caseIncrement = nil
	}
	
	if ProductID == ShopProperties.DevProducts.SkipTime then  -- Skip Chest Time
		DataManager.setClaim(PlayerService:GetPlayerByUserId(PlayerID), 3)
	elseif ProductID == ShopProperties.DevProducts.coin1 then
		DataManager.AddCoins(PlayerService:GetPlayerByUserId(PlayerID), 500)
	elseif ProductID == ShopProperties.DevProducts.coin2 then
		DataManager.AddCoins(PlayerService:GetPlayerByUserId(PlayerID), 1200)
	elseif ProductID == ShopProperties.DevProducts.coin3 then
		DataManager.AddCoins(PlayerService:GetPlayerByUserId(PlayerID), 2500)
	elseif ProductID == ShopProperties.DevProducts.x1Case then
		caseData.caseIncrement = 1
		InventoryHandler:AddToInventory(PlayerService:GetPlayerByUserId(PlayerID), "case", caseData)
	elseif ProductID == ShopProperties.DevProducts.x2Case then
		caseData.caseIncrement = 2
		InventoryHandler:AddToInventory(PlayerService:GetPlayerByUserId(PlayerID), "case", caseData)
	elseif ProductID == ShopProperties.DevProducts.x3Case then
		caseData.caseIncrement = 3
		InventoryHandler:AddToInventory(PlayerService:GetPlayerByUserId(PlayerID), "case", caseData)
	end
	
end

function ShopHandler:RewardGiftedPlayer(ReceivingPlayer, ProductName, BuyerId)
	
	local Text = "You Have Received, " .. ProductName .. " From : " .. PlayerService:GetPlayerByUserId(BuyerId).Name .. " !!!"
	
	NotificationsEvent:FireClient(ReceivingPlayer, Text)
end

----------------------------------------------------------------------------------------------------------------------------------------

return ShopHandler
