local ShopUI = {}

local d = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Directory"))

-- Modules
local MusicModule = require(d.Modules:WaitForChild("MusicModule"))

local iconDB = false

ShopUI.SelectedPlayer = nil
ShopUI.connections = {}
ShopUI.Products = {
	Passes = {
		VIP = 1696086440,
		TipJar = 1695991782,
	},

	DevProducts = {
		x1Case = 3527680986,
		x3Case = 3527681268,
		x2Case = 3527681381,
		VIP = 3534903128,
		coin1 = 3534903503, -- 500 C
		coin2 = 3534903625, -- 1200 C
		coin3 = 3534903574, -- 2500 C
		
	}
}

local _BuyButtons = {}
local _GiftButtons = {}

----------------------------------------------------------------------------------------------------------------------------------------

local function clearConnections()
	for _, conn in ipairs(ShopUI.connections) do
		conn:Disconnect()
	end
	table.clear(ShopUI.connections)
end

local function fetchShopUI()
	local player = d.localPlayer
	local ScreenGui = player:WaitForChild("PlayerGui"):WaitForChild("UI"):WaitForChild("ScreenGui")
	local ShopIcon = ScreenGui:WaitForChild("LeftFrame"):WaitForChild("Shop")
	local shopFrame = ScreenGui:WaitForChild("ShopUI")
	local Exit = shopFrame:WaitForChild("Exit")
	local ScrollingFrame = shopFrame:WaitForChild("ScrollingFrame")
	local PlayerList = shopFrame:WaitForChild("PlayerList")
	local Notifications = ScreenGui:WaitForChild("Notifications")
	
	
	return shopFrame,ScrollingFrame, Exit, ShopIcon, PlayerList, Notifications
end

----------------------------------------------------------------------------------------------------------------------------------------


function ShopUI:Init()
	clearConnections()

	local shopFrame, ScrollingFrame, Exit, ShopIcon, PlayerList, Notifications = fetchShopUI()
	
	table.insert(self.connections, ShopIcon.MouseButton1Click:Connect(function()
		if iconDB == true then iconDB = false shopFrame.Visible = false return end
		MusicModule:PlaySFX("Click")
		shopFrame.Visible = true
		iconDB = true
	end))
	
	table.insert(self.connections, Exit.MouseButton1Click:Connect(function()
		if iconDB == true then iconDB = false shopFrame.Visible = false return end
		MusicModule:PlaySFX("Click")
		iconDB = true
		shopFrame.Visible = false
	end))
	
	self:HoverEffect(ShopIcon)
	
	self:LoadPlayers(PlayerList)
	self:GetPlayerToGift(PlayerList)
	local BuyButton, GiftButton = self:LoadCaseButtons(ScrollingFrame, shopFrame)
	self:LoadButtons(ScrollingFrame)
	ShopUI:HandleButtonListeners(BuyButton, GiftButton)
	self:TweenNotification(Notifications)
	
end

function ShopUI:HoverEffect(Button)
	
	local normalSize = Button.Size
	local hoverSize = UDim2.new(normalSize.X.Scale * 1.1, 0, normalSize.Y.Scale * 1.1, 0)

	local sizeTween = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	
	table.insert(self.connections, Button.MouseEnter:Connect(function()
		MusicModule:PlaySFX("Hover")
		local tween = d.TweenService:Create(Button, sizeTween, {Size = hoverSize})
		tween:Play()
	end))
	
	table.insert(self.connections, Button.MouseLeave:Connect(function()
		local tween = d.TweenService:Create(Button, sizeTween, {Size = normalSize})
		tween:Play()
	end))
	
end

----------------------------------------------------------------------------------------------------------------------------------------


-- Dictionary Format
		--[[
		
		local BuyButton = {
			"3Case" = 3Case ( TextButton Instance ), 
			"2Case" = 2Case ( TextButton Instance ), 
			"1Case" = 1Case ( TextButton Instance ), 
		}
		
		]]


-- LOAD BUTTONS

function ShopUI:LoadCaseButtons(ScrollingFrame : ScrollingFrame, shopFrame)
	local CaseShopFrame = ScrollingFrame:WaitForChild("CaseShop")
	local ButtonsFolder = CaseShopFrame:WaitForChild("Buttons")
	local BuyButton = {}
	local GiftButton = {}
	
	for _, Button in pairs(ButtonsFolder:GetChildren()) do
		if Button:IsA("TextButton") then
			BuyButton[Button.Name] = Button
			
		end
		
		if Button:IsA("ImageButton") then
			GiftButton[Button.Name] = Button
		end
	end
	
	return BuyButton, GiftButton
	
