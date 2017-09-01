include("shared.lua")

local shaft_wall = CreateMaterial("BarrierWall16", "VertexLitGeneric", {
	["$basetexture"] = "metal/citadel_metalwall072a",
	["$surfaceprop"] = "metal",
	["$envmap"] = "env_cubemap",
	["$envmaptint"] = "[.05 .05 .05]"
})
local shaft_base = CreateMaterial("BarrierBase16", "VertexLitGeneric", {
	["$basetexture"] = "metal/citadel_metalwall077a",
	["$surfaceprop"] = "metal",
	["$envmap"] = "env_cubemap",
	["$envmaptint"] = "[.05 .05 .05]"
})
local hatch_mat = CreateMaterial("BarrierHatch16", "VertexLitGeneric", {
	["$basetexture"] = "metal/metalcombine002",
	["$surfaceprop"] = "metal",
	["$envmap"] = "env_cubemap",
	["$envmaptint"] = "[.05 .05 .05]"
})

function ENT:Initialize()
	self:SetModel(self.Model)
	self:SetCollisionGroup(COLLISION_GROUP_WORLD)
	self:SetNotSolid(true)

	self.active = false
	self.activate_time = 0

	self.camouflage = false
	self.next_mat_grab = 0

	self.light_color = render.GetLightColor(self:GetPos())

	self.cutout_h = 0
	self.draw_scale = 0.1
	-- width of the hazard stripes around the barrier
	self.padding_width = 2

	self.dummy = Entity(self:GetDummy())
	self.mover = Entity(self:GetMover())

	self.min = self.dummy:OBBMins()
	self.max = self.dummy:OBBMaxs()
	local diff = self.max - self.min
	self.w = (diff.y * self.dummy:GetRight()):Length() + self.EdgePadding
	self.h = (diff.x * self.dummy:GetForward()):Length() + self.EdgePadding
	-- z height
	self.h_over_ground = (self:GetPos() - self:LocalToWorld(self.min)).z
	self.zh = diff.z

	self.mat_id = self:EntIndex()..CurTime()
	self.stripes = CreateMaterial("hazstripes"..self.mat_id, "VertexLitGeneric", {
		["$basetexture"] = "halflife/stripes2",
		["$basetexturetransform"] = "center .5 .5 scale "..self.w.." "..self.h.." rotate 0 translate 0 0"
	})
end

function ENT:Think()
	if not IsValid(self.dummy) then
		return
	end

	if CurTime() >= self.next_mat_grab then
		self.next_mat_grab = CurTime() + 5
		self:GrabWorldMat()
	end

	local zpos = (self.mover:GetPos() - Vector(0, 0, self.min / 2)).z

	-- dont let the server overwrite this
	self.dummy:SetNoDraw(true)

	local goal = 0
	local h = self.h * (1/self.draw_scale)
	if self.active and CurTime() >= self.activate_time then
		goal = h
	end

	local speed = self:GetClosed() and ((h / self.MoveDelay) * FrameTime()) or 0
	self.cutout_h = math.Approach(self.cutout_h, (goal or 0), speed)
end

