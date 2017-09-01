ENT.Type = "anim"
ENT.PrintName = "Retracting Prop"
ENT.Author = "Atebite"
ENT.Information = "A magical prop that retracts and shit"
ENT.Category = "Combine"

ENT.Editable = true
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.PhysgunDisabled = true
ENT.RenderGroup = RENDERGROUP_BOTH

ENT.Model = "models/props_combine/combine_barricade_med02a.mdl"

ENT.EdgePadding = 7
ENT.MoveDelay = 3
ENT.ActivateDelay = 2

function ENT:UpdateProp(model)
	self:SetModel(model)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_NONE)
	self:DrawShadow(false)
	local phys = self:GetPhysicsObject()
	if phys then
		phys:EnableMotion(false)
		phys:Wake()
	end
	self:SetNotSolid(true)
	--self:SetCollisionGroup(COLLISION_GROUP_WORLD)

	self.dummy:SetModel(model)
	self.dummy:PhysicsInit(SOLID_VPHYSICS)
	local phys = self.dummy:GetPhysicsObject()
	if phys then
		phys:EnableMotion(false)
		phys:Wake()
	end

	local min, max = self.dummy:OBBMins(), self.dummy:OBBMaxs()
	local diff = max - min
	self.w = (diff.y * self.dummy:GetRight()):Length() + 7
	self.h = (diff.x * self.dummy:GetForward()):Length() + 7
	-- z height
	self.zh = diff.z
	-- positive direction downwards
	self.zpos = self.zh

	self.retracted_pos = self:GetPos() - Vector(0, 0, self.zh)

	self.dummy:SetPos(self.retracted_pos)
end

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "Dummy")
	self:NetworkVar("Int", 1, "Mover")
	self:NetworkVar("Bool", 0, "Closed")
end

function ENT:SetState(state)
	if self.active == state then return end

	self.active = state
	self.resting = false
	self.activate_time = CurTime() + self.ActivateDelay
	self.move_time = CurTime() + self.MoveDelay

	if SERVER then
		-- give clients some time to move the cover out of the way
		self.move_time = self.move_time + (self.MoveDelay / 2)
		self:EmitSound("ambient/alarms/klaxon1.wav")
	end
end