end

function ShopUI:LoadButtons(ScrollingFrame : ScrollingFrame)
	for _, item in pairs(ScrollingFrame:GetChildren()) do
		for _, i in pairs(item:GetChildren()) do
			if i:IsA("TextButton") and i.Name == "Buy" then
				table.insert(_BuyButtons, i)
			end

			if i:IsA("TextButton") and i.Name == "Gift" then
				table.insert(_GiftButtons, i)
			end
			
		end
	end
end


-- CREATE LISTENERS FOR EACH BUTTON

function ShopUI:HandleButtonListeners(BuyButton, GiftButton) 
	
	------------------------------------------case buttons------------------------------------------------------	
		
	-- Buy Button	
	 for name, Button in pairs(BuyButton) do
		table.insert(self.connections, Button.MouseButton1Click:Connect(function()
			self:NormalPurchase(Button.Name)
		end))
	 end
	 
	-- Gifting Button
	for name, Button in pairs(GiftButton) do
		table.insert(self.connections, Button.MouseButton1Click:Connect(function()
			self:GiftPurchase(Button.Name)
			print("GiftButton Clicked")
			
			-- Check if player have chosen a player to gift to
			
		end))
	end
	 
	 
	-------------------------------------------- NON CASE BUTTONS----------------------------------------------------
	
	for name, Button in pairs(_BuyButtons) do
		table.insert(self.connections, Button.MouseButton1Click:Connect(function()
			self:NormalPurchase(Button.Parent.Name)
		end))
	end
	
	for name, Button in pairs(_GiftButtons) do
		table.insert(self.connections, Button.MouseButton1Click:Connect(function()
			self:GiftPurchase(Button.Parent.Name)
		end))
	end
	
	
	------------------------------------------------------------------------------------------------
	 
end


-- HANDLE PLAYER LIST
function ShopUI:LoadPlayers(PlayerList : ScrollingFrame)
	local TemplateButton = PlayerList:WaitForChild("TemplateButton")
	
	for _, player in ipairs(d.PlayerService:GetPlayers()) do
		local newButton = TemplateButton:Clone()
		newButton.Name = player.Name
		newButton.Text = player.Name
		newButton.Visible = true
		newButton.Parent = PlayerList
	end

	-- Handle new players joining
	table.insert(self.connections, d.PlayerService.PlayerAdded:Connect(function(player)
		local newButton = TemplateButton:Clone()
		newButton.Name = player.Name
		newButton.Text = player.Name
		newButton.Visible = true
		newButton.Parent = PlayerList
		
		self:SetupPlayerButton(newButton, PlayerList)
	end))
end

-- GET PLAYER TO GIFT
function ShopUI:GetPlayerToGift(PlayerList : ScrollingFrame)
	for _, Item in pairs(PlayerList:GetChildren()) do
		-- Only setup if it's a button AND it's not the template
		if Item:IsA("TextButton") and Item.Name ~= "TemplateButton" then
			self:SetupPlayerButton(Item, PlayerList)
		end
	end
end

-- Setups the button listeners for the player list
function ShopUI:SetupPlayerButton(Item, PlayerList)
	local ErrorTxt = PlayerList.Parent:WaitForChild("ErrorMessage")

	table.insert(self.connections, Item.MouseButton1Click:Connect(function()
		-- Added checks for d.localPlayer and Item existence
		if d.localPlayer and Item.Name == d.localPlayer.Name then
			ErrorTxt.Text = "You Can't Gift Yourself!"
			ErrorTxt.Visible = true
			self.SelectedPlayer = nil
			task.wait(2)
			ErrorTxt.Visible = false
		else
			-- Clean up other buttons first (Optional: un-highlight previous selection)
			for _, btn in pairs(PlayerList:GetChildren()) do
				if btn:IsA("TextButton") then btn.BackgroundColor3 = Color3.fromRGB(255,255,255) end
			end

			Item.BackgroundColor3 = Color3.fromRGB(149,220,41)
			self.SelectedPlayer = d.PlayerService:FindFirstChild(Item.Name)
			print("Selected to gift:", self.SelectedPlayer)
		end
	end))
end


----------------------------------------------------------------------------------------------------------------------------------------

-- ProductEvent:FireServer(Action, Data {})

local Data = {
	ReceivingPlayer = nil,
	ProductToGift = nil,
	ProductName = nil,
}

