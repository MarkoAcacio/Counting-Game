local Ragdoll = {}


------------------------------------------------------------------------------------------------------------------------

-- RAGDOLL will only play if it's first set to false. 

function Ragdoll:SetupRagdoll(Player : Player, Character, Humanoid:Humanoid, creationTracker)

	if Character ~= nil then
		self:ConvertJoints(Player, Character, Humanoid)
		Character:SetAttribute("Ragdolled", true)

		if Character:GetAttribute("canClone") == true then
			task.wait(2)

			-- CHECK: If cleanup happened during the wait, abort
			if creationTracker and creationTracker[Player] == false then
				print("Ragdoll clone cancelled for", Player.Name)
				return
			end

			-- Also verify character still exists and hasn't been replaced
			if not Character.Parent or Player.Character ~= Character then
				print("Character no longer valid, aborting ragdoll clone")
				return
			end

			Character.Archivable = true
			local ClonedCharacter = Character:Clone()
			local clonedHumanoid = ClonedCharacter:FindFirstChildOfClass("Humanoid")

			-- Tag the clone with owner info for easier cleanup
			ClonedCharacter:SetAttribute("OwnerUserId", Player.UserId)
			ClonedCharacter.Name = Player.Name .. "_Ragdoll"

			ClonedCharacter.Parent = workspace.Ragdolls
			ClonedCharacter.HumanoidRootPart.Anchored = true
			clonedHumanoid.Health = 0
			clonedHumanoid.MaxHealth = 0
			clonedHumanoid:ChangeState(Enum.HumanoidStateType.Dead)
			Character.Archivable = false

			-- Mark creation as complete
			if creationTracker then
				creationTracker[Player] = false
			end
		end
	end
end

------------------------------------------------------------------------------------------------------------------------
function Ragdoll:ConvertJoints(Player,Character, humanoid : Humanoid)
	local motors = {}

	if Character:GetAttribute("Ragdolled") == false then
		for _, descendant in pairs(Character:GetDescendants()) do
			if descendant:IsA("Motor6D") then
				table.insert(motors, descendant)
			end
		end

		for _, joint in pairs(motors) do
			local part0 = joint.Part0
			local part1 = joint.Part1
			if part0 and part1 then
				local att0 = Instance.new("Attachment")
				local att1 = Instance.new("Attachment")
				att0.CFrame = joint.C0
				att1.CFrame = joint.C1
				att0.Name = joint.Name .. "_Att0"
				att1.Name = joint.Name .. "_Att1"
				att0.Parent = part0
				att1.Parent = part1
				
				local socket = Instance.new("BallSocketConstraint")
				socket.Name = joint.Name .. "_Socket"
				socket.Attachment0 = att0
				socket.Attachment1 = att1
				socket.LimitsEnabled = true
				socket.TwistLimitsEnabled = true
				socket.UpperAngle = 45
				socket.Parent = part0
				joint:Destroy()
			end
		end
		
		if Player then
			for _, part in pairs(Character:GetDescendants()) do
				if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
					part:SetNetworkOwner(Player)
				end
			end
		end
		
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)

		task.defer(function()
			for _, part in pairs(Character:GetDescendants()) do
				if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
					local rootPart = Character:FindFirstChild("HumanoidRootPart") or Character:FindFirstChild("Torso") or Character:FindFirstChild("UpperTorso")
					if rootPart and rootPart ~= part then
						local noCollision = Instance.new("NoCollisionConstraint")
						noCollision.Part0 = rootPart
						noCollision.Part1 = part
						noCollision.Parent = part
					end
				end
			end
		end)
	end
end


------------------------------------------------------------------------------------------------------------------------

return Ragdoll