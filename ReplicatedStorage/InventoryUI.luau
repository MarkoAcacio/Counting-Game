local InventoryUI = {}

local d = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Directory"))
local MusicModule = require(d.Modules:WaitForChild("MusicModule"))

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

InventoryUI.CaseClones = {}
InventoryUI.EmoteClones = {}
InventoryUI.ImageClones = {}

local _emoteTemplate

------------------------------------------------------------------------------------------------------------------------------------

local function fetchInventoryUI()
	local player = d.localPlayer
	local ScreenGui = player:WaitForChild("PlayerGui"):WaitForChild("UI"):WaitForChild("ScreenGui")
	local InventoryButton = ScreenGui:WaitForChild("LeftFrame"):WaitForChild("Inventory")
	local InventoryFrame = ScreenGui:WaitForChild("Inventory")

	return InventoryButton, InventoryFrame
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
	local InventoryBtn, InventoryFrame = fetchInventoryUI()
	self:HandleListeners(InventoryBtn, InventoryFrame)
	
	self:CloneTemplate(InventoryFrame)
	self:LoadButtons()
end


function InventoryUI:parseData(data)
	self.EmoteData = data.Inventory.Emotes
	self.ImageData = data.Inventory.CountImages
	self.CaseData = data.Inventory.Case
	self.NumOfEmotes = data.Slots.emoteSlots
	self.NumOfCases = data.Slots.caseSlots
end


local db = false
local isLoaded = false
function InventoryUI:HandleListeners(InventoryBtn : ImageButton, InventoryFrame : Frame)

	local CaseCategory = InventoryFrame:WaitForChild("Cases")
	local EmoteCategory = InventoryFrame:WaitForChild("Emotes")
	local AllCategory = InventoryFrame:WaitForChild("All")
	local CategoryText = InventoryFrame:WaitForChild("CategoryText")

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
		if db == true then db = false InventoryFrame.Visible = false MusicModule:PlaySFX("Click") return end
		
		MusicModule:PlaySFX("Click")
		InventoryFrame.Visible = not InventoryFrame.Visible
		db = true

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

-- Handles Equip & Open buttons.
function InventoryUI:_Buttons()
	
	-- Clears old connections & Rebuild when new emote is loaded.
	self:clearButtonConn()
	
	----- EQUIP BUTTON -----
	
	for _, buttons in pairs(self.EquipButtons) do
		local Slot = buttons.Parent:WaitForChild("Slot")
		for _, child in ipairs(Slot:GetChildren()) do
			
			-- Handle Equip...
			-- Inside InventoryUI:_Buttons()
			if child:IsA("TextButton") then
				table.insert(self._ButtonConn, child.MouseButton1Click:Connect(function()
					MusicModule:PlaySFX("Click") -- Play sound here
					local slotName = "Emote"..child.Name -- e.g., "Emote1"
					local emoteName = buttons.Parent.Name
					local emoteID = self.EmoteClones[emoteName].emoteID

					-- 1. Update local UI immediately
					self.EquipEmote = {
						slotName = slotName,
						emoteName = emoteName,
						emoteID = emoteID,
					}
					d.EmoteChange:Fire() 

					-- 2. Tell the server to SAVE it to the EmoteConfig template
					d.SaveEmoteSlot:FireServer(slotName, emoteName, emoteID)

					MusicModule.PlaySFX("Click")
					buttons.Parent.Slot.Visible = false
				end))
			end
			
			-- Exit Slot
			if child:IsA("ImageButton") then
				table.insert(self._ButtonConn, child.MouseButton1Click:Connect(function()
					Slot.Visible = false
				end))
			end
		end
	end

	for _, buttons in pairs(self.EquipButtons) do

		table.insert(self._ButtonConn, buttons.MouseButton1Click:Connect(function()
			MusicModule:PlaySFX("Click")
			local slot = buttons.Parent.Slot
			slot.Visible = true

		end))
	end

	------ OPEN BUTTON ------

	for _, buttons in pairs(self.OpenButtons) do
		table.insert(self._ButtonConn, buttons.MouseButton1Click:Connect(function()
			MusicModule:PlaySFX("Click")
		end))
	end

	-----------------------------
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
	
	self:_Buttons()
	
end