function ShopUI:NormalPurchase(Name)
	
	print(Name)
	
	if Name then
		d.MarketPlaceService:promptProductPurchase(d.localPlayer, self.Products.DevProducts[Name])

		Data.ReceivingPlayer = self.SelectedPlayer
		Data.ProductToGift = self.Products.DevProducts[Name]
		Data.ProductName = "x1 Case"

		d.ProductEvent:FireServer("Gifting",Data)
	end
end

function ShopUI:GiftPurchase(Name)
	
	if Name == "1Case" then
		
		if self.SelectedPlayer ~= nil then
			d.MarketPlaceService:PromptProductPurchase(d.localPlayer, self.Products.DevProducts.x1Case)
			
			Data.ReceivingPlayer = self.SelectedPlayer
			Data.ProductToGift = self.Products.DevProducts.x1Case
			Data.ProductName = "x1 Case"
			
			d.ProductEvent:FireServer("Gifting",Data)
		end
		
		-- CHECK FIRST IF PLAYER HAVE CLICKED A GIFT PLAYER IF NOT THEN REJECT!
	elseif Name == "2Case" then
		
		if self.SelectedPlayer ~= nil then
			d.MarketPlaceService:PromptProductPurchase(d.localPlayer, self.Products.DevProducts.x2Case)

			Data.ReceivingPlayer = self.SelectedPlayer
			Data.ProductToGift = self.Products.DevProducts.x2Case
			Data.ProductName = "x2 Case"

			d.ProductEvent:FireServer("Gifting",Data)
		end
	
	elseif Name == "3Case" then
		if self.SelectedPlayer ~= nil then
			d.MarketPlaceService:PromptProductPurchase(d.localPlayer, self.Products.DevProducts.x3Case)

			Data.ReceivingPlayer = self.SelectedPlayer
			Data.ProductToGift = self.Products.DevProducts.x3Case
			Data.ProductName = "x3 Case"

			d.ProductEvent:FireServer("Gifting",Data)
		end
	elseif Name == "VIP" then
		if self.SelectedPlayer ~= nil then
			d.MarketPlaceService:PromptProductPurchase(d.localPlayer, self.Products.DevProducts.VIP)

			Data.ReceivingPlayer = self.SelectedPlayer
			Data.ProductToGift = self.Products.DevProducts.VIP
			Data.ProductName = "VIP"

			d.ProductEvent:FireServer("Gifting",Data)
		end
	else
		warn("INVALID CASES NAME | @GiftCase")
	end
	
end


local SlideUp = TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local SlideDown = TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In)



local function TweenNotif(txt,Container, data, type)
	
	if type == "str" then txt.TextColor3 = Color3.fromRGB(138, 243, 127) txt.Text = data -- If string
	else txt.TextColor3 = Color3.fromRGB(243, 179, 101) txt.Text = "+".. data .. " Coins"  end -- If integer
	
	
	local tween = d.TweenService:Create(txt, SlideUp, {TextTransparency = 0})
	local tweenDown = d.TweenService:Create(txt, SlideDown, {TextTransparency = 1})
	local tweenC = d.TweenService:Create(Container, SlideUp, {Position = UDim2.new(0.2, 0, 1, 0)})
	local tweenDownC = d.TweenService:Create(Container, SlideDown, {Position = UDim2.new(0.2, 0, 5, 0)})
	tweenC:Play()
	tween:Play()
	MusicModule:PlaySFX("Coin")

	tween.Completed:Connect(function()
		task.wait(0.3)
		if type == "str" then MusicModule:PlaySFX("Notif") end
		task.wait(3)
		tweenDown:Play()
		tweenDownC:Play()
	end)
end



function ShopUI:TweenNotification(Notifications : Frame)
	
	-- {Coins = 5, Wins = 1} what event will receive from win
	
	table.insert(self.connections, d.NotificationEvent.OnClientEvent:Connect(function(data)
		print(data)
		local Container = Notifications:WaitForChild("Container")
		local txt = Container:WaitForChild("txt")
		Notifications.Visible = true
		
		if typeof(data) ~=  "number" then  -- If data is a string.
			TweenNotif(txt, Container, data, "str")
		elseif typeof(data) == "number" then -- If data is a number.
			TweenNotif(txt, Container, data, "int")
		else
			warn("Invalid Type for Data. | " , typeof(data))
		end	
		
	end))
end

----------------------------------------------------------------------------------------------------------------------------------------

return ShopUI
