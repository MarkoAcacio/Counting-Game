local GachaUI = {}

local d = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Directory"))

-- Modules
local MusicModule = require(d.Modules:WaitForChild("MusicModule"))


local FetchGachaFrame

-- containerFramePos | {0.157, 0},{0.208, 0}

-- Configs

local numberOfTemplates = 68
local TargetCanvasPos = 8300
local RewardTemplate = 62

-- Tween 

local OpeningAnim = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local DragContainer = TweenInfo.new(1.5, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
local ScrollAnimation = TweenInfo.new(9, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)


-- Images

local Images = {
	temp = "rbxassetid://76241828849737"
}

local ItemTable= {
		"Death1", "Death2", "Death3","Emote1", "Emote2", "Emote3"
}

local isCloned = false
local tweenConnections = {}
local cloneTable = {}

local RewardFramePos

local RARITY_COLORS = {
	["Common"] = Color3.fromRGB(255, 255, 255), -- White
	["Rare"] = Color3.fromRGB(117, 198, 255),   -- Light Blue
	["Mythical"] = Color3.fromRGB(170, 0, 255), -- Purple
}

GachaUI.connections = {}

-----------------------------------------------------------------------------------------------

function GachaUI:DisconnectConnections()
	for _, conn in ipairs(self.connections) do
		conn:Disconnect()
	end
	table.clear(self.connections)
	
	for _, conn in ipairs(tweenConnections) do
		conn:Disconnect()
	end
	table.clear(tweenConnections)
end


function GachaUI:Init()
	
	self:DisconnectConnections()
	
	GachaUI.PreloadImages()
	
	-- @PARAMS | caseItem ( Determined Reward ), CaseType ( Normal, Premium )
	table.insert(self.connections, d.GachaEvent.OnClientEvent:Connect(function(caseItem, CaseType, ProximityPrompt, allPrizes)
		ProximityPrompt.Enabled = false
		-- Pass allPrizes into the next function
		GachaUI.OpenGachaUI(caseItem, CaseType, ProximityPrompt, allPrizes)
	end))
end

-----------------------------------------------------------------------------------------------

function GachaUI.OpenGachaUI(caseItem, CaseType, ProximityPrompt, allPrizes)
	local gachaFrame, ContainerFrame, ScrollingFrame, ItemTemplate, midPoint, CaseName, PrizeName = FetchGachaFrame()
	
	if GachaUI.CloneTemplate(ItemTemplate, ScrollingFrame, caseItem, allPrizes) then
		gachaFrame.Visible = true
		
		local BGTween = d.TweenService:Create(gachaFrame, OpeningAnim, {BackgroundTransparency = 0.4})
		local containerTween = d.TweenService:Create(ContainerFrame, DragContainer, {Position = UDim2.new(0.5, 0, 0.45, 0)})
		

		BGTween:Play()
		table.insert(tweenConnections, BGTween.Completed:Connect(function()
			containerTween:Play()
		end))

		-- Inside OpenGachaUI
		table.insert(tweenConnections, containerTween.Completed:Connect(function()
			task.wait(0.3)
			MusicModule:PlaySFX("Spin")
			-- ADD caseItem HERE
			GachaUI.SpinGacha(caseItem, CaseType, ProximityPrompt)
		end))
		

	end
	
end


function GachaUI.SpinGacha(caseItem, CaseType, ProximityPrompt)
	local gachaFrame, ContainerFrame, ScrollingFrame, ItemTemplate, midPoint, CaseName, PrizeName = FetchGachaFrame()

	local GachaTween = d.TweenService:Create(ScrollingFrame, ScrollAnimation, {CanvasPosition = Vector2.new(RewardFramePos, 0)})
	GachaTween:Play()

	-- ADD caseItem HERE
	return GachaUI.GachaFinished(gachaFrame, GachaTween, ContainerFrame, ProximityPrompt, caseItem)
end


function GachaUI.GachaFinished(GachaFrame, GachaTween : Tween, ContainerFrame, ProximityPrompt:ProximityPrompt, CaseItem)

	table.insert(tweenConnections, GachaTween.Completed:Connect(function()
		MusicModule:PlaySFX("SpinFinish")

		-- Display the final prize name in the UI label
		local _, _, _, _, _, _, PrizeName = FetchGachaFrame()
		if PrizeName then
			PrizeName.Text = "YOU WON: " .. CaseItem.Name
			PrizeName.TextColor3 = RARITY_COLORS[CaseItem.RarityName] or Color3.new(1,1,1)
			PrizeName.Visible = true
		end

		task.wait(3)
		ProximityPrompt.Enabled = true
		GachaUI.ResetUI(GachaFrame, ContainerFrame)  
	end))
end


local function getRarityColor(rarityName)
	return RARITY_COLORS[rarityName] or Color3.new(1, 1, 1)
end

function GachaUI.CloneTemplate(ItemTemplate : Frame, ScrollingFrame : ScrollingFrame, CaseItem, allPrizes)
	local counter = 0
	local rewardFrame = nil

	-- Cleanup existing clones
	for _, clone in pairs(cloneTable) do clone:Destroy() end
	table.clear(cloneTable)

	while counter <= numberOfTemplates do
		local clone = ItemTemplate:Clone()
		local itemImage = clone:WaitForChild("ItemImage")
		local itemName = clone:WaitForChild("ItemName")

		-- Ensure a UIStroke exists for the border
		local stroke = clone:FindFirstChild("UIStroke") or Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = clone

		clone.Visible = true

		-- PICK FILLER DATA
		-- We pick a random item from the actual prize pool for the 'filler' effect
		local fillerData = allPrizes[math.random(1, #allPrizes)]

		itemName.Text = fillerData.Name
		itemName.TextColor3 = getRarityColor(fillerData.RarityName)
		stroke.Color = getRarityColor(fillerData.RarityName)

		-- Placeholder for Image (Update this if you add icons to your table later)
		itemImage.Image = Images.temp 

		-- THE REWARD (The actual item the player won)
		if counter == RewardTemplate then
			rewardFrame = clone
			itemName.Text = CaseItem.Name

			local rewardColor = getRarityColor(CaseItem.RarityName)
			itemName.TextColor3 = rewardColor
			stroke.Color = rewardColor
			stroke.Thickness = 4 -- Make the reward border thicker!

			-- Add a slight "Glow" effect for Mythical rewards
			if CaseItem.RarityName == "Mythical" then
				local gradient = Instance.new("UIGradient")
				gradient.Color = ColorSequence.new(rewardColor, Color3.new(1,1,1))
				gradient.Parent = stroke
			end
		end

		table.insert(cloneTable, clone)
		clone.Parent = ScrollingFrame
		counter += 1
	end

	task.wait()

	if rewardFrame then
		local frameCanvasPos = rewardFrame.AbsolutePosition.X - ScrollingFrame.AbsolutePosition.X
		RewardFramePos = frameCanvasPos + (rewardFrame.AbsoluteSize.X / 2) - (ScrollingFrame.AbsoluteSize.X / 2)
	end

	return true
end


function GachaUI.PreloadImages()
	local preloadList = {}

	for _, imageId in pairs(Images) do
		table.insert(preloadList, imageId)
	end

	d.ContentProvider:PreloadAsync(preloadList)
end

function GachaUI.ResetUI(gachaFrame : Frame, ContainerFrame : Frame)

	gachaFrame.Visible = false
	ContainerFrame.Position = UDim2.new(0.5, 0, -0.5, 0)

	-- Clear the prize text for the next spin
	local _, _, _, _, _, _, PrizeName = FetchGachaFrame()
	if PrizeName then
		PrizeName.Text = ""
		PrizeName.Visible = false
	end
	
	local ScrollingFrame = ContainerFrame:WaitForChild("ScrollingFrame")
	
	ScrollingFrame.CanvasPosition = Vector2.new(0, 0)

	for i, clone in pairs(cloneTable) do
		if clone and clone.Parent then
			clone:Destroy()
		end
	end
	table.clear(cloneTable)

	task.defer(function()
		for _, connection in pairs(tweenConnections) do
			connection:Disconnect()
		end
		table.clear(tweenConnections)
	end)
end
-----------------------------------------------------------------------------------------------

FetchGachaFrame = function()
	local ScreenGui = d.localPlayer:WaitForChild("PlayerGui"):WaitForChild("UI"):WaitForChild("ScreenGui")
	ScreenGui.ResetOnSpawn = false
	
	local gachaFrame = ScreenGui:WaitForChild("GachaFrame")
	local ContainerFrame = gachaFrame:WaitForChild("Container")
	local ScrollingFrame = ContainerFrame:WaitForChild("ScrollingFrame")
	local ItemTemplate = ScrollingFrame:WaitForChild("template") -- VISIBILITY = FALSE
	local midPoint = ScrollingFrame.AbsoluteSize.Y / 2
	local CaseName = ContainerFrame:WaitForChild("CaseName")
	local PrizeName = ContainerFrame:WaitForChild("PrizeName")
	
	
	return gachaFrame, ContainerFrame, ScrollingFrame, ItemTemplate, midPoint, CaseName, PrizeName
end

-----------------------------------------------------------------------------------------------



return GachaUI
