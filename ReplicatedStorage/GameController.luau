-- Services
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

-- Packages
local Packages = ReplicatedStorage.Packages
local BridgeNet2 = require(Packages.BridgeNet2)

-- Assets
local LocalPlayer = Players.LocalPlayer

-- CONSTANTS
local AFK_THRESHOLD = RunService:IsStudio() and 15555 or 17.5 * 60  --game.PlaceId == 106049047545461 and 15555 or 18 * 60

--
local GameController = {
	RejoinAFKEvent = BridgeNet2.ReferenceBridge("RejoinAFK"),
}

function GameController:_setupAFKListener()
	--
	local lastInput = os.time()
	UserInputService.InputBegan:Connect(function()
		lastInput = os.time()
	end)

	--
	task.spawn(function()
		while true do
			task.wait(1)
			if os.time() - lastInput > AFK_THRESHOLD then
				self.RejoinAFKEvent:Fire(Players.LocalPlayer:GetAttribute("AFK"))
				break
			end
		end
	end)

--[[ 	local tpData = TeleportService:GetLocalPlayerTeleportData()
	local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	local wasAFK = (tpData and tpData.isInChair)

	if tpData and wasAFK then
		AFKChairController:StartAFK()
	end ]]
end

function GameController:OnInit()
	self:_setupAFKListener()
end

return GameController
