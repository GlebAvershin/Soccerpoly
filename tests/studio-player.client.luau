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
	local printLayer = player.PlayerGui:WaitForChild("BoardPrint")
	waitFor(function() return #printLayer:GetChildren() == #board.tiles end, "all printed cards")
	local camera = waitFor(function()
		local current = workspace.CurrentCamera
		return current and current.CameraType == Enum.CameraType.Scriptable and current.ViewportSize.X > 2 and current
	end, "scriptable play camera", 8)
	local input = assert(game:GetService("UserInputService"):CreateVirtualInput())
	local function press(key)
		input:SendKey(true,key,false)
		task.wait(.08)
		input:SendKey(false,key,false)
	end
	local target = script:GetAttribute("Edition") or "en"
	local picker = hud.Viewport:WaitForChild("LanguagePicker")
	local sample = printLayer.Cell1["Printed programme"]["Club name"]
	assert(not picker.Visible and not hud.AutoLocalize and hud.Viewport.ChangeLanguage.Visible)
	assert(sample.Text=="Kickoff" and hud.Viewport.MatchPanel.Phase.Text=="SELECT A FIGURE","English first launch")
	local ground = stage["Arena surroundings"]["Stadium district"]
	local district = ground:WaitForChild("Matchday district",8)
	assert(district and district.Concourse.ImageContent.Object.Size==Vector2.new(1024,1024))
	assert(not ground.CanQuery and ground.Position.Y < printLayer.Cell1.Adornee.Position.Y)
	for _,lang in {if target=="ru" then "en" else "ru",target} do
		if not picker.Visible then press(Enum.KeyCode.L) end
		waitFor(function() return picker.Visible end,"language choice")
		press(if lang=="ru" then Enum.KeyCode.R else Enum.KeyCode.E)
		waitFor(function()
			return not picker.Visible and player:GetAttribute("TableLanguage")==lang
				and sample.Text==(if lang=="ru" then "Старт" else "Kickoff")
				and hud.Viewport.MatchPanel.Phase.Text==(if lang=="ru" then "ВЫБОР ФИГУРКИ" else "SELECT A FIGURE")
		end,"explicit language on board and HUD")
	end
	local function nonoverlapping(a,b)
		local ax,ay,aw,ah = a.Position.X.Scale,a.Position.Y.Scale,a.Size.X.Scale,a.Size.Y.Scale
		local bx,by,bw,bh = b.Position.X.Scale,b.Position.Y.Scale,b.Size.X.Scale,b.Size.Y.Scale
		return ax+aw <= bx+.0001 or bx+bw <= ax+.0001 or ay+ah <= by+.0001 or by+bh <= ay+.0001
	end
	local function verifyPrint()
		for index,tile in board.tiles do
			local cell=printLayer["Cell"..index]
			assert(cell.Adornee:GetAttribute("BoardIndex")==index and not cell.AlwaysOnTop and not cell.AutoLocalize)
			local paper=cell["Printed programme"]
			local poster,title,cost=paper["Art window"],paper["Club name"],paper["Club cost"]
			local nativeWindow = player.PlayerGui["Programme typography"][cell.Name]["Art window"]
			local mount = poster:FindFirstChild("Lithograph mount") or nativeWindow:FindFirstChild("Lithograph mount")
			assert(mount and mount:FindFirstChild("Lithograph"), "Missing illustrated print "..tile.name)
			assert((#nativeWindow:GetChildren() + #poster:GetChildren()) == 1,"Duplicate or missing illustration on "..cell.Name)
			assert(nativeWindow.Visible == (mount.Parent==nativeWindow),"Visible window has the wrong illustration "..cell.Name)
			assert(title:IsA("TextLabel") and title.Text ~= "" and title.TextFits, "Clipped title "..title.Text)
			assert(cell.CanvasSize.X >= cell.Adornee.Size.X*22-1)
			assert(title.FontFace.Family:find("RobotoCondensed") and cost.FontFace.Family:find("/Roboto.json",1,true))
			assert(poster.Size.Y.Scale >= .10 and poster.Size.Y.Scale<=title.Position.Y.Scale and title.Position.Y.Scale+title.Size.Y.Scale<=1.00001 and not title.Text:find("\n"))
			local display=player.PlayerGui["Programme typography"]
			assert(display.DisplayOrder<hud.DisplayOrder and display.ScreenInsets==Enum.ScreenInsets.DeviceSafeInsets)
			local ink=display[cell.Name]["Club name"]
			assert(nonoverlapping(poster,title), "Art overlaps club name on "..cell.Name)
			assert(ink.Text==title.Text and ink.TextScaled)
			if tile.league>0 then
				local badge=mount["Embroidered kit"]
				assert(badge.ImageContent.Object.Size==Vector2.new(256,256) and badge.SizeConstraint==Enum.SizeConstraint.RelativeYY)
			end
			if ink.Visible then
				local v=title.Position.Y.Scale+title.Size.Y.Scale*.5
				local at=camera:WorldToViewportPoint(cell.Adornee.Position+cell.Adornee.CFrame.UpVector*cell.Adornee.Size.Y*(.5-v))
				local middle=ink.AbsolutePosition-display[cell.Name].AbsolutePosition+ink.AbsoluteSize*.5
				assert(math.abs(middle.X-at.X)<4 and math.abs(middle.Y-at.Y)<4 and ink.TextFits,
					"Title registration "..cell.Name.." centre="..tostring(middle).." expected="..tostring(at).." fits="..tostring(ink.TextFits))
				assert(not title.Visible,"Double print on "..cell.Name)
			end

			if tile.price>0 then
				assert(nonoverlapping(title,cost) and nonoverlapping(poster,cost) and cost.TextFits and cost.Text~="",
					"Price overlaps a different print region on "..cell.Name)
				assert(cost.Position.Y.Scale+cost.Size.Y.Scale<=1.00001,"Price outside card "..cell.Name)
			end
		end
	end
	verifyPrint()
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
				if not (head and head:IsA("MeshPart") and head:GetAttribute("PaintedAtlas")
					and jersey and jersey:IsA("MeshPart") and jersey:GetAttribute("PaintedAtlas")
					and figure:FindFirstChild("Ribbed sock",true):IsA("MeshPart")) then return false end
				for _, side in {"Left elbow", "Right elbow"} do
					local elbow = figure:FindFirstChild(side)
					local palm = elbow and elbow:FindFirstChild("Palm")
					local forearm = elbow and elbow:FindFirstChild("Bent forearm")
					if not (palm and palm:IsA("MeshPart") and forearm and forearm:IsA("MeshPart")) then return false end
					if (forearm.Position - palm.Position).Magnitude < forearm.Size.Y * .50 then return false end
				end
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
			local music = game:GetService("SoundService"):FindFirstChild("Soccerpoly Music")
			local sound = music and music:FindFirstChild("Feel That Move")
			return sound and sound.IsLoaded and sound.IsPlaying
		end, "music")
	end
	if verifyMatchday then
		waitFor(function()
			local enamel = stage.Board:FindFirstChild("Porcelain face", true)
			local sole = hud:FindFirstChild("Molded outsole", true)
			local plinth = stage.Board:FindFirstChild("Octagonal arena plinth")
			local seal = stage:FindFirstChild("Cup seal", true)
			local deck = printLayer.Cell5:FindFirstChild("Lithograph",true) or player.PlayerGui["Programme typography"].Cell5:FindFirstChild("Lithograph",true)
			return deck and deck:IsA("ImageLabel") and enamel and enamel:IsA("MeshPart") and sole and sole:IsA("MeshPart")
				and plinth and plinth:IsA("MeshPart") and seal and seal:IsA("BasePart")
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
	if verifyMatchday then
		for _,lang in {if target=="ru" then "en" else "ru",target} do
			press(Enum.KeyCode.L)
			waitFor(function() return picker.Visible end,"in-match language settings")
			press(if lang=="ru" then Enum.KeyCode.R else Enum.KeyCode.E)
			waitFor(function()
				return player:GetAttribute("TableLanguage")==lang and sample.Text==(if lang=="ru" then "Старт" else "Kickoff")
					and hud.Viewport.Scoreboard.Seat1.PlayerName.Text==(if lang=="ru" then "Ты" else "You")
			end,"in-match language on board and scoreboard")
		end
	end
	local function onCell(index: number, point: Vector3, margin: number): boolean
		local face = printLayer["Cell"..index].Adornee
		local localPoint = face.CFrame:PointToObjectSpace(point)
		return math.abs(localPoint.X) <= face.Size.X*.5+margin and math.abs(localPoint.Y) <= face.Size.Y*.5+margin
	end
	if verifyMatchday then
		local inactive = snapshot.match.seats[(snapshot.match.active % #snapshot.match.seats)+1]
		local figures = workspace.LocalTablePieces["Match pawns"]
		local resting = figures:WaitForChild(board.figures[inactive.figure].name)
		for _, seat in snapshot.match.seats do
			local pawn = figures:WaitForChild(board.figures[seat.figure].name)
			assert(onCell(seat.position,pawn:GetPivot().Position,0),"Kickoff figure outside its printed tile")
		end
		local face = resting.Head.Face
		local at = resting:GetPivot()
		local before = at:ToObjectSpace(face.CFrame)
		waitFor(function()
			local current = resting:GetPivot():ToObjectSpace(face.CFrame)
			return (current.Position-before.Position).Magnitude > .025 or current.LookVector:Dot(before.LookVector) < .9998
		end,"idle pose on a waiting figure",2)
		assert((at.Position-resting:GetPivot().Position).Magnitude < .01,"Waiting figure slid off its cell")
	end
	local function verifyOverview()
		local display = player.PlayerGui["Programme typography"]
		local minName, minPrice = math.huge, math.huge
		local base = stage.Board["Octagonal arena plinth"]
		for _, x in {-1,1} do
			for _, z in {-1,1} do
				local _, visible = camera:WorldToViewportPoint(base.Position + Vector3.new(x*base.Size.X*.5,0,z*base.Size.Z*.5))
				assert(visible,"Cropped board base")
			end
		end
		for index, tile in board.tiles do
			local part = printLayer["Cell"..index].Adornee
			for _, x in {-1,1} do
				for _, y in {-1,1} do
					local corner = part.CFrame * Vector3.new(x*part.Size.X*.5,y*part.Size.Y*.5,0)
					local _, visible = camera:WorldToViewportPoint(corner)
					assert(visible,"Clipped overview corner: "..tile.name)
				end
			end
			if tile.price == 0 then continue end
			local cell = display["Cell"..index]
			local name, cost = cell["Club name"], cell["Club cost"]
			assert(name.TextFits and cost.TextFits and not name.Text:find("\n"),tile.name)
			local paper = printLayer["Cell"..index]["Printed programme"]
			assert(name.Visible ~= paper["Club name"].Visible and cost.Visible ~= paper["Club cost"].Visible,
				"Missing or double-printed overview label: "..tile.name)
			if index == 11 or index == 26 then
				local russian = player:GetAttribute("TableLanguage") == "ru"
				local expectedName = if index==11 then (if russian then "Ливерпуль" else "Liverpool")
					else (if russian then "Дортмунд" else "Dortmund")
				assert(name.Visible and name.Text==expectedName, "Missing single-line club name: "..name.Text)
			end
			minName, minPrice = math.min(minName,name.TextBounds.Y), math.min(minPrice,cost.TextBounds.Y)
		end
		print("OVERVIEW_TYPE",camera.ViewportSize,minName,minPrice)
		local shortEdge = math.min(camera.ViewportSize.X,camera.ViewportSize.Y)
		assert(minName >= math.floor(shortEdge*.022) and minPrice >= math.floor(shortEdge*.03),
			"Overview name or price too small")
	end
	if closeup and hud.Viewport.AbsoluteSize.Y < 430 and camera.ViewportSize.X > camera.ViewportSize.Y then
		verifyOverview()
	end
	if closeup and camera.ViewportSize.X < camera.ViewportSize.Y * .86 then
		local cameraButton = hud.Viewport:FindFirstChild("BoardCamera")
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
		waitFor(function()
			return span() < 1 and settledView()
		end, "default portrait overview", 2)
		verifyPrint()
		verifyOverview()
		capture("full-board")
		task.wait(.24)
		local caption = player.PlayerGui["Programme typography"].Cell11["Club name"]
		local function click(control)
			local position = control.AbsolutePosition+control.AbsoluteSize*.5
			-- VirtualInput expects the whole device screen, including the notch.
			position -= game:GetService("GuiService"):GetInsetArea(Enum.ScreenInsets.None).Min
			input:SendMouseButton(position,Enum.UserInputType.MouseButton1,true,0)
			task.wait(.04)
			input:SendMouseButton(position,Enum.UserInputType.MouseButton1,false,0)
		end
		click(caption)
		local backdrop = hud.Viewport.PropertyBackdrop
		waitFor(function()
			local header = backdrop:FindFirstChild("Club header",true)
			local title = header and header:FindFirstChildWhichIsA("TextLabel")
			return backdrop.Visible and title and title.Text:find(caption.Text,1,true)
		end,"inspect Liverpool on its own tile",2)
		click(backdrop:FindFirstChild("CloseCard",true))
		waitFor(function() return not backdrop.Visible end,"close club inspection",2)
		toggleCamera()
		waitFor(function()
			local active = snapshot.match.seats[snapshot.match.active]
			local pieces = workspace:FindFirstChild("LocalTablePieces")
			local figures = pieces and pieces:FindFirstChild("Match pawns")
			local actor = figures and figures:FindFirstChild(board.figures[active.figure].name)
			if not actor or not cameraButton or not cameraButton.Visible then return false end
			local point, visible = camera:WorldToViewportPoint(actor:GetPivot().Position)
			local a = camera:WorldToViewportPoint(Vector3.new(-63, art.tileTop, 54))
			local b = camera:WorldToViewportPoint(Vector3.new(63, art.tileTop, 54))
			local title = printLayer.Cell1["Printed programme"]["Club name"]
			return visible and point.Y > camera.ViewportSize.Y * .18 and point.Y < camera.ViewportSize.Y * .81
				and math.abs(b.X - a.X) > camera.ViewportSize.X * 1.33
				and printLayer.Cell1.Enabled and title.TextFits
		end, "portrait turn close-up and horizontal type", 3)
		waitFor(settledView, "settled close-up", 2)
		verifyPrint()
		capture("focused-board")
		task.wait(.24)
		toggleCamera()
		waitFor(function() return span() < 1 and settledView() end, "return to overview", 2)
	end
	if verifyMatchday then
		waitFor(function()
			local music = game:GetService("SoundService")["Soccerpoly Music"]
			local score = music:FindFirstChild("Plug In and Party (match underscore)")
			return score and score.IsLoaded and score.IsPlaying and score.Volume > .90 and not music["Feel That Move"].IsPlaying
		end, "crossfade to match music")
	end
	local diceSeen, cardSeen, boardSeen = false, false, false
	local shotResult = script:GetAttribute("ExpectedShot") or "goal"
	local previous, captured = -1, {}
	local trackFrames, checkedLandings = 0, 0
	local leftTrack = false
	local movementCheck
	if verifyMatchday then
		movementCheck = game:GetService("RunService").RenderStepped:Connect(function()
			local pieces = workspace:FindFirstChild("LocalTablePieces")
			local figures = pieces and pieces:FindFirstChild("Match pawns")
			local motion = snapshot.match and snapshot.match.motion
			if not figures or not motion or not pieces["Motion effects"]:FindFirstChild("Travel shadow") then return end
			for _, seat in snapshot.match.seats do
				if seat.id ~= motion.who then continue end
				local pawn = figures:FindFirstChild(board.figures[seat.figure].name)
				if not pawn then return end
				local point = pawn:GetPivot().Position
				trackFrames += 1
				for step = 0,motion.steps do
					local index = (motion.from-1+step) % #board.tiles+1
					-- The printed face is inset by .55 studs from the centre of the seam.
					if onCell(index,point,.56) then return end
				end
				leftTrack = true
			end
		end)
	end
	local replaySeen = false
	local runSeen = false
	local expires = os.clock() + 42
	while snapshot.match.phase ~= "final" and os.clock() < expires do
		local s = snapshot.match
		local effects = workspace:FindFirstChild("LocalTablePieces")
		local replay = effects and effects["Motion effects"]:FindFirstChild("Matchday players")
		if verifyMatchday and replay and s.last.who == player.UserId and not replaySeen then
			replaySeen = true
			assert(s.last.kind == shotResult and s.last.amount == ({goal=140,save=25,offside=-40})[shotResult], "Shot outcome and award")
			waitFor(function() return not printLayer.Cell1.Enabled and camera.FieldOfView > art.boardFov + 2 end, "shot camera", 1)
			capture("strike")
			local ball = effects["Motion effects"]:FindFirstChild("Matchday ball")
			assert(ball and ball.PrimaryPart and replay:FindFirstChild("Goalkeeper") and replay:FindFirstChild("Striker"))
			local from = ball:GetPivot().Position
			local sounds = game:GetService("SoundService")["Soccerpoly Effects"]
			waitFor(function()
				return sounds.kick.IsLoaded and sounds.kick.IsPlaying and (ball:GetPivot().Position - from).Magnitude > 4
			end, "kick sound and moving ball", 1)
			waitFor(function()
				local feedback = if shotResult=="offside" then true
					else replay:FindFirstChild(if shotResult=="save" then "Glove impact" else "Goal net burst")
				return sounds[shotResult].IsLoaded and sounds[shotResult].IsPlaying and feedback
					and replay:FindFirstChild("Matchday goal"):IsA("MeshPart")
			end, "shot impact, frame and outcome cue", 1.5)
			task.wait(.09)
			capture(shotResult)
			waitFor(function() return printLayer.Cell1.Enabled and math.abs(camera.FieldOfView - art.boardFov) < .1 end, "board camera restored", 3)
		end
		local dice = effects and effects["Motion effects"]:FindFirstChild("Dice roll")
		if dice and not diceSeen then
			diceSeen = true
			assert(#dice:GetChildren() == 2)
			if verifyMatchday then
				waitFor(function()
					local sound = game:GetService("SoundService")["Soccerpoly Effects"].dice
					return sound.IsLoaded and sound.IsPlaying
				end, "dice sound", 1)
			end
			capture("dice")
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
			local strideDistance = if s.motion.steps > 1 then 13 else 2
			waitFor(function()
				local relative = thigh:GetPivot():ToObjectSpace(knee:GetPivot())
				return (model:GetPivot().Position - at).Magnitude > strideDistance and relative.LookVector:Dot(prior.LookVector) < .995
			end, "moving knee and translated figure", 1)
			local head = model.Head.Face
			local top, visibleHead = camera:WorldToViewportPoint(head.Position)
			local foot, visibleFeet = camera:WorldToViewportPoint(model:GetPivot().Position)
			assert(visibleHead and visibleFeet and foot.Y-top.Y > 10,"Running figure silhouette "..tostring(foot).." / "..tostring(top))
			assert(player.PlayerGui["Programme typography"]["Turn arrow"].Visible, "Active runner marker")
			runSeen = true
			capture("run")
		end
		local open = hud.Viewport.PropertyBackdrop.Visible
		if open and s.seats[s.active].id == player.UserId and (s.phase == "offer" or s.phase == "upgrade" or s.phase == "rebuy") then
			cardSeen = true
			local picture=hud.Viewport.PropertyBackdrop:FindFirstChild("Lithograph",true)
			assert(picture and picture.ImageContent.Object.Size==Vector2.new(768,307),"Missing high-resolution dossier")
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
				for _,cell in printLayer:GetChildren() do
					local point, shown = camera:WorldToViewportPoint(cell.Adornee.Position)
					if shown and (camera.ViewportSize.X >= camera.ViewportSize.Y or cell.Adornee:GetAttribute("BoardIndex")==s.seats[s.active].position) then
						point=camera:WorldToScreenPoint(cell.Adornee.Position)
						assert(point.Y < scoreboard.AbsolutePosition.Y or point.Y > lowerRight.Y or point.X < scoreboard.AbsolutePosition.X or point.X > lowerRight.X,
							"Scoreboard obscures "..cell.Name)
					end
				end
			end
			capture("table")
		end
		local current = snapshot
		-- Capturing a frame may yield across a bot turn or a new server phase.
		if current.match ~= s then continue end
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
			local picture=hud.Viewport.PropertyBackdrop:FindFirstChild("Lithograph",true)
			assert(picture and picture.ImageContent.Object.Size==Vector2.new(768,307),"Missing high-resolution dossier")
						task.wait(.36)
						capture("property")
						task.wait(.20)
					end
					if verifyMatchday then
						local pieces = workspace.LocalTablePieces
						local pawn = pieces["Match pawns"][board.figures[seat.figure].name]
						waitFor(function() return not pieces["Motion effects"]:FindFirstChild("Travel shadow") end,"finish on purchased cell",1)
						assert(onCell(seat.position,pawn:GetPivot().Position,0),"Runner stopped outside the offered club")
						checkedLandings += 1
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
	if movementCheck then
		movementCheck:Disconnect()
		assert(trackFrames > 0 and checkedLandings > 0 and not leftTrack,"Runner left the perimeter of the rolled cells")
		print("ON_TILE_FRAMES",trackFrames,"CLUB_LANDINGS",checkedLandings)
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
