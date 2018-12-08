--[[
	Server pings all clients regularly.
	If the client doesn't receive a ping within some amount of time,
	you get a timeout and assume the server is dying. We then notify
	the player that the server might be OOF'd
--]]
local tag = "DCWatch"

local ping_interval = 2

if CLIENT then
	local dead_flavors = {
		"kicked the bucket",
		"gone OOF!",
		"given up hope",
		"gotten tired of its job",
		"bit the dust"
	}

	-- seconds without a ping that makes for timeout
	local timeout_threshold = 10
	-- 20 s after noticing the server might be dead, we reconnect
	local reconnect_delay = 20

	local server_dead = false
	local last_ping = CurTime()
	local reconnect_in = 0
	-- flavor text for server death
	local dead_flavor = ""

	local function DCWatchPing()
		last_ping = CurTime()
		server_dead = false
	end
	net.Receive("DCWatchPing", DCWatchPing)

	local function Think()
		local CT = CurTime()

		if server_dead then
			if CT > reconnect_in then
				LocalPlayer():ConCommand("retry")
				return
			end
		elseif (CT - last_ping) > timeout_threshold then
			server_dead = true
			reconnect_in = CT + reconnect_delay
			dead_flavor = table.Random(dead_flavors)
			return
		end
	end
	hook.Add("Think", tag, Think)

	surface.CreateFont("DCWatch1", {
		font = "Arial",
		size = 24
	})
	surface.CreateFont("DCWatch2", {
		font = "Arial",
		size = 16
	})

	local panel_speed = 0
	local pw, ph = ScrW(), 80
	local px, py = -pw, ScrH()/3
	local function HUDPaint()
		local accel = FrameTime() * 20
		if not server_dead then accel = -accel end
		panel_speed = panel_speed + accel
		px = math.max(math.min(px + panel_speed, 0), -pw)

		-- bounce effect
		if px == 0 then
			panel_speed = panel_speed * -1/4
		end

		-- box is fully offscreen
		if px == -pw then
			panel_speed = 0
			progress_bar_w = 0
			return
		end

		local time_to_reconnect = reconnect_in - CurTime()
		local reconnecting_in = math.max(math.Truncate(time_to_reconnect), 0)
		if reconnecting_in == 0 then
			reconnecting_in = "now!"
		else
			reconnecting_in = reconnecting_in .. " second" .. (reconnecting_in == 1 and "" or "s") .. "..."
		end

		draw.RoundedBox(0, px, py, pw, ph, Color(32, 32, 32))
		draw.SimpleText("The server might have "..dead_flavor, "DCWatch1", px + pw / 2, py + 10, Color(189, 195, 199), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		draw.SimpleText("Attempting to reconnect in: "..reconnecting_in, "DCWatch2", px + pw / 2, py + 39, Color(189, 195, 199), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

		local reconnect_progress = (reconnect_delay - time_to_reconnect) / reconnect_delay
		draw.RoundedBox(0, px, py + 65, pw, 15, Color(64, 64, 64))
		draw.RoundedBox(0, px, py + 65, pw * reconnect_progress, 15, Color(189, 195, 199))
	end
	hook.Add("HUDPaint", tag, HUDPaint)
end

if SERVER then
	util.AddNetworkString("DCWatchPing")

	local function PingClients()
		net.Start("DCWatchPing")
		net.Broadcast()
	end

	local next_ping = 0
	local function Think()
		local CT = CurTime()
		if CT > next_ping then
			next_ping = CT + 5
			PingClients()
		end
	end
	hook.Add("Think", tag, Think)
end