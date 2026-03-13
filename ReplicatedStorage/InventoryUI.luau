local InventoryUI = {}

local d = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Directory"))
local MusicModule = require(d.Modules:WaitForChild("MusicModule"))
local GuiModule = require(d.Modules:WaitForChild("GuiModule"))

InventoryUI.OpenButtons = {}
InventoryUI.EquipButtons = {}
InventoryUI.EquipImageBtn = {}
InventoryUI.Connections = {}
InventoryUI._ButtonConn = {}
InventoryUI.Data = {}

InventoryUI.EquipEmote = {}

--Config

InventoryUI.NumOfEmotes = 0  -- TEMPLATES
InventoryUI.NumOfCases = 0  -- TEMPLATES
InventoryUI.CaseData = {}  -- TEMPLATES
InventoryUI.EmoteData = {}  -- TEMPLATES
InventoryUI.ImageData = {}  -- TEMPLATES

InventoryUI.NumOfEmotes = {}
InventoryUI.NumOfCases = {}

InventoryUI.CaseClones = {}
InventoryUI.EmoteClones = {}
InventoryUI.ImageClones = {}
InventoryUI.DeathClones = {}
InventoryUI.CountClones = {} -- NEW: For count animations

local _emoteTemplate
local _deathTemplate
local _countTemplate -- NEW

local RARITY_COLORS = {
	["Common"] = Color3.fromRGB(255, 255, 255),
	["Rare"] = Color3.fromRGB(117, 198, 255),
	["Mythical"] = Color3.fromRGB(170, 0, 255),
}

------------------------------------------------------------------------------------------------------------------------------------

local function fetchInventoryUI()
	local player = d.localPlayer
	local ScreenGui = player:WaitForChild("PlayerGui"):WaitForChild("UI"):WaitForChild("ScreenGui")
	local InventoryButton = ScreenGui:WaitForChild("LeftFrame"):WaitForChild("Inventory")
	local InventoryFrame = ScreenGui:WaitForChild("Inventory")
	local ShopFrame = ScreenGui:WaitForChild("ShopUI")
	local DailyRewards = ScreenGui:WaitForChild("DailyRewards")

	return InventoryButton, InventoryFrame, ShopFrame, DailyRewards
end

function InventoryUI:clearConnections()
	for _, conn in ipairs(self.Connections) do
		conn:Disconnect()
	end
	table.clear(self.Connections)

	table.clear(self.OpenButtons)
	table.clear(self.EquipButtons)
end

function InventoryUI:clearButtonConn()

	if self._ButtonConn ~= nil then
		for _, conn in ipairs(self._ButtonConn) do
			conn:Disconnect()
		end
		table.clear(self._ButtonConn)
	end

end


------------------------------------------------------------------------------------------------------------------------------------


function InventoryUI:Init()
	self:clearConnections()
	local InventoryBtn, InventoryFrame, SF, DF = fetchInventoryUI()  -- SF shop frame, DF daily rewards Frame
	self:HandleListeners(InventoryBtn, InventoryFrame, SF, DF)

	self:CloneTemplate(InventoryFrame)
	self:LoadButtons()
end


function InventoryUI:parseData(data)
	self.EmoteData = data.Inventory.Emotes
	self.ImageData = data.Inventory.CountImages
	self.DeathData = data.Inventory.Deaths
	self.CountData = data.Inventory.Counts -- NEW: Parse count animations

	self.CaseData = data.Inventory.Case

	self.NumOfEmotes = data.Slots.emoteSlots
	self.NumOfCases = data.Slots.caseSlots
end

