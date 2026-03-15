local ShopUI = {}

local d = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Directory"))
local RunService = game:GetService("RunService")

-- Modules
local MusicModule = require(d.Modules:WaitForChild("MusicModule"))
local GuiModule = require(d.Modules:WaitForChild("GuiModule"))

-- Assets
local player = d.localPlayer

-- getGUI is now called INSIDE Init so refs are always fresh after respawn
local function getGUI()
	local ScreenGui = player:WaitForChild("PlayerGui"):WaitForChild("UI"):WaitForChild("ScreenGui")
	local ShopIcon = ScreenGui:WaitForChild("LeftFrame"):WaitForChild("Shop")
	local shopFrame = ScreenGui:WaitForChild("ShopUI")
	local Exit = shopFrame:WaitForChild("Exit")
	local ScrollingFrame = shopFrame:WaitForChild("ScrollingFrame")
	local PlayerList = shopFrame:WaitForChild("PlayerList")
	local listBG = shopFrame:WaitForChild("listBG")
	local Notifications = ScreenGui:WaitForChild("Notifications")
	local IF = ScreenGui:WaitForChild("Inventory")
	local DF = ScreenGui:WaitForChild("DailyRewards")

	return ShopIcon, shopFrame, Exit, ScrollingFrame, PlayerList, listBG, Notifications, IF, DF
end

local iconDB = false

ShopUI.SelectedPlayer = nil
ShopUI.SelectedProduct = nil
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
		coin1 = 3534903503,
		coin2 = 3534903574,
		coin3 = 3534903625,
		SkipTime = 3529893514,

		tip10 = 3554677793,
		tip20 = 3554677887,
		tip30 = 3554677983,
		tip40 = 3554678040,
		tip50 = 3554678086,
	}
}

local _BuyButtons = {}
local _GiftButtons = {}
local _TipButtons = {}
local _SelectedProduct = nil

----------------------------------------------------------------------------------------------------------------------------------------

local function clearConnections()
	for _, conn in ipairs(ShopUI.connections) do
		conn:Disconnect()
	end
	table.clear(ShopUI.connections)

	-- Also stop the floating animation so it doesn't keep running on a dead UI
	if ShopUI.FloatConnection then
		ShopUI.FloatConnection:Disconnect()
		ShopUI.FloatConnection = nil
	end

	-- Clear button tables so they don't accumulate stale refs across respawns
	table.clear(_BuyButtons)
	table.clear(_GiftButtons)
	table.clear(_TipButtons)
end

local function toggleGiftList(toggle: boolean, PlayerList, listBG)
	PlayerList.Visible = toggle
	listBG.Visible = toggle
end

----------------------------------------------------------------------------------------------------------------------------------------

