local ProductHandler = {}

local d = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Directory"))

-- Configs
local groupID = 228201671
ProductHandler["ProductID"] = {
	NormalCase = 3527680986,
	PremiumCase = 3529888644,
	SkipChestTimer = 3529893514
}


--------------------------------------------------------------------------------

function ProductHandler:Init()
	
	-- ACTIONS LIST : NoMoneyNormal, NoMoneyPremium, SkipChestTimer

	
	d.PromptEvent.OnClientEvent:Connect(function(--[[fav : boolean]])
		
	--	if fav then
			--d.AvatarService:PromptSetFavorite(72311304436842, 1, true)
			ProductHandler:PromptUserJoinGroup()
			d.PromptEvent:fireServer()
		--else
			--ProductHandler:PromptUserJoinGroup()
		--end
	end)
	
	d.ProductEvent.OnClientEvent:Connect(function(type_, action : string)
		if type_ == "case" then
			ProductHandler:HandleCases(action)
		end
		
	end)
	
end

--------------------------------------------------------------------------------

function ProductHandler:HandleCases(action : string)
	
	if action == "NoMoneyNormal" then
		d.MarketPlaceService:PromptProductPurchase(d.localPlayer, self["ProductID"].NormalCase)
		-- SEND EVENT IF BUY SUCCESS
	elseif action == "NoMoneyPremium" then
		d.MarketPlaceService:PromptProductPurchase(d.localPlayer, self["ProductID"].PremiumCase)
		-- SEND EVENT IF BUY SUCCESS
	elseif action == "SkipChestTimer" then
		d.MarketPlaceService:PromptProductPurchase(d.localPlayer, self["ProductID"].SkipChestTimer)
		-- SEND EVENT IF BUY SUCCESS
	else
		warn("INVALID ACTION | @HandleCases, ProductHandler.Module")
	end
	
	
end

--------------------------------------------------------------------------------

-- Add this at the top of ProductHandler
local isPromptActive = false
local lastPromptTime = 0
local PROMPT_COOLDOWN = 10 -- 10 seconds between prompts

--------------------------------------------------------------------------------
function ProductHandler:PromptUserJoinGroup()
	d.localPlayer:WaitForChild("PlayerGui")
	if not d.localPlayer.Character then
		d.localPlayer.CharacterAdded:Wait()
	end

	task.spawn(function()
		-- Debounce check
		local now = tick()
		if isPromptActive or (now - lastPromptTime) < PROMPT_COOLDOWN then
			warn("Group prompt on cooldown or already active")
			return
		end

		-- Check if already in group
		local status = d.localPlayer:IsInGroupAsync(groupID)
		if status then
			return
		end

		isPromptActive = true
		lastPromptTime = now

		local success, err = pcall(function()
			d.GroupService:PromptJoinAsync(groupID)
		end)

		if not success then
			warn("Failed to show group prompt:", err)
		end

		task.wait(2) -- Wait for prompt to fully close
		isPromptActive = false
	end)
end

return ProductHandler
