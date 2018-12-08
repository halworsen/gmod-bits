local function SetupPlayerVisibility()
	for k,v in pairs(ents.FindByClass("sent_combinecamera")) do
		AddOriginToPVS(v:GetPos())
	end
end
hook.Add("SetupPlayerVisibility", "AddCombineCamerasToPVS", SetupPlayerVisibility)