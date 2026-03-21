local CaseProperties = {}
-- 1 = 100%, etc.
local d = require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Directory"))
CaseProperties["Items"] = {
	Death = {
		-- Total: 1.0
		["Minecraft"] = {EmoteID = 116941381075668, Rarity = 0.67, RarityName = "Common", Type = "DeathAnim"},
		["Elevate"]   = {EmoteID = 72613900336729, Rarity = 0.3, RarityName = "Rare",   Type = "DeathAnim"},
	}, 
	Emotes = {
		-- Total: 1.0
		["67"]          = {EmoteID = 79180445676225, Rarity = 0.673, RarityName = "Common",   Type = "Emote"},
		["HaiDi"]       = {EmoteID = 83421797309983, Rarity = 0.25,  RarityName = "Rare",     Type = "Emote"}, -- Now 9% (Very Rare)
		["LowCortisol"] = {EmoteID = 87567280757105, Rarity = 0.09, RarityName = "Mythical", Type = "Emote"}, -- 3.7%
	},
	Count = {
		-- Total: 1.0
		["PinoyCrouch"] = {EmoteID = 108549287750033, Rarity = 0.81, RarityName = "Common", Type = "CountAnim"},
		["Pose3"]       = {EmoteID = 115818106602857, Rarity = 0.45, RarityName = "Common", Type = "CountAnim"},
		["Yay"]         = {EmoteID = 113451589990535, Rarity = 0.4, RarityName = "Rare",   Type = "CountAnim"},
	},
}
-- ["Jojo"] = 103201215781653,  -- Make this premium.

local function generatePrizeList(categoryName, isPremium)
	local list = {}
	local categoryData = CaseProperties["Items"][categoryName]
	if categoryData then
		for itemName, data in pairs(categoryData) do
			-- NEW: Filter out specific items for Premium
			if isPremium and (itemName == "67" or itemName == "Minecraft" or itemName == "Pose3") then
				continue -- Skip this item entirely
			end
			local entry = {Name = itemName}
			for key, value in pairs(data) do
				entry[key] = value
			end
			-- BUFF CHANCES FOR PREMIUM
			if isPremium then
				if entry.RarityName == "Mythical" then
					entry.Rarity = entry.Rarity * 5 
				elseif entry.RarityName == "Rare" then
					entry.Rarity = entry.Rarity * 3 
				elseif entry.RarityName == "Common" then
					entry.Rarity = entry.Rarity * 2 
				end
			end
			table.insert(list, entry)
		end
	end
	return list
end

local function normalizeProbabilities(prizeList)
	-- Calculate total probability
	local total = 0
	for _, item in ipairs(prizeList) do
		total = total + item.Rarity
	end
	
	-- Normalize so total equals 1.0 (100%)
	if total > 0 then
		for _, item in ipairs(prizeList) do
			item.Rarity = item.Rarity / total
		end
	end
	
	return prizeList
end

local function getCombinedPrizes(categories, isPremium)
	local combined = {}
	for _, category in ipairs(categories) do
		local items = generatePrizeList(category, isPremium)
		for _, item in ipairs(items) do
			table.insert(combined, item)
		end
	end
	
	-- Normalize the combined list to sum to 1.0 (100%)
	return normalizeProbabilities(combined)
end

-- Regular Odds (normalized to 100%)
CaseProperties["NormalPrizes"] = getCombinedPrizes({"Emotes", "Death", "Count"}, false)
-- Premium Odds (Rare and Mythical are buffed, then normalized to 100%)
CaseProperties["PremiumPrizes"] = getCombinedPrizes({"Emotes", "Death", "Count"}, true)

CaseProperties["Chances"] = {
	Emotes = 60, -- 40%
	Death = 20,  -- 30%
	Count = 20   -- 30%
}

CaseProperties["CoinPrices"] = {
	NormalCase = 500,
}

CaseProperties["RewardCooldown"] = 43200
CaseProperties["ChestReward"] = 100

d.CaseRequest.OnServerInvoke = function(player)
	local Normal = {
		CategoryName = "NormalPrizes",
		Items = CaseProperties["NormalPrizes"]
	}
	local Premium = {
		CategoryName = "PremiumPrizes",
		Items = CaseProperties["PremiumPrizes"]
	}
	local finalData = {
		Normal = Normal,
		Premium = Premium
	}
	return finalData
end

return CaseProperties