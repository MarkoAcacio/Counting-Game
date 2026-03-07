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

	
	d.PromptEvent.OnClientEvent:Connect(function()
		d.AvatarService:PromptSetFavorite(72311304436842, 1, true)
		ProductHandler:PromptUserJoinGroup()
		d.PromptEvent:fireServer()
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

function ProductHandler:PromptUserJoinGroup()
	
	d.localPlayer:WaitForChild("PlayerGui")
	if not d.localPlayer.Character then
		d.localPlayer.CharacterAdded:Wait()
	end
	
	task.spawn(function()
		while true do
			
			local status = d.localPlayer:IsInGroupAsync(groupID)
			local groupRank  = d.localPlayer:GetRankInGroupAsync(groupID)

			if status then
				break
			elseif status == false and groupRank == 0 then
				d.GroupService:PromptJoinAsync(groupID)
			else
				warn("Error | PromptUserJoinGroup")
			end

			task.wait(120)
		end
	end)
end


return ProductHandler