local db = false
local isLoaded = false
function InventoryUI:HandleListeners(InventoryBtn : ImageButton, InventoryFrame : Frame, SF, DF)

	local CaseCategory = InventoryFrame:WaitForChild("Cases")
	local EmoteCategory = InventoryFrame:WaitForChild("Emotes")
	local AllCategory = InventoryFrame:WaitForChild("All")
	local CategoryText = InventoryFrame:WaitForChild("CategoryText")
	local ExitBtn = InventoryFrame:WaitForChild("Exit")
	
	self:ApplyButtonEffect(InventoryBtn)
	self:ApplyButtonEffect(ExitBtn)

	self:ApplyCategoryEffect(CaseCategory)
	self:ApplyCategoryEffect(EmoteCategory)
	self:ApplyCategoryEffect(AllCategory)

	local normalSize = InventoryBtn.Size
	local exitSize = InventoryFrame.Exit.Size
	local hoverSize = UDim2.new(normalSize.X.Scale * 1.1, 0, normalSize.Y.Scale * 1.1, 0)
	local exitHover = UDim2.new(exitSize.X.Scale * 1.1, 0, exitSize.Y.Scale * 1.1, 0)

	----------------------------Remote Events ( Receive Data )---------------------------------

	-- DATA passes the inventory table itself.
	table.insert(self.Connections, d.InventoryEvent.OnClientEvent:Connect(function(data)
		if isLoaded then
			self:parseData(data)
			self:UpdateInventory()
		else
			print(data)
			self:parseData(data)
			isLoaded = true
		end
	end))

	----- INVENTORY BUTTON -----

	table.insert(self.Connections, InventoryBtn.MouseButton1Click:Connect(function()
		MusicModule:PlaySFX("Click")

		local isAlreadyOpen = InventoryFrame.Visible

		-- Toggle
		InventoryFrame.Visible = not isAlreadyOpen

		-- Shut others
		SF.Visible = false
		DF.Visible = false

		-- Sync Global Module
		GuiModule.FramesValue.IF = not isAlreadyOpen
		GuiModule.FramesValue.SF = false
		GuiModule.FramesValue.DF = false
	end))

	table.insert(self.Connections, InventoryBtn.MouseEnter:Connect(function()
		MusicModule:PlaySFX("Hover")
		local tween = d.TweenService:Create(InventoryBtn, d.HoverInfo, {Size = hoverSize})
		tween:Play()
	end))

	table.insert(self.Connections, InventoryBtn.MouseLeave:Connect(function()
		local tween = d.TweenService:Create(InventoryBtn, d.HoverInfo, {Size = normalSize})
		tween:Play()
	end))

	----------- CATEGORIES ----------

	table.insert(self.Connections, CaseCategory.MouseButton1Click:Connect(function()
		MusicModule:PlaySFX("Click")
		self:ToggleCategory("Case", CategoryText)
	end))

	table.insert(self.Connections, EmoteCategory.MouseButton1Click:Connect(function()
		MusicModule:PlaySFX("Click")
		self:ToggleCategory("Emote", CategoryText)
	end))

	table.insert(self.Connections, AllCategory.MouseButton1Click:Connect(function()
		MusicModule:PlaySFX("Click")
		self:ToggleCategory("All", CategoryText)
	end))

	----- ExitButton -----

	table.insert(self.Connections, InventoryFrame.Exit.MouseButton1Click:Connect(function()
		if db == true then db = false InventoryFrame.Visible = false MusicModule:PlaySFX("Click") return end
		MusicModule:PlaySFX("Click")
		InventoryFrame.Visible = false
		db = true
	end))

	table.insert(self.Connections, InventoryFrame.Exit.MouseEnter:Connect(function()
		MusicModule:PlaySFX("Hover")
		local tween = d.TweenService:Create(InventoryFrame.Exit, d.HoverInfo, {Size = exitHover})
		tween:Play()
	end))

	table.insert(self.Connections, InventoryFrame.Exit.MouseLeave:Connect(function()
		local tween = d.TweenService:Create(InventoryFrame.Exit, d.HoverInfo, {Size = exitSize})
		tween:Play()
	end))

	--------------------------------


end

