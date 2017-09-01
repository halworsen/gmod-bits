AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

local alarm = "ambient/alarms/combine_bank_alarm_loop4.wav"
local lift = "retractbarrier/lift.wav"

function ENT:Initialize()
	self:DrawShadow(false)
	--self:SetNotSolid(true)
	self:SetCollisionGroup(COLLISION_GROUP_WORLD)
	local name = "retractprop_"..self:EntIndex()
	self:SetName(name)

	self:SetNotSolid(true)

	self.active = false
	self.activate_time = 0
	self.move_time = 0
	self.moving = false
	self.resting = true
	self.move_speed = 10

	self:SetClosed(true)

	self.dummy = ents.Create("prop_physics")
	self.dummy:SetModel(self.Model)
	self.dummy:Spawn()
	self.dummy.PhysgunDisabled = true

	self.dummy:PhysicsInit(SOLID_VPHYSICS)
	local phys = self.dummy:GetPhysicsObject()
	if phys then
		phys:EnableMotion(false)
		phys:Wake()
	end

	self:SetDummy(self.dummy:EntIndex())

	local min, max = self.dummy:OBBMins(), self.dummy:OBBMaxs()
	local diff = max - min
	-- +7 for some leeway
	self.w = (diff.y * self.dummy:GetRight()):Length() + self.EdgePadding
	self.h = (diff.x * self.dummy:GetForward()):Length() + self.EdgePadding
	-- z height
	self.zh = diff.z

	self.retracted_pos = self:GetPos() - self:GetUp() * self.zh

	self.mover = ents.Create("func_movelinear")
	self.mover:SetPos(self.retracted_pos)
	self.mover:SetAngles(self:GetAngles())
	self.mover:SetModel(self.Model)
	self.mover:Spawn()
	self.mover.PhysgunDisabled = true

	self.mover:SetNoDraw(true)
	self.mover:SetMoveType(MOVETYPE_PUSH)

	self.mover:SetSaveValue("m_vecPosition1", tostring(self.retracted_pos))
	self.mover:SetSaveValue("m_vecPosition2", tostring(self:GetPos()))
	self.mover:SetKeyValue("OnFullyOpen", name..",FinishMove")
	self.mover:SetKeyValue("OnFullyClosed", name..",FinishMove")

	self:SetMover(self.mover:EntIndex())
	self:SetSpeed(self.move_speed)

	-- mutual destruction
	self:DeleteOnRemove(self.dummy)
	self:DeleteOnRemove(self.mover)
	self.dummy:DeleteOnRemove(self)
	self.mover:DeleteOnRemove(self)

	self.dummy:SetPos(self.retracted_pos)
	self.dummy:SetAngles(self:GetAngles())
	self.dummy:SetParent(self.mover)
end

function ENT:SpawnFunction(ply, tr, class)
	if !tr.Hit then return end

	local ent = ents.Create(class)
	ent:SetModel(self.Model)
	ent:SetPos(tr.HitPos + Vector(0, 0, 100))
	ent:DropToFloor()
	local ang = Angle(0, ply:EyeAngles().yaw + 180,0):SnapTo("yaw", 90)
	ent:SetAngles(ang)
	ent:Spawn()
	ent:Activate()

	return ent
end

function ENT:OnRemove()
	if self.alarm then
		self.alarm:Stop()
	end

	if self.move then
		self.move:Stop()
	end
end

function ENT:AcceptInput(name)
	if name == "FinishMove" then
		self.resting = true
		self.moving = false

		self.alarm:FadeOut(0.3)
		self.move:FadeOut(0.3)

		self:SetClosed(not self.active)
	end
end

function ENT:PlaySounds()
	self.alarm = self.alarm or CreateSound(self, alarm)
	self.alarm:Play()
	self.move = self.move or CreateSound(self, lift)
	self.move:Play()
end

function ENT:SetSpeed(speed)
	self.move_speed = speed
	self.mover:Fire("SetSpeed", tostring(speed))
end

function ENT:Think()
	if not IsValid(self.dummy) then
		return
	end

	if self.move_time == 0 then
		return
	end

	if self.activate_time == 0 then
		return
	end

	if self.resting then
		return
	end

	if self.active and CurTime() >= self.move_time then
		if not self.alarm or not self.move or not self.alarm:IsPlaying() or not self.move:IsPlaying() then
			self:PlaySounds()
		end

		self.mover:Fire("Open")
	elseif not self.active and CurTime() >= self.activate_time then
		if not self.alarm or not self.move or not self.alarm:IsPlaying() or not self.move:IsPlaying() then
			self:PlaySounds()
		end

		self.mover:Fire("Close")
	end
end