function ENT:Draw()
	if self.grabbing_mat then return end

	local dpos = self.dummy:GetPos()
	local mpos = self.mover:GetPos()
	--render.DrawLine(dpos, dpos + self.dummy:GetUp() * 100, Color(255, 0, 0), true)
	--render.DrawLine(mpos, mpos + self.mover:GetUp() * 100, Color(0, 255, 0), false)

	render.ClearStencil()
	render.SetStencilEnable(true)
	-- lighting fix
	render.SuppressEngineLighting(true)
	render.ResetModelLighting(self.light_color.x, self.light_color.y, self.light_color.z)
	

	render.SetStencilWriteMask(255)
	render.SetStencilTestMask(255)

	-- create an outline of hazard stripes
	render.SetStencilReferenceValue(1)
	render.SetStencilCompareFunction(STENCIL_ALWAYS)
	render.SetStencilPassOperation(STENCIL_REPLACE)

	local pos = self:GetPos() - Vector(0, 0, self.h_over_ground)
	pos = pos + (self:GetRight() * self.w / 2)
	pos = pos - (self:GetForward() * self.h / 2)

	local ang = self:GetAngles()
	ang:RotateAroundAxis(self:GetUp(), 90)

	cam.Start3D2D(pos, ang, self.draw_scale)
		local mul = 1/self.draw_scale
		local pad = self.padding_width * mul
		local total_pad = pad * 2
		local w, h = self.w * mul, self.h * mul

		surface.SetDrawColor(0, 0, 0, 1)
		surface.DrawRect(0, 0, w, h)

		render.SetStencilCompareFunction(STENCIL_NOTEQUAL)
		
		surface.SetDrawColor(255, 255, 255)
		surface.SetMaterial(self.stripes)
		surface.DrawTexturedRect(-pad, -pad, w + total_pad, h + total_pad)
		
		-- setup the interior cutout
		render.SetStencilReferenceValue(2)
		render.SetStencilCompareFunction(STENCIL_ALWAYS)
		
		surface.SetDrawColor(0, 0, 0, 255)
		surface.DrawRect(0, 0, w, h)
	cam.End3D2D()

	if not IsValid(self.dummy) then
		render.SetStencilEnable(false)

		return
	end

	render.SetStencilCompareFunction(STENCIL_NOTEQUAL)

	-- draw the barricade outside the cutout
	self.dummy:DrawModel()

	-- now draw the barricade inside the cutout (along with shaft walls)
	render.SetStencilCompareFunction(STENCIL_EQUAL)
	render.ClearBuffersObeyStencil(0, 0, 0, 255, true)

	render.SetMaterial(self.camouflage and self.grabbed_mat_up or hatch_mat)
	local offset = self.cutout_h * self.draw_scale / 1.99 -- 1.99 prevents ugly clipping with the shaft walls
	render.DrawBox(pos, self:GetAngles(), Vector(-offset, 0, -2), Vector((self.h / 2) - offset, self.w, 0.1), Color(255, 255, 255), true)
	render.SetMaterial(self.camouflage and self.grabbed_mat_down or hatch_mat)
	render.DrawBox(pos, self:GetAngles(), Vector((self.h / 2) + offset, 0, -2), Vector(self.h + offset, self.w, 0.1), Color(255, 255, 255), true)

	self.dummy:DrawModel()

	render.SetMaterial(shaft_wall)
	render.DrawBox(pos, self:GetAngles(), Vector(self.h, self.w, 0), Vector(0, 0, -self.zh - 1, Color(255, 255, 255), true))

	local base_pos = self.mover:GetPos()
	local zpos = (self.mover:GetPos() - self.mover:LocalToWorld(self.min)).z
	base_pos = base_pos + (self:GetRight() * self.w / 2)
	base_pos = base_pos - (self:GetForward() * self.h / 2)
	base_pos = base_pos - Vector(0, 0, zpos)
	cam.Start3D2D(base_pos, ang, self.draw_scale)
		surface.SetDrawColor(255, 255, 255)
		surface.SetMaterial(shaft_base)
		surface.DrawTexturedRect(0, 0, w, h)
	cam.End3D2D()

	render.SuppressEngineLighting(false)
	render.SetStencilEnable(false)
end

function ENT:GrabWorldMat()
	local mul = (1/self.draw_scale)

	self.mat_grabber_up = GetRenderTarget("WMatGrabberUp"..self.mat_id, self.w * mul, self.h * mul / 2, true)
	self.mat_grabber_down = GetRenderTarget("WMatGrabberDown"..self.mat_id, self.w * mul, self.h * mul / 2, true)
	self.grabbed_mat_up = CreateMaterial("WMatGrabUp"..self.mat_id, "UnlitGeneric", {["$basetexture"] = "WMatGrabberUp"..self.mat_id})
	self.grabbed_mat_down = CreateMaterial("WMatGrabDown"..self.mat_id, "UnlitGeneric", {["$basetexture"] = "WMatGrabberDown"..self.mat_id})

	local pos = self:GetPos()
	local ang = self:GetAngles()
	ang:RotateAroundAxis(self:GetUp(), 180)
	ang:RotateAroundAxis(self:GetRight(), 90)

	render.PushRenderTarget(self.mat_grabber_up)
		self.grabbing_mat = true
		render.RenderView({
			origin = pos,
			angles = ang,
			x = 0, y = 0,
			w = ScrW(), h = ScrH(),
			drawviewmodel = false,
			ortho = true,
			ortholeft = -36,
			orthoright = 36.1,
			orthotop = 0,
			orthobottom = self.h / 2
		})
		self.grabbing_mat = false
	render.PopRenderTarget()

	render.PushRenderTarget(self.mat_grabber_down)
		self.grabbing_mat = true
		render.RenderView({
			origin = pos,
			angles = ang,
			x = 0, y = 0,
			w = ScrW(), h = ScrH(),
			drawviewmodel = false,
			ortho = true,
			ortholeft = -36,
			orthoright = 36.1,
			orthotop = -self.h / 2,
			orthobottom = 0
		})
		self.grabbing_mat = false
	render.PopRenderTarget()

	--local scale = 0.25
	--local function HUDPaint()
	--	if not self.grabbed_mat_up or not self.grabbed_mat_down then return end

	--	surface.SetMaterial(self.grabbed_mat_up)
	--	surface.DrawTexturedRect(0, 0, self.w * mul, self.h * mul / 2)

	--	surface.SetMaterial(self.grabbed_mat_down)
	--	surface.DrawTexturedRect(0, self.h * mul / 2, self.w * mul, self.h * mul / 2)
	--end
	--hook.Add("HUDPaint", "rtdebug", HUDPaint)
end