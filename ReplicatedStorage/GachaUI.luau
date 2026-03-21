local GachaUI = {}

local d = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Directory"))

-- Modules
local MusicModule = require(d.Modules:WaitForChild("MusicModule"))


GachaUI.Spinning = false

local FetchGachaFrame

-- containerFramePos | {0.157, 0},{0.208, 0}

-- Configs

local numberOfTemplates = 68
local TargetCanvasPos = 8300
local RewardTemplate = 62

local prox = {
	Normal = d.CasesFolder.NormalCase:WaitForChild("Mesh").ProximityPrompt,
	Premium = d.CasesFolder.PremiumCase:WaitForChild("Mesh").ProximityPrompt,
}

-- Tween 

local OpeningAnim = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local DragContainer = TweenInfo.new(1.5, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
local ScrollAnimation = TweenInfo.new(9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)


-- Images

local Images = {
	temp = "rbxassetid://76241828849737",
	Common = "rbxassetid://105563091365190",
	Rare = "rbxassetid://109584791294995",
	Mythical = "rbxassetid://111810078433809"
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
local blur = d.Lighting:WaitForChild("Blur")

-- NEW: Track currently active proximity prompts
local activeProximityPrompts = {}

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

-- NEW: Function to clean up active state
function GachaUI:CleanupState()
	-- Stop any ongoing tweens
	for _, conn in ipairs(tweenConnections) do
		conn:Disconnect()
	end
	table.clear(tweenConnections)

	-- Clear clones
	for _, clone in pairs(cloneTable) do
		if clone and clone.Parent then
			clone:Destroy()
		end
	end
	table.clear(cloneTable)

	-- Reset spinning state
	self.Spinning = false

	-- Re-enable all proximity prompts
	for _, prompt in ipairs(activeProximityPrompts) do
		if prompt then
			prompt.Enabled = true
		end
	end
	table.clear(activeProximityPrompts)

	-- Reset UI
	local success, gachaFrame = pcall(function()
		return d.localPlayer.PlayerGui:FindFirstChild("UI"):FindFirstChild("ScreenGui"):FindFirstChild("GachaFrame")
	end)

	if success and gachaFrame then
		gachaFrame.Visible = false
		local ContainerFrame = gachaFrame:FindFirstChild("Container")
		if ContainerFrame then
			ContainerFrame.Position = UDim2.new(0.5, 0, -0.5, 0)

			local ScrollingFrame = ContainerFrame:FindFirstChild("ScrollingFrame")
			if ScrollingFrame then
				ScrollingFrame.CanvasPosition = Vector2.new(0, 0)
			end

			-- Hide prize elements
			local PrizeName = ContainerFrame:FindFirstChild("PrizeName")
			if PrizeName then
				PrizeName.Text = ""
				PrizeName.Visible = false
			end

			local PrizeFrame = ContainerFrame:FindFirstChild("Prize")
			if PrizeFrame then
				PrizeFrame.Visible = false
			end
		end
	end
end


function GachaUI:Init()
	-- Only disconnect if we're truly re-initializing
	if #self.connections > 0 then
		self:DisconnectConnections()
	end

	GachaUI.PreloadImages()

	-- @PARAMS | caseItem ( Determined Reward ), CaseType ( Normal, Premium )
	table.insert(self.connections, d.GachaEvent.OnClientEvent:Connect(function(caseItem, CaseType, ProximityPrompt, allPrizes)
		-- Don't process if we're already spinning
		if self.Spinning then return end

		ProximityPrompt.Enabled = false
		table.insert(activeProximityPrompts, ProximityPrompt)

		GachaUI.OpenGachaUI(caseItem, CaseType, ProximityPrompt, allPrizes)
	end))

	-- Detect when player dies/resets and clean up everything
	table.insert(self.connections, d.localPlayer.CharacterRemoving:Connect(function()
		self:CleanupState()
	end))

	-- DON'T reconnect on CharacterAdded - the connection is still valid
	-- The Init() should only be called ONCE when the module first loads
end
-----------------------------------------------------------------------------------------------

function GachaUI.OpenGachaUI(caseItem, CaseType, ProximityPrompt, allPrizes)
	local gachaFrame, ContainerFrame, ScrollingFrame, ItemTemplate, midPoint, CaseName, PrizeName = FetchGachaFrame()

	local gradientName = (CaseType == "PremiumCase") and "PM_Gradient" or "NC_Gradient"
	local existingGradient = ContainerFrame:FindFirstChild("GachaGradient")
	CaseName.Text = CaseType == "PremiumCase" and "Premium Case" or "Normal Case"

	if existingGradient then existingGradient:Destroy() end

	local newGradient = d.ReplicatedStorage:WaitForChild("Particles"):FindFirstChild(gradientName):Clone()
	newGradient.Name = "GachaGradient"
	newGradient.Parent = CaseName

	-- Set spinning state
	GachaUI.Spinning = true
	local info = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local blurTween = d.TweenService:Create(blur, info, {Size = 24})
	blur.Enabled = true
	blurTween:Play()

	local ScreenGui = gachaFrame.Parent
	local DR = ScreenGui:FindFirstChild("DailyRewards")
	local EW = ScreenGui:FindFirstChild("EmoteWheel")
	local IV = ScreenGui:FindFirstChild("Inventory")
	local SH = ScreenGui:FindFirstChild("ShopUI")

	DR.Visible = false
	EW.Visible = false
	IV.Visible = false
	SH.Visible = false

	if CaseType == "PremiumCase" then
		prox.Normal.Enabled = false
	elseif CaseType == "NormalCase" then
		prox.Premium.Enabled = false
	end



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
		local _, _, _, _, _, _, PrizeName, PrizeFrame = FetchGachaFrame()
		if PrizeName then
			PrizeName.Text = "YOU WON: " .. CaseItem.Name
			PrizeName.TextColor3 = RARITY_COLORS[CaseItem.RarityName] or Color3.new(1,1,1)
			PrizeName.Visible = true
		end

		if PrizeFrame then
			PrizeFrame.Visible = true

			-- Update ItemName text color
			local itemName = PrizeFrame:FindFirstChild("ItemName")
			if itemName then
				itemName.Text = CaseItem.Name
				itemName.TextColor3 = RARITY_COLORS[CaseItem.RarityName]
			end

			-- Update background image based on rarity
			local bg = PrizeFrame:FindFirstChild("bg")
			if bg then
				bg.Image = Images[CaseItem.RarityName] or Images.Common
			end
		end

		task.wait(3)

		-- Pass ProximityPrompt to ResetUI
		local info = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local blurTween = d.TweenService:Create(blur, info, {Size = 0})
		blurTween:Play()
		task.spawn(function()
			blur.Enabled = false
		end)
		prox.Normal.Enabled = true
		prox.Premium.Enabled = true
		GachaUI.ResetUI(GachaFrame, ContainerFrame, ProximityPrompt)  
	end))
