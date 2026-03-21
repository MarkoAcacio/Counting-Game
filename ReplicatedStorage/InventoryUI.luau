local InventoryUI = {}

local d = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Directory"))
local MusicModule = require(d.Modules:WaitForChild("MusicModule"))
local GuiModule = require(d.Modules:WaitForChild("GuiModule"))
local GachaModule= require(d.Modules:WaitForChild("GachaUI"))
local TweenUtils = require(d.Modules:WaitForChild("TweenUtils"))

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

InventoryUI.ActiveCategory = nil
InventoryUI.CurrentEquippedDeath = nil -- Track current equipped death
InventoryUI.CurrentEquippedCount = nil -- Track current equipped count
InventoryUI.CurrentEquippedEmotes = {} -- Track current equipped emotes (Emote1-4)

-- NEW: Track which case is currently being opened
InventoryUI.CurrentlyOpeningCase = nil

InventoryUI.Images = {
	opt1 = {normal = "rbxassetid://82261850428650", selected = "rbxassetid://117541092509512"},
	opt2 = {normal = "rbxassetid://92505326809050", selected = "rbxassetid://73176336335035"},
	opt3 = {normal = "rbxassetid://138024768658972", selected = "rbxassetid://74750387412653"},

	Button = {normal = "rbxassetid://108036905139974", selected = "rbxassetid://84999112566304"}
}

local IDLE_IMAGE = "rbxassetid://YOUR_IDLE_ID"
local SELECTED_IMAGE = "rbxassetid://YOUR_SELECTED_ID"

local _emoteTemplate
local _deathTemplate
local _countTemplate -- NEW