function ShopUI:Init()
	-- Full cleanup before re-initialising (important on respawn)
	clearConnections()

	-- Grab fresh UI refs every time
	local ShopIcon, shopFrame, Exit, ScrollingFrame, PlayerList, listBG, Notifications, IF, DF = getGUI()

	local bg = ScrollingFrame:WaitForChild("CaseShop")
	if bg and bg:FindFirstChild("CaseImage") then
		self:StartFloatingEffect(bg.CaseImage)
	end

	-- Shop icon toggle
	table.insert(self.connections, ShopIcon.MouseButton1Click:Connect(function()
		MusicModule:PlaySFX("Click")
		local isAlreadyOpen = shopFrame.Visible
		shopFrame.Visible = not isAlreadyOpen
		IF.Visible = false
		DF.Visible = false
		GuiModule.FramesValue.SF = not isAlreadyOpen
		GuiModule.FramesValue.IF = false
		GuiModule.FramesValue.DF = false
	end))

	-- Exit button
	table.insert(self.connections, Exit.MouseButton1Click:Connect(function()
		if iconDB == true then iconDB = false shopFrame.Visible = false return end
		MusicModule:PlaySFX("Click")
		iconDB = true
		shopFrame.Visible = false
	end))

	-- Close gift list when shop closes
	table.insert(self.connections, shopFrame:GetPropertyChangedSignal("Visible"):Connect(function()
		if not shopFrame.Visible then
			toggleGiftList(false, PlayerList, listBG)
		end
	end))

	-- Hover effects
	self:HoverEffect(ShopIcon)
	self:HoverEffect(Exit)
	self:ApplyHoverToShopButtons(ScrollingFrame)

	-- Load content
	self:LoadPlayers(PlayerList, listBG)
	self:GetPlayerToGift(PlayerList, listBG)
	local BuyButton, GiftButton = self:LoadCaseButtons(ScrollingFrame)
	self:LoadButtons(ScrollingFrame)
	self:LoadTipButtons(ScrollingFrame)
	ShopUI:HandleButtonListeners(BuyButton, GiftButton, PlayerList, listBG)
	self:TweenNotification(Notifications)

	-- ── Respawn listener ──────────────────────────────────────────────────────
	-- When the character is added (i.e. after death), the PlayerGui UI gets
	-- rebuilt by Roblox, so we wait briefly then re-init with fresh references.
	table.insert(self.connections, player.CharacterAdded:Connect(function()
		task.wait(0.5) -- let PlayerGui finish loading
		self:Init()   -- re-init cleanly (clearConnections runs at the top)
	end))
end

----------------------------------------------------------------------------------------------------------------------------------------

local tweenCache = {}

function ShopUI:HoverEffect(Button, Partner)
	if not tweenCache[Button] then
		tweenCache[Button] = Button.Size
	end
	if Partner and not tweenCache[Partner] then
		tweenCache[Partner] = Partner.Size
	end

	local normalSize = tweenCache[Button]
	local hoverSize  = UDim2.new(normalSize.X.Scale * 1.1, 0, normalSize.Y.Scale * 1.1, 0)
	local clickSize  = UDim2.new(normalSize.X.Scale * 0.9, 0, normalSize.Y.Scale * 0.9, 0)

	local pNormal, pHover, pClick
	if Partner then
		pNormal = tweenCache[Partner]
		pHover  = UDim2.new(pNormal.X.Scale * 1.05, 0, pNormal.Y.Scale * 1.05, 0)
		pClick  = UDim2.new(pNormal.X.Scale * 0.95, 0, pNormal.Y.Scale * 0.95, 0)
	end

	local sizeTween = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local isHovering = false

	table.insert(self.connections, Button.MouseEnter:Connect(function()
		isHovering = true
		MusicModule:PlaySFX("Hover")
		d.TweenService:Create(Button, sizeTween, {Size = hoverSize}):Play()
		if Partner then d.TweenService:Create(Partner, sizeTween, {Size = pHover}):Play() end
	end))

	table.insert(self.connections, Button.MouseLeave:Connect(function()
		isHovering = false
		d.TweenService:Create(Button, sizeTween, {Size = normalSize}):Play()
		if Partner then d.TweenService:Create(Partner, sizeTween, {Size = pNormal}):Play() end
	end))

	table.insert(self.connections, Button.MouseButton1Down:Connect(function()
		d.TweenService:Create(Button, sizeTween, {Size = clickSize}):Play()
		if Partner then d.TweenService:Create(Partner, sizeTween, {Size = pClick}):Play() end
	end))

	table.insert(self.connections, Button.MouseButton1Up:Connect(function()
		local targetSize  = isHovering and hoverSize or normalSize
		local pTargetSize = isHovering and pHover    or pNormal
		d.TweenService:Create(Button, sizeTween, {Size = targetSize}):Play()
		if Partner then d.TweenService:Create(Partner, sizeTween, {Size = pTargetSize}):Play() end
	end))
end


