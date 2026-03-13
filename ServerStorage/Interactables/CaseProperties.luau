local CaseProperties = {}

-- 1 = 100%, etc.

local d = require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Directory"))

CaseProperties["Items"] = {
	Death = {
		-- Total: 1.0
		["Minecraft"] = {EmoteID = 116941381075668, Rarity = 0.87, RarityName = "Common", Type = "DeathAnim"},
		["Elevate"]   = {EmoteID = 72613900336729, Rarity = 0.13, RarityName = "Rare",   Type = "DeathAnim"},
	}, 
	Emotes = {
		-- Total: 1.0
		["67"]          = {EmoteID = 79180445676225, Rarity = 0.873, RarityName = "Common",   Type = "Emote"},
		["HaiDi"]       = {EmoteID = 83421797309983, Rarity = 0.09,  RarityName = "Rare",     Type = "Emote"}, -- Now 9% (Very Rare)
		["LowCortisol"] = {EmoteID = 87567280757105, Rarity = 0.037, RarityName = "Mythical", Type = "Emote"}, -- 3.7%
	},
	Count = {
		-- Total: 1.0
		["PinoyCrouch"] = {EmoteID = 108549287750033, Rarity = 0.51, RarityName = "Common", Type = "CountAnim"},
		["Pose3"]       = {EmoteID = 115818106602857, Rarity = 0.38, RarityName = "Common", Type = "CountAnim"},
		["Yay"]         = {EmoteID = 113451589990535, Rarity = 0.11, RarityName = "Rare",   Type = "CountAnim"},
	},
}
-- ["Jojo"] = 103201215781653,  -- Make this premium.

local function generatePrizeList(categoryName, isPremium)
	local list = {}
	local categoryData = CaseProperties["Items"][categoryName]

	if categoryData then
		for itemName, data in pairs(categoryData) do
			local entry = {Name = itemName}
			for key, value in pairs(data) do
				entry[key] = value
			end

			-- BUFF CHANCES FOR PREMIUM
			if isPremium then
				if entry.RarityName == "Mythical" then
					entry.Rarity = entry.Rarity * 3 -- e.g., 2% becomes 6%
				elseif entry.RarityName == "Rare" then
					entry.Rarity = entry.Rarity * 2 -- e.g., 15% becomes 30%
				end
			end

			table.insert(list, entry)
		end
	end
	return list
end
local function getCombinedPrizes(categories)
	local combined = {}
	for _, category in ipairs(categories) do
		local items = generatePrizeList(category)
		for _, item in ipairs(items) do
			table.insert(combined, item)
		end
	end
	return combined
end



-- Regular Odds
CaseProperties["NormalPrizes"] = getCombinedPrizes({"Emotes", "Death", "Count"}, false)

-- Premium Odds (Rare and Mythical are doubled/tripled)
CaseProperties["PremiumPrizes"] = getCombinedPrizes({"Emotes", "Death", "Count"}, true)



CaseProperties["Chances"] = {
	Emotes = 60, -- 40%
	Death = 20,  -- 30%
	Count = 20   -- 30%
}

CaseProperties["CoinPrices"] = {
	NormalCase = 1,
	PremiumCAse = 1299,
}

CaseProperties["RewardCooldown"] = 43200
CaseProperties["ChestReward"] = 50

d.CaseRequest.OnServerInvoke = function(player)
	
	local Normal = {
			CategoryName = "NormalPrizes",
			Items = CaseProperties["NormalPrizes"]
	}
	
	local Premium = {
		CategoryName = "PremiumPrizes",
		Items = CaseProperties["NormalPrizes"]
	}
	
	local finalData = {
		Normal = Normal,
		Premium = Premium
	}
	
	return finalData
end


return CaseProperties
