local ShopUI = {}

local d = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Directory"))
local RunService = game:GetService("RunService")

-- Modules
local MusicModule = require(d.Modules:WaitForChild("MusicModule"))
local GuiModule = require(d.Modules:WaitForChild("GuiModule"))
local TweenUtils = require(d.Modules:WaitForChild("TweenUtils"))

ShopUI.PlayerButtons = {}


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


-- NEW: Function to handle player table management
function ShopUI:ManagePlayerTable()
	-- Clear existing table
	table.clear(self.PlayerButtons)

	-- Add all existing players to table
	for _, plr in ipairs(d.PlayerService:GetPlayers()) do
		if plr ~= d.localPlayer then
			self.PlayerButtons[plr.UserId] = plr
		end
	end

	-- When a new player joins, add to table
	table.insert(self.connections, d.PlayerService.PlayerAdded:Connect(function(plr)
		if plr ~= d.localPlayer then
			self.PlayerButtons[plr.UserId] = plr
		end
	end))

	-- When a player leaves, remove from table
	table.insert(self.connections, d.PlayerService.PlayerRemoving:Connect(function(plr)
		self.PlayerButtons[plr.UserId] = nil
	end))
end


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

local function getRigs(CS_Shop)
	local rwTable = {}
	for _, obj in CS_Shop:GetChildren() do
		if obj:IsA("Frame") then
			local frameName = obj.Name
			for _, child in obj:GetChildren() do
				if child:IsA("ViewportFrame") then
					local rig = child:WaitForChild("WorldModel"):FindFirstChild("Rig")
					rwTable[frameName] = rig
				end
			end
		end
	end
	
	return rwTable
end

