AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:SpawnFunction(ply, tr, class)
	if !tr.Hit then return end

	tr = util.QuickTrace(tr.HitPos, Vector(0, 0, 10000))

	if !tr.Hit then return end

	local ent = ents.Create(class)
	ent:SetPos(tr.HitPos)
	ent:SetAngles(Angle(0, ply:EyeAngles().yaw + 180,0))
	ent:SetModel(self.Model)
	ent:Spawn()
	ent:Activate()

	return ent
end