AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Use(ply)
	local pos = self:GetPos() + self:GetUp() * 47.9 + self:GetRight() * 9.77 - self:GetForward() * 2.25
	local ang = self:GetAngles()
	ang:RotateAroundAxis(self:GetUp(), 90)
	ang:RotateAroundAxis(self:GetRight(), -42)

	self.panel_scale = 0.09

	local cx, cy = GetCursorPos(pos, ang:Up(), ang, ply)
	local mul = 1 / self.panel_scale
	cx, cy = math.Clamp(cx * mul, 0, 172), math.Clamp(cy * mul, 0, 85)

	self:UseFunc(self, cx, cy)
end