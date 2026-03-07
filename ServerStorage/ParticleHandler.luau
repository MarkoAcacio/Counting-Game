local ParticleHandler = {}

local AvailableParticles = {}
local d = require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Directory"))

-----------------------------------------------------------------


local function ParentParticle(c : Model?, ParticleName : string?)
	local ParticleFolder = d.Templates:WaitForChild("Particles")
	
	local att = ParticleFolder:FindFirstChild(ParticleName):Clone()
	local particle = att.effect
	att.Parent = c:FindFirstChild("HumanoidRootPart")
	particle.Enabled = false
end

local function RemoveParticle(c : Model?, ParticleName : string?)
	if c:FindFirstChild("HumanoidRootPart"):FindFirstChild(ParticleName) then
		c:FindFirstChild("HumanoidRootPart"):FindFirstChild(ParticleName):Destroy()
	end
end

local function isExist(c : Model?, ParticleName : string?)
	if c:FindFirstChild("HumanoidRootPart"):FindFirstChild(ParticleName) then
		return true
	else
		return false
	end
end

-----------------------------------------------------------------

function ParticleHandler:Show(c : Model?, ParticleName : string?)
	if isExist(c, ParticleName) then
		local p = c:FindFirstChild("HumanoidRootPart"):FindFirstChild(ParticleName).effect
		p.Enabled = true
		p:Emit(1)
	end
end

function ParticleHandler:ChangeParticle()
	
end

function ParticleHandler:InitParticle(char, particle)
	RemoveParticle(char, particle)  -- Check if particle is present first, if yes, remove.
	ParentParticle(char, particle) -- Re-Parent particle
end

-----------------------------------------------------------------


return ParticleHandler
