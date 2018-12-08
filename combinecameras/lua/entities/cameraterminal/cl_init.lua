include("shared.lua")

local previous = Material("combinecamera/previous.png", "smooth mips")
local next = Material("combinecamera/next.png", "smooth mips")
local lock_on = Material("combinecamera/lock_on.png", "smooth mips")
local lock_off = Material("combinecamera/lock_off.png", "smooth mips")
local picture = Material("combinecamera/picture.png", "smooth mips")
local find_cams = Material("combinecamera/find_cams.png", "smooth mips")
local toggle_power = Material("combinecamera/power.png", "smooth mips")
local move_on = Material("combinecamera/move.png", "smooth mips")
local move_off = Material("combinecamera/move_off.png", "smooth mips")

-- get the cursor positon on the panel
local function GetCursorPos(origin, normal, ang, ply)
	ply = ply or LocalPlayer()
	local p = util.IntersectRayWithPlane(ply:EyePos(), ply:EyeAngles():Forward(), origin, normal)
	if not p then return -1, -1 end
	local offset = origin - p
	local o = offset:Length()
	
	local copy_ang = Angle(ang.p, ang.y, ang.r)
	
	copy_ang:RotateAroundAxis(ang:Forward(), 90)
	local dir = copy_ang:Forward()
	local cos = offset:Dot(dir) / (o * dir:Length())
	local x = math.abs(o * cos)
	
	-- out of bounds
	if math.acos(cos) < (math.pi / 2) then
		x = 0
	end

	copy_ang:RotateAroundAxis(ang:Up(), -90)
	dir = copy_ang:Forward()
	cos = offset:Dot(dir) / (o * dir:Length())
	local y = math.abs(o * cos)

	if math.acos(cos) < (math.pi / 2) then
		y = 0
	end

	return x, y
end

local function InBoxBounds(cx, cy, x, y, w, h)
	if (cx > x and cx < (x + w)) and (cy > y and cy < (y + h)) then
		return true
	end

	return false
end

-- draws a box with the specified icon centered in it
-- fucktons of arguments but saves lines so *shrug*
local function DrawIconBox(cx, cy, x, y, w, h, iw, ih, color, mat)
	if InBoxBounds(cx, cy, x, y, w, h) then
		color.r = color.r + 32
		color.g = color.g + 32
		color.b = color.b + 32
	end
	surface.SetDrawColor(color.r, color.g, color.b)
	surface.DrawRect(x, y, w, h)

	local ix, iy = x + (w / 2) - (iw / 2), y + (h / 2) - (ih / 2)

	surface.SetMaterial(mat)
	surface.SetDrawColor(255, 255, 255)
	surface.DrawTexturedRect(ix, iy, iw, ih)
end

function ENT:OnRemove()
	if IsValid(self.emitter) then
		self.emitter:Finish()
	end
end

function ENT:Draw()
	self:DrawModel()
end

function ENT:DrawTranslucent()
	-- control panel
	local pos = self:GetPos() + self:GetUp() * 47.9 + self:GetRight() * 9.77 - self:GetForward() * 2.25
	local ang = self:GetAngles()
	ang:RotateAroundAxis(self:GetUp(), 90)
	ang:RotateAroundAxis(self:GetRight(), -42)

	local cx, cy = GetCursorPos(pos, ang:Up(), ang)
	local mul = 1 / self.panel_scale
	cx, cy = math.Clamp(cx * mul, 0, 172), math.Clamp(cy * mul, 0, 85)

	if not input.IsKeyDown(KEY_E) and self.press then
		self.press = false
	end

	if cx > -1 and #self.cameras > 0 and input.IsKeyDown(KEY_E) and not self.press then
		self.press = true

		UseFunc(self, cx, cy)
	end

	cam.Start3D2D(pos, ang, self.panel_scale)
		local w, h = 172, 85

		surface.SetDrawColor(0, 0, 0)
		surface.DrawRect(0, 0, w, h)

		-- previous
		DrawIconBox(cx, cy, 2, 2, 50, 81, 30, 51, Color(32, 32, 32), previous)

		-- next
		DrawIconBox(cx, cy, 120, 2, 50, 81, 30, 51, Color(32, 32, 32), next)

		if #self.cameras == 0 then
			surface.SetDrawColor(32, 32, 32)
			surface.DrawRect(2, 2, (w - 4), (h - 4))

			local rotation = (CurTime() * 60) % 360
			surface.SetMaterial(find_cams)
			surface.SetDrawColor(255, 255, 255)
			surface.DrawTexturedRectRotated(((w - 4) / 2), ((h - 4) / 2), 44, 48, rotation)
		else
			-- toggle locking
			local lock_mat = lock_off
			if self.active_camera and self.cameras[self.active_camera].lock_targets then
				lock_mat = lock_on
			end
			DrawIconBox(cx, cy, 54, 2, 31, 40, 20, 30, Color(64, 64, 32), lock_mat)

			-- take picture
			DrawIconBox(cx, cy, 54, 44, 31, 39, 23, 20, Color(32, 32, 54), picture)

			-- toggle power
			DrawIconBox(cx, cy, 87, 2, 31, 40, 23, 25, Color(64, 32, 32), toggle_power)

			-- toggle halting
			local move_mat = move_on
			if self.active_camera and self.cameras[self.active_camera].halting then
				move_mat = move_off
			end
			DrawIconBox(cx, cy, 87, 44, 31, 39, 23, 13, Color(32, 64, 32), move_mat)
		end

		-- cursor
		--surface.SetDrawColor(255, 0, 0)
		--surface.DrawRect(cx - 2, cy - 2, 4, 4)
	cam.End3D2D()

	if not self.active_camera or not IsValid(self.cameras[self.active_camera]) then return end

	-- camera display
	pos = self:GetPos() + self:GetUp() * 80 + self:GetRight() * 14 - self:GetForward() * 15
	ang = self:GetAngles()
	ang:RotateAroundAxis(self:GetUp(), 90)
	ang:RotateAroundAxis(self:GetRight(), -90)

	cam.Start3D2D(pos, ang, 0.05)
		surface.SetDrawColor(0, 0, 0)
		surface.DrawRect(0, 0, 512, 512)

		surface.SetMaterial(self.cameras[self.active_camera].RTMat)
		surface.DrawTexturedRect(2, 2, 508, 508)
	cam.End3D2D()
end

function ENT:SetupParticles()
	local pos = self:GetPos() + self:GetUp() * 45 + self:GetRight() * 2.5 - self:GetForward() * 15

	local effect_data = EffectData()
	effect_data:SetOrigin(pos)
	effect_data:SetEntity(self)
	util.Effect("screen_projection", effect_data, true, true)
end