function InventoryUI:_Buttons()
	self:clearButtonConn()

	for _, buttons in pairs(self.EquipButtons) do
		local parentFrame = buttons.Parent
		local itemName = parentFrame.Name
		local Slot = parentFrame:FindFirstChild("Slot") -- Use FindFirstChild for safety
		
			self:ApplyButtonEffect(buttons)

		-- 1. Main Equip Button Click
		table.insert(self._ButtonConn, buttons.MouseButton1Click:Connect(function()
			MusicModule:PlaySFX("Click")

			-- IF DEATH ANIMATION: Equip immediately (No slots needed)
			if self.DeathClones and self.DeathClones[itemName] then
				local itemID = self.DeathClones[itemName].emoteID
				print("Attempting to Equip Death: " .. itemName)

				d.EquipDeath:FireServer(itemName, itemID) 
				return -- Stop here so the Slot doesn't open
			end

			-- NEW: IF COUNT ANIMATION: Equip immediately (No slots needed)
			if self.CountClones and self.CountClones[itemName] then
				local itemID = self.CountClones[itemName].emoteID
				print("Attempting to Equip Count: " .. itemName)

				d.EquipCount:FireServer(itemName, itemID)
				return -- Stop here
			end

			-- IF EMOTE: Open the Slot UI
			if Slot then
				Slot.Visible = true
			end
		end))

		-- 2. Handle the specific Slots (Emote1, Emote2, etc.) ONLY if it's an Emote
		if Slot then
			for _, child in ipairs(Slot:GetChildren()) do
				if child:IsA("TextButton") then
					table.insert(self._ButtonConn, child.MouseButton1Click:Connect(function()
						MusicModule:PlaySFX("Click")

						local slotName = "Emote" .. child.Name
						local emoteData = self.EmoteClones[itemName]

						if emoteData then
							local emoteID = emoteData.emoteID

							-- Update Local UI
							self.EquipEmote = {
								slotName = slotName,
								emoteName = itemName,
								emoteID = emoteID,
							}
							d.EmoteChange:Fire()

							-- Save to Server
							d.SaveEmoteSlot:FireServer(slotName, itemName, emoteID)
							Slot.Visible = false
						end
					end))
				elseif child:IsA("ImageButton") then -- Exit button for slot
					table.insert(self._ButtonConn, child.MouseButton1Click:Connect(function()
						Slot.Visible = false
					end))
				end
			end
		end
	end

	-- OPEN BUTTON (Cases)
	for _, buttons in pairs(self.OpenButtons) do
			self:ApplyButtonEffect(buttons)
		table.insert(self._ButtonConn, buttons.MouseButton1Click:Connect(function()
			MusicModule:PlaySFX("Click")
			
			d.CaseOpen:FireServer()
			
			-- Your opening logic here
		end))
	end
end

------------------------------------------------------------------------------------------------------------------------------------

function InventoryUI:LoadButtons()

	for caseName, slotData in pairs(self.CaseClones) do
		local Button = slotData.case:WaitForChild("Open")
		if Button:IsA("TextButton") then
			table.insert(self.OpenButtons, Button)
		end
	end

	for imageName, imageData in pairs(self.ImageClones) do
		local Button = imageData.image:WaitForChild("Equip")
		if Button:IsA("TextButton") then
			table.insert(self.EquipImageBtn, Button)
		end
	end

	for emoteName, emoteData in pairs(self.EmoteClones) do
		local Button = emoteData.emote:WaitForChild("Equip")
		if Button:IsA("TextButton") then
			table.insert(self.EquipButtons, Button)
		end
	end

	for deathName, deathData in pairs(self.DeathClones or {}) do
		local Button = deathData.emote:WaitForChild("Equip")
		if Button:IsA("TextButton") then
			table.insert(self.EquipButtons, Button) 
		end
	end

	-- NEW: Load Count Animation Buttons
	for countName, countData in pairs(self.CountClones or {}) do
		local Button = countData.emote:WaitForChild("Equip")
		if Button:IsA("TextButton") then
			table.insert(self.EquipButtons, Button)
		end
	end

	self:_Buttons()

end


