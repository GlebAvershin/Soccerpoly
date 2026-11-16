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
	local board = workspace:WaitForChild("WorldDraftArena"):WaitForChild("Board")
	local catalog = require(game:GetService("ReplicatedStorage").League.Board)
	local tileCount, indices = 0, {}
	local camera = workspace.CurrentCamera
	local cameraDeadline = os.clock() + 4
	while camera.CameraType ~= Enum.CameraType.Scriptable and os.clock() < cameraDeadline do
		task.wait(.05)
		camera = workspace.CurrentCamera
	end
	assert(camera.CameraType == Enum.CameraType.Scriptable, "Board camera not active")
	for _, part in board:GetDescendants() do
		if part.Name == "Printed tile" then
			local index = part:GetAttribute("BoardIndex")
			assert(index and not indices[index], "Missing or duplicate board index")
			tileCount += 1
			indices[index] = true
			local _, visible = camera:WorldToViewportPoint(part.Position + Vector3.yAxis * .11)
			assert(visible, "Board camera loses cell " .. index .. " at " .. tostring(camera.ViewportSize))
			local tile = catalog.tiles[index]
			local artwork = part.Artwork
			assert(artwork.Value.Text ~= "", "Unlabelled board cell")
			if tile.kind == "club" then
				assert(artwork.ClubName.Text:gsub("\n", " ") == tile.name, "Wrong club on board cell " .. index)
				assert(artwork.Value.Text == tostring(tile.price) .. " CR", "Wrong club price on board cell " .. index)
			else
				assert(artwork.EventName.Text ~= "", "Missing event name")
			end
		end
	end
	assert(tileCount == 24, "Incomplete board")
	if expected == 1 and not device then
		local virtual = game:GetService("UserInputService"):CreateVirtualInput()
		if virtual then
			local tile
			for _, candidate in board:GetDescendants() do
				if candidate:GetAttribute("BoardIndex") == 8 then tile = candidate break end
			end
			local screen = camera:WorldToViewportPoint(tile.Position + Vector3.yAxis * .11)
			local function click(point)
				virtual:SendMouseButton(point, Enum.UserInputType.MouseButton1, true, 0)
				task.wait(.05)
				virtual:SendMouseButton(point, Enum.UserInputType.MouseButton1, false, 0)
				task.wait(.12)
			end
			click(Vector2.new(screen.X, screen.Y))
			local details = hud:FindFirstChild("CellDetails", true)
			assert(details, "Tap did not open cell details")
			local close = hud:FindFirstChild("Close", true)
			click(close.AbsolutePosition + close.AbsoluteSize * .5 + game:GetService("GuiService"):GetGuiInset())
			assert(not hud.Viewport.DismissBackdrop.Visible, "Cell details did not close")
		end
	end
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
		for _, action in {"RouteShort", "RouteLong"} do
			local route = button(action)
			assert(route.Destination.Text ~= "" and route.Stake.Text ~= "", "Missing route information")
		end
		local shownBy = os.clock() + 4
		local viewport = hud.Viewport
		while not (viewport.RouteBadge1.Visible and viewport.RouteBadge2.Visible) and os.clock() < shownBy do task.wait(.05) end
		assert(viewport.RouteBadge1.Visible and viewport.RouteBadge2.Visible, "Route markers not shown")
		assert((hud:FindFirstChild("CoachHint", true) ~= nil) == (begun.variant == "coach"), "First route hint does not match assignment")
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
		task.wait(.18)
		assert(hud.Viewport.PlayResult.Visible, "Signing feedback not shown")
	else
		intent:FireServer("short", begun.version)
	end
	local steps, visitedCup = 0, false
	while last.match.phase ~= "final" do
		local data = await(function(next)
			local s = next.match
			return s and (s.phase == "final" or s.seats[s.active].id == me.UserId)
		end, "next personal turn", if expected == 6 then 34 else 12)
		if data.match.phase == "final" then break end
		steps += 1
		assert(steps < 20)
		local verb
		if data.match.phase == "matchday" then
			button("Shoot")
			button("SafePlay")
			visitedCup = true
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
		assert(visitedCup and seatOf(final.match).trophies > 0, "Host did not earn a cup")
		assert(workspace.LocalTablePieces.Markers:FindFirstChild("Continental Cup"), "Cup visualization missing")
		task.wait(if expected == 6 then 1.20 else 0.25)
		intent:FireServer("lobby", final.version)
	end
	await(function(data) return data.match == nil end, "replay lobby")
	button("StartSeason")
end)
report:FireServer(if ok then "PASS" else "FAIL " .. tostring(failure))
