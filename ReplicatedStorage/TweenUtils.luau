local TweenUtils = {}

local d = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Directory"))

local sizeTweenInfo = d.HoverInfo or TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local clickTweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)


------------------------------------------

local hoverScale = 1.1
local clickScale = 0.9
local HoverCache = {}
local HoverConnections = {}

function TweenUtils:TweenButton(Button)
	
	local hoverScale = 1.1
	local clickScale = 0.9
	
	if not HoverCache[Button] then
		HoverCache[Button] = Button.Size
	end
	
	if not HoverConnections[Button] then
		HoverConnections[Button] = {}
	end
	
	local originalSize = HoverCache[Button]
	local isHovering = false
	
	local hoverSize = UDim2.new(originalSize.X.Scale * hoverScale, 0, originalSize.Y.Scale * hoverScale, 0)
	local shrinkSize = UDim2.new(originalSize.X.Scale * clickScale, 0, originalSize.Y.Scale * clickScale, 0)
	
	local function scaleButton(multiplier, info)
		local newSize = UDim2.new(
			originalSize.X.Scale * multiplier, 0, 
			originalSize.Y.Scale * multiplier, 0
		)
		d.TweenService:Create(Button, info, {Size = newSize}):Play()
	end	
	
	table.insert(HoverConnections[Button], Button.MouseEnter:Connect(function()
		isHovering = true
		local tween = d.TweenService:Create(Button, sizeTweenInfo, {Size = hoverSize})
		tween:Play()
	end))

	-- Mouse Leave
	table.insert(HoverConnections[Button], Button.MouseLeave:Connect(function()
		isHovering = false
		local tween = d.TweenService:Create(Button, sizeTweenInfo, {Size = originalSize})
		tween:Play()
	end))

	-- Mouse Down
	table.insert(HoverConnections[Button], Button.MouseButton1Down:Connect(function()
		local tween = d.TweenService:Create(Button, clickTweenInfo, {Size = shrinkSize})
		tween:Play()
	end))

	-- Mouse Up
	table.insert(HoverConnections[Button], Button.MouseButton1Up:Connect(function()
		local targetSize = isHovering and hoverSize or originalSize
		local tween = d.TweenService:Create(Button, clickTweenInfo, {Size = targetSize})
		tween:Play()
	end))
	
end


------------------------------------------

-- PUT TWEENS HERE LATER! FOR NOW, TWEEN IN THEIR OWN MODULES...



return TweenUtils
