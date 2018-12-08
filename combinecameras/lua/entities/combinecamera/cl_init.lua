include("shared.lua")

surface.CreateFont("CCameraInfo", {
	font = "Default",
	size = 18,
	outline = true
})

local RT_W, RT_H = 512, 512
local glow = Material("sprites/glow04_noz")
local flash = Material("sprites/light_glow03")
local render_overlay = Material("effects/combine_binocoverlay")
local picture_mat = Material("combinecamera/picture.png", "smooth mips")

-- ents.findincone is broken
local function FindInCone(origin, direction, radius, angle)
	local entities = ents.FindInSphere(origin, radius)
	local result = {}

	direction:Normalize()

	local cos = math.cos(angle)

	for _, entity in pairs(entities) do
		local pos = entity:GetPos()
		local dir = pos - origin
		dir:Normalize()
		local dot = direction:Dot(dir)

		if (dot > cos) then
			table.insert(result, entity)
		end
	end

	return result
end

-- camera position for rendering purposes
function ENT:GetCamInfo()
	local cam_ang = self:GetAngles() + Angle(self.aim_pitch - 5, self.aim_yaw, 0)
	local cam_pos = self:GetBonePosition(self.bones["Combine_Camera.Lens"]) + cam_ang:Forward() * 5

	return cam_pos, cam_ang
end

function ENT:MaxYawSpeed()
	if (self.lock and IsValid(self.lock_ent)) or self.take_picture ~= 0 or self.animation then
		return 5
	end

	return 2.5
end

-- returns the position the camera would look towards if locked to the entity
function ENT:GetLockPos(ent)
	local obbmax, obbmin = ent:OBBMaxs(), ent:OBBMins()
	local z_size = (obbmax.z - obbmin.z) / 2
	
	return (ent:GetPos() + Vector(0, 0, z_size))
end

function ENT:OnRemove()
	if self.proj_tex then
		self.proj_tex:Remove()
	end
end

function ENT:Draw()
	self:DrawModel()

	local pos, ang = self:GetCamInfo()

	-- 2 is the light attachment
	local glow_pos = self:GetAttachment(2).Pos --self:GetBonePosition(self.bones["Combine_Camera.Lens"])
	render.SetMaterial(glow)
	render.DrawSprite(glow_pos, 8, 8, self.color)

	local flash_pos = self:GetAttachment(1).Pos + ang:Forward() * 7
	self.camera_flash_color.a = math.Approach(self.camera_flash_color.a, self.flash_alpha_goal or 0, 5)
	render.DrawSprite(flash_pos, 48, 48, self.camera_flash_color)

	if self.camera_light then return end
	
	if self.camera_flash_color.a == 0 and self.proj_tex then
		self.proj_tex:Remove()
		self.proj_tex = nil
	end
end

-- camera-specific stuff
-- render the view from the camera to our RT
function ENT:RenderCameraView(picture, offline)
	local CT = CurTime()

	-- testing shows that the "true" pitch is aim_pitch - 5
	local cam_pos, cam_ang = self:GetCamInfo()

	render.PushRenderTarget(self.RT, 0, 0, RT_W, RT_H)
		if offline then
			cam.Start2D()
				surface.SetDrawColor(0, 0, 0)
				surface.DrawRect(0, 0, RT_W, RT_H)

				surface.SetFont("CCameraInfo")
				surface.SetTextColor(255, 255, 255, 255)
				surface.SetTextPos((RT_W / 2) - (off_w / 2), (RT_H / 2) - (off_h / 2))
				surface.DrawText(off_msg)
			cam.End2D()

			render.PopRenderTarget()

			return
		end

		render.RenderView({
			x = 0, y = 0,
			w = RT_W, h = RT_H,
			origin = cam_pos,
			angles = cam_ang,
			drawviewmodel = false,
			fov = 100
		})

		cam.Start2D()
			surface.SetDrawColor(255, 255, 255, 255)
			surface.SetMaterial(render_overlay)
			surface.DrawTexturedRect(-50, 0, RT_W + 100, RT_H)

			surface.SetFont("CCameraInfo")
			surface.SetTextColor(255, 255, 255, 255)
			surface.SetTextPos(10, 10)
			self.id_text = self.id_text or "CAMID-#"..self:EntIndex()
			surface.DrawText(self.id_text)

			local timestamp = math.Round(CT, 1)
			local w, h = surface.GetTextSize(timestamp)
			surface.SetTextPos(RT_W - 10 - w, 10)
			surface.DrawText(timestamp)

			local lock_text = "NO LOCK"
			if self.lock and IsValid(self.lock_ent) then lock_text = "LOCK: "..self.lock_ent:Name() end
			w, h = surface.GetTextSize(self.id_text)
			surface.SetTextPos(10, 10 + h)
			surface.DrawText(lock_text)

			if picture then
				surface.SetDrawColor(255, 255, 255, 255)
				surface.SetMaterial(picture_mat)

				local tw, th = surface.GetTextSize(lock_text)
				if w > tw then
					tw, th = w, h
				end

				local mw, mh = picture_mat:Width(), picture_mat:Height()
				local scale = mw/mh
				mh = th + h
				mw = scale * mh
				
				surface.DrawTexturedRect(20 + tw, 10, mw, mh)
			end
		cam.End2D()
	render.PopRenderTarget()