function InventoryUI:CloneTemplate(InventoryFrame : Frame)
	local ScrollingFrame = InventoryFrame:WaitForChild("UI"):WaitForChild("ScrollingFrame")
	local CaseTemplate = ScrollingFrame:WaitForChild("CaseTemplate")
	local EmoteTemplate = ScrollingFrame:WaitForChild("EmoteTemplate")
	local DeathTemplate = ScrollingFrame:WaitForChild("DeathTemplate")
	local CountTemplate = ScrollingFrame:WaitForChild("CountTemplate") -- NEW: Add this to your UI

	_emoteTemplate = EmoteTemplate
	_deathTemplate = DeathTemplate
	_countTemplate = CountTemplate -- NEW

	repeat task.wait(0.1) until typeof(self.CaseData) == "table" and next(self.CaseData) ~= nil

	-- 1. CLONE CASES
	for _caseName, _qty in pairs(self.CaseData) do
		local displayName = _caseName:gsub("(%l)(%u)", "%1 %2")
		local CaseClone = CaseTemplate:Clone()
		CaseClone.Parent = ScrollingFrame
		CaseClone.Name = _caseName
		CaseClone.caseName.Text = displayName
		CaseClone.qty.Text = "QTY: ".._qty
		CaseClone.Visible = true
		self.CaseClones[_caseName] = { case = CaseClone, caseQty = _qty }
	end

	-- 2. CLONE EMOTES
	for _emoteName, data in pairs(self.EmoteData) do
		local actualID = (type(data) == "table" and data.ID) or data

		local EmoteClone = EmoteTemplate:Clone()
		EmoteClone.Parent = ScrollingFrame
		EmoteClone.Name = _emoteName
		EmoteClone.Visible = true

		-- Apply Text Color
		EmoteClone.emoteName.Text = _emoteName
		EmoteClone.emoteName.TextColor3 = RARITY_COLORS[data.RarityName]

		self:PlaySlotEmote(EmoteClone, actualID)
		self.EmoteClones[_emoteName] = { emote = EmoteClone, emoteID = actualID }
	end

	-- 3. CLONE DEATHS
	self.DeathClones = {} 
	for _deathName, data in pairs(self.DeathData or {}) do
		local actualID = (type(data) == "table" and data.ID) or data

		local DeathClone = DeathTemplate:Clone()
		DeathClone.Parent = ScrollingFrame
		DeathClone.Name = _deathName
		DeathClone.Visible = true

		-- Apply Rarity Color
		DeathClone.emoteName.Text = _deathName
		DeathClone.emoteName.TextColor3 = RARITY_COLORS[data.RarityName]

		self:PlaySlotEmote(DeathClone, actualID)
		self.DeathClones[_deathName] = { emote = DeathClone, emoteID = actualID }
	end

	-- 4. CLONE COUNTS (NEW)
	self.CountClones = {}
	for _countName, data in pairs(self.CountData or {}) do
		local actualID = (type(data) == "table" and data.ID) or data

		local CountClone = CountTemplate:Clone()
		CountClone.Parent = ScrollingFrame
		CountClone.Name = _countName
		CountClone.Visible = true

		-- Apply Rarity Color
		CountClone.emoteName.Text = _countName
		CountClone.emoteName.TextColor3 = RARITY_COLORS[data.RarityName]

		self:PlaySlotEmote(CountClone, actualID)
		self.CountClones[_countName] = { emote = CountClone, emoteID = actualID }
	end
end


