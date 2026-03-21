local TweenUtils = {}

local d = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Directory"))

local sizeTweenInfo = d.HoverInfo or TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local clickTweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)


------------------------------------------

local hoverScale = 1.1
local clickScale = 0.9
local HoverCache = {}
local HoverConnections = {}
local RotateConnections = {}
local IdleConnections = {}

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

local ShakeCache = {}

function TweenUtils:ShakeButton(Button)
	-- 1. Initialize cache with BOTH Rotation and Size
	if not ShakeCache[Button] then
		ShakeCache[Button] = {
			Rotation = Button.Rotation,
			Size = Button.Size, -- Store the original size for resetting
			LastDir = 1
		}
	end

	-- 2. Configuration
	local shakeIntensity = 10   -- Degrees of tilt
	local popIntensity = 1.1    -- 1.1 = 110% of original size
	local shakeTime = 0.07      -- Very snappy

	-- We use 'true' for Reverses so it automatically returns to original state
	local info = TweenInfo.new(shakeTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, true)

	-- 3. Reset & Flip (Spam-Proofing)
	Button.Rotation = ShakeCache[Button].Rotation
	Button.Size = ShakeCache[Button].Size

	ShakeCache[Button].LastDir *= -1

	-- 4. Calculate Targets
	local targetRotation = ShakeCache[Button].Rotation + (shakeIntensity * ShakeCache[Button].LastDir)
	local targetSize = UDim2.new(
		ShakeCache[Button].Size.X.Scale * popIntensity, 0, 
		ShakeCache[Button].Size.Y.Scale * popIntensity, 0
	)

	-- 5. Create and Play "Weighted" Shake
	local weightedTween = d.TweenService:Create(Button, info, {
		Rotation = targetRotation,
		Size = targetSize
	})

	weightedTween:Play()
end
function TweenUtils.BG_Blur(state : boolean, size : number)
	local blur = game:GetService("Lighting"):WaitForChild("Blur")
	
	local info = TweenInfo.new(0.3, Enum.EasingStyle.Quad, state and Enum.EasingDirection.Out or Enum.EasingDirection.In)
	local goal = {Size = size}
	local tween = d.TweenService:Create(blur, info, goal)
	
	if state then
		blur.Enabled = true
		tween:Play()
	else
		task.spawn(function()
			tween:Play()
			tween.Completed:Wait()
			blur.Enabled=false
		end)
	end
end


function TweenUtils:SpinUI(Element, speed)
	-- 1. Default speed if none provided
	local spinSpeed = speed or 45 -- Degrees per second

	-- 2. Clean up any existing rotation for this specific element
	if RotateConnections[Element] then
		RotateConnections[Element]:Disconnect()
		RotateConnections[Element] = nil
	end

	-- 3. Start the rotation loop
	RotateConnections[Element] = game:GetService("RunService").RenderStepped:Connect(function(dt)
		if not Element or not Element.Parent then
			RotateConnections[Element]:Disconnect()
			RotateConnections[Element] = nil
			return
		end

		-- Use dt (delta time) so it spins at the same speed regardless of FPS
		Element.Rotation = Element.Rotation + (spinSpeed * dt)
	end)
end

function TweenUtils:StopSpin(Element)
	if RotateConnections[Element] then
		RotateConnections[Element]:Disconnect()
		RotateConnections[Element] = nil
	end
end

function TweenUtils:SetIdleFloat(Element, speed, amplitude)
	local floatSpeed = speed or 2 -- How fast it bobs
	local floatAmp = amplitude or 0.05 -- How far it moves (Scale)

	-- Store original position to calculate offset from "home"
	local originalPos = Element.Position

	-- Clean up existing idle if it exists
	if IdleConnections[Element] then
		IdleConnections[Element]:Disconnect()
	end

	-- Random offset so multiple items don't sync up perfectly
	local syncOffset = math.random() * 10 

	IdleConnections[Element] = game:GetService("RunService").RenderStepped:Connect(function()
		if not Element or not Element.Parent then
			IdleConnections[Element]:Disconnect()
			return
		end

		local t = (tick() + syncOffset) * floatSpeed
		local yOffset = math.sin(t) * floatAmp

		-- Apply the bobbing to the Y Scale
		Element.Position = UDim2.new(
			originalPos.X.Scale, 
			originalPos.X.Offset, 
			originalPos.Y.Scale + yOffset, 
			originalPos.Y.Offset
		)
	end)
end

function TweenUtils:StopIdle(Element)
	if IdleConnections[Element] then
		IdleConnections[Element]:Disconnect()
		IdleConnections[Element] = nil
	end
end
------------------------------------------

-- PUT TWEENS HERE LATER! FOR NOW, TWEEN IN THEIR OWN MODULES...



return TweenUtils