end

function ENT:UpdateCameraLight()
	local pos, ang = self:GetCamInfo()
	
	if self.active then
		if self.camera_light then
			self.flash_alpha_goal = 255
		end
		self.proj_tex:SetNearZ(1)
	else
		self.flash_alpha_goal = 0
		self.proj_tex:SetNearZ(0)
	end

	self.proj_tex:SetPos(pos)
	self.proj_tex:SetAngles(ang)

	self.proj_tex:Update()
end

function ENT:SetupCameraLight(force)
	if self.use_projected_textures and not force then
		local light = render.GetLightColor(self:GetPos()):Length()
		if light > 0.0001 then
			return
		else
			self.camera_light = true
		end
	end

	self.proj_tex = ProjectedTexture()

	self.proj_tex:SetTexture("effects/flashlight/soft")
	self.proj_tex:SetEnableShadows(self.use_fancy_shadows)

	self.proj_tex:SetColor(Color(255, 255, 255))
	self.proj_tex:SetBrightness(5)

	self.proj_tex:SetNearZ(0)
	self.proj_tex:SetFarZ(self.lock_radius + 100)
	self.proj_tex:SetFOV(90)

	self.proj_tex:Update()
end

-- update the angles we aim to have
function ENT:UpdateGoalAngs()
	local CT = CurTime()

	if self.lock and IsValid(self.lock_ent) then
		local cam_ang = self:GetAngles() + Angle(self.aim_pitch - 5, self.aim_yaw, 0)
		local cam_pos = self:EyePos()--self:GetBonePosition(self.bones["Combine_Camera.Lens"]) + cam_ang:Forward() * 5

		-- v looks odd when the camera bounces up and down with the player movement
		--local bone_id = self.lock_ent:LookupBone("ValveBiped.Bip01_Spine")
		local lock_pos = self:GetLockPos(self.lock_ent)
		local ang = (lock_pos - cam_pos):Angle()

		local yaw = ang.yaw - self:GetAngles().yaw
		self.goal_angle.yaw = yaw

		if ang.pitch >= 180 then
			ang.pitch = ang.pitch - 360
		end
		self.goal_angle.pitch = ang.pitch
	else
		-- 100deg yaw range
		-- gonna be a bit less in reality because of the low yaw speed
		-- which is required anyways to prevent too snappy returns after unlocks
		if not self.halting then
			local mul = math.sin(self.sweep_speed * (CT - self.sine_offset))
			self.goal_angle.yaw = 50 * mul
		end
		self.goal_angle.pitch = 20
	end
end

-- update pose parameters to move the camera
-- in large part trying to copy what the C++ code does
function ENT:UpdatePoseParams()
	local CT = CurTime()

	local moved = false

	local pitch, yaw = self.stored_pitch or 0.5, self.stored_yaw or 0.5
	local cur_ang = Angle((pitch * 180) - 90, (yaw * 360) - 180, 0) -- i hate my life

	local target_change = self.goal_angle - cur_ang

	-- math.ApproachAngle also works but creates linear (ugly) movement
	-- local yaw = math.ApproachAngle(0, target_change.yaw, 0.5 * self:MaxYawSpeed())
	-- local pitch = math.ApproachAngle(0, target_change.pitch, 0.5 * self:MaxYawSpeed())
	-- local diff_angle = Angle(pitch, yaw, 0)
	local diff_angle = LerpAngle(FrameTime() * self:MaxYawSpeed(), Angle(0, 0, 0), target_change)

	local diff = diff_angle.yaw
	self.aim_yaw = cur_ang.yaw + diff

	if math.abs(diff) >= 0.1 then
		moved = true
	end

	diff = diff_angle.pitch
	self.aim_pitch = cur_ang.pitch + diff

	if math.abs(diff) >= 1 then
		moved = true
	end

	if moved and CT >= self.next_move_sound then
		self.next_move_sound = CT + 1
		self:EmitSound("NPC_CombineCamera.Move")
	end

	self:SetPoseParameter("aim_yaw", math.NormalizeAngle(self.aim_yaw))
	self:SetPoseParameter("aim_pitch", math.NormalizeAngle(self.aim_pitch))
	-- using getposeparameter at the beginning of the function will sometimes return the wrong value????
	-- it caused the camera to snap back to the default position twice in the first few seconds after being deployed
	self.stored_pitch, self.stored_yaw = self:GetPoseParameter("aim_pitch"), self:GetPoseParameter("aim_yaw")

	self:InvalidateBoneCache()