function ShopUI:StartFloatingEffect(CaseImage)
	local originalPos = CaseImage.Position
	local amplitude   = 0.07
	local speed       = 2.5

	if self.FloatConnection then self.FloatConnection:Disconnect() end

	self.FloatConnection = RunService.RenderStepped:Connect(function()
		if not CaseImage or not CaseImage.Parent then return end
		local time        = tick() * speed
		local targetY     = originalPos.Y.Scale + (math.sin(time) * amplitude)
		local targetPos   = UDim2.new(originalPos.X.Scale, originalPos.X.Offset, targetY, originalPos.Y.Offset)
		CaseImage.Position = CaseImage.Position:Lerp(targetPos, 0.1)
	end)
end

function ShopUI:ApplyHoverToShopButtons(ScrollingFrame)
	local CaseShop   = ScrollingFrame:WaitForChild("CaseShop")
	local BTN        = CaseShop.Buttons

	self:HoverEffect(BTN:WaitForChild("x1Case"), BTN:WaitForChild("bg1"))
	self:HoverEffect(BTN:WaitForChild("x2Case"), BTN:WaitForChild("bg2"))
	self:HoverEffect(BTN:WaitForChild("x3Case"), BTN:WaitForChild("bg3"))
	self:HoverEffect(BTN:WaitForChild("1Case"))
	self:HoverEffect(BTN:WaitForChild("2Case"))
	self:HoverEffect(BTN:WaitForChild("3Case"))

	local Tips = ScrollingFrame:FindFirstChild("Tips")
	if Tips then
		local ButtonHolder = Tips:FindFirstChild("ButtonHolder")
		if ButtonHolder then
			for _, tipButton in pairs({"10", "20", "30", "40", "50"}) do
				local btn = ButtonHolder:FindFirstChild(tipButton)
				if btn then self:HoverEffect(btn) end
			end
		end
	end

	local VIP = ScrollingFrame:FindFirstChild("VIP")
	if VIP then
		local buyBtn  = VIP:FindFirstChild("Buy")
		local giftBtn = VIP:FindFirstChild("Gift")
		if buyBtn  then self:HoverEffect(buyBtn)  end
		if giftBtn then self:HoverEffect(giftBtn) end
	end

	for _, coinFrame in pairs({"coin1", "coin2", "coin3"}) do
		local frame = ScrollingFrame:FindFirstChild(coinFrame)
		if frame then
			local buyBtn  = frame:FindFirstChild("Buy")
			local giftBtn = frame:FindFirstChild("Gift")
			if buyBtn  then self:HoverEffect(buyBtn)  end
			if giftBtn then self:HoverEffect(giftBtn) end
		end
	end
end

----------------------------------------------------------------------------------------------------------------------------------------

function ShopUI:LoadCaseButtons(ScrollingFrame)
	local CaseShopFrame = ScrollingFrame:WaitForChild("CaseShop")
	local ButtonsFolder = CaseShopFrame:WaitForChild("Buttons")
	local BuyButton  = {}
	local GiftButton = {}

	for _, Button in pairs(ButtonsFolder:GetChildren()) do
		if Button:IsA("TextButton")  then BuyButton[Button.Name]  = Button end
		if Button:IsA("ImageButton") then GiftButton[Button.Name] = Button end
	end

	return BuyButton, GiftButton
end

function ShopUI:LoadButtons(ScrollingFrame)
	for _, item in pairs(ScrollingFrame:GetChildren()) do
		for _, i in pairs(item:GetChildren()) do
			if i:IsA("TextButton") and i.Name == "Buy"  then table.insert(_BuyButtons,  i) end
			if i:IsA("TextButton") and i.Name == "Gift" then table.insert(_GiftButtons, i) end
		end
	end
end

function ShopUI:LoadTipButtons(ScrollingFrame)
	local TipsFrame = ScrollingFrame:FindFirstChild("Tips")
	if not TipsFrame then warn("Tips frame not found") return end

	local ButtonHolder = TipsFrame:FindFirstChild("ButtonHolder")
	if not ButtonHolder then warn("ButtonHolder not found") return end

	for _, Button in pairs(ButtonHolder:GetChildren()) do
		if Button:IsA("TextButton") then
			local tipKey = "tip" .. Button.Name
			if self.Products.DevProducts[tipKey] then
				table.insert(_TipButtons, Button)
			end
		end
	end