function InventoryUI:UpdateInventory()
	-- 1. Update Case Quantities
	for caseName, caseQty in pairs(self.CaseData) do
		if self.CaseClones[caseName] then
			self.CaseClones[caseName].case.qty.Text = "QTY: ".. caseQty
		end
	end

	local newlyAdded = false

	-- 2. Handle New Emotes
	for name, data in pairs(self.EmoteData) do
		if not self.EmoteClones[name] then
			self:CreateNewSlot(name, data, _emoteTemplate, "emote")
			newlyAdded = true
		end
	end

	-- 3. Handle New Deaths
	for name, data in pairs(self.DeathData or {}) do
		if not self.DeathClones[name] then
			self:CreateNewSlot(name, data, _deathTemplate, "death")
			newlyAdded = true
		end
	end

	-- 4. Handle New Counts (NEW)
	for name, data in pairs(self.CountData or {}) do
		if not self.CountClones[name] then
			self:CreateNewSlot(name, data, _countTemplate, "count")
			newlyAdded = true
		end
	end

	if newlyAdded then
		self:LoadButtons() -- Re-scan and connect buttons immediately
	end
end

function InventoryUI:CreateNewSlot(name, data, template, itemType)
	-- DEBUG: Check the output window to see what 'data' actually contains
	print("Processing Item:", name, "Data Type:", typeof(data))
	if typeof(data) == "table" then
		for k, v in pairs(data) do print("  Key:", k, "Value:", v) end
	end

	local id = (type(data) == "table" and data.ID) or data
	local rarity = (type(data) == "table" and data.RarityName) or "Common"

	-- Force the color selection
	local targetColor = RARITY_COLORS[rarity] or RARITY_COLORS.Common
	print("Assigned Rarity:", rarity, "Target Color:", targetColor)

	local clone = template:Clone()
	clone.Name = name
	clone.Parent = template.Parent
	clone.Visible = true

	-- SET TEXT COLOR IMMEDIATELY
	local label = clone:FindFirstChild("emoteName")
	if label then
		label.Text = name
		label.TextColor3 = targetColor
	else
		warn("Could not find 'emoteName' in template for item: " .. name)
	end

	self:PlaySlotEmote(clone, id)

	-- Store in appropriate table
	if itemType == "death" then
		self.DeathClones[name] = { emote = clone, emoteID = id }
	elseif itemType == "count" then
		self.CountClones[name] = { emote = clone, emoteID = id }
	else
		self.EmoteClones[name] = { emote = clone, emoteID = id }
	end
end



function InventoryUI:ToggleCategory(Category : string, CategoryText : TextLabel)
	local function setVisibility(tab, visible)
		for _, data in pairs(tab) do
			if data.emote then data.emote.Visible = visible end
			if data.case then data.case.Visible = visible end
		end
	end

	if Category == "Case" then
		setVisibility(self.EmoteClones, false)
		setVisibility(self.DeathClones, false)
		setVisibility(self.CountClones, false) -- NEW
		setVisibility(self.CaseClones, true)
		CategoryText.Text = "Cases"
	elseif Category == "Emote" then
		setVisibility(self.CaseClones, false)
		setVisibility(self.EmoteClones, true)
		setVisibility(self.DeathClones, true)
		setVisibility(self.CountClones, true) -- NEW: Counts visible in Emote tab
		CategoryText.Text = "Emotes"
	elseif Category == "All" then
		setVisibility(self.CaseClones, true)
		setVisibility(self.EmoteClones, true)
		setVisibility(self.DeathClones, true)
		setVisibility(self.CountClones, true) -- NEW
		CategoryText.Text = "All"
	end
end



function InventoryUI:PlaySlotEmote(emoteSlot : Frame, emoteID)
	local id = (type(emoteID) == "table" and emoteID.ID) or emoteID	
	task.wait(0.3)

	local vp = emoteSlot:WaitForChild("vp")
	local rig = vp:WaitForChild("WorldModel"):WaitForChild("Rig")
	local animator = rig:WaitForChild("Humanoid"):WaitForChild("Animator")


	local anim = Instance.new("Animation")
	anim.AnimationId = "rbxassetid://" .. tostring(id)
	anim.Parent = animator

	local loadedAnimation = animator:LoadAnimation(anim)
	loadedAnimation.Priority = Enum.AnimationPriority.Action
	loadedAnimation:Play()
	loadedAnimation.Looped = true

end



local tweenCache = {}

