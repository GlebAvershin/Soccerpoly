local Players = game:GetService("Players")
local Capture = game:GetService("CaptureService")
local player = Players.LocalPlayer
local shared = game:GetService("ReplicatedStorage")
local net = shared:WaitForChild("WorldDraft")
local report = net:WaitForChild("StudioReport")
local hud = player:WaitForChild("PlayerGui"):WaitForChild("WorldDraftHUD")
local board = require(shared.League.TourBoard)
local snapshot
net.Snapshot.OnClientEvent:Connect(function(data) snapshot = data end)
net.Intent:FireServer("sync")

local function waitFor(check, description, seconds)
	local deadline = os.clock() + (seconds or 10)
	repeat
		local result = check()
		if result then return result end
		task.wait(.04)
	until os.clock() > deadline
	error("Timeout: " .. description)
end
local function capture(name)
	if script:GetAttribute("CaptureFrames") then
		Capture:CaptureScreenshot(function(path) print("TOUR_CAPTURE", name, path) end)
	end
end
local function dispatch(verb, value)
	local before = snapshot
	task.wait(math.max(0, before.availableAt - workspace:GetServerTimeNow()) + .06)
	net.Intent:FireServer(verb, if verb == "bid" then before.auction.token else before.version, value)
end

local ok, err = pcall(function()
	local expected = script:GetAttribute("ExpectedPlayers") or 1
	local data = waitFor(function()
		return snapshot and #snapshot.lobby == expected and snapshot
	end, "lobby", 24)
	local start = waitFor(function() return hud:FindFirstChild("StartSeason", true) end, "start button")
	assert(start.AbsoluteSize.Y >= 40)
	local verifyMatchday = script:GetAttribute("VerifyMatchday") == true
	local stage = workspace:WaitForChild("WorldDraftArena")
	local printLayer = hud.Viewport:WaitForChild("BoardPrint")
	assert(#printLayer:GetChildren() == 32)
	local camera = waitFor(function()
		local current = workspace.CurrentCamera
		return current and current.CameraType == Enum.CameraType.Scriptable and current.ViewportSize.X > 2 and current
	end, "scriptable play camera", 8)
	waitFor(function()
		return printLayer.Cell1["Club name"].AbsoluteSize.X > 25
	end, "projected board print")
	for _, cell in printLayer:GetChildren() do
		assert(cell["Club name"].Text ~= "" and cell["Club name"].TextFits, "Unreadable title " .. cell.Name)
	end
	for _, part in stage.Board:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("BoardIndex") then
			local point, shown = camera:WorldToViewportPoint(part.Position)
			assert(shown and point.Z > 0, "Tile outside camera: " .. part:GetAttribute("BoardIndex") .. " " .. tostring(point))
		end
	end
	if script:GetAttribute("VerifyBlenderArt") then
		waitFor(function()
			local preview = hud:FindFirstChild("FootballerPreview", true)
			return preview and preview:FindFirstChild("Face", true) and preview:FindFirstChild("Face", true):IsA("MeshPart")
		end, "Blender figure")
		waitFor(function()
			local music = game:GetService("SoundService"):FindFirstChild("Footbolapolia Music")
			local sound = music and music:FindFirstChildOfClass("Sound")
			return sound and sound.IsLoaded and sound.IsPlaying
		end, "music")
	end
	if verifyMatchday then
		waitFor(function()
			local enamel = stage.Board:FindFirstChild("Porcelain face", true)
			local sole = hud:FindFirstChild("Molded outsole", true)
			return enamel and enamel:IsA("MeshPart") and sole and sole:IsA("MeshPart")
		end, "Blender tile and outsole")
		dispatch("format", 2)
		waitFor(function() return snapshot.format == 2 end, "long format")
		dispatch("format", 1)
		waitFor(function() return snapshot.format == 1 end, "quick format")
		capture("lobby")
	end
	report:FireServer("READY")
	if data.host == player.UserId then
		waitFor(function() return report:GetAttribute("ReadyCount") == expected end, "ready players", 25)
		dispatch("start")
	end
	waitFor(function() return snapshot and snapshot.match end, "kickoff")
	assert(#snapshot.match.seats == board.maxSeats)
	local diceSeen, cardSeen, boardSeen = false, false, false
	local previous, captured = -1, {}
	local replaySeen = false
	local expires = os.clock() + 42
	while snapshot.match.phase ~= "final" and os.clock() < expires do
		local s = snapshot.match
		local effects = workspace:FindFirstChild("LocalTablePieces")
		local replay = effects and effects["Motion effects"]:FindFirstChild("Matchday players")
		if verifyMatchday and replay and s.last.who == player.UserId and not replaySeen then
			replaySeen = true
			assert(s.last.kind == "goal" and s.last.amount == 140, "Expected a goal and its reward")
			waitFor(function() return not printLayer.Visible and camera.FieldOfView > 10 end, "shot camera", 1)
			capture("strike")
			local ball = effects["Motion effects"]:FindFirstChild("Matchday ball")
			assert(ball and ball.PrimaryPart and replay:FindFirstChild("Goalkeeper") and replay:FindFirstChild("Striker"))
			local from = ball:GetPivot().Position
			local sounds = game:GetService("SoundService")["Footbolapolia Effects"]
			waitFor(function()
				return sounds.kick.IsLoaded and sounds.kick.IsPlaying and (ball:GetPivot().Position - from).Magnitude > 4
			end, "kick sound and moving ball", 1)
			waitFor(function()
				return sounds.goal.IsLoaded and sounds.goal.IsPlaying and replay:FindFirstChild("Matchday goal"):IsA("MeshPart")
			end, "goal sound and goal mesh", 1)
			task.wait(.25)
			capture("goal")
			waitFor(function() return printLayer.Visible and math.abs(camera.FieldOfView - 7.5) < .1 end, "board camera restored", 3)
		end
		local dice = effects and effects["Motion effects"]:FindFirstChild("Dice roll")
		if dice and not diceSeen then
			diceSeen = true
			assert(#dice:GetChildren() == 2)
			task.defer(capture, "dice")
		end
		local open = hud.Viewport.PropertyBackdrop.Visible
		if open and (s.phase == "offer" or s.phase == "upgrade" or s.phase == "rebuy") then
			cardSeen = true
			local index = s.seats[s.active].position
			if board.tiles[index].league > 0 and not captured.club then
				captured.club = true
				task.wait(.36)
				capture("club-levels")
				task.wait(.20)
			end
			if not captured.card then
				captured.card = true
				task.wait(.36)
				capture("property")
				task.wait(.20)
			end
		end
		local roll = hud:FindFirstChild("RollDice", true)
		if roll and not boardSeen then
			boardSeen = true
			capture("table")
		end
		local current = snapshot
		local ready = workspace:GetServerTimeNow() >= current.availableAt
		if ready and current.version ~= previous then
			local seat = s.seats[s.active]
			if current.auction then
				previous = current.version
				if not current.auction.responded[table.find(s.seats, seat)] or seat.id ~= player.UserId then
					net.Intent:FireServer("bid", current.auction.token, 0)
				end
			elseif seat.id == player.UserId and not seat.bot then
				previous = current.version
				if s.phase == "move" or s.phase == "bench" then
					roll = waitFor(function() return hud:FindFirstChild("RollDice", true) end, "roll action", 2)
					assert(roll.AbsoluteSize.Y >= 40, "Dice button missing")
					if not boardSeen then
						boardSeen = true
						capture("table")
						task.wait(.23)
					end
					dispatch("roll")
				elseif s.phase == "offer" then
					waitFor(function() return hud.Viewport.PropertyBackdrop.Visible and hud:FindFirstChild("SignClub", true) end, "purchase card", 2)
					if not captured.card then
						captured.card = true
						cardSeen = true
						task.wait(.36)
						capture("property")
						task.wait(.20)
					end
					dispatch("buy", if board.tiles[seat.position].league > 0 then 2 else 0)
				elseif s.phase == "matchday" then
					waitFor(function() return hud:FindFirstChild("MatchdayShoot", true) end, "shoot button", 2)
					dispatch(if verifyMatchday then "shoot" else "safe")
				elseif s.phase == "upgrade" or s.phase == "rebuy" or s.phase == "championship" or s.phase == "shield" then
					dispatch("skip")
				elseif s.phase == "tour" then
					dispatch("travel", 1)
				elseif s.phase == "debt" then
					dispatch("bankrupt")
				end
			end
		end
		task.wait(.04)
	end
	assert(snapshot.match.phase == "final" and #snapshot.match.standings == 4 and diceSeen)
	if expected == 1 then assert(cardSeen and boardSeen, "Did not see playable property or dice action") end
	if verifyMatchday then assert(replaySeen, "Did not see a Matchday replay") end
	assert(hud:FindFirstChild("Rank1", true), "Final table missing")
	print("TOUR_QA", workspace.CurrentCamera.ViewportSize, snapshot.match.rollSerial, snapshot.match.finishReason, cardSeen)
	if snapshot.host == player.UserId then
		dispatch("lobby")
		waitFor(function() return snapshot and not snapshot.match end, "return to lobby")
	end
end)
report:FireServer(if ok then "PASS" else "FAIL " .. tostring(err))
