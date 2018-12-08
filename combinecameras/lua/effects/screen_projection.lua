function EFFECT:Init(data)
	self.origin = data:GetOrigin()
	self.parent = data:GetEntity()

	self.parent.emitter = ParticleEmitter(self.origin, true)

	self.next_fire = 0
end

function EFFECT:Think()
	local CT = CurTime()

	if not IsValid(self.parent) then
		return false
	end

	if not IsValid(self.parent.emitter) then
		return false
	end

	if not self.parent.cameras then
		return false
	end

	if #self.parent.cameras == 0 then
		return false
	end

	if CT >= self.next_fire then
		self.next_fire = CT + 0.005

		local emitter = self.parent.emitter
		local pos = self.parent:GetPos() + self.parent:GetUp() * 45 + self.parent:GetRight() * 1.5 - self.parent:GetForward() * 16
		emitter:SetPos(pos)

		local ang = self.parent:GetAngles()

		local particle = emitter:Add("effects/splashwake3", pos)

		particle:SetVelocity(self.parent:GetUp():GetNormalized() * 80)
		particle:SetAngles(ang)

		particle:SetLifeTime(0)
		particle:SetDieTime(0.1)

		particle:SetStartSize(0)
		particle:SetEndSize(10)

		particle:SetRoll(0)
		particle:SetRollDelta(0)

		particle:SetStartAlpha(255)
		particle:SetEndAlpha(0)
		particle:SetColor(92, 195, 255)

		particle:SetCollide(false)
	end

	return true
end

function EFFECT:Render()

end