end


local function getRarityColor(rarityName)
	return RARITY_COLORS[rarityName] or Color3.new(1, 1, 1)
end

function GachaUI.CloneTemplate(Templates, ScrollingFrame, CaseItem, allPrizes)
	local counter = 0
	local rewardFrame = nil

	-- Cleanup existing clones
	for _, clone in pairs(cloneTable) do clone:Destroy() end
	table.clear(cloneTable)

	while counter <= numberOfTemplates do
		-- PICK FILLER DATA
		local fillerData = allPrizes[math.random(1, #allPrizes)]

		-- NEW: Get the appropriate template based on rarity
		local templateToUse

		-- THE REWARD (The actual item the player won) - Use correct template
		if counter == RewardTemplate then
			templateToUse = Templates[CaseItem.RarityName]
			if not templateToUse then
				warn("No template found for reward rarity:", CaseItem.RarityName)
				templateToUse = Templates.Common
			end
		else
			templateToUse = Templates[fillerData.RarityName]
			if not templateToUse then
				warn("No template found for rarity:", fillerData.RarityName)
				templateToUse = Templates.Common -- Fallback to Common
			end
		end

		local clone = templateToUse:Clone()
		local itemName = clone:FindFirstChild("ItemName")

		clone.Visible = true

		-- Set the item name and text color
		if counter == RewardTemplate then
			-- THE REWARD
			rewardFrame = clone
			if itemName then
				itemName.Text = CaseItem.Name
				itemName.TextColor3 = RARITY_COLORS[CaseItem.RarityName] or Color3.new(1,1,1)
			end
		else
			-- FILLER
			if itemName then
				itemName.Text = fillerData.Name
				itemName.TextColor3 = RARITY_COLORS[fillerData.RarityName] or Color3.new(1,1,1)
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

function GachaUI.ResetUI(gachaFrame : Frame, ContainerFrame : Frame, ProximityPrompt)

	-- Re-enable the ProximityPrompt
	if ProximityPrompt then
		ProximityPrompt.Enabled = true

		-- Remove from active prompts list
		for i, prompt in ipairs(activeProximityPrompts) do
			if prompt == ProximityPrompt then
				table.remove(activeProximityPrompts, i)
				break
			end
		end
	end

	local existingGradient = ContainerFrame.CaseName:FindFirstChild("GachaGradient")
	if existingGradient then
		existingGradient:Destroy()
	end

	gachaFrame.Visible = false
	ContainerFrame.Position = UDim2.new(0.5, 0, -0.5, 0)

	-- Clear the prize text for the next spin
	local _, _, _, _, _, _, PrizeName, PrizeFrame = FetchGachaFrame()
	if PrizeName then
		PrizeName.Text = ""
		PrizeName.Visible = false
	end

	if PrizeFrame then
		PrizeFrame.Visible = false
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

	-- Reset spinning state
	GachaUI.Spinning = false
end
-----------------------------------------------------------------------------------------------

FetchGachaFrame = function()
	local ScreenGui = d.localPlayer:WaitForChild("PlayerGui"):WaitForChild("UI"):WaitForChild("ScreenGui")
	ScreenGui.ResetOnSpawn = false

	local gachaFrame = ScreenGui:WaitForChild("GachaFrame")
	local ContainerFrame = gachaFrame:WaitForChild("Container")
	local ScrollingFrame = ContainerFrame:WaitForChild("ScrollingFrame")

	local Templates = {
		Common = ScrollingFrame:WaitForChild("Common"),
		Rare = ScrollingFrame:WaitForChild("Rare"),
		Mythical = ScrollingFrame:WaitForChild("Mythical")
	}

	local midPoint = ScrollingFrame.AbsoluteSize.Y / 2
	local CaseName = ContainerFrame:WaitForChild("CaseName")
	local PrizeName = ContainerFrame:WaitForChild("PrizeName")
	local PrizeFrame = ContainerFrame:FindFirstChild("Prize")

	return gachaFrame, ContainerFrame, ScrollingFrame, Templates, midPoint, CaseName, PrizeName, PrizeFrame
end
-----------------------------------------------------------------------------------------------



return GachaUI