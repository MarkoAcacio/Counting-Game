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
	table.insert(self.connections, d.GachaEvent.OnClientEvent:Connect(function(caseItem, CaseType, ProximityPrompt : ProximityPrompt)
		ProximityPrompt.Enabled = false
		GachaUI.OpenGachaUI(caseItem, CaseType, ProximityPrompt)
	end))
	
end

-----------------------------------------------------------------------------------------------

function GachaUI.OpenGachaUI(caseItem, CaseType, ProximityPrompt)
	local gachaFrame, ContainerFrame, ScrollingFrame, ItemTemplate, midPoint, CaseName, PrizeName = FetchGachaFrame()
	
	if GachaUI.CloneTemplate(ItemTemplate, ScrollingFrame, caseItem) then
		gachaFrame.Visible = true
		
		local BGTween = d.TweenService:Create(gachaFrame, OpeningAnim, {BackgroundTransparency = 0.4})
		local containerTween = d.TweenService:Create(ContainerFrame, DragContainer, {Position = UDim2.new(0.5, 0, 0.45, 0)})
		

		BGTween:Play()
		table.insert(tweenConnections, BGTween.Completed:Connect(function()
			containerTween:Play()
		end))

		table.insert(tweenConnections, containerTween.Completed:Connect(function()
			task.wait(0.3)
			-- RUN GACHA SPIN HERE
			MusicModule:PlaySFX("Spin")
			GachaUI.SpinGacha(caseItem, CaseType,  ProximityPrompt)

		end))
		

	end
	
end


function GachaUI.SpinGacha(caseItem, CaseType,  ProximityPrompt)
	local gachaFrame, ContainerFrame, ScrollingFrame, ItemTemplate, midPoint, CaseName, PrizeName = FetchGachaFrame()
	
	local GachaTween = d.TweenService:Create(ScrollingFrame, ScrollAnimation, {CanvasPosition = Vector2.new(RewardFramePos, 0)})
	GachaTween:Play()

	
	return GachaUI.GachaFinished(gachaFrame,GachaTween, ContainerFrame,  ProximityPrompt)
end



function GachaUI.GachaFinished(GachaFrame, GachaTween : Tween, ContainerFrame,  ProximityPrompt:ProximityPrompt)
	
	table.insert(tweenConnections, GachaTween.Completed:Connect(function()
		MusicModule:PlaySFX("SpinFinish")
		task.wait(3)
		ProximityPrompt.Enabled = true
		GachaUI.ResetUI(GachaFrame, ContainerFrame)  
	end))
	
end



function GachaUI.CloneTemplate(ItemTemplate : Frame, ScrollingFrame : ScrollingFrame, CaseItem)
	local counter = 0
	local rewardFrame = nil
	
	

	while counter <= numberOfTemplates do
		local clone = ItemTemplate:Clone()
		local itemImage = clone:WaitForChild("ItemImage")
		local itemName = clone:WaitForChild("ItemName")
		clone.Visible = true

		itemImage.Image = Images.temp
		itemName.Text = ItemTable[math.random(1, #ItemTable)]

		if counter == 62 then
			rewardFrame = clone
			itemName.Text = CaseItem
		end
		
		table.insert(cloneTable, clone)

		clone.Parent = ScrollingFrame
		counter += 1
	end

	-- Wait for UIListLayout to update positions
	task.wait()

	if rewardFrame then
		-- Calculate position to center the reward frame in viewport
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