local RARITY_COLORS = {
	["Common"] = Color3.fromRGB(255, 255, 255),
	["Rare"] = Color3.fromRGB(117, 198, 255),
	["Mythical"] = Color3.fromRGB(170, 0, 255),
	["Legendary"] = Color3.fromRGB(255, 215, 16)
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

-- NEW: Request equipped items from server
function InventoryUI:RequestEquippedItems()
	local success, DeathEquipped, CountEquipped, EmoteConfig = pcall(function()
		return d.EquippedRequest:InvokeServer()
	end)

	if success then

		self.CurrentEquippedDeath = DeathEquipped
		self.CurrentEquippedCount = CountEquipped
		self.CurrentEquippedEmotes = EmoteConfig or {} -- Store the emote slots config

		-- Update UI to show equipped status
		self:UpdateEquippedUI()
	else
		warn("Failed to get equipped items from server")
	end
end

-- NEW: Update the UI to show which items are equipped
-- NEW: Update the UI to show which items are equipped
function InventoryUI:UpdateEquippedUI()
	-- Update Death Animations
	for deathName, deathData in pairs(self.DeathClones) do
		local equipButton = deathData.emote:WaitForChild("Equip") 
		local buttonLabel = equipButton:FindFirstChild("Equip") 

		if deathName == self.CurrentEquippedDeath then
			buttonLabel.Text = "Equipped"
			equipButton.Image = self.Images.Button.selected
		else
			buttonLabel.Text = "Equip"
			equipButton.Image = self.Images.Button.normal
		end
	end

	-- Update Count Animations
	for countName, countData in pairs(self.CountClones) do
		local equipButton = countData.emote:WaitForChild("Equip") 
		local buttonLabel = equipButton:FindFirstChild("Equip") 

		if countName == self.CurrentEquippedCount then
			buttonLabel.Text = "Equipped"
			equipButton.Image = self.Images.Button.selected
		else
			buttonLabel.Text = "Equip"
			equipButton.Image = self.Images.Button.normal
		end
	end

	-- Build reverse lookup table
	local equippedEmoteNames = {}
	for slotName, slotData in pairs(self.CurrentEquippedEmotes) do
		equippedEmoteNames[slotData.EmoteName] = true
	end

	-- Update Emote Animations
	for emoteName, emoteData in pairs(self.EmoteClones) do
		local equipButton = emoteData.emote:WaitForChild("Equip") 
		local buttonLabel = equipButton:FindFirstChild("Equip") 

		if equippedEmoteNames[emoteName] then
			buttonLabel.Text = "Equipped"
			equipButton.Image = self.Images.Button.selected
		else
			buttonLabel.Text = "Equip"
			equipButton.Image = self.Images.Button.normal
		end
	end
end

-- NEW: Set a case button to "Opening..." state
function InventoryUI:SetCaseOpening(caseName, isOpening)
	if self.CaseClones[caseName] then
		local openButton = self.CaseClones[caseName].case:WaitForChild("Open")
		if openButton then
			local buttonLabel = openButton:FindFirstChild("TextLabel")
			if buttonLabel then
				if isOpening then
					buttonLabel.Text = "Opening..."
					self.CurrentlyOpeningCase = caseName
				else
					buttonLabel.Text = "Open"
					if self.CurrentlyOpeningCase == caseName then
						self.CurrentlyOpeningCase = nil
					end
				end
			end
		end
	end
end

-- NEW: Reset all case buttons to normal state
function InventoryUI:ResetAllCaseButtons()
	for caseName, caseData in pairs(self.CaseClones) do
		local openButton = caseData.case:WaitForChild("Open")
		if openButton then
			local buttonLabel = openButton:WaitForChild("TextLabel")
			if buttonLabel and buttonLabel.Text == "Opening..." then
				buttonLabel.Text = "Open"
			end
		end
	end
	self.CurrentlyOpeningCase = nil
end

------------------------------------------------------------------------------------------------------------------------------------


function InventoryUI:Init()
	self:clearConnections()

	-- CRITICAL FIX: Wait for UI to exist in PlayerGui
	-- When player dies, PlayerGui gets reset, so we need fresh references
	local player = d.localPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local uiScreenGui = playerGui:WaitForChild("UI"):WaitForChild("ScreenGui")

	-- Make sure the UI is actually loaded before proceeding
	if not uiScreenGui then
		warn("ScreenGui not found, waiting...")
		repeat task.wait(0.1) until playerGui:WaitForChild("UI") and playerGui.UI:WaitForChild("ScreenGui")
		uiScreenGui = playerGui.UI.ScreenGui
	end

	local InventoryBtn, InventoryFrame, SF, DF = fetchInventoryUI()  -- SF shop frame, DF daily rewards Frame

	-- CRITICAL FIX: Verify we got valid UI elements
	if not InventoryBtn or not InventoryFrame then
		warn("InventoryUI:Init() - UI elements not found, retrying...")
		task.wait(0.5)
		InventoryBtn, InventoryFrame, SF, DF = fetchInventoryUI()
	end

	self:HandleListeners(InventoryBtn, InventoryFrame, SF, DF)

	self:CloneTemplate(InventoryFrame)
	self:LoadButtons()

	self:RequestEquippedItems()

	table.insert(self.Connections, d.localPlayer.CharacterAdded:Connect(function()
		if GachaModule then
			GachaModule.Spinning = false
		end

		for _, buttons in pairs(self.OpenButtons) do
			buttons.Interactable = true
			buttons.Active = true
		end
	end))

	-- Keep existing CharacterRemoving connection
	table.insert(self.Connections, d.localPlayer.CharacterRemoving:Connect(function()
		if GachaModule then
			GachaModule.Spinning = false
		end
	end))
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


	local CaseCategory = InventoryFrame.CategoryFrame.opt2
	local EmoteCategory = InventoryFrame.CategoryFrame.opt1
	local AllCategory = InventoryFrame.CategoryFrame.opt3
	local ExitBtn = InventoryFrame:FindFirstChild("Exit")

	TweenUtils:TweenButton(InventoryBtn)
	TweenUtils:TweenButton(ExitBtn)


	self:ApplyCategoryEffect(CaseCategory)
	self:ApplyCategoryEffect(EmoteCategory)
	self:ApplyCategoryEffect(AllCategory)

	-- NEW: Set default category to "All" on initialization
	self:SetCategoryActive(AllCategory)

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
		
		if not isAlreadyOpen then
			TweenUtils.BG_Blur(not isAlreadyOpen, 15)
		else
			TweenUtils.BG_Blur(not isAlreadyOpen, 0)
		end

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
		self:SetCategoryActive(CaseCategory)  -- Set active BEFORE toggle
		self:ToggleCategory("Case")
	end))

	table.insert(self.Connections, EmoteCategory.MouseButton1Click:Connect(function()
		MusicModule:PlaySFX("Click")
		self:SetCategoryActive(EmoteCategory)  -- Set active BEFORE toggle
		self:ToggleCategory("Emote")
	end))

	table.insert(self.Connections, AllCategory.MouseButton1Click:Connect(function()
		MusicModule:PlaySFX("Click")
		self:SetCategoryActive(AllCategory)  -- Set active BEFORE toggle
		self:ToggleCategory("All")
	end))

	----- ExitButton -----

	table.insert(self.Connections, InventoryFrame.Exit.MouseButton1Click:Connect(function()
		if db == true then db = false InventoryFrame.Visible = false MusicModule:PlaySFX("Click") TweenUtils.BG_Blur(false, 0) return end
		MusicModule:PlaySFX("Click")
		TweenUtils.BG_Blur(false, 0)
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

				-- NEW: Update equipped tracking
				self.CurrentEquippedDeath = tostring(itemName)
				self:UpdateEquippedUI()

				return -- Stop here so the Slot doesn't open
			end

			-- NEW: IF COUNT ANIMATION: Equip immediately (No slots needed)
			if self.CountClones and self.CountClones[itemName] then
				local itemID = self.CountClones[itemName].emoteID
				print("Attempting to Equip Count: " .. itemName)

				d.EquipCount:FireServer(itemName, itemID)

				-- NEW: Update equipped tracking
				self.CurrentEquippedCount = tostring(itemName)
				self:UpdateEquippedUI()

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

							-- Update Local UI data for internal systems
							self.EquipEmote = {
								slotName = slotName,
								emoteName = itemName,
								emoteID = emoteID,
							}
							d.EmoteChange:Fire()

							-- Save to Server
							d.SaveEmoteSlot:FireServer(slotName, itemName, emoteID)
							Slot.Visible = false

							-- UPDATE TRACKING: Update your local table so the UI knows what's equipped
							if not self.CurrentEquippedEmotes then
								self.CurrentEquippedEmotes = {}
							end

							-- Record that this slot now contains this emote
							self.CurrentEquippedEmotes[slotName] = {
								EmoteName = itemName, -- MATCH THIS KEY with your check in UpdateEquippedUI
								EmoteID = emoteID
							}

							-- REFRESH UI: This forces all buttons to check their equipped status
							self:UpdateEquippedUI()
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
			local caseName = buttons.Parent.Name
			
			local success = d._CaseOpen:InvokeServer(caseName)
			if success then
				
				
				
				if not GachaModule.Spinning then buttons.Interactable = false end

				if GachaModule.Spinning == true then
					buttons.Interactable = false
					warn("Gacha is already spinning!") return
				end

				-- Check if already opening a case OR if gacha is spinning
				if self.CurrentlyOpeningCase ~= nil or GachaModule.Spinning == true then
					buttons.Interactable = false
					warn("WAIT FOR CURRENT CASE TO FINISH OPENING")
					return
				end

				-- Check if this specific button says "Opening..."
				local buttonLabel = buttons:FindFirstChild("TextLabel")
				if buttonLabel and buttonLabel.Text == "Opening..." then
					buttons.Interactable = false
					warn("THIS CASE IS ALREADY BEING OPENED")
					return
				end

				MusicModule:PlaySFX("Click")

				-- Set button to "Opening..." state
				self:SetCaseOpening(caseName, true)

				-- NEW: Monitor GachaModule.Spinning to reset button when done
				task.spawn(function()
					-- Wait for spinning to start (in case there's a delay)
					local timeout = 0
					while not GachaModule.Spinning and timeout < 50 do
						task.wait(0.1)
						timeout = timeout + 1
					end

					-- Now wait for it to finish
					while GachaModule.Spinning do
						task.wait(0.1)
					end

					-- Reset button state
					buttons.Interactable = true
					self:SetCaseOpening(caseName, false)
				end)
			
			else
				warn("Failed to open case - not enough cases or invalid")
				MusicModule:PlaySFX("Error")
			end
		end))
	end
end

------------------------------------------------------------------------------------------------------------------------------------

function InventoryUI:LoadButtons()

	for caseName, slotData in pairs(self.CaseClones) do
		local Button = slotData.case:WaitForChild("Open")
		if Button:IsA("ImageButton") then
			table.insert(self.OpenButtons, Button)
		end
	end


	for emoteName, emoteData in pairs(self.EmoteClones) do
		local Button = emoteData.emote:WaitForChild("Equip")
		if Button:IsA("ImageButton") then
			table.insert(self.EquipButtons, Button)
		end
	end

	for deathName, deathData in pairs(self.DeathClones or {}) do
		local Button = deathData.emote:WaitForChild("Equip")
		if Button:IsA("ImageButton") then
			table.insert(self.EquipButtons, Button) 
		end
	end

	-- NEW: Load Count Animation Buttons
	for countName, countData in pairs(self.CountClones or {}) do
		local Button = countData.emote:WaitForChild("Equip")
		if Button:IsA("ImageButton") then
			table.insert(self.EquipButtons, Button)
		end
	end

	self:_Buttons()

end


function InventoryUI:CloneTemplate(InventoryFrame : Frame)
	-- CRITICAL FIX: Verify the InventoryFrame is still valid
	if not InventoryFrame or not InventoryFrame.Parent then
		warn("InventoryFrame is invalid or deleted, aborting CloneTemplate")
		return
	end

	local ScrollingFrame = InventoryFrame:WaitForChild("UI"):FindFirstChild("ScrollingFrame")
	local CaseTemplate = ScrollingFrame:WaitForChild("CaseTemplate")
	local EmoteTemplate = ScrollingFrame:WaitForChild("EmoteTemplate")
	local DeathTemplate = ScrollingFrame:WaitForChild("DeathTemplate")
	local CountTemplate = ScrollingFrame:WaitForChild("CountTemplate")

	_emoteTemplate = EmoteTemplate
	_deathTemplate = DeathTemplate
	_countTemplate = CountTemplate

	repeat task.wait(0.1) until typeof(self.CaseData) == "table" and next(self.CaseData) ~= nil

	-- Clear any existing clones ONLY if they're from the old UI
	for _, child in ipairs(ScrollingFrame:GetChildren()) do
		if child:IsA("Frame") and child.Visible == true and 
			child ~= CaseTemplate and child ~= EmoteTemplate and 
			child ~= DeathTemplate and child ~= CountTemplate then
			child:Destroy()
		end
	end

	-- Clear clone tracking tables
	table.clear(self.CaseClones)
	table.clear(self.EmoteClones)
	table.clear(self.DeathClones)
	table.clear(self.CountClones)

	-- 1. CLONE CASES
	for _caseName, _qty in pairs(self.CaseData) do
		local displayName = _caseName:gsub("(%l)(%u)", "%1 %2")
		local CaseClone = CaseTemplate:Clone()
		CaseClone.Parent = ScrollingFrame
		CaseClone.Name = _caseName
		CaseClone:WaitForChild("caseName").Text = displayName
		CaseClone:WaitForChild("qty").Text = _qty .. "x"
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
		EmoteClone:WaitForChild("emoteName").Text = _emoteName
		print(data)
		EmoteClone:WaitForChild("emoteName").TextColor3 = RARITY_COLORS[data.RarityName]

		self:PlaySlotEmote(EmoteClone, actualID)
		self.EmoteClones[_emoteName] = { emote = EmoteClone, emoteID = actualID }
	end

	-- 3. CLONE DEATHS
	for _deathName, data in pairs(self.DeathData or {}) do
		local actualID = (type(data) == "table" and data.ID) or data

		local DeathClone = DeathTemplate:Clone()
		DeathClone.Parent = ScrollingFrame
		DeathClone.Name = _deathName
		DeathClone.Visible = true

		-- Apply Rarity Color
		DeathClone:WaitForChild("emoteName").Text = _deathName
		DeathClone:WaitForChild("emoteName").TextColor3 = RARITY_COLORS[data.RarityName]

		self:PlaySlotEmote(DeathClone, actualID)
		self.DeathClones[_deathName] = { emote = DeathClone, emoteID = actualID }
	end

	-- 4. CLONE COUNTS
	for _countName, data in pairs(self.CountData or {}) do
		local actualID = (type(data) == "table" and data.ID) or data

		local CountClone = CountTemplate:Clone()
		CountClone.Parent = ScrollingFrame
		CountClone.Name = _countName
		CountClone.Visible = true

		-- Apply Rarity Color
		CountClone:WaitForChild("emoteName").Text = _countName
		CountClone:WaitForChild("emoteName").TextColor3 = RARITY_COLORS[data.RarityName]

		self:PlaySlotEmote(CountClone, actualID)
		self.CountClones[_countName] = { emote = CountClone, emoteID = actualID }
	end
end

function InventoryUI:UpdateInventory()
	-- 1. Update Case Quantities
	for caseName, caseQty in pairs(self.CaseData) do
		if self.CaseClones[caseName] then
			self.CaseClones[caseName].case:WaitForChild("qty").Text = caseQty .. "x"
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

	-- ✅ FIX: Only reconnect buttons if NEW items were added
	if newlyAdded then
		self:clearButtonConn() -- Clear old connections first
		self:_Buttons() -- Only reconnect the NEW buttons
		self:RequestEquippedItems() -- Update equipped status for new items
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
	local label = clone:WaitForChild("emoteName")
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
	elseif Category == "Emote" then
		setVisibility(self.CaseClones, false)
		setVisibility(self.EmoteClones, true)
		setVisibility(self.DeathClones, true)
		setVisibility(self.CountClones, true) -- NEW: Counts visible in Emote tab
	elseif Category == "All" then
		setVisibility(self.CaseClones, true)
		setVisibility(self.EmoteClones, true)
		setVisibility(self.DeathClones, true)
		setVisibility(self.CountClones, true) -- NEW
	end
end



function InventoryUI:PlaySlotEmote(emoteSlot : Frame, emoteID)
	-- Ensure we have a clean ID string
	local id = (type(emoteID) == "table" and emoteID.ID) or emoteID	
	if not id or id == 0 or id == "" then return end

	local vp = emoteSlot:WaitForChild("vp")
	local worldModel = vp and vp:FindFirstChild("WorldModel")
	local rig = worldModel and worldModel:FindFirstChild("Rig")
	local humanoid = rig and rig:FindFirstChild("Humanoid")

	if not humanoid then return end

	-- Ensure Animator exists
	local animator = humanoid:FindFirstChild("Animator") or Instance.new("Animator", humanoid)

	-- Clear old animations to prevent overlapping/freezing
	for _, track in pairs(animator:GetPlayingAnimationTracks()) do
		track:Stop()
	end

	local anim = Instance.new("Animation")
	anim.AnimationId = "rbxassetid://" .. tostring(id)

	local success, track = pcall(function()
		return animator:LoadAnimation(anim)
	end)

	if success and track then
		track.Looped = true
		track.Priority = Enum.AnimationPriority.Action
		track:Play()

		-- VIEWPORT FIX: Sometimes animations need a frame to initialize in VPFs
		task.defer(function()
			if track then track:Play() end
		end)
	else
		warn("Failed to load animation ID: " .. tostring(id) .. " for " .. emoteSlot.Name)
	end
end

local tweenCache = {}

function InventoryUI:SetCategoryActive(clickedButton)
	local CategoryFrame = clickedButton.Parent -- Get the CategoryFrame

	-- Reset ALL category buttons to their normal state
	for _, button in pairs(CategoryFrame:GetChildren()) do
		if button:IsA("ImageButton") and self.Images[button.Name] then
			button.Image = self.Images[button.Name].normal
		end
	end

	-- Set the clicked button to selected state
	if self.Images[clickedButton.Name] then
		clickedButton.Image = self.Images[clickedButton.Name].selected
		self.ActiveCategory = clickedButton.Name -- Track the active category
	end
end

function InventoryUI:ApplyCategoryEffect(button)
	-- The button is opt1, opt2, or opt3 (ImageButton)
	-- We check for a TextLabel inside it (Emotes, Cases, or All)
	local label = button:FindFirstChild("TextLabel")

	-- 1. Cache original sizes
	if not tweenCache[button] then tweenCache[button] = button.Size end
	if label and not tweenCache[label] then tweenCache[label] = label.Size end

	local btnNormal = tweenCache[button]

	local sizeTweenInfo = d.HoverInfo or TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local isHovering = false

	-- 2. Scaling Logic
	local function scaleCategory(multiplier)
		-- Scale the ImageButton
		local targetBtn = UDim2.new(btnNormal.X.Scale * multiplier, 0, btnNormal.Y.Scale * multiplier, 0)
		d.TweenService:Create(button, sizeTweenInfo, {Size = targetBtn}):Play()

		-- Scale the Label inside if it exists
		if label and tweenCache[label] then
			local labelNormal = tweenCache[label]
			local targetLabel = UDim2.new(labelNormal.X.Scale * multiplier, 0, labelNormal.Y.Scale * multiplier, 0)
			d.TweenService:Create(label, sizeTweenInfo, {Size = targetLabel}):Play()
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

		-- IMPORTANT: Reset to the correct image state based on if it's active
		if self.ActiveCategory == button.Name then
			button.Image = self.Images[button.Name].selected
		else
			button.Image = self.Images[button.Name].normal
		end
	end))

	table.insert(self.Connections, button.MouseButton1Down:Connect(function()
		scaleCategory(0.9)
	end))

	table.insert(self.Connections, button.MouseButton1Up:Connect(function()
		scaleCategory(isHovering and 1.1 or 1)
	end))
