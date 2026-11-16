local players = game:GetService("Players")
local me = players.LocalPlayer
local net = game:GetService("ReplicatedStorage"):WaitForChild("WorldDraft")
local report, intent, pushes = net:WaitForChild("StudioReport"), net.Intent, net.Snapshot
local hud = me:WaitForChild("PlayerGui"):WaitForChild("WorldDraftHUD", 8)
local last
pushes.OnClientEvent:Connect(function(snapshot) last = snapshot end)
local function await(predicate, label, limit)
	local deadline = os.clock() + (limit or 10)
	repeat
		if last and predicate(last) then return last end
		task.wait(0.04)
	until os.clock() > deadline
	error("Waiting for " .. label)
end
local function button(name)
	local found = hud:FindFirstChild(name, true)
	assert(found and found:IsA("GuiButton"), "Missing HUD button " .. name)
	assert(found.AbsoluteSize.X > 40 and found.AbsoluteSize.Y >= 40, "Button lacks touch target: " .. name)
	local canvas = hud:FindFirstChild("Viewport")
	local a, b = found.AbsolutePosition, found.AbsolutePosition + found.AbsoluteSize
	local lo, hi = canvas.AbsolutePosition, canvas.AbsolutePosition + canvas.AbsoluteSize
	assert(a.X >= lo.X and a.Y >= lo.Y and b.X <= hi.X + 1 and b.Y <= hi.Y + 1, "Action outside safe area: " .. name)
	return found
end
local function seatOf(s)
	for _, seat in s.seats do if seat.id == me.UserId then return seat end end
	error("Local participant missing")
end
local ok, failure = pcall(function()
	assert(hud, "HUD never loaded")
	local device = script:GetAttribute("Device")
	if device then
		local size = workspace.CurrentCamera.ViewportSize
		local ready = os.clock() + 5
		while size.X <= 1 and os.clock() < ready do
			task.wait()
			size = workspace.CurrentCamera.ViewportSize
		end
		assert((size.Y > size.X) == (device == "portrait"), "Device orientation failed: " .. tostring(size))
		assert(size.X < 700, "Device was not emulated: " .. tostring(size))
	end
	local expected = script:GetAttribute("ExpectedPlayers") or 1
	task.spawn(function()
		while not last or #last.lobby < expected do
			intent:FireServer("sync")
			task.wait(0.5)
		end
	end)
	intent:FireServer("sync")
	local lobby = await(function(data) return data.match == nil and #data.lobby == expected end, "full test lobby", 42)
	task.wait(0.18)
	button("StartSeason")
	assert(hud:FindFirstChild("FootballerPreview", true), "No figure preview")
	if lobby.host == me.UserId then
		if expected == 1 then
			intent:FireServer("figure", lobby.version, 4)
			lobby = await(function(data) return data.lobby[1].figure == 4 end, "figure update")
		end
		task.wait(0.7)
		intent:FireServer("start", lobby.version)
	end
	local begun = await(function(data) return data.match ~= nil end, "kickoff", 14)
	local seats = math.max(expected, 3)
	assert(#begun.match.seats == seats)
	assert(begun.match.seats[1].id == begun.host)
	local figures = {}
	for slot, seat in begun.match.seats do
		assert(seat.bot == (slot > expected), "Unexpected human/bot seat")
		assert(not figures[seat.figure], "Duplicate figure")
		figures[seat.figure] = true
	end
	assert(begun.match.deck == nil, "Private tactics deck replicated")
	local own = seatOf(begun.match)
	assert(own.position == 1 and own.cash == 700)
	if begun.host == me.UserId then
		button("RouteShort")
		button("RouteLong")
		task.wait(0.28)
		intent:FireServer("long", begun.version - 1)
		task.wait(0.20)
		assert(last.version == begun.version and seatOf(last.match).position == 1, "Stale action mutated match")
		intent:FireServer("short", begun.version)
		local offer = await(function(data) return data.match.phase == "offer" end, "contract")
		assert(seatOf(offer.match).position == 2)
		button("SignClub")
		task.wait(0.88)
		intent:FireServer("buy", offer.version)
		intent:FireServer("buy", offer.version)
		local signed = await(function(data) return data.match.clubs[2].owner == me.UserId end, "one signing")
		assert(seatOf(signed.match).cash == 540, "Duplicate buy was applied")
	else
		intent:FireServer("short", begun.version)
	end
	local steps = 0
	while last.match.phase ~= "final" do
		local data = await(function(next)
			local s = next.match
			return s and (s.phase == "final" or s.seats[s.active].id == me.UserId)
		end, "next personal turn")
		if data.match.phase == "final" then break end
		steps += 1
		assert(steps < 20)
		local verb
		if data.match.phase == "matchday" then
			button("Shoot")
			button("SafePlay")
			verb = "shoot"
		else
			verb = if data.match.phase == "move" then "long" elseif data.match.phase == "offer" then "buy" else "upgrade"
		end
		task.wait(math.max(0.04, data.availableAt - workspace:GetServerTimeNow() + 0.07))
		intent:FireServer(verb, data.version)
		await(function(newer) return newer.version > data.version end, "action accepted")
	end
	local final = last
	assert(#final.match.standings == seats and final.match.round == 8)
	assert(final.match.motion.serial == 8 * seats)
	assert(final.match.standings[1].score >= final.match.standings[seats].score)
	button("BackToLobby")
	assert(hud:FindFirstChild("Rank1", true))
	if final.host == me.UserId then
		task.wait(0.25)
		intent:FireServer("lobby", final.version)
	end
	await(function(data) return data.match == nil end, "replay lobby")
	button("StartSeason")
end)
report:FireServer(if ok then "PASS" else "FAIL " .. tostring(failure))