function InventoryUI:ApplyCategoryEffect(button)
	local ParentFrame = button.Parent
	-- Find the specific sibling based on your mapping
	local iconName = (button.Name == "Emotes" and "opt1") or 
		(button.Name == "Cases" and "opt2") or 
		(button.Name == "All" and "opt3")

	local icon = ParentFrame:FindFirstChild(iconName)

	-- 1. Cache original sizes
	if not tweenCache[button] then tweenCache[button] = button.Size end
	if icon and not tweenCache[icon] then tweenCache[icon] = icon.Size end

	local normalSize = tweenCache[button]
	local sizeTweenInfo = d.HoverInfo or TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local isHovering = false

	-- 2. Scaling Logic for Sibling Hierarchy
	local function scaleCategory(multiplier)
		-- Scale the Button
		local targetBtn = UDim2.new(normalSize.X.Scale * multiplier, 0, normalSize.Y.Scale * multiplier, 0)
		d.TweenService:Create(button, sizeTweenInfo, {Size = targetBtn}):Play()

		-- Scale the Sibling Icon
		if icon and tweenCache[icon] then
			local iconNormal = tweenCache[icon]
			local targetIcon = UDim2.new(iconNormal.X.Scale * multiplier, 0, iconNormal.Y.Scale * multiplier, 0)
			d.TweenService:Create(icon, sizeTweenInfo, {Size = targetIcon}):Play()
		end
	end

	-- 3. Triggers
	table.insert(self.Connections, button.MouseEnter:Connect(function()
		isHovering = true
		MusicModule:PlaySFX("Hover")
		scaleCategory(1.1)
	end))

	table.insert(self.Connections, button.MouseLeave:Connect(function()
		isHovering = false
		scaleCategory(1)
	end))

	table.insert(self.Connections, button.MouseButton1Down:Connect(function()
		scaleCategory(0.9)
	end))

	table.insert(self.Connections, button.MouseButton1Up:Connect(function()
		scaleCategory(isHovering and 1.1 or 1)
	end))
end

function InventoryUI:ApplyButtonEffect(button)
	local ParentFrame = button.Parent
	-- Find siblings
	local btnImage = ParentFrame:FindFirstChild("btn")
	local iconImage = ParentFrame:FindFirstChild("icon")

	-- 1. Cache sizes for everything that exists
	local targets = {button, btnImage, iconImage}
	for _, obj in ipairs(targets) do
		if obj and not tweenCache[obj] then
			tweenCache[obj] = obj.Size
		end
	end

	-- 2. Configuration
	local sizeTweenInfo = d.HoverInfo or TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local clickTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local isHovering = false

	-- 3. Unified Scaling Logic
	local function scaleElements(multiplier, info)
		for _, obj in ipairs(targets) do
			if obj and tweenCache[obj] then
				local originalSize = tweenCache[obj]
				local newSize = UDim2.new(
					originalSize.X.Scale * multiplier, 0, 
					originalSize.Y.Scale * multiplier, 0
				)
				d.TweenService:Create(obj, info, {Size = newSize}):Play()
			end
		end
	end

	-- 4. Triggers
	table.insert(self.Connections, button.MouseEnter:Connect(function()
		isHovering = true
		MusicModule:PlaySFX("Hover")
		scaleElements(1.15, sizeTweenInfo) -- Hover Grow
	end))

	table.insert(self.Connections, button.MouseLeave:Connect(function()
		isHovering = false
		scaleElements(1, sizeTweenInfo) -- Return to Normal
	end))

	table.insert(self.Connections, button.MouseButton1Down:Connect(function()
		scaleElements(0.9, clickTweenInfo) -- Click Shrink
	end))

	table.insert(self.Connections, button.MouseButton1Up:Connect(function()
		local targetMultiplier = isHovering and 1.15 or 1
		scaleElements(targetMultiplier, clickTweenInfo)
	end))
end
------------------------------------------------------------------------------------------------------------------------------------

return InventoryUI