end


function InventoryUI:ApplyButtonEffect(button)
	-- 1. Cache only the button size
	if not tweenCache[button] then
		tweenCache[button] = button.Size
	end

	-- 2. Configuration
	-- Using 'Back' easing for hover gives it that bouncy, premium feel
	local sizeTweenInfo = d.HoverInfo or TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local clickTweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local isHovering = false

	local originalSize = tweenCache[button]

	-- 3. Unified Scaling Logic
	local function scaleButton(multiplier, info)
		local newSize = UDim2.new(
			originalSize.X.Scale * multiplier, 0, 
			originalSize.Y.Scale * multiplier, 0
		)
		d.TweenService:Create(button, info, {Size = newSize}):Play()
	end

	-- 4. Triggers
	table.insert(self.Connections, button.MouseEnter:Connect(function()
		isHovering = true
		MusicModule:PlaySFX("Hover")
		scaleButton(1.1, sizeTweenInfo) -- Grow 10%
	end))

	table.insert(self.Connections, button.MouseLeave:Connect(function()
		isHovering = false
		scaleButton(1, sizeTweenInfo) -- Reset
	end))

	table.insert(self.Connections, button.MouseButton1Down:Connect(function()
		scaleButton(0.9, clickTweenInfo) -- Shrink on click
	end))

	table.insert(self.Connections, button.MouseButton1Up:Connect(function()
		local targetMultiplier = isHovering and 1.1 or 1
		scaleButton(targetMultiplier, clickTweenInfo)
	end))
end
------------------------------------------------------------------------------------------------------------------------------------

return InventoryUI