end

-- lock/unlock targets
function ENT:HandleLocking()
	if not self.active then return end

	if not self.lock_targets then
		if self.lock then
			self:Unlock()
		end

		return
	end

	local pos = self:GetPos()
	local xy_pos = Vector(pos.x, pos.y, 0)

	-- find a target to lock on to
	if not self.lock then
		if CurTime() >= self.next_search then
			self.next_search = CurTime() + 0.5 -- findincone is expensive, so we shouldn't be too eager with looking for targets

			local orig = self:GetAttachment(1).Pos -- "eye"

			for k,v in pairs(FindInCone(orig, self:GetAttachment(1).Ang:Forward(), self.lock_radius, math.pi/4)) do
				if v:IsPlayer() and v:Alive() then
					local lock_pos = v:GetPos()
					local xy_lock_pos = Vector(lock_pos.x, lock_pos.y, 0)

					local distance = xy_pos:Distance(xy_lock_pos)

					if distance <= self.lock_radius then
						-- check if we have line of sight
						local pos = self:GetCamInfo()
						local lock_pos = self:GetLockPos(v)
						local tr = util.TraceLine({start = pos, endpos = lock_pos, mask = MASK_BLOCKLOS, filter = self})

						if tr.Fraction == 1 then
							self:Lock(v)
						end
					end
				end
			end
		end

		return
	end

	if not IsValid(self.lock_ent) and self.lock then
		self:Unlock()
	end

	local lock_pos = self.lock_ent:GetPos()
	local xy_lock_pos = Vector(lock_pos.x, lock_pos.y, 0)
	local distance = xy_pos:Distance(xy_lock_pos)
	-- unlock if our target is too close or far away in the xy plane
	-- ignore the z-plane because we're at the ceiling

	if distance >= self.lock_radius then
		self:Unlock()
	end
end

-- make a ping sound
function ENT:Ping()
	local CT = CurTime()

	if CT >= self.next_ping then
		self.next_ping = CT + 1
		self:EmitSound("NPC_CombineCamera.Ping")
	end
end

-- snap a pic
function ENT:TakePicture()
	if not self.active then return end

	self.color = self.color_angry
	self:EmitSound("NPC_CombineCamera.Angry")

	-- halt for the picture if we're not locked on
	if not self.lock and not self.halting then
		self:ToggleHalt()
	elseif self.halting then
		self.keep_halt_after_picture = true
	end

	-- use for timing + signalling that we should stay still
	self.take_picture = CurTime() + 0.9
end

function ENT:FinishPicture()
	self.next_render = CurTime() + 5

	self:EmitSound("NPC_CombineCamera.Click")
	self.camera_flash_color.a = 255

	if not self.proj_tex then
		self:SetupCameraLight(true)
	end

	local pos, ang = self:GetCamInfo()

	self.proj_tex:SetPos(pos)
	self.proj_tex:SetAngles(ang)

	self.proj_tex:SetNearZ(1)

	self.proj_tex:Update()

	self:RenderCameraView(true)

	self.color = self.lock and self.color_lock or self.color_idle
	if self.halting and not self.keep_halt_after_picture then
		self:ToggleHalt()
	end

	self.keep_halt_after_picture = nil
end

function ENT:ToggleHalt()
	local CT = CurTime()

	-- halting cannot be turned off while taking a picture
	if self.take_picture ~= 0 and self.halting then
		return
	end

	if self.halting then
		self.sine_offset = self.sine_offset + (CT - self.halt_start)
	else
		self.halt_start = CT

		if not self.lock then
			-- lerp makes it lag a fair bit behind, so we cheat a bit
			-- makes it all halt much faster
			local x = CT - self.sine_offset
			local derivative = math.cos(self.sweep_speed * x) * x

			local yaw = self.stored_yaw or 0.5
			local cur_ang = (yaw * 360) - 180
			
			if yaw < 0.5 and derivative < 0 then
				self.goal_angle.yaw = cur_ang - 3
			elseif yaw < 0.5 and derivative > 0 then
				self.goal_angle.yaw = cur_ang + 3
			elseif yaw > 0.5 and derivative < 0 then
				self.goal_angle.yaw = cur_ang - 3
			else
				self.goal_angle.yaw = cur_ang + 3
			end
		end
	end

	self.halting = not self.halting
end

-- lock on to a target
function ENT:Lock(ent)
	if not IsValid(ent) then return end
	if not self.active then return end

	self.lock = true
	self.lock_ent = ent
	self.color = self.color_lock

	if CLIENT then
		self:EmitSound("NPC_CombineCamera.Active")
	end
end

function ENT:Unlock()
	self.lock = false
	self.color = self.color_idle
end