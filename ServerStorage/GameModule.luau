local GameModule = {}

local d = require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Directory"))

-- Services
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Folders
local ClientEvents = ReplicatedStorage:WaitForChild("Events")
local ModulesFolder = ServerStorage:WaitForChild("Modules")
local EventsFolder = ReplicatedStorage:WaitForChild("Events")
local TemplatesFolder = ServerStorage:WaitForChild("Templates")

-- Modules
local PlayerModule = require(d.Modules:WaitForChild("PlayerModule"))

-- Variables & Functions & Eventss
local CountUI = d.Templates:WaitForChild("Count")

local HandleClick
local updateCount


-- Config
local clickWindow = 0.5 -- Time frame where the button opens a state for " players clicking at the same time "
-- clickwindow 0.3 normally
GameModule.numberCount = 0
GameModule.finalStandClicks = {}
GameModule.LastPlayerClicked = nil

--[[

Formula Used : if math.abs(t1 - t2) <= clickWindow then
		ex: t1 : 10, t2 : 10.2, t3 : 10.5

		t1 - t2 = 0.2 <= 0.3 - ELIMINATE
		t1 - t3 = 0.5 <= 0.3 - SURVIVE
]]

---------------------------------------------------------------------------------------------------------------------------------------------

-- BUTTON EVENT PARAMS : player, roundType
-- roundType - 1 = Normal, 2 = Last Stand

function GameModule:HandleCounting()
	
	-- DISCONNECT CONNECTION WHEN ROUND OVER.
	 
	if self.conn then  -- At every new round, if self.conn is not nil, disconnect it.
		print("New Round, Disconnect")
		self.conn:Disconnect()
	end
	
	self.LastPlayerClicked = nil
	 
	self.conn = d.ButtonEvent.OnServerEvent:Connect(function(player, roundType)
		local data = PlayerModule.Players[player]
		if not data or not data.Alive then return end
		
		
		
		self:OnClick(player, data, roundType)
		
	end)
end


-----------------------------------------------------------------------------------------------------------------------

-- Sets TimeClick Data to time of click. 
function GameModule:OnClick(player, data, roundType)
	
	if roundType == 1 then
		data.timeClick = os.clock()
		-- Check which players clicked within this click window
		self:CheckRoundClicks(player, roundType)
	elseif roundType == 2 then
		self:FinalStand(player, roundType)
	end
	
end

function GameModule:CheckRoundClicks(player, roundType)
	local t1 = PlayerModule.Players[player].timeClick
	if not t1 then return end

	local toEliminate = {}
	local ButtonClick= {}
	local latestTime = 0
	local lastPlayer = nil

	-- Find all players that clicked within the window
	for otherPlayer, otherData in pairs(PlayerModule.Players) do
		if otherData.timeClick and otherData.Alive then
			local t2 = otherData.timeClick
			if math.abs(t1 - t2) <= clickWindow then
				table.insert(toEliminate, otherPlayer)
				table.insert(ButtonClick, otherPlayer)
				
				if t2 > latestTime then
					latestTime = t2
					self.LastPlayerClicked = otherPlayer
				end
			end
		end
	end

	self:HandleLastPlayer()

	-- Eliminate players if needed
	self:eliminatePlayers(toEliminate)

	if #toEliminate == 1 then
		self:updateCount(ButtonClick, player, roundType)
	else
		for _, player in ipairs(toEliminate) do
			self:SetCountingUI(player, "dec")
		end
	end

	-- Update numberCount **once per player per click window**
	print("Number Count:", self.numberCount)  -- Pass This To a UI Next Time
end


function GameModule:HandleLastPlayer()
	local activePlayers = 0
	local clickedPlayers = 0
	local AlivePlayers = PlayerModule:GetAlivePlayers()


	for player, data in pairs(PlayerModule.Players) do
		if data.Alive and data.isPlaying then
			activePlayers += 1
			if data.timeClick then
				clickedPlayers += 1
			end
		end
	end

	if #AlivePlayers == 1  then  -- If he's the only one standing.
		for player, data in pairs(PlayerModule.Players) do
			if self.LastPlayerClicked == player then
				data.Counted = true
				data.Alive = true
				local highlight = Instance.new("Highlight")
				highlight.FillColor = Color3.fromRGB(255, 213, 44)
				highlight.FillTransparency = 0.7
				highlight.Parent = player.Character
			end
		end
	
	else
		if activePlayers > 0 and (clickedPlayers == activePlayers) then -- Check if all players have clicked.
			for player, data in pairs(PlayerModule.Players) do
				if self.LastPlayerClicked == player then
					data.Counted = true
					data.Alive = false
					local highlight = Instance.new("Highlight")
					highlight.FillColor = Color3.fromRGB(255, 0, 0)
					highlight.FillTransparency = 0.7
					highlight.Parent = player.Character

					PlayerModule:EliminatePlayers() 
				end
			end
		end
	end
end


-------------------------------------------------- FINAL STAND --------------------------------------------------------



function GameModule:FinalStand(player, roundType)
	GameModule:updateCount(nil, player, roundType)	
end



-----------------------------------------------------------------------------------------------------------------------

