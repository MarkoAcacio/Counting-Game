local ShopHandler = {}

local d = require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Directory"))

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
local CaseModule = require(ModulesFolder:WaitForChild("Interactables"):WaitForChild("CaseModule"))

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
				print(data)
			end
		elseif action == "Normal" then
			ShopHandler.PendingGifts[player.UserId] = nil
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
					self:RewardGiftedPlayer(receivingPlayer, ProductName, buyerID, productID)
					self.PendingGifts[buyerID] = nil
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

	local currentCase = "PremiumCase"  -- Current Case Banner
	local caseData = {
		caseName = currentCase,
		caseIncrement = nil
	}
	
	local idReceived = tonumber(ProductID)
	local targetID = tonumber(ShopProperties.DevProducts.x1CaseIns)

	local player = PlayerService:GetPlayerByUserId(PlayerID)
	print(ProductID)
	print(player)

	-- Cases
	if ProductID == ShopProperties.DevProducts.x1Case then
		caseData.caseIncrement = 1
		print("Bought x1")
		InventoryHandler:AddToInventory(player, "case", caseData)
		d.SFXEvent:FireClient(player, "Purchase2")
		
	elseif idReceived == targetID then
		print("asdasd")
		CaseModule.OpenPremiumCase(player, 1)
		d.SFXEvent:FireClient(player, "Purchase2")
	elseif ProductID == ShopProperties.DevProducts.x2Case then
		caseData.caseIncrement = 2
		print("Bought x2")
		InventoryHandler:AddToInventory(player, "case", caseData)
		d.SFXEvent:FireClient(player, "Purchase2")
	elseif ProductID == ShopProperties.DevProducts.x3Case then
		caseData.caseIncrement = 3
		print("Bought x3")
		InventoryHandler:AddToInventory(player, "case", caseData)
		d.SFXEvent:FireClient(player, "Purchase2")

		-- Coins
	elseif ProductID == ShopProperties.DevProducts.coin1 then
		DataManager.AddCoinsProduct(player, 500)
		DataManager.SendCurrencies(player)
		d.SFXEvent:FireClient(player, "Purchase2")
	elseif ProductID == ShopProperties.DevProducts.coin2 then
		DataManager.AddCoinsProduct(player, 2500)
		DataManager.SendCurrencies(player)
		d.SFXEvent:FireClient(player, "Purchase2")
	elseif ProductID == ShopProperties.DevProducts.coin3 then
		DataManager.AddCoinsProduct(player, 1200)
		DataManager.SendCurrencies(player)
		d.SFXEvent:FireClient(player, "Purchase2")

		-- Skip Chest Timer
	elseif ProductID == ShopProperties.DevProducts.SkipTime then
		DataManager.setClaim(player, 3)
		d.SFXEvent:FireClient(player, "Purchase2")

		-- Tips (Support the Dev!)
	elseif ProductID == ShopProperties.DevProducts.tip10 then
		-- Thank you message
		NotificationsEvent:FireClient(player, "Thank you for the 10 Robux tip! ❤️")
		d.SFXEvent:FireClient(player, "Purchase2")

	elseif ProductID == ShopProperties.DevProducts.tip20 then
		NotificationsEvent:FireClient(player, "Thank you for the 20 Robux tip! ❤️")
		d.SFXEvent:FireClient(player, "Purchase2")

	elseif ProductID == ShopProperties.DevProducts.tip30 then
		NotificationsEvent:FireClient(player, "Thank you for the 30 Robux tip! ❤️")
		d.SFXEvent:FireClient(player, "Purchase2")

	elseif ProductID == ShopProperties.DevProducts.tip40 then
		NotificationsEvent:FireClient(player, "Thank you for the 40 Robux tip! ❤️")
		d.SFXEvent:FireClient(player, "Purchase2")

	elseif ProductID == ShopProperties.DevProducts.tip50 then
		NotificationsEvent:FireClient(player, "Thank you for the 50 Robux tip! ❤️ You're amazing!")
		d.SFXEvent:FireClient(player, "Purchase2")
	end

end

function ShopHandler:RewardGiftedPlayer(ReceivingPlayer, ProductName, BuyerId, ProductID)
	local receiverID = (typeof(ReceivingPlayer) == "Instance") and ReceivingPlayer.UserId or ReceivingPlayer

	local Text = "You Have Received, " .. ProductName .. " From : " .. PlayerService:GetPlayerByUserId(BuyerId).Name .. " !!!"
	self:RewardPlayer(receiverID,  ProductID)
	NotificationsEvent:FireClient(ReceivingPlayer, Text)
end

----------------------------------------------------------------------------------------------------------------------------------------

return ShopHandler