end

----------------------------------------------------------------------------------------------------------------------------------------

-- PlayerList and listBG are now passed in so listeners always reference the live UI
function ShopUI:HandleButtonListeners(BuyButton, GiftButton, PlayerList, listBG)

	-- Case buy buttons
	for _, Button in pairs(BuyButton) do
		table.insert(self.connections, Button.MouseButton1Click:Connect(function()
			self:NormalPurchase(Button.Name)
		end))
	end

	-- Case gift buttons
	for _, Button in pairs(GiftButton) do
		table.insert(self.connections, Button.MouseButton1Click:Connect(function()
			toggleGiftList(true, PlayerList, listBG)
			ShopUI.SelectedProduct = "x" .. Button.Name
		end))
	end

	-- Other buy buttons
	for _, Button in pairs(_BuyButtons) do
		table.insert(self.connections, Button.MouseButton1Click:Connect(function()
			self:NormalPurchase(Button.Parent.Name)
		end))
	end

	-- Other gift buttons
	for _, Button in pairs(_GiftButtons) do
		table.insert(self.connections, Button.MouseButton1Click:Connect(function()
			toggleGiftList(true, PlayerList, listBG)
			ShopUI.SelectedProduct = Button.Name
		end))
	end

	-- Tip buttons
	for _, Button in pairs(_TipButtons) do
		table.insert(self.connections, Button.MouseButton1Click:Connect(function()
			self:NormalPurchase("tip" .. Button.Name)
			MusicModule:PlaySFX("Click")
		end))
	end
end

----------------------------------------------------------------------------------------------------------------------------------------

function ShopUI:LoadPlayers(PlayerList, listBG)
	local TemplateButton = PlayerList:WaitForChild("PlayerTemplate")

	-- Clear existing player buttons first (prevent duplicates on respawn)
	for _, child in pairs(PlayerList:GetChildren()) do
		if child:IsA("Frame") and child.Name ~= "PlayerTemplate" then
			child:Destroy()
		end
	end

	for _, plr in ipairs(d.PlayerService:GetPlayers()) do
		if plr == d.localPlayer then continue end

		local newButton = TemplateButton:Clone()
		newButton.Name                       = plr.Name
		newButton.PlayerName.Text            = plr.Name
		newButton.PlayerDisplayName.Text     = plr.DisplayName
		newButton.Visible                    = true
		newButton.Parent                     = PlayerList
		newButton.PlayerImage.Image          = d.PlayerService:GetUserThumbnailAsync(plr.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)

		self:SetupPlayerButton(newButton.Button, PlayerList, listBG)
	end

	table.insert(self.connections, d.PlayerService.PlayerAdded:Connect(function(plr)
		-- Don't add if already exists
		if PlayerList:FindFirstChild(plr.Name) then return end

		local newButton = TemplateButton:Clone()
		newButton.Name                       = plr.Name
		newButton.PlayerName.Text            = plr.Name
		newButton.PlayerDisplayName.Text     = plr.DisplayName
		newButton.Visible                    = true
		newButton.Parent                     = PlayerList
		newButton.PlayerImage.Image          = d.PlayerService:GetUserThumbnailAsync(plr.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)

		self:SetupPlayerButton(newButton.Button, PlayerList, listBG)
	end))

	-- Remove buttons for players who leave
	table.insert(self.connections, d.PlayerService.PlayerRemoving:Connect(function(plr)
		local btn = PlayerList:FindFirstChild(plr.Name)
		if btn then btn:Destroy() end
	end))
end

function ShopUI:GetPlayerToGift(PlayerList, listBG)
	-- This function is no longer needed since LoadPlayers already sets up all buttons
	-- Keeping it empty for compatibility, but you can remove this function entirely