-- If Players doesn't click, eliminate them
-- MODIFY THIS IF YOU WANT PLAYERS TO SEE THE ELIMINATED PLAYERS DIE
function GameModule:CheckClicks()  -- HANDLER AFTER ROUND CHECKINGS!
	print("Checking Clicks")
	
	print(self.LastPlayerClicked)
	
	for playerObj, player in pairs(PlayerModule.Players) do
		
		if player.Alive and not player.Counted and player.isPlaying then
			print("PLAYER NO CLICK")
			player.Alive = false
			player.Counted = true     --------------- !!!!!!!!!!!!!!!!
			PlayerModule:EliminatePlayers()  
		end
		
		if not player.Alive and player.Counted and player.isPlaying then  -- Kill Active players, but dont kill players already eliminated
			player.Alive = false
		-- Dont set is playing to false, it's already handled in player system
		
			PlayerModule:EliminatePlayers()
		end
		self:DeleteCountUI()
	end
end

function GameModule:eliminatePlayers(toEliminate)
	if #toEliminate > 1 then
		for _, p in ipairs(toEliminate) do
			local data = PlayerModule.Players[p]
			local char = p.Character
			if data.Alive and data.isPlaying then
				data.Alive = false
				data.Counted = true
				
				local highlight = Instance.new("Highlight")
				highlight.FillColor = Color3.fromRGB(255, 0, 0)
				highlight.FillTransparency = 0.7
				highlight.Parent = char
				
				
				PlayerModule:EliminatePlayers()  
				print("Eliminating Player:", p)
			end
		end
	else
	end
end

function GameModule:updateCount(ButtonClick, player: Player, roundType : number)
	
	if roundType == 1 and ButtonClick then  -- NORMAL ROUND

		for _, p in ipairs(ButtonClick) do
			local data = PlayerModule.Players[p]
			if not data.Counted then
				self.numberCount += 1
				self:SetCountingUI(p, "inc", roundType)
				data.Counted = true
			end
		end
	
	elseif roundType == 2 and ButtonClick == nil then -- FINAL STAND
		if not self.finalStandClicks[player] then
			self.finalStandClicks[player] = {
				count = 0
			}
		end
		
		self.finalStandClicks[player].count += 1
		self:SetCountingUI(player, "inc", roundType)
	end
	
end

---------------------------------------------------------------------------------------------------------------------------------------------

function GameModule:SetCountingUI(player:Player, action : string , roundType : number)

	local char = player.Character
	if not char then return end 

	local head = char:FindFirstChild("Head")
	if not head then return end

	local countUI = head:FindFirstChild("Count")
	local countText = countUI and countUI:FindFirstChild("CountText")


	------------------ IF EXIST, JUST UPDATE --------------------------

	if countText then
		if action == "inc" then
			if roundType == 1 then -- NORMAL ROUND
				countText.Text = self.numberCount
				
			elseif roundType == 2 then -- LAST STAND
				countText.Text = tostring(self.finalStandClicks[player].count)
			end
		elseif action == "dec" then
			countText.Text = self.numberCount
			countText.TextColor3 = Color3.fromRGB(255, 0, 0) -- Red
	
		end
		return
	end	

	--------------------------------------------------------------------

	local clonedCountingUI = CountUI:Clone()
	clonedCountingUI.Parent = head
	clonedCountingUI.Enabled = true

	countText = clonedCountingUI:FindFirstChild("CountText")
	if not countText then return end

	if action == "inc" then
		if roundType == 1 then -- NORMAL ROUND
			countText.Text = self.numberCount
			
			local highlight = Instance.new("Highlight")
			highlight.FillColor = Color3.fromRGB(126, 255, 126)
			highlight.FillTransparency = 0.7
			highlight.Parent = char
		elseif roundType == 2 then -- LAST STAND
			countText.Text = tostring(self.finalStandClicks[player].count)
		end

	elseif action == "dec" then
		countText.Text = self.numberCount
		countText.TextColor3 = Color3.fromRGB(255, 0, 0) -- Red
	else
		warn("Invalid Action | 178 SetCountingUi")
	end

end


function GameModule:DeleteCountUI()
	for player, char in pairs(PlayerModule.Characters) do
		if char and char.Parent then
			
			local head = char:FindFirstChild("Head")
			local highlight = char:FindFirstChild("Highlight")
			if highlight then highlight:Destroy() end
			
			if head and head:FindFirstChild("Count") then
				local countUI = head:FindFirstChild("Count")
				countUI:Destroy()
			end
		end
	end
end

function GameModule:ResetRound()
	print("Resetting Round")
	
	self.numberCount = 0
	self.EliminatedPlayers = {}
	self.finalStandClicks = {}
	GameModule:DeleteCountUI()
	
	task.wait(0.5)
	PlayerModule:RagdollAction("delete")
	
	for player, data in pairs(PlayerModule.Players) do 
		data.timeClick = nil
		data.Counted = false
	end
end

function GameModule:ResetGame()
	print("Resetting Game")
	
	task.wait(0.4)
	
	self.numberCount = 0
	self.EliminatedPlayers = {}
	GameModule:DeleteCountUI()
	self.finalStandClicks = {}
	
	task.wait(0.5)
	
	PlayerModule:RagdollAction("delete")
	for player, data in pairs(PlayerModule.Players) do 
		data.timeClick = nil
		data.Alive = true
		data.isPlaying = true
		data.Counted = false
	end
end

---------------------------------------------------------------------------------------------------------------------------------------------

return GameModule
