-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Packages
local Packages = ReplicatedStorage.Packages
local BridgeNet2 = require(Packages.BridgeNet2)


local GameManager = {
	RejoinAFKEvent = BridgeNet2.ReferenceBridge("RejoinAFK"),
}

local serverTypes = {
	Public = 1,
	Reserved = 2,
	VIP = 3,
}

local function getServerType()
	if game.PrivateServerId ~= "" then
		if game.PrivateServerOwnerId ~= 0 then
			return serverTypes.VIP
		else
			return serverTypes.Reserved
		end
	else
		return serverTypes.Public
	end
end

local function shouldReserveServer()
	return (getServerType() == serverTypes.Public and #Players:GetPlayers() <= 1) and true or false
end

--
function GameManager:RejoinAFK(player: Player, isAFK: boolean)
	local newTeleportDetails = {}
	local serverType = getServerType()
	local isReserved = shouldReserveServer()
	local character = player.Character
	local humanoidRootPart: Part = character and character:FindFirstChild("HumanoidRootPart")
	local teleportOptions = Instance.new("TeleportOptions")
	teleportOptions.ShouldReserveServer = isReserved

	--newTeleportDetails.isInChair = isAFK
	newTeleportDetails["reserved"] = isReserved

	teleportOptions:SetTeleportData(newTeleportDetails)

	if not RunService:IsStudio() then
		if getServerType() ~= serverTypes.VIP then
			--warn "is normal"
			player:SetAttribute("teleporting", true)
			TeleportService:TeleportAsync(game.PlaceId, { player }, teleportOptions)
		--[[ else
			warn "is VIP"
			local code = TeleportService:ReserveServer(game.PlaceId)
			TeleportService:TeleportToPrivateServer(game.PlaceId, code, {player})
			player:SetAttribute("teleporting", true)
			TeleportService:TeleportAsync(game.PlaceId, {player}, teleportOptions)
			TeleportService:TeleportToPrivateServer(game.PlaceId, TeleportService:ReserveServer(game.PlaceId), {player})
			TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player) ]]
		end
	end
	
	if RunService:IsStudio() then
		warn "is studio cant teleport"
	else
		TeleportService:TeleportAsync(game.PlaceId, { player }, teleportOptions)
	end

end

--
function GameManager:OnInit()
	self.RejoinAFKEvent:Connect(function(player: Player, isAFK)
		self:RejoinAFK(player, isAFK)
	end)

end

return GameManager