end

function ShopUI:GetPlayerToGift(PlayerList, listBG)
	for _, Item in pairs(PlayerList:GetChildren()) do
		if Item:IsA("TextButton") and Item.Name ~= "TemplateButton" and Item.Name ~= "PlayerTemplate" then
			self:SetupPlayerButton(Item, PlayerList, listBG)
		end
	end
end

function ShopUI:SetupPlayerButton(Item, PlayerList, listBG)
	local ErrorTxt = PlayerList.Parent:WaitForChild("ErrorMessage")

	table.insert(self.connections, Item.MouseButton1Click:Connect(function()
		if d.localPlayer and Item.Name == d.localPlayer.Name then
			ErrorTxt.Text    = "You Can't Gift Yourself!"
			ErrorTxt.Visible = true
			self.SelectedPlayer = nil
			task.wait(2)
			ErrorTxt.Visible = false
		else
			self.SelectedPlayer = d.PlayerService:FindFirstChild(Item.Parent.Name)
			self:GiftPurchase(ShopUI.SelectedProduct, PlayerList, listBG)
			toggleGiftList(false, PlayerList, listBG)
		end
	end))
end

----------------------------------------------------------------------------------------------------------------------------------------

local Data = {
	ReceivingPlayer = nil,
	ProductToGift   = nil,
	ProductName     = nil,
}

function ShopUI:NormalPurchase(Name)
	if not Name then return end

	local productId = self.Products.DevProducts[Name]
	if productId then
		local localData = {
			ReceivingPlayer = d.localPlayer,
			ProductToGift   = productId,
			ProductName     = Name,
		}
		d.ProductEvent:FireServer("Normal", localData)
		d.MarketPlaceService:PromptProductPurchase(d.localPlayer, productId)
	end
end

function ShopUI:GiftPurchase(Name, PlayerList, listBG)
	if not Name then warn("GiftPurchase: no name") return end

	if self.SelectedPlayer == nil then
		warn("GiftPurchase: no player selected")
		return
	end

	local productId = self.Products.DevProducts[Name]
	if productId then
		local giftData = {
			ReceivingPlayer = self.SelectedPlayer,
			ProductToGift   = productId,
			ProductName     = Name,
		}
		d.ProductEvent:FireServer("Gifting", giftData)
		d.MarketPlaceService:PromptProductPurchase(d.localPlayer, productId)
		self.SelectedPlayer    = nil
		ShopUI.SelectedProduct = nil
	end

	toggleGiftList(false, PlayerList, listBG)
end

----------------------------------------------------------------------------------------------------------------------------------------

local SlideUp   = TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local SlideDown = TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In)

local function TweenNotif(txt, Container, data, type)
	if type == "str" then
		txt.TextColor3 = Color3.fromRGB(138, 243, 127)
		txt.Text       = data
	else
		txt.TextColor3 = Color3.fromRGB(243, 179, 101)
		txt.Text       = "+" .. data .. " Coins"
	end

	local tween      = d.TweenService:Create(txt,       SlideUp,   {TextTransparency = 0})
	local tweenDown  = d.TweenService:Create(txt,       SlideDown, {TextTransparency = 1})
	local tweenC     = d.TweenService:Create(Container, SlideUp,   {Position = UDim2.new(0.2, 0, 1, 0)})
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

function ShopUI:TweenNotification(Notifications)
	table.insert(self.connections, d.NotificationEvent.OnClientEvent:Connect(function(data)
		local Container = Notifications:WaitForChild("Container")
		local txt       = Container:WaitForChild("txt")
		Notifications.Visible = true

		if typeof(data) ~= "number" then
			TweenNotif(txt, Container, data, "str")
		elseif typeof(data) == "number" then
			TweenNotif(txt, Container, data, "int")
		else
			warn("Invalid data type:", typeof(data))
		end
	end))
end

----------------------------------------------------------------------------------------------------------------------------------------

return ShopUI