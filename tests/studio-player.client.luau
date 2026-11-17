local Players = game:GetService("Players")
local Capture = game:GetService("CaptureService")
local player = Players.LocalPlayer
local shared = game:GetService("ReplicatedStorage")
local net = shared:WaitForChild("WorldDraft")
local report = net:WaitForChild("StudioReport")
local hud = player:WaitForChild("PlayerGui"):WaitForChild("WorldDraftHUD")
local board = require(shared.League.TourBoard)
local art = require(shared.League.Presentation)
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
	local closeup = script:GetAttribute("VerifyBlenderArt") == true
	local verifyMatchday = script:GetAttribute("VerifyMatchday") == true
	local stage = workspace:WaitForChild("WorldDraftArena")
	local printLayer = hud.Viewport:WaitForChild("BoardPrint")
	assert(#printLayer:GetChildren() == 32)
	local camera = waitFor(function()
		local current = workspace.CurrentCamera
		return current and current.CameraType == Enum.CameraType.Scriptable and current.ViewportSize.X > 2 and current
	end, "scriptable play camera", 8)
	waitFor(function()
		return printLayer.Cell1["Club name"].AbsoluteSize.X > (if camera.ViewportSize.Y < 430 then 18 else 25)
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
			local face = preview and preview:FindFirstChild("Face", true)
			local collar = preview and preview:FindFirstChild("Woven collar", true)
			local hand = preview and preview:FindFirstChild("Palm", true)
			return face and face:IsA("MeshPart") and collar and collar:IsA("MeshPart") and hand and hand:IsA("MeshPart")
		end, "Blender figure")
		waitFor(function()
			local roster = workspace:FindFirstChild("LocalTablePieces")
			if not roster then return false end
			for _, footballer in board.figures do
				local figure = roster:FindFirstChild(footballer.name)
				local head = figure and figure:FindFirstChild("Face", true)
				local jersey = figure and figure:FindFirstChild("Jersey", true)
				if not (head and head:IsA("MeshPart") and jersey and jersey:IsA("MeshPart")) then return false end
			end
			return true
		end, "six portrait sculpts and six match kits")
		local pawn = require(script.Parent.Pawn)
		local inspection = Instance.new("Folder")
		for index in {1, 2} do
			local model = pawn.make(index, inspection, true)
			pawn.animate(model, "kick", 0)
			local left, right = model["Left leg"], model["Right leg"]
			local initialLeft, initialRight = left:GetPivot().UpVector, right:GetPivot().UpVector
			pawn.animate(model, "kick", .58)
			local leftTurn = initialLeft:Dot(left:GetPivot().UpVector)
			local rightTurn = initialRight:Dot(right:GetPivot().UpVector)
			local leftFoot = board.figures[index].leftFoot
			assert(if leftFoot then leftTurn < rightTurn else rightTurn < leftTurn, "Dominant foot and Blender kick differ")
			pawn.animate(model, "cheer", .45)
			assert((model["Right arm"]:GetPivot().LookVector - Vector3.new(0, 0, -1)).Magnitude > .5)
		end
		inspection:Destroy()
		waitFor(function()
			local music = game:GetService("SoundService"):FindFirstChild("Footbolapolia Music")
			local sound = music and music:FindFirstChild("Feel That Move")
			return sound and sound.IsLoaded and sound.IsPlaying
		end, "music")
	end
	if verifyMatchday then
		waitFor(function()
			local enamel = stage.Board:FindFirstChild("Porcelain face", true)
			local sole = hud:FindFirstChild("Molded outsole", true)
			local plinth = stage.Board:FindFirstChild("Octagonal arena plinth")
			local stencil = stage:FindFirstChild("Footbolapolia field stencil", true)
			local deck = stage.Board:FindFirstChild("Chance cards", true)
			return deck and deck:IsA("MeshPart") and enamel and enamel:IsA("MeshPart") and sole and sole:IsA("MeshPart")
				and plinth and plinth:IsA("MeshPart") and stencil and stencil:IsA("MeshPart")
		end, "Blender arena, tile and outsole")
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
	if closeup and camera.ViewportSize.X < camera.ViewportSize.Y * .86 then
		local cameraButton = hud.Viewport:FindFirstChild("BoardCamera")
		waitFor(function()
			local active = snapshot.match.seats[snapshot.match.active]
			local pieces = workspace:FindFirstChild("LocalTablePieces")
			local figures = pieces and pieces:FindFirstChild("Match pawns")
			local actor = figures and figures:FindFirstChild(board.figures[active.figure].name)
			if not actor or not cameraButton or not cameraButton.Visible then return false end
			local point, visible = camera:WorldToViewportPoint(actor:GetPivot().Position)
			local a = camera:WorldToViewportPoint(Vector3.new(-63, art.tileTop, 54))
			local b = camera:WorldToViewportPoint(Vector3.new(63, art.tileTop, 54))
			local title = printLayer.Cell1["Club name"]
			return visible and point.Y > camera.ViewportSize.Y * .18 and point.Y < camera.ViewportSize.Y * .81
				and math.abs(b.X - a.X) > camera.ViewportSize.X * 1.33
				and title.Visible and title.Rotation == 0 and title.TextFits
		end, "portrait turn close-up and horizontal type", 3)
		local input = assert(game:GetService("UserInputService"):CreateVirtualInput())
		local function toggleCamera()
			input:SendKey(true, Enum.KeyCode.V, false)
			task.wait(.06)
			input:SendKey(false, Enum.KeyCode.V, false)
		end
		local function span()
			local a = camera:WorldToViewportPoint(Vector3.new(-63, art.tileTop, 54))
			local b = camera:WorldToViewportPoint(Vector3.new(63, art.tileTop, 54))
			return math.abs(b.X - a.X) / camera.ViewportSize.X
		end
		local function settledView()
			local before = camera.CFrame.Position
			task.wait(.06)
			return (camera.CFrame.Position - before).Magnitude < 1.4
		end
		waitFor(settledView, "settled close-up", 2)
		capture("focused-board")
		task.wait(.24)
		toggleCamera()
		waitFor(function()
			if span() >= 1 or not settledView() then return false end
			for _, part in stage.Board:GetDescendants() do
				if part:IsA("BasePart") and part:GetAttribute("BoardIndex") then
					local _, shown = camera:WorldToViewportPoint(part.Position)
					if not shown then return false end
				end
			end
			return true
		end, "full board button and all tile centers", 2)
		capture("full-board")
		task.wait(.24)
		toggleCamera()
		waitFor(function() return span() > 1.33 end, "return to active turn", 2)
	end
	if verifyMatchday then
		waitFor(function()
			local music = game:GetService("SoundService")["Footbolapolia Music"]
			local score = music:FindFirstChild("Plug In and Party (match underscore)")
			return score and score.IsLoaded and score.IsPlaying and score.Volume > .90 and not music["Feel That Move"].IsPlaying
		end, "crossfade to match music")
	end
	local diceSeen, cardSeen, boardSeen = false, false, false
	local previous, captured = -1, {}
	local replaySeen = false
	local runSeen = false
	local expires = os.clock() + 42
	while snapshot.match.phase ~= "final" and os.clock() < expires do
		local s = snapshot.match
		local effects = workspace:FindFirstChild("LocalTablePieces")
		local replay = effects and effects["Motion effects"]:FindFirstChild("Matchday players")
		if verifyMatchday and replay and s.last.who == player.UserId and not replaySeen then
			replaySeen = true
			assert(s.last.kind == "goal" and s.last.amount == 140, "Expected a goal and its reward")
			waitFor(function() return not printLayer.Visible and camera.FieldOfView > art.boardFov + 2 end, "shot camera", 1)
			capture("strike")
			local ball = effects["Motion effects"]:FindFirstChild("Matchday ball")
			assert(ball and ball.PrimaryPart and replay:FindFirstChild("Goalkeeper") and replay:FindFirstChild("Striker"))
			local from = ball:GetPivot().Position
			local sounds = game:GetService("SoundService")["Footbolapolia Effects"]
			waitFor(function()
				return sounds.kick.IsLoaded and sounds.kick.IsPlaying and (ball:GetPivot().Position - from).Magnitude > 4
			end, "kick sound and moving ball", 1)
			waitFor(function()
				local burst = replay:FindFirstChild("Goal net burst")
				return sounds.goal.IsLoaded and sounds.goal.IsPlaying and sounds.goalMotif.IsLoaded and sounds.goalMotif.IsPlaying
					and replay:FindFirstChild("Matchday goal"):IsA("MeshPart") and burst and #burst:GetChildren() == 30
			end, "goal mesh, net burst and musical motif", 1)
			local ribbon = stage:FindFirstChild("Live stadium ribbon", true)
			waitFor(function() return ribbon and ribbon:FindFirstChild("Message", true).Text ~= "FOOTBOLAPOLIA" end, "live goal ribbon", 1)
			task.wait(.25)
			capture("goal")
			waitFor(function() return printLayer.Visible and math.abs(camera.FieldOfView - art.boardFov) < .1 end, "board camera restored", 3)
		end
		local moving = effects and effects["Motion effects"]:FindFirstChild("Travel shadow")
		if verifyMatchday and moving and s.motion.who == player.UserId and not runSeen then
			local roster = effects:FindFirstChild("Match pawns")
			local seat = nil
			for _, entry in s.seats do if entry.id == player.UserId then seat = entry; break end end
			local model = roster and seat and roster:FindFirstChild(board.figures[seat.figure].name)
			assert(model and model:FindFirstChild("Right knee") and model:FindFirstChild("Right elbow"), "Articulated figure missing")
			local knee, thigh = model["Right knee"], model["Right leg"]
			local prior = thigh:GetPivot():ToObjectSpace(knee:GetPivot())
			local at = model:GetPivot().Position
			waitFor(function()
				local relative = thigh:GetPivot():ToObjectSpace(knee:GetPivot())
				return (model:GetPivot().Position - at).Magnitude > 1 and relative.LookVector:Dot(prior.LookVector) < .995
			end, "moving knee and translated figure", 1)
			runSeen = true
			capture("run")
		end
		local dice = effects and effects["Motion effects"]:FindFirstChild("Dice roll")
		if dice and not diceSeen then
			diceSeen = true
			assert(#dice:GetChildren() == 2)
			if verifyMatchday then
				waitFor(function()
					local sound = game:GetService("SoundService")["Footbolapolia Effects"].dice
					return sound.IsLoaded and sound.IsPlaying
				end, "dice sound", 1)
			end
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
			if verifyMatchday then
				local scoreboard = hud.Viewport.Scoreboard
				local lowerRight = scoreboard.AbsolutePosition + scoreboard.AbsoluteSize
				for _, cell in printLayer:GetChildren() do
					local label = cell["Club name"]
					if not label.Visible then continue end
					local center = label.AbsolutePosition + label.AbsoluteSize * .5
					assert(center.Y > lowerRight.Y or center.X < scoreboard.AbsolutePosition.X or center.X > lowerRight.X,
						"Scoreboard obscures " .. label.Text)
				end
			end
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
	if verifyMatchday then assert(runSeen and replaySeen, "Missing run or Matchday replay") end
	assert(hud:FindFirstChild("Rank1", true), "Final table missing")
	print("TOUR_QA", workspace.CurrentCamera.ViewportSize, snapshot.match.rollSerial, snapshot.match.finishReason, cardSeen)
	if snapshot.host == player.UserId then
		dispatch("lobby")
		waitFor(function() return snapshot and not snapshot.match end, "return to lobby")
	end
end)
report:FireServer(if ok then "PASS" else "FAIL " .. tostring(err))
