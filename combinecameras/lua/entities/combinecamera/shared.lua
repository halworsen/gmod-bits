ENT.Type = "anim"
ENT.PrintName = "Combine Camera"
ENT.Author = "Atebite"
ENT.Information = "A camera"
ENT.Category = "Combine"

ENT.Editable = true
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.RenderGroup = RENDERGROUP_OPAQUE

ENT.Model = "models/combine_camera/combine_camera.mdl"

ENT.bones = {
	["Combine_Camera.Camera_bone"] = 10,
	["Combine_Camera.Lens"] = 11
}

function ENT:Initialize()
	self:SetModel(self.Model)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_NONE)
	self:SetSolid(SOLID_VPHYSICS)

	self.goal_angle = Angle(0, 0, 0)
	self.aim_yaw = 0
	self.aim_pitch = 0
	self.sweep_speed = 2
	self.active = false

	self.lock_targets = true -- lock onto targets at all?
	self.lock_radius = 300
	self.lock = false

	self.color_idle = Color(0, 255, 0, 255)
	self.color_lock = Color(255, 150, 0, 255)
	self.color_angry = Color(255, 0, 0, 255)
	self.color = self.color_idle

	self.next_render = 0
	self.next_search = 0
	self.next_move_sound = 0
	self.next_ping = 0

	if CLIENT then
		-- convar related things
		self.use_projected_textures = GetConVar("combinecams_expensive_lights"):GetBool()
		self.use_fancy_shadows = GetConVar("combinecams_expensive_shadows"):GetBool()

		local entid = self:EntIndex()
		self.RT = GetRenderTarget("CameraRT_"..entid, RT_W, RT_H, true)
		self.RTMat = CreateMaterial("CameraRTMat_"..entid, "UnlitGeneric", {["$basetexture"] = "CameraRT_"..entid})

		self.refresh_rate = 5 -- Hz

		self.take_picture = 0
		self.camera_flash_color = Color(255, 255, 255, 0)

		if self.use_projected_textures then
			self:SetupCameraLight()
		end
	end

	-- deploy on spawn
	self:Deploy()
end

function ENT:Think()
	local CT = CurTime()

	-- sequence animation
	self:DoSeqAnims()

	if SERVER then
		return
	end

	-- handle target locking
	self:HandleLocking()

	-- set where we want to move
	if self.active or self.animation then
		-- stop moving for the pic unless we're locked on to someone
		if not self.animation then
			self:UpdateGoalAngs()
		end

		-- update pose parameters (move the camera)
		self:UpdatePoseParams()
	end

	if self.active and not self.lock and self.take_picture == 0 then
		-- pingaling ding
		self:Ping()
	end

	if self.use_projected_textures and self.proj_tex then
		self:UpdateCameraLight(true)
	end

	if self.active and CT >= self.next_render then
		self.next_render = CT + (1/self.refresh_rate)

		self:RenderCameraView()
	end

	if self.take_picture ~= 0 and CT >= self.take_picture then
		self.take_picture = 0

		self:FinishPicture()
	end
end

-- perform sequence animations such as deploying and retracting
function ENT:DoSeqAnims()
	if self.animation then
		self:FrameAdvance(RealTime() - self.last_frame)
		self.last_frame = RealTime()

		if self:GetCycle() == 1 then
			self.animation = false
			if self.anim_cb then
				self.anim_cb()
			end
		end
	end
end

-- start a sequence. callback is called when the animation ends
function ENT:PerformSequence(seq, cb)
	self.animation = true
	self.last_frame = RealTime()
	self.anim_cb = cb

	self:SetCycle(0)
	self:ResetSequence(seq)
end

function ENT:Deploy()
	if self.animation then return end

	self:PerformSequence("deploy", function()
		self.active = true
		self.sine_offset = CurTime()
	end)
end

function ENT:Retract()
	if self.animation then return end

	self.active = false
	self.goal_angle.yaw = 0
	self.goal_angle.pitch = 0

	self:RenderCameraView(false, true)

	if self.lock and IsValid(self.lock_ent) then
		self:Unlock()
	end

	self:PerformSequence("retract", function()
		self.aim_yaw = 0
		self.aim_pitch = 0
	end)
end