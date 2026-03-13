local ShopUI = {}

local d = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Directory"))

-- Modules
local MusicModule = require(d.Modules:WaitForChild("MusicModule"))
local GuiModule = require(d.Modules:WaitForChild("GuiModule"))

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
		coin2 = 3534903574, -- 2500 C
		coin3 = 3534903625, -- 1200 C
		SkipTime = 3529893514,

		-- Tips
		tip10 = 3554677793,
		tip20 = 3554677887,
		tip30 = 3554677983,
		tip40 = 3554678040,
		tip50 = 3554678086,
	}
}

local _BuyButtons = {}
local _GiftButtons = {}
local _TipButtons = {} -- NEW: For tip jar buttons

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
	local IF = ScreenGui:WaitForChild("Inventory")
	local DF = ScreenGui:WaitForChild("DailyRewards")


	return shopFrame,ScrollingFrame, Exit, ShopIcon, PlayerList, Notifications, IF, DF
end

----------------------------------------------------------------------------------------------------------------------------------------


function ShopUI:Init()
	clearConnections()

	local shopFrame, ScrollingFrame, Exit, ShopIcon, PlayerList, Notifications,IF, DF = fetchShopUI()

	table.insert(self.connections, ShopIcon.MouseButton1Click:Connect(function()
		MusicModule:PlaySFX("Click")

		local isAlreadyOpen = shopFrame.Visible

		-- Toggle
		shopFrame.Visible = not isAlreadyOpen

		-- Shut others
		IF.Visible = false
		DF.Visible = false

		-- Sync Global Module
		GuiModule.FramesValue.SF = not isAlreadyOpen
		GuiModule.FramesValue.IF = false
		GuiModule.FramesValue.DF = false
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
	self:LoadTipButtons(ScrollingFrame) -- NEW: Load tip jar buttons
	ShopUI:HandleButtonListeners(BuyButton, GiftButton)
	self:TweenNotification(Notifications)

end

local tweenCache = {}

function ShopUI:HoverEffect(Button)
	if not tweenCache[Button] then
		tweenCache[Button] = Button.Size
	end

	local normalSize = tweenCache[Button]
	local hoverSize = UDim2.new(normalSize.X.Scale * 1.1, 0, normalSize.Y.Scale * 1.1, 0)
	local clickSize = UDim2.new(normalSize.X.Scale * 0.9, 0, normalSize.Y.Scale * 0.9, 0)

	local sizeTween = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local clickInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	local isHovering = false

	-- Mouse Enter
	table.insert(self.connections, Button.MouseEnter:Connect(function()
		isHovering = true
		MusicModule:PlaySFX("Hover")
		d.TweenService:Create(Button, sizeTween, {Size = hoverSize}):Play()
	end))

	-- Mouse Leave
	table.insert(self.connections, Button.MouseLeave:Connect(function()
		isHovering = false
		d.TweenService:Create(Button, sizeTween, {Size = normalSize}):Play()
	end))

	-- Mouse Down (Press)
	table.insert(self.connections, Button.MouseButton1Down:Connect(function()
		d.TweenService:Create(Button, clickInfo, {Size = clickSize}):Play()
	end))

	-- Mouse Up (Release)
	table.insert(self.connections, Button.MouseButton1Up:Connect(function()
		local targetSize = isHovering and hoverSize or normalSize
		d.TweenService:Create(Button, clickInfo, {Size = targetSize}):Play()
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

-- NEW: Load tip jar buttons
function ShopUI:LoadTipButtons(ScrollingFrame : ScrollingFrame)
	local TipsFrame = ScrollingFrame:FindFirstChild("Tips")
	if not TipsFrame then 
		warn("Tips frame not found in ScrollingFrame")
		return 
	end

	local ButtonHolder = TipsFrame:FindFirstChild("ButtonHolder")
	if not ButtonHolder then
		warn("ButtonHolder not found in Tips frame")
		return
	end

	-- Load tip buttons (10, 20, 30, 40, 50)
	for _, Button in pairs(ButtonHolder:GetChildren()) do
		if Button:IsA("TextButton") then
			-- Map button name (10, 20, etc.) to product key (tip10, tip20, etc.)
			local tipKey = "tip" .. Button.Name
			if self.Products.DevProducts[tipKey] then
				table.insert(_TipButtons, Button)
				self:HoverEffect(Button) -- Add hover effects to tip buttons
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

	-- NEW: Tip jar buttons
	for _, Button in pairs(_TipButtons) do
		table.insert(self.connections, Button.MouseButton1Click:Connect(function()
			-- Button name is "10", "20", etc.
			-- Product key is "tip10", "tip20", etc.
			local productKey = "tip" .. Button.Name
			self:NormalPurchase(productKey)
			MusicModule:PlaySFX("Click")
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
	if not Name then return end

	local productId = self.Products.DevProducts[Name]
	if productId then
		-- 1. Create LOCAL data so it doesn't overwrite other clicks
		local localData = {
			ReceivingPlayer = d.localPlayer, -- Me
			ProductToGift = productId,
			ProductName = Name,
		}

		-- 2. Tell the server to expect a purchase for ME
		d.ProductEvent:FireServer("Normal", localData) 

		-- 3. Trigger the actual purchase window
		d.MarketPlaceService:PromptProductPurchase(d.localPlayer, productId)
	end
end

function ShopUI:GiftPurchase(Name)
	if not Name then return end

	-- Safety Check: Make sure someone is selected
	if self.SelectedPlayer == nil then
		-- You might want to trigger your ErrorMessage UI here
		warn("No player selected for gifting!")
		return 
	end

	local productId = self.Products.DevProducts[Name]
	if productId then
		-- 1. Fresh LOCAL table
		local giftData = {
			ReceivingPlayer = self.SelectedPlayer,
			ProductToGift = productId,
			ProductName = Name
		}

		-- 2. Tell server who the target is
		d.ProductEvent:FireServer("Gifting", giftData)

		-- 3. Prompt purchase
		d.MarketPlaceService:PromptProductPurchase(d.localPlayer, productId)

		-- 4. OPTIONAL: Clear selection so they have to click a name again for the next gift
		self.SelectedPlayer = nil
		-- (Add code here to reset the player list button colors to white)
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