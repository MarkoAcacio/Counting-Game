local BillboardService = {}

local d = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Directory"))

local RARITY_COLORS = {
	["Common"] = Color3.fromRGB(255, 255, 255), -- White
	["Rare"] = Color3.fromRGB(117, 198, 255),   -- Light Blue
	["Mythical"] = Color3.fromRGB(170, 0, 255), -- Purple
}

------------------------------------------

local function PlayEmoteInViewport(viewport, emoteID)
	local worldModel = viewport:FindFirstChildOfClass("WorldModel")
	if not worldModel then return end

	local rig = worldModel:FindFirstChild("Rig")
	if not rig then return end

	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")

	if animator then
		-- Use task.defer to run this at the end of the frame
		task.defer(function()
			local anim = Instance.new("Animation")
			anim.AnimationId = "rbxassetid://" .. tostring(emoteID)

			local success, track = pcall(function()
				return animator:LoadAnimation(anim)
			end)

			if success and track then
				track.Looped = true
				track:Play()
			else
				warn("Failed to load animation: " .. tostring(emoteID))
			end
		end)
	end

	-- Setup Camera
	local cam = viewport:FindFirstChildOfClass("Camera") or Instance.new("Camera")
	cam.FieldOfView = 50 -- Lowering this acts like a "Zoom Out," higher is "Wide Angle"
	viewport.CurrentCamera = cam
	cam.Parent = viewport

	local root = rig:FindFirstChild("HumanoidRootPart") or rig:FindFirstChild("UpperTorso")
	if root then
		-- INCREASE the 4 to 7 or 8 to move the camera further back
		-- INCREASE the 1.5 to 2 to look slightly more "down" on the character
		local cameraOffset = Vector3.new(0, 2, 7) 
		local lookAtOffset = Vector3.new(0, 0, 0) -- Center of the rig

		cam.CFrame = CFrame.new(root.Position + cameraOffset, root.Position + lookAtOffset)
	end
end

local function CloneTemplate(parentFrame, itemsList)
	local template = parentFrame:FindFirstChild("EmoteTemplate")
	if not template or not itemsList then return end
	template.Visible = false 

	-- Sort by Rarity (High to Low)
	table.sort(itemsList, function(a, b)
		return a.Rarity > b.Rarity
	end)

	-- Cleanup
	for _, child in pairs(parentFrame:GetChildren()) do
		if child:IsA("ViewportFrame") and child.Name ~= "EmoteTemplate" then
			child:Destroy()
		end
	end

	-- Populate
	for i, data in pairs(itemsList) do
		local clone = template:Clone()
		clone.Name = data.Name
		clone.LayoutOrder = i -- Forces the UI to respect the sorted order
		clone.Parent = parentFrame
		clone.Visible = true

		local emoteNameLabel = clone:FindFirstChild("EmoteName")
		local rarityLabel = clone:FindFirstChild("Rarity")

		-- Get the color based on rarity
		local rarityColor = RARITY_COLORS[data.RarityName] or Color3.new(1, 1, 1)

		if emoteNameLabel then 
			emoteNameLabel.Text = data.Name 
			emoteNameLabel.TextColor3 = rarityColor -- Applied rarity color to Name
		end

		if rarityLabel then
			local percent = data.Rarity * 100
			rarityLabel.Text = string.format("%s - %d%%", data.RarityName, percent)
			rarityLabel.TextColor3 = rarityColor -- Applied rarity color to Rarity text
		end

		if data.EmoteID then
			PlayEmoteInViewport(clone, data.EmoteID)
		end
	end
end


local function GetCases()
	local NormalCase = d.CasesFolder["NormalCase"]
	local PremiumCase = d.CasesFolder["PremiumCase"]
	local NormShow = NormalCase.NormShow
	local PremShow = PremiumCase.PremShow
	
	return NormalCase, PremiumCase, NormShow, PremShow
end

local function HoverCases(Normal, Premium)
	-- The baseline Y-axis you provided
	local originalY = 2.24
	local hoverHeight = 1.5 -- How high it floats up

	-- 1. Reset the meshes to their exact starting position immediately
	-- This prevents them from stacking heights if the script re-runs
	Normal.Position = Vector3.new(Normal.Position.X, originalY, Normal.Position.Z)
	Premium.Position = Vector3.new(Premium.Position.X, originalY, Premium.Position.Z)

	-- 2. Define the Hover Tween
	local HoverInfo = TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

	-- 3. Tween specifically to (originalY + hoverHeight)
	local tweenN = d.TweenService:Create(Normal, HoverInfo, {
		Position = Vector3.new(Normal.Position.X, originalY + hoverHeight, Normal.Position.Z)
	})

	local tweenP = d.TweenService:Create(Premium, HoverInfo, {
		Position = Vector3.new(Premium.Position.X, originalY + hoverHeight, Premium.Position.Z)
	})

	tweenN:Play()
	tweenP:Play()
end
------------------------------------------

function BillboardService:GetData()
	local success, result = pcall(function()
		return d.CaseRequest:InvokeServer()
	end)

	if success then
		return result
	else
		warn("The request failed!")
		return nil
	end
end


function BillboardService:SetupBillboards(casesData)
	local playerGui = d.localPlayer:WaitForChild("PlayerGui")
	local BillboardFolder = playerGui:FindFirstChild("Billboards") or playerGui:WaitForChild("Billboards")

	local NF = BillboardFolder.NormalCase.Frame
	local PF = BillboardFolder.PremiumCase.Frame
	
	local allData = self:GetData()

	if allData then
		if allData.Normal then
			CloneTemplate(NF, allData.Normal.Items)
		end
		if allData.Premium then
			CloneTemplate(PF, allData.Premium.Items)
		end
	end

	-- Helper function to check if the character touching is the LocalPlayer
	local function isLocalPlayer(hit)
		return hit.Parent == d.localPlayer.Character
	end

	-- NORMAL CASE
	casesData.NormShow.Touched:Connect(function(hit)
		if isLocalPlayer(hit) then
			NF.Visible = true
		end
	end)

	casesData.NormShow.TouchEnded:Connect(function(hit)
		if isLocalPlayer(hit) then
			NF.Visible = false
		end
	end)

	-- PREMIUM CASE
	casesData.PremShow.Touched:Connect(function(hit)
		if isLocalPlayer(hit) then
			PF.Visible = true
		end
	end)

	casesData.PremShow.TouchEnded:Connect(function(hit)
		if isLocalPlayer(hit) then
			PF.Visible = false
		end
	end)
end


function BillboardService:Init()
	-- Load Billboards
	local NormalCase, PremiumCase, NormShow, PremShow = GetCases()
	
	HoverCases(NormalCase.Mesh, PremiumCase.Mesh)
	
	local casesData = {
		NormalCase = NormalCase,
		PremiumCase = PremiumCase,
		NormShow = NormShow,
		PremShow = PremShow
	}
	
	-- Load Billboards
	self:SetupBillboards(casesData)
	
end


return BillboardService