function InventoryUI:CloneTemplate(InventoryFrame : Frame)
	local ScrollingFrame = InventoryFrame:WaitForChild("UI"):WaitForChild("ScrollingFrame")
	local CaseTemplate = ScrollingFrame:WaitForChild("CaseTemplate")
	local EmoteTemplate = ScrollingFrame:WaitForChild("EmoteTemplate")
	local imageTemplate = ScrollingFrame:WaitForChild("ImageTemplate")
	_emoteTemplate = EmoteTemplate
	
	repeat 
		task.wait(0.1) 
	until typeof(self.CaseData) == "table" and next(self.CaseData) ~= nil

	
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
	
	for _imageName, imageID in pairs(self.ImageData) do
		local ImageClone = imageTemplate:Clone()
		ImageClone.Parent = ScrollingFrame
		ImageClone.Name = _imageName
		ImageClone.imgName.Text = _imageName
		ImageClone.Visible = true
		
		print(imageID)
		
		ImageClone.img.Image = "rbxassetid://"  .. 4575171283  -- find image id & change image 

		self.ImageClones[_imageName] = { image = ImageClone, imageID = imageID }
	end


	for _emoteName, emoteID in pairs(self.EmoteData) do
		local EmoteClone = EmoteTemplate:Clone()
		EmoteClone.Parent = ScrollingFrame
		EmoteClone.Name = _emoteName
		EmoteClone.emoteName.Text = _emoteName
		EmoteClone.Visible = true

		self:PlaySlotEmote(EmoteClone, emoteID)

		self.EmoteClones[_emoteName] = { emote = EmoteClone, emoteID = emoteID }
	end

end


function InventoryUI:UpdateInventory()
	-- Handle Case Update
	for caseName, caseQty in pairs(self.CaseData) do
		if self.CaseClones[tostring(caseName)] then
			self.CaseClones[tostring(caseName)].case.qty.Text = "QTY: ".. caseQty
		end
	end

	local newlyAdded = false

	-- Handle New Emotes
	for emoteName, emoteID in pairs(self.EmoteData) do
		if not self.EmoteClones[emoteName] then
			local EmoteClone = _emoteTemplate:Clone()
			EmoteClone.Parent = _emoteTemplate.Parent
			EmoteClone.Name = emoteName
			EmoteClone.emoteName.Text = emoteName
			EmoteClone.Visible = true

			-- Ensure visibility matches current category filter
			local CategoryText = EmoteClone.Parent.Parent.Parent:WaitForChild("CategoryText")
			if CategoryText.Text == "Cases" then
				EmoteClone.Visible = false
			end

			self:PlaySlotEmote(EmoteClone, emoteID)
			self.EmoteClones[emoteName] = { emote = EmoteClone, emoteID = emoteID }

			newlyAdded = true
		end
	end

	-- If new items were added, we must rebuild the button tables and reconnect listeners
	if newlyAdded then
		-- Clear internal button tracking tables (but not the connections yet, 
		-- LoadButtons calls _Buttons which clears _ButtonConn)
		table.clear(self.EquipButtons)
		table.clear(self.OpenButtons)
		table.clear(self.EquipImageBtn)

		-- Re-scan all clones and re-apply listeners
		self:LoadButtons()
	end
end




function InventoryUI:ToggleCategory(Category : string, CategoryText : TextLabel)
	
	if Category == "Case" then  -- TURNS OFF VISIBILITY OF EMOTES TO FALSE
		
		for _, Button in pairs(self.EquipButtons) do
			local Template = Button.Parent
			Template.Visible = false
		end
		
		for _, Button in pairs(self.OpenButtons) do
			local Template = Button.Parent
			Template.Visible = true
		end
		
		CategoryText.Text = "Cases"
		
	elseif Category == "Emote" then
		
		for _, Button in pairs(self.OpenButtons) do
			local Template = Button.Parent
			Template.Visible = false
		end
		
		for _, Button in pairs(self.EquipButtons) do
			local Template = Button.Parent
			Template.Visible = true
		end
		
		CategoryText.Text = "Emotes"
		
	elseif Category == "All" then

		for _, Button in pairs(self.OpenButtons) do
			local Template = Button.Parent
			Template.Visible = true
		end
		
		for _, Button in pairs(self.EquipButtons) do
			local Template = Button.Parent
			Template.Visible = true
		end
		
		CategoryText.Text = "All"
		
	else
		warn("Invalid category")
	end

end



function InventoryUI:PlaySlotEmote(emoteSlot : Frame, emoteID)
	
	task.wait(0.3)
	
	local vp = emoteSlot:WaitForChild("vp")
	local rig = vp:WaitForChild("WorldModel"):WaitForChild("Rig")
	
	
	local animator = rig:WaitForChild("Humanoid"):WaitForChild("Animator")
	
	local anim = Instance.new("Animation")
	anim.Parent = animator
	anim.AnimationId = "rbxassetid://" .. emoteID
	
	local loadedAnimation = animator:LoadAnimation(anim)
	loadedAnimation.Priority = Enum.AnimationPriority.Action
	loadedAnimation:Play()
	loadedAnimation.Looped = true
	
end

------------------------------------------------------------------------------------------------------------------------------------

return InventoryUI