function ShopUI:Init()
	-- Full cleanup before re-initialising (important on respawn)
	clearConnections()
	
	self:ManagePlayerTable()

	-- Grab fresh UI refs every time
	local ShopIcon, shopFrame, Exit, ScrollingFrame, PlayerList, listBG, Notifications, IF, DF = getGUI()

	local CS_Shop = ScrollingFrame:WaitForChild("CaseShop")
	if CS_Shop and CS_Shop:FindFirstChild("CaseImage") then
		self:StartFloatingEffect(CS_Shop.CaseImage, CS_Shop.ray)
	end
	
	local rigTable = getRigs(CS_Shop)

	-- Shop icon toggle
	table.insert(self.connections, ShopIcon.MouseButton1Click:Connect(function()
		MusicModule:PlaySFX("Click")
		local isAlreadyOpen = shopFrame.Visible
		shopFrame.Visible = not isAlreadyOpen
		
		if not isAlreadyOpen then
			TweenUtils.BG_Blur(not isAlreadyOpen, 15)
		else
			TweenUtils.BG_Blur(not isAlreadyOpen, 0)
		end
		
		IF.Visible = false
		DF.Visible = false
		GuiModule.FramesValue.SF = not isAlreadyOpen
		GuiModule.FramesValue.IF = false
		GuiModule.FramesValue.DF = false
	end))

	-- Exit button
	table.insert(self.connections, Exit.MouseButton1Click:Connect(function()
		if iconDB == true then iconDB = false shopFrame.Visible = false TweenUtils.BG_Blur(false, 0) return end
		MusicModule:PlaySFX("Click")
		iconDB = true
		shopFrame.Visible = false
		TweenUtils.BG_Blur(false, 0)
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
	local BuyButton, GiftButton = self:LoadCaseButtons(ScrollingFrame)
	self:LoadButtons(ScrollingFrame)
	self:LoadTipButtons(ScrollingFrame)
	ShopUI:HandleButtonListeners(BuyButton, GiftButton, PlayerList, listBG)
	self:TweenNotification(Notifications)
	self:PlayEmotes(rigTable)

	-- ── Respawn listener ──────────────────────────────────────────────────────
	-- When the character is added (i.e. after death), the PlayerGui UI gets
	-- rebuilt by Roblox, so we wait briefly then re-init with fresh references.
	table.insert(self.connections, player.CharacterAdded:Connect(function()
		task.wait(0.5) -- let PlayerGui finish loading
		self:Init()   -- re-init cleanly (clearConnections runs at the top)
	end))
end

----------------------------------------------------------------------------------------------------------------------------------------

function ShopUI:PlayEmotes(rigTable)
	-- Ensure we have a clean ID string

	for frameName, rig in pairs(rigTable) do
		local animator = rig:WaitForChild("Humanoid"):FindFirstChild("Animator")
		local animation = animator:FindFirstChild("Animation")
		
		for _, track in pairs(animator:GetPlayingAnimationTracks()) do
			track:Stop()
		end
		
		

		local success, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		
		if success and track then
			
			if frameName == "RW1Frame" then
				task.spawn(function()
					while true do
						-- Forward
						track:Play(0.1, 1, 1)
						track.Stopped:Wait()

						-- Backward
						track.TimePosition = track.Length
						track:Play(0.1, 1, -1)
						track.Stopped:Wait()
					end
				end)
				continue
			end
			
			track.Looped = true
			track.Priority = Enum.AnimationPriority.Action
			track:Play()

			-- VIEWPORT FIX: Sometimes animations need a frame to initialize in VPFs
			task.defer(function()
				if track then track:Play() end
			end)
		else
			warn("Failed to load animation")
		end
		
	end
end

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


function ShopUI:StartFloatingEffect(CaseImage, ray)
	local originalPos = CaseImage.Position
	local amplitude   = 0.07
	local speed       = 1.5
	local rotationSpeed = 25 -- Degrees per second

	if self.FloatConnection then self.FloatConnection:Disconnect() end

	self.FloatConnection = RunService.RenderStepped:Connect(function(dt)
		if not CaseImage or not CaseImage.Parent or not ray then 
			self.FloatConnection:Disconnect()
			return 
		end

		local currentTime = tick()
		local bobbingTime = currentTime * speed

		-- 1. Calculate the new Floating Position for the Case
		local targetY = originalPos.Y.Scale + (math.sin(bobbingTime) * amplitude)
		local targetPos = UDim2.new(originalPos.X.Scale, originalPos.X.Offset, targetY, originalPos.Y.Offset)

		-- 2. Apply Lerp for smooth movement
		CaseImage.Position = CaseImage.Position:Lerp(targetPos, 0.1)

		-- 3. Make the Ray follow the Case's current position
		ray.Position = CaseImage.Position

		-- 4. Spin the Ray independently
		ray.Rotation = ray.Rotation + (rotationSpeed * dt)
	end)
end

function ShopUI:ApplyHoverToShopButtons(ScrollingFrame)
	local CaseShop   = ScrollingFrame:WaitForChild("CaseShop")
	local BTN        = CaseShop:WaitForChild("Buttons")

	self:HoverEffect(BTN:WaitForChild("x1Case"), BTN:WaitForChild("bg1"))
	self:HoverEffect(BTN:WaitForChild("x2Case"), BTN:WaitForChild("bg2"))
	self:HoverEffect(BTN:WaitForChild("x3Case"), BTN:WaitForChild("bg3"))
	self:HoverEffect(BTN:WaitForChild("1Case"))
	self:HoverEffect(BTN:WaitForChild("2Case"))
	self:HoverEffect(BTN:WaitForChild("3Case"))

	local Tips = ScrollingFrame:WaitForChild("Tips")
	if Tips then
		local ButtonHolder = Tips:FindFirstChild("ButtonHolder")
		if ButtonHolder then
			for _, tipButton in pairs({"10", "20", "30", "40", "50"}) do
				local btn = ButtonHolder:FindFirstChild(tipButton)
				if btn then self:HoverEffect(btn) end
			end
		end
	end

	local VIP = ScrollingFrame:WaitForChild("VIP")
	if VIP then
		local buyBtn  = VIP:FindFirstChild("Buy")
		local giftBtn = VIP:FindFirstChild("Gift")
		if buyBtn  then self:HoverEffect(buyBtn)  end
		if giftBtn then self:HoverEffect(giftBtn) end
	end

	for _, coinFrame in pairs({"coin1", "coin2", "coin3"}) do
		local frame = ScrollingFrame:WaitForChild(coinFrame)
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
	local TipsFrame = ScrollingFrame:WaitForChild("Tips")
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
			MusicModule:PlaySFX("Click")
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
			ShopUI.SelectedProduct = Button.Parent.Name
			MusicModule:PlaySFX("Click")
			print(ShopUI.SelectedProduct)
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

function ShopUI:CreatePlayerButton(plr, TemplateButton, PlayerList, listBG)
	local newButton = TemplateButton:Clone()
	newButton.Name                       = plr.Name
	newButton.Visible                    = true
	newButton.Parent                     = PlayerList

	-- Wait for critical children to exist before accessing them
	local PlayerName = newButton:WaitForChild("PlayerName", 2)
	local PlayerDisplayName = newButton:WaitForChild("PlayerDisplayName", 2)
	local PlayerImage = newButton:WaitForChild("PlayerImage", 2)

	if not PlayerName or not PlayerDisplayName or not PlayerImage then
		warn("Failed to load player button UI for:", plr.Name)
		newButton:Destroy()
		return
	end

	PlayerName.Text = plr.Name
	PlayerDisplayName.Text = plr.DisplayName

	local success, thumbnailUrl = pcall(function()
		return d.PlayerService:GetUserThumbnailAsync(plr.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
	end)

	if success then
		PlayerImage.Image = thumbnailUrl
	end

	local buttonChild = newButton:FindFirstChild("Button")
	if buttonChild then
		self:SetupPlayerButton(buttonChild, PlayerList, listBG, plr.UserId)
	else
		warn("Button child not found in cloned template for player:", plr.Name)
	end
end

function ShopUI:LoadPlayers(PlayerList, listBG)
	local TemplateButton = PlayerList:WaitForChild("PlayerTemplate")

	-- Clear existing player buttons in UI
	for _, child in pairs(PlayerList:GetChildren()) do
		if child:IsA("Frame") and child.Name ~= "PlayerTemplate" then
			child:Destroy()
		end
	end

	-- Create buttons for all players in our table
	for userId, plr in pairs(self.PlayerButtons) do
		self:CreatePlayerButton(plr, TemplateButton, PlayerList, listBG)
	end

	-- When a new player joins, create their button
	table.insert(self.connections, d.PlayerService.PlayerAdded:Connect(function(plr)
		if plr == d.localPlayer then return end

		-- Only create if doesn't already exist
		if not PlayerList:FindFirstChild(plr.Name) then
			self:CreatePlayerButton(plr, TemplateButton, PlayerList, listBG)
		end
	end))

	-- When a player leaves, destroy their button
	table.insert(self.connections, d.PlayerService.PlayerRemoving:Connect(function(plr)
		local btn = PlayerList:FindFirstChild(plr.Name)
		if btn then btn:Destroy() end
	end))
end

--[[
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
end ]]

function ShopUI:SetupPlayerButton(Item, PlayerList, listBG, userId)
	if not Item then
		warn("SetupPlayerButton called with nil Item")
		return
	end

	local ErrorTxt = PlayerList.Parent:FindFirstChild("ErrorMessage")

	table.insert(self.connections, Item.MouseButton1Click:Connect(function()
		-- Check if player still exists in our tracking table
		local targetPlayer = self.PlayerButtons[userId]

		if not targetPlayer or not targetPlayer.Parent then
			if ErrorTxt then
				ErrorTxt.Text = "Player not found!"
				ErrorTxt.Visible = true
				task.wait(2)
				ErrorTxt.Visible = false
			end
			return
		end

		if targetPlayer == d.localPlayer then
			if ErrorTxt then
				ErrorTxt.Text = "You Can't Gift Yourself!"
				ErrorTxt.Visible = true
			end
			self.SelectedPlayer = nil
			task.wait(2)
			if ErrorTxt then
				ErrorTxt.Visible = false
			end
		else
			self.SelectedPlayer = targetPlayer
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
		local txt       = Container:FindFirstChild("txt")
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