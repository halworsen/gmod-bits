ENT.Type = "anim"
ENT.PrintName = "Combine Camera Terminal"
ENT.Author = "Atebite"
ENT.Information = "A camera terminal"
ENT.Category = "Combine"

ENT.Editable = true
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.RenderGroup = RENDERGROUP_BOTH

ENT.Model = "models/props_combine/combine_interface001.mdl"

function ENT:Think()
	for k,v in pairs(self.cameras) do
		if not IsValid(v) then
			if self.active_camera == k then
				if #self.cameras == 0 then
					self.active_camera = nil
				else
					self:Previous()
				end
			end

			table.remove(self.cameras, k)
		end
	end

	if CurTime() >= self.next_search then
		self.next_search = CurTime() + 1

		self:FindCameras()
	end
end

-- find some cameras that aren't already used by other terminals
function ENT:FindCameras()
	for k,v in pairs(ents.FindByClass("combinecamera")) do
		if not table.HasValue(self.cameras, v) then
			self.cameras[#self.cameras + 1] = v

			if #self.cameras == 1 then
				self.active_camera = k
			end
		end
	end

	if #self.cameras > 0 and CLIENT then
		self:SetupParticles()
	end
end

function ENT:UseFunc(cx, cy)
	-- previous
	if InBoxBounds(cx, cy, 2, 2, 50, 81) then
		self:Previous()
	end

	-- next
	if InBoxBounds(cx, cy, 120, 2, 50, 81) then
		self:Next()
	end

	if #ent.cameras > 0 then
		-- toggle power
		if InBoxBounds(cx, cy, 87, 2, 31, 40) then
			self:TogglePower()
		end

		if SERVER then
			return
		end

		-- toggle locking
		if InBoxBounds(cx, cy, 54, 2, 31, 40) then
			self:ToggleLocking()
		end

		-- take picture
		if InBoxBounds(cx, cy, 54, 44, 31, 39) then
			self:TakePicture()
		end

		-- toggle halting
		if InBoxBounds(cx, cy, 87, 44, 31, 40) then
			self:ToggleHalting()
		end
	end
end

function ENT:Next()
	if #self.cameras == 0 then return end

	self.active_camera = (self.active_camera + 1) % (#self.cameras + 1)

	if self.active_camera == 0 then
		self.active_camera = 1
	end
end

function ENT:Previous()
	if #self.cameras == 0 then return end

	self.active_camera = (self.active_camera - 1) % (#self.cameras + 1)

	if self.active_camera == 0 then
		self.active_camera = #self.cameras
	end
end

function ENT:TogglePower()
	local cam = self.cameras[self.active_camera]

	if cam.active then
		cam:Retract()
	else
		cam:Deploy()
	end
end

function ENT:ToggleHalting()
	self.cameras[self.active_camera]:ToggleHalt()
end

function ENT:ToggleLocking()
	self.cameras[self.active_camera].lock_targets = not self.cameras[self.active_camera].lock_targets
end

function ENT:TakePicture()
	self.cameras[self.active_camera]:TakePicture()
end