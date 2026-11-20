--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local shared = ReplicatedStorage:WaitForChild("League")
local Board = require(shared.TourBoard)
local Geometry = require(shared.Geometry)
local Art = require(shared.Presentation)
local Game = require(shared.Rules).withBoard(Board, require(shared.EventCards))
local Pawn = require(script.Parent.Pawn)
local Meshes = require(script.Parent.MeshLibrary)
local rollDice = require(script.Parent.TableDice)
local BoardLabels = require(script.Parent.BoardLabels)
local MatchdayReplay = require(script.Parent.MatchdayReplay)
local UI = require(script.Parent.Components)
local Arena = {}
local TAU = math.pi * 2
local C = Color3.fromHex

local function part(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name, p.Size, p.Position, p.Color = name, size, position, color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored, p.CastShadow = true, false
	p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
	p.Parent = parent
	return p
end

local function medallion(parent: Instance, name: string, at: Vector3, width: number, height: number, color: Color3): Part
	local base = part(parent, name, Vector3.new(height, width, width), at, color)
	base.Shape = Enum.PartType.Cylinder
	base.CFrame *= CFrame.Angles(0, 0, math.pi / 2)
	return base
end

local function position(index: number, slot: number?, count: number?): Vector3
	local tile = Geometry.cells[index]
	local size = Geometry.tileSize(index)
	local sideways = math.floor((index - 1) / 8) % 2 == 0
	local width = if sideways then size.Y else size.X
	local depth = if sideways then size.X else size.Y
	local total, ordinal = count or 1, slot or 1
	local row = math.floor((ordinal-1)/2)
	local onRow = math.min(2,total-row*2)
	local col = (ordinal-1)%2
	-- Place the boots on the artwork. Two pairs share a corner at kickoff.
	local x = tile.X + (col-(onRow-1)*.5)*width*.43
	local depthOffset = if total <= 2 then .20 else .02+row*.32
	local z = tile.Z-depth*depthOffset
	return Vector3.new(x, Art.tileTop + .04 - Art.figureScale * .376, z)
end

local function settled(point: Vector3): CFrame
	return CFrame.new(point) * CFrame.Angles(0, math.rad(19), 0)
end

local function decorated(parent: Instance, name: string, shape: string, size: Vector3, at: Vector3, fallback: Instance, pop: boolean?)
	local marker = part(parent, name, size, at, Color3.new(1, 1, 1))
	marker.Transparency = 1
	marker:SetAttribute("MeshPlaceholder", true)
	if pop then marker:SetAttribute("PopIn", true) end
	Meshes.apply(shape, marker, {fallback})
end

local function clubStadium(parent: Folder, p: Vector3, level: number, color: Color3, index: number, pop: boolean?)
	local inside = CFrame.Angles(0, Geometry.tileYaw(index), 0):VectorToWorldSpace(Vector3.new(0, 0, -4))
	local x, z = p.X + inside.X, p.Z + inside.Z
	local fallback = Instance.new("Folder")
	fallback.Parent = parent
	local function stadiumPart(name: string, width: number, height: number, depth: number, px: number, y: number, pz: number, tint: Color3)
		return part(fallback, name, Vector3.new(width, height, depth), Vector3.new(px, y, pz), tint)
	end
	-- Team-colored glowing ownership plinth beneath every club build for instant visual ownership read
	local teamBase = part(parent, "Club team plinth", Vector3.new(3.9 + .22 * level, .10, 3.3 + .18 * level),
		Vector3.new(x, Art.tileTop + .05, z), color)
	teamBase.Material = Enum.Material.SmoothPlastic
	local shape, dims, height: number
	if level == 0 then
		shape = "club_flag"
		height = 2.15
		dims = Vector3.new(2.55, height, 2.12)
		stadiumPart("Flag plinth", 2.35, .26, 1.95, x, Art.tileTop + .18, z, Art.ink)
		stadiumPart("Flag pole", .14, 1.85, .14, x - .4, Art.tileTop + 1.05, z, Art.paper)
		stadiumPart("Flag pennant", 1.15, .56, .10, x + .18, Art.tileTop + 1.65, z, color)
	elseif level == 1 then
		shape = "academy"
		height = 1.48
		dims = Vector3.new(3.65, height, 3.00)
		stadiumPart("Stadium foundations", 3.1, .31, 2.6, x, .86, z, Art.ink)
		stadiumPart("Stadium pitch", 2.6, .12, 2.2, x, 1.06, z, Art.field)
		for _, side in {-1, 1} do
			stadiumPart("Terrace", .48, .50, 2.40, x + side * 1.22, 1.24, z, color)
		end
	elseif level == 2 then
		shape = "arena"
		height = 1.82
		dims = Vector3.new(4.15, height, 3.45)
		stadiumPart("Stadium foundations", 3.4, .31, 2.9, x, .86, z, Art.ink)
		stadiumPart("Stadium pitch", 2.6, .12, 2.4, x, 1.06, z, Art.field)
		for _, side in {-1, 1} do
			local px = x + side * 1.32
			stadiumPart("Terrace", .55, .78, 2.60, px, 1.35, z, color)
			stadiumPart("Stadium canopy", .75, .16, 2.75, px, 1.86, z, Art.paper)
		end
	else
		shape = "megastadium"
		height = 2.62
		dims = Vector3.new(4.65, height, 3.92)
		stadiumPart("Stadium foundations", 3.9, .36, 3.3, x, .88, z, Art.ink)
		stadiumPart("Stadium pitch", 2.6, .12, 2.2, x, 1.08, z, Art.field)
		for _, side in {-1, 1} do
			stadiumPart("Bowl wall", .62, 1.25, 3.10, x + side * 1.48, 1.56, z, color)
			stadiumPart("Bowl roof", .92, .18, 3.25, x + side * 1.32, 2.28, z, Art.paper)
		end
	end
	decorated(parent, "Club stadium", shape, dims, Vector3.new(x, Art.tileTop + height * .5 + .06, z), fallback, pop)
end

local function trophy(parent: Folder, at: Vector3, color: Color3)
	local fallback = Instance.new("Folder")
	fallback.Parent = parent
	medallion(parent, "Cup base", at + Vector3.yAxis * .15, 1.73, .20, color)
	medallion(fallback, "Cup stem", at + Vector3.yAxis * .66, .41, .70, Art.gold)
	medallion(fallback, "Continental Cup", at + Vector3.yAxis * 1.20, 1.08, .64, Art.gold)
	medallion(fallback, "Cup rim", at + Vector3.yAxis * 1.58, 1.20, .13, C("FFE595"))
	for _, side in {-1, 1} do
		local handle = part(fallback, "Cup handle", Vector3.new(.27, .47, .24), at + Vector3.new(side * .62, 1.32, 0), Art.gold)
		handle.CFrame *= CFrame.Angles(0, 0, side * .38)
	end
	decorated(parent, "Continental Cup", "cup", Vector3.new(1.98, 1.64, 1.27),
		at + Vector3.yAxis * .91, fallback)
end

type Flight = {model: Model, shadow: Part, start: number, from: number, steps: number, route: {Vector3},
	origin: Vector3, destination: Vector3, color: Color3, bounced: number}
local PREP, STEP, SETTLE, ROLL_LEAD = Art.runAnticipation, Art.runPerCell, Art.runBrake, Art.diceLead

function Arena.landingAfter(steps: number): number
	return Art.arrivalAfter(steps)
end

local function routeAt(route: {Vector3}, progress: number): Vector3
	if progress <= 0 then return route[1] end
	if progress >= #route - 1 then return route[#route] end
	local whole = math.floor(progress)
	local t = progress - whole
	local p0, p1, p2, p3 = route[math.max(1, whole)], route[whole + 1],
		route[whole + 2], route[math.min(#route, whole + 3)]
	-- Continuous tangent rounds corners without a rotational snap at a cell boundary.
	local m1 = (p2 - p0) * .46
	local m2 = (p3 - p1) * .46
	local square, cube = t * t, t * t * t
	return p1 * (2 * cube - 3 * square + 1) + m1 * (cube - 2 * square + t)
		+ p2 * (-2 * cube + 3 * square) + m2 * (cube - square)
end

function Arena.new(myId: number, root: Frame, translate: (string, ...any) -> string, playSound: (string) -> ())
	local localPlayer = game:GetService("Players").LocalPlayer
	local labels = BoardLabels(root, translate)
	local ribbonText: TextLabel? = nil
	local ribbonVersion = 0
	local displaySnapshot: any = nil
	local updateDisplay: ((any)->())? = nil
	task.defer(function()
		local stage = workspace:WaitForChild("WorldDraftArena", 12)
		if not stage then return end
		local screen = stage:FindFirstChild("JumbotronDisplay", true)
		if screen and screen:IsA("SurfaceGui") then
			local mounted = require(script.Parent.StadiumDisplay)(screen, translate)
			updateDisplay = mounted
			mounted(displaySnapshot)
		end
		Meshes.decorate(stage)
		require(script.Parent.PitchSurface)(stage:WaitForChild("Continental Cup stadium"))
		require(script.Parent.StadiumDistrict)(stage:WaitForChild("Arena surroundings"):WaitForChild("Stadium district"))
		local ribbon = stage:FindFirstChild("Live stadium ribbon", true)
		local message = ribbon and ribbon:FindFirstChild("Message", true)
		if message and message:IsA("TextLabel") then ribbonText = message end
	end)
	local localParts = Instance.new("Folder")
	localParts.Name, localParts.Parent = "LocalTablePieces", workspace
	local matchPawns = Instance.new("Folder")
	matchPawns.Name, matchPawns.Parent = "Match pawns", localParts
	local markers = Instance.new("Folder")
	markers.Name, markers.Parent = "Markers", localParts
	local effects = Instance.new("Folder")
	effects.Name, effects.Parent = "Motion effects", localParts
	-- Sleek glowing team-colored turn aura pedestal instead of jagged pixel Highlight outlines
	local turnAura = medallion(localParts, "Active turn aura", Vector3.new(0, -50, 0), 4.0, .045, Art.mint)
	turnAura.Material, turnAura.Transparency = Enum.Material.Neon, 1
	local turnAuraRing = medallion(localParts, "Active turn ring", Vector3.new(0, -50, 0), 4.8, .03, Art.ink)
	turnAuraRing.Transparency = 1
	local replay = MatchdayReplay(effects, playSound)
	local replaying = false

	local models: {[number]: Model} = {}
	local activeId = 0
	local activeTeamColor = Art.mint
	local cheerId, cheerUntil = 0, 0
	local lastMatchState: any = nil
	local lastFinalConfetti = 0
	local celebrate: (number, boolean) -> ()
	local previews: {Model} = {}
	local heroModel: Model? = nil
	local portraitModel: Model? = nil
	local heroFigure = 0
	local serial, lastMotion, lastRoll = -1, 0, 0
	local signature = ""
	local prevLevels: {[number]: number} = {}
	local activeFlight: Flight? = nil
	type Warp = {model: Model, start: number, origin: Vector3, destination: Vector3, color: Color3}
	local activeWarp: Warp? = nil
	local reduced = GuiService.ReducedMotionEnabled
	local oldSize: Vector2? = nil
	local oldRoot: Vector2? = nil
	local overview: CFrame? = nil
	local portraitCamera = false
	local shortLandscape = false
	local followTurn = false
	local focusOrbit = Vector3.zero
	local focusDistance = 0
	local overviewDistance, viewDistance = 0,0
	local viewPoint: Vector3? = nil
	local boardPose: CFrame? = nil
	local lastInkPose: CFrame? = nil
	local lastInkTime = 0

	local userYaw, userPitch, userZoom = 0, 0, 1.0
	local targetYaw, targetPitch, targetZoom = 0, 0, 1.0
	local isDragging = false
	local dragStartPos = Vector2.zero

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.Touch then
			isDragging = true
			dragStartPos = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.Touch then
			isDragging = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local currentPos = Vector2.new(input.Position.X, input.Position.Y)
			local delta = currentPos - dragStartPos
			dragStartPos = currentPos
			targetYaw += delta.X * 0.0055
			targetPitch = math.clamp(targetPitch + delta.Y * 0.0045, -0.28, 0.40)
		elseif not gameProcessed and input.UserInputType == Enum.UserInputType.MouseWheel then
			targetZoom = math.clamp(targetZoom - input.Position.Z * 0.08, 0.65, 1.45)
		end
	end)

	local EMOTE_MAP: {[string]: {icon: string, label: string}} = {
		goal = {icon = "⚽", label = "GOAL!"},
		fire = {icon = "🔥", label = "ON FIRE!"},
		trophy = {icon = "🏆", label = "CHAMPION!"},
		gg = {icon = "👏", label = "RESPECT!"},
		shock = {icon = "😱", label = "UNBELIEVABLE!"},
		laugh = {icon = "😂", label = "LOL!"},
	}

	local function showPawnEmote(userId: number, emoteId: string)
		local model = models[userId]
		if not model then return end
		local info = EMOTE_MAP[emoteId] or {icon = "⚽", label = "LET'S GO!"}
		local head = model:FindFirstChild("Head") or model.PrimaryPart
		local headPos = if head and head:IsA("BasePart") then head.Position else model:GetPivot().Position

		local bubbleAtt = Instance.new("Attachment")
		bubbleAtt.Position = headPos + Vector3.new(0, 3.2, 0)
		bubbleAtt.Parent = workspace.Terrain

		local bb = Instance.new("BillboardGui")
		bb.Name = "PawnEmoteBubble"
		bb.Size = UDim2.fromOffset(140, 44)
		bb.StudsOffset = Vector3.new(0, 0.4, 0)
		bb.AlwaysOnTop = true
		bb.MaxDistance = 160
		bb.Adornee = bubbleAtt
		bb.Parent = bubbleAtt

		local pill = Instance.new("Frame")
		pill.Size = UDim2.fromScale(1, 1)
		pill.BackgroundColor3 = Color3.fromHex("121820")
		pill.BorderSizePixel = 0
		pill.Parent = bb
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = pill
		local stroke = Instance.new("UIStroke")
		stroke.Color = Art.gold
		stroke.Thickness = 2
		stroke.Parent = pill

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = info.icon .. " " .. info.label
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Font = Enum.Font.BuilderSansExtraBold
		label.TextSize = 18
		label.Parent = pill

		playSound("select")

		task.spawn(function()
			local start = os.clock()
			while os.clock() - start < 2.2 do
				local elapsed = os.clock() - start
				local t = elapsed / 2.2
				local curPos = if head and head:IsA("BasePart") and head.Parent then head.Position else headPos
				bubbleAtt.Position = curPos + Vector3.new(0, 3.2 + math.sin(t * math.pi) * 0.35 + t * 0.7, 0)
				if t > 0.75 then
					local alpha = (t - 0.75) / 0.25
					pill.BackgroundTransparency = alpha
					stroke.Transparency = alpha
					label.TextTransparency = alpha
				end
				RunService.RenderStepped:Wait()
			end
			bubbleAtt:Destroy()
		end)
	end

	task.spawn(function()
		local wd = ReplicatedStorage:WaitForChild("WorldDraft", 8)
		local emoteNet = if wd then wd:WaitForChild("EmoteAction", 8) :: RemoteEvent? else nil
		if emoteNet and emoteNet:IsA("RemoteEvent") then
			emoteNet.OnClientEvent:Connect(function(userId, emoteId)
				showPawnEmote(userId, emoteId)
			end)
		end
	end)

	local function finishFlight()
		local flight = activeFlight
		if not flight then return end
		flight.model:PivotTo(settled(flight.destination))
		Pawn.pose(flight.model, 0, 0)
		flight.shadow:Destroy()
		activeFlight = nil
	end

	local function layout(camera: Camera)
		local size = camera.ViewportSize
		local aspect = size.X / size.Y
		local fov = Art.boardFov
		local tangent = math.tan(math.rad(fov) * .5)
		portraitCamera = aspect < .86
		shortLandscape = aspect > 1 and root.AbsoluteSize.Y < 430
		local angle = math.rad(if portraitCamera then 63 elseif shortLandscape then 42 else 40)
		local orbit = Vector3.zAxis * math.cos(angle) + Vector3.yAxis * math.sin(angle)
		local span = Geometry.width
		local width = .85
		local height = if size.Y < 550 then .60 else .718
		local distance = math.max(span / (2 * tangent * aspect * width), span * math.sin(angle) / (2 * tangent * height))
		local verticalOffset = 0
		if portraitCamera or shortLandscape then
			-- Fit the near corners, with four logical pixels clear on either side.
			local widthPixels = math.max(1, math.min(root.AbsoluteSize.X,size.X) - (if shortLandscape then 208 else 8))
			local heightPixels = if shortLandscape then math.max(1,size.Y-16)
				else math.max(size.Y*.39,root.AbsoluteSize.Y-224)
			-- Studio devices can render behind a notch; measure the actual projection.
			camera.FieldOfView = fov
			local basis = camera.CFrame
			local origin = camera:WorldToViewportPoint(basis * Vector3.new(0,0,-100))
			local right = camera:WorldToViewportPoint(basis * Vector3.new(10,0,-100))
			local focalLength = (right.X-origin.X)*10
			if shortLandscape then
				verticalOffset = (size.Y*.5-origin.Y)/focalLength
			end
			local extent = Art.plinthWidth
			local trackWidth = if shortLandscape then span else extent
			distance = math.max(trackWidth*focalLength/widthPixels,extent*math.sin(angle)*focalLength/heightPixels)
				+ extent*.5*math.cos(angle) + Art.tileTop*math.sin(angle)
		end
		if not portraitCamera and not shortLandscape then
			-- Reserve the score strip above the north touchline and the roll control below.
			local sample = camera.CFrame * Vector3.new(0,0,-100)
			camera.FieldOfView = fov
			local origin = camera:WorldToViewportPoint(sample)
			local edge = camera:WorldToViewportPoint(sample + camera.CFrame.RightVector*10)
			local focal = (edge.X-origin.X)*10
			local topInset = origin.Y-camera:WorldToScreenPoint(sample).Y
			local boardTop = topInset + (if root.AbsoluteSize.X >= 1040 then 8 else 41) + 58 + 9
			local boardBottom = size.Y-65
			local usableHeight = math.max(1,boardBottom-boardTop)
			local usableWidth = math.max(1,root.AbsoluteSize.X-116)
			distance = math.max(span*focal/usableWidth,span*math.sin(angle)*focal/usableHeight)
				+ span*.5*math.cos(angle) + Art.tileTop*math.sin(angle)
			verticalOffset = ((boardTop+boardBottom)*.5-origin.Y)/focal
		end
		local base = CFrame.lookAt(orbit * distance, Vector3.zero)
		local half = Geometry.width * .5
		local near = base:PointToObjectSpace(Vector3.new(half, Art.tileTop, half))
		local far = base:PointToObjectSpace(Vector3.new(-half, Art.tileTop, -half))
		local centerY = (near.Y / -near.Z + far.Y / -far.Z) * .5
		local targetY = if shortLandscape then 0 elseif portraitCamera then -.010 else 0
		overview = base * CFrame.new(0, (centerY + verticalOffset - targetY * tangent) * distance, 0)
		local followAngle = math.rad(34)
		focusOrbit = Vector3.zAxis * math.cos(followAngle) + Vector3.yAxis * math.sin(followAngle)
		focusDistance = span / (2*tangent*aspect*.86) * (if portraitCamera then .25 else .48)
		boardPose, viewPoint, overviewDistance = nil, nil, distance
		oldSize, oldRoot, camera.FieldOfView = size, root.AbsoluteSize, fov
	end

	local function focusedBoard(): CFrame?
		if lastMatchState and lastMatchState.phase == "final" then
			local target = Vector3.new(0, Art.tileTop + 3.0, 0)
			return CFrame.lookAt(target + focusOrbit * (focusDistance * 1.12), target)
		end
		local flight = activeFlight
		local pawn = if flight then flight.model else models[activeId]
		if not (followTurn and pawn) then return nil end
		local at = pawn:GetPivot().Position
		if flight then
			local progress = (os.clock()-flight.start-PREP)/STEP
			at = at:Lerp(routeAt(flight.route,progress+.55),.32)
		end
		local target = Vector3.new(at.X*.88,Art.tileTop+5.5,at.Z*.88)
		return CFrame.lookAt(target + focusOrbit * focusDistance, target)
	end

	local function pulse(at: Vector3, color: Color3, impact: boolean)
		if reduced then return end
		local glow = medallion(effects, "Landing pulse", Vector3.new(at.X, Art.tileTop + .038, at.Z), 1.2, .032, color)
		glow.Material, glow.Transparency = Enum.Material.Neon, if impact then .22 else .55
		local reach = if impact then 7.2 else 3.2
		TweenService:Create(glow, TweenInfo.new(if impact then .34 else .17, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Size = Vector3.new(.025, reach, reach), Transparency = 1}):Play()
		Debris:AddItem(glow, .38)

		if impact then
			local core = medallion(effects, "Impact Core", Vector3.new(at.X, Art.tileTop + .042, at.Z), 0.8, .035, Art.gold)
			core.Material, core.Transparency = Enum.Material.Neon, 0.1
			TweenService:Create(core, TweenInfo.new(.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{Size = Vector3.new(.025, 4.0, 4.0), Transparency = 1}):Play()
			Debris:AddItem(core, .25)

			for i = 1, 8 do
				local a = i * math.pi / 4
				local spark = medallion(effects, "StepSpark", Vector3.new(at.X, Art.tileTop + 0.05, at.Z), 0.38, 0.02, Art.gold)
				spark.Material = Enum.Material.Neon
				local endPos = at + Vector3.new(math.cos(a) * 2.6, 0.05, math.sin(a) * 2.6)
				TweenService:Create(spark, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Position = endPos,
					Size = Vector3.new(0.01, 0.08, 0.08),
					Transparency = 1,
				}):Play()
				Debris:AddItem(spark, 0.30)
			end
		end
	end

	local function flashTile(index: number, color: Color3)
		if reduced then return end
		local arenaStage = workspace:FindFirstChild("WorldDraftArena")
		local board = if arenaStage then arenaStage:FindFirstChild("Board") else nil
		if not board then return end
		local children = board:GetChildren()
		local cell = children[index]
		if not cell then return end
		local face = cell:FindFirstChild("Porcelain face")
		if face and face:IsA("BasePart") then
			local original = face.Color
			face.Color = color:Lerp(Color3.new(1, 1, 1), 0.4)
			TweenService:Create(face, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Color = original
			}):Play()
		end
	end

	local function markDestination(index: number, color: Color3)
		if reduced then return end
		local tile = Geometry.cells[index]
		local size = Geometry.tileSize(index)
		local pose = CFrame.new(tile.X, Art.tileTop + .075, tile.Z) * CFrame.Angles(0, Geometry.tileYaw(index), 0)
		for _, x in {-1, 1} do
			for _, z in {-1, 1} do
				local corner = pose * CFrame.new(x * (size.X * .5 - .42), 0, z * (size.Y * .5 - .42))
				for _, horizontal in {true, false} do
					local offset = if horizontal then Vector3.new(-x * .92, 0, 0) else Vector3.new(0, 0, -z * .92)
					local dimensions = if horizontal then Vector3.new(1.98, .047, .21) else Vector3.new(.21, .047, 1.98)
					local mark = part(effects, "Tile arrival light", dimensions, Vector3.zero, color, Enum.Material.Neon)
					mark.CFrame = corner * CFrame.new(offset)
					mark.Transparency = .14
					TweenService:Create(mark, TweenInfo.new(.47, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
						{Transparency = 1}):Play()
					Debris:AddItem(mark, .49)
				end
			end
		end
	end

	local function spawnUpgradeEffect(parent: Folder, p: Vector3, color: Color3)
		local emitterAtt = Instance.new("Attachment")
		emitterAtt.Position = Vector3.new(p.X, Art.tileTop + 1.2, p.Z)
		emitterAtt.Parent = parent

		local sparks = Instance.new("ParticleEmitter")
		sparks.Name = "BuildSparks"
		sparks.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Art.gold),
			ColorSequenceKeypoint.new(0.5, color),
			ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
		})
		sparks.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.4),
			NumberSequenceKeypoint.new(0.6, 0.7),
			NumberSequenceKeypoint.new(1, 0),
		})
		sparks.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.7, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparks.Speed = NumberRange.new(8, 16)
		sparks.SpreadAngle = Vector2.new(60, 60)
		sparks.Lifetime = NumberRange.new(0.5, 0.9)
		sparks.Rate = 0
		sparks.Parent = emitterAtt

		sparks:Emit(24)
		task.delay(1.0, function()
			emitterAtt:Destroy()
		end)
	end

	local function savedDecor(s: any)
		local bits = {}
		for i, club in s.clubs do
			if club.owner ~= 0 then table.insert(bits, i .. ":" .. club.owner .. "/" .. club.level .. "/" .. tostring(club.shield)) end
		end
		for _, seat in s.seats do table.insert(bits, seat.id .. "/" .. seat.figure .. "/" .. seat.trophies) end
		table.insert(bits, tostring(s.festival or 0))
		if s.phase == "final" then table.insert(bits,"final") end
		local key = table.concat(bits, "|")
		if key == signature then return end
		signature = key
		markers:ClearAllChildren()
		local colors: {[number]: Color3} = {}
		for slot, seat in s.seats do
			local color = Art.seatColors[slot] or Art.hex(Board.figures[seat.figure].color)
			colors[seat.id] = color
			if seat.trophies > 0 then trophy(markers, Vector3.new((slot - (#s.seats + 1) * .5) * 4.1, .43, 38.15), color) end
		end
		for i, club in s.clubs do
			local tag = if club.owner ~= 0 then club.owner * 10 + club.level else -1
			local changed = prevLevels[i] ~= nil and prevLevels[i] ~= tag and club.owner ~= 0
			if changed and prevLevels[i] ~= -1 and (prevLevels[i] % 10) < club.level then
				playSound("upgrade")
				if not reduced then
					spawnUpgradeEffect(effects, Geometry.cells[i], colors[club.owner] or Art.gold)
				end
			end
			prevLevels[i] = tag
			if club.owner ~= 0 then
				local p, color = Geometry.cells[i], colors[club.owner]

				if Board.tiles[i].league > 0 then clubStadium(markers, p, club.level, color, i, changed and not reduced) end
				if s.festival == i then trophy(markers, Vector3.new(p.X, Art.tileTop, p.Z) + Art.boardRight * 2.8, color) end
				if club.shield then
					local badge = part(markers, "Club protection", Vector3.new(2.42, .23, 2.64), p + Vector3.new(2.6, 1.7, 0), C("F4C65E"))
					badge.CFrame *= CFrame.Angles(1.37, 0, 0)
					Meshes.apply("crest", badge)
				end
			end
		end
		if s.phase == "final" then
			trophy(markers, Vector3.new(2.2, Art.tileTop, 1.4), Art.gold)
		end

	end

	local function sync(snapshot: any)
		displaySnapshot = snapshot
		if updateDisplay then updateDisplay(snapshot) end
		local s = snapshot.match
		lastMatchState = s
		labels.update(snapshot)
		if s == nil then
			replay.clear()
			activeId, cheerId = 0, 0
			finishFlight()
			effects:ClearAllChildren()
			signature = ""
			markers:ClearAllChildren()
			for id, model in models do model:Destroy(); models[id] = nil end
			if #previews == 0 then
				for i in Board.figures do
					local model = Pawn.make(i, localParts)
					model:ScaleTo(1.42)
					local at = Art.boardRight * ((i - 3.5) * 7.22) + Art.boardNear * 16.05 + Vector3.yAxis * .37
					model:PivotTo(settled(at))
					table.insert(previews, model)
				end
			end
			local chosen = 1
			for _, seat in snapshot.lobby do
				if seat.id == myId then chosen = seat.figure break end
			end
			if chosen ~= heroFigure or not heroModel then
				if heroModel then heroModel:Destroy() end
				local model = Pawn.make(chosen, localParts)
				model:ScaleTo(4.3)
				model:PivotTo(settled(Vector3.new(0, .36, -.90)))
				heroModel, heroFigure, lastIdlePose = model, chosen, -1
			end
			return
		end
		if heroModel then heroModel:Destroy(); heroModel = nil end
		for _, model in previews do model:Destroy() end
		table.clear(previews)
		local sameMatch = serial == snapshot.serial
		if not sameMatch then
			replay.clear()
			lastRoll = 0
			finishFlight()
			for id, model in models do model:Destroy(); models[id] = nil end
			signature = ""
		end
		local rolled = (s.rollSerial or 0) > lastRoll
		if sameMatch and rolled and s.diceA and s.diceB then
			rollDice(effects, s.diceA, s.diceB, reduced)
			if s.diceA == s.diceB then
				playSound("double")
			else
				playSound("dice")
			end
		end
		lastRoll = s.rollSerial or 0
		local moved = sameMatch and s.motion.serial > lastMotion
		if moved then finishFlight() end
		local tileCounts: {[number]: number} = {}
		local tileSlots: {[number]: number} = {}
		for _, seat in s.seats do
			if seat.bankrupt then continue end
			tileCounts[seat.position] = (tileCounts[seat.position] or 0) + 1
		end
		for _, seat in s.seats do
			local model = models[seat.id]
			if seat.bankrupt then
				if model then model:Destroy(); models[seat.id] = nil end
				continue
			end
			if not model then
				model = Pawn.make(seat.figure, matchPawns, true)
				model:ScaleTo(Art.figureScale)
				models[seat.id] = model
			end
			local slot = (tileSlots[seat.position] or 0) + 1
			tileSlots[seat.position] = slot
			local destination: Vector3
			if s.phase == "final" then
				local winnerId = s.winner or (s.standings and s.standings[1] and s.standings[1].id)
				if seat.id == winnerId then
					destination = Vector3.new(0, Art.tileTop, 0)
				else
					local rank = 2
					if s.standings then
						for r, rec in s.standings do
							if rec.id == seat.id then rank = r break end
						end
					end
					local angle = (rank - 2.5) * 0.55
					destination = Vector3.new(math.sin(angle) * 8.5, Art.tileTop, math.cos(angle) * 7.5 + 3.2)
				end
			else
				destination = position(seat.position, slot, tileCounts[seat.position])
			end
			local seatIdx = table.find(s.seats, seat) or 1
			local color = Art.seatColors[seatIdx] or Art.hex(Board.figures[seat.figure].color)
			if moved and s.motion.who == seat.id and s.motion.steps > 0 and not reduced and s.phase ~= "final" then
				local at = model:GetPivot().Position
				local shadow = medallion(effects, "Travel shadow", Vector3.new(at.X, Art.tileTop + .025, at.Z), 3.88, .022, Art.ink)
				shadow.Transparency = .62
				local route = {at}
				for i = 1, s.motion.steps - 1 do
					table.insert(route, position(Game.target(s.motion.from, i)))
				end
				table.insert(route, destination)
				activeFlight = {model = model, shadow = shadow, from = s.motion.from, steps = s.motion.steps, route = route,
					start = os.clock() + ROLL_LEAD, origin = at, destination = destination, color = color, bounced = 0}
			elseif moved and s.motion.who == seat.id and s.motion.warp and not reduced then
				local at = model:GetPivot().Position
				activeWarp = {model = model, start = os.clock(), origin = at, destination = destination, color = color}
				playSound("land")
			elseif not activeFlight or activeFlight.model ~= model then
				model:PivotTo(settled(destination))
			end
		end
		serial, lastMotion = snapshot.serial, s.motion.serial
		savedDecor(s)
		local active = s.seats[s.active]
		activeId = if s.phase == "final" then 0 else active.id
		activeTeamColor = if s.phase ~= "final" then (Art.seatColors[s.active] or Art.mint) else Art.mint
	end

	RunService:BindToRenderStep("WorldDraftCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local camera = workspace.CurrentCamera
		if not camera or camera.ViewportSize.X < 2 or camera.ViewportSize.Y < 2 then return end
		camera.CameraType = Enum.CameraType.Scriptable
		if oldSize ~= camera.ViewportSize or oldRoot ~= root.AbsoluteSize or not overview then layout(camera) end
		local entry = activeFlight
		local clock = os.clock()
		replay.step(clock, reduced)
		local runner = if entry then entry.model else (if activeWarp then activeWarp.model else models[activeId])
		local head = runner and runner:FindFirstChild("Head")
		local face = head and head:FindFirstChild("Face")
		local frame = replay.framing(camera)
		if runner and not frame then
			local rootAt = runner:GetPivot().Position
			local pulseAlpha = 0.5 + 0.5 * math.sin(clock * 5)
			local auraDiam = 3.8 + 0.45 * pulseAlpha
			local auraSkin = if activeId == myId and localPlayer then (localPlayer:GetAttribute("CareerEquippedAura") :: string?) else nil
			local auraColor = activeTeamColor
			local ringColor = activeTeamColor:Lerp(Art.ink, 0.45)
			if auraSkin == "flame_trail" then
				auraColor = Color3.fromHex("FF4500")
				ringColor = Color3.fromHex("FFA500")
			elseif auraSkin == "golden_radiance" then
				auraColor = Color3.fromHex("FFD700")
				ringColor = Color3.fromHex("FFF8DC")
			elseif auraSkin == "champions_halo" then
				auraColor = Color3.fromHex("FFDF00")
				ringColor = Color3.fromHex("FFE87C")
				auraDiam += 0.4 * math.cos(clock * 6)
			end
			turnAura.Position = Vector3.new(rootAt.X, Art.tileTop + 0.04, rootAt.Z)
			turnAura.Size = Vector3.new(0.04, auraDiam, auraDiam)
			turnAura.Color = auraColor
			turnAura.Transparency = if reduced then 0.5 else (0.24 + 0.22 * pulseAlpha)
			turnAuraRing.Position = Vector3.new(rootAt.X, Art.tileTop + 0.035, rootAt.Z)
			turnAuraRing.Size = Vector3.new(0.03, auraDiam + 0.8, auraDiam + 0.8)
			turnAuraRing.Color = ringColor
			turnAuraRing.Transparency = if reduced then 0.7 else (0.45 + 0.25 * pulseAlpha)
		else
			turnAura.Position = Vector3.new(0, -50, 0)
			turnAuraRing.Position = Vector3.new(0, -50, 0)
		end

		if replaying ~= (frame ~= nil) then
			replaying = frame ~= nil
			root:SetAttribute("ShotPlaying",replaying)
			labels.show(not replaying)
			matchPawns.Parent = if replaying then nil else localParts
		end
		if frame then
			camera.CFrame = frame
		else
			local focus = focusedBoard()
			local target = focus or (overview :: CFrame)
			local last = boardPose or (overview :: CFrame)
			-- Interpolate around the target. A straight blend between two long-lens
			-- eye positions can swing the subject off screen during a pitch change.
			local targetDistance = if focus then focusDistance else overviewDistance
			local targetPoint = target.Position + target.LookVector*targetDistance
			local blend = if reduced then 1 else 1-math.exp(-dt*12)
			if not viewPoint or (last.Position-target.Position).Magnitude < .08 then
				viewPoint, viewDistance, boardPose = targetPoint, targetDistance, target
			else
				viewPoint = viewPoint:Lerp(targetPoint,blend)
				viewDistance += (targetDistance-viewDistance)*blend
				local axis = last.LookVector:Lerp(target.LookVector,blend).Unit
				boardPose = CFrame.lookAt(viewPoint-axis*viewDistance,viewPoint)
			end
			userYaw += (targetYaw - userYaw) * math.min(1, dt * 14)
			userPitch += (targetPitch - userPitch) * math.min(1, dt * 14)
			userZoom += (targetZoom - userZoom) * math.min(1, dt * 14)
			local freeDist = viewDistance * userZoom
			local freeRot = CFrame.Angles(0, userYaw, 0) * CFrame.Angles(userPitch, 0, 0)
			local axis = if boardPose then (boardPose.Position - viewPoint).Unit else (overview.Position - viewPoint).Unit
			local finalPose = CFrame.lookAt(viewPoint + freeRot * (axis * freeDist), viewPoint)
			camera.CFrame, camera.Focus, camera.FieldOfView = finalPose, CFrame.identity, Art.boardFov
			if camera.CFrame~=lastInkPose or clock-lastInkTime >= (if entry then 1/30 else .09) then
				lastInkPose,lastInkTime=camera.CFrame,clock
				local silhouettes={}
				for _,model in models do
					local at=model:GetPivot().Position
					local face=model:FindFirstChild("Head") and model.Head:FindFirstChild("Face")
					if not face or not face:IsA("BasePart") then continue end
					local top=camera:WorldToViewportPoint(face.Position+Vector3.yAxis*face.Size.Y*.55)
					local foot=camera:WorldToViewportPoint(at)
					local side=camera:WorldToViewportPoint(at+camera.CFrame.RightVector*3.4)
					local extent=math.abs(side.X-foot.X)
					table.insert(silhouettes,Rect.new(math.min(top.X,foot.X)-extent,math.min(top.Y,foot.Y),
						math.max(top.X,foot.X)+extent,math.max(top.Y,foot.Y)))
				end
				labels.layout(camera,silhouettes,shortLandscape or (portraitCamera and not focus))
			end
		end
		local tip, inView
		if not frame and face and face:IsA("BasePart") then
			tip, inView = camera:WorldToViewportPoint(face.Position + Vector3.yAxis*face.Size.Y*.58)
		end
		labels.markTurn(if inView then tip else nil)
		local portrait = portraitModel
		if portrait and not portrait.Parent then portraitModel = nil end
		local portraitFrame = math.floor(clock * 24)
		if portrait and portrait.Parent and not reduced and portraitFrame ~= lastPortraitPose then
			lastPortraitPose = portraitFrame
			portrait:PivotTo(CFrame.Angles(0, math.sin(clock * 1.55) * .19, 0))
			Pawn.pose(portrait, clock * 2.5, 0)
		end
		-- Independent breathing and weight shifts for every seated player (liquid smooth 60 FPS)
		if not reduced and not frame then
			if lastMatchState and lastMatchState.phase == "final" then
				local winnerId = lastMatchState.winner or (lastMatchState.standings and lastMatchState.standings[1] and lastMatchState.standings[1].id)
				for id, model in models do
					if id == winnerId then
						model:PivotTo(CFrame.new(0, Art.tileTop, 0) * CFrame.Angles(0, math.sin(clock * 1.2) * 0.15, 0))
						Pawn.pose(model, clock * 2.5, 0, (clock * 1.5) % 1)
					else
						Pawn.pose(model, clock * 1.8, 0)
					end
				end
				if clock - lastFinalConfetti > 1.6 then
					lastFinalConfetti = clock
					celebrate(1, true)
				end
			else
				for id, model in models do
					if entry and model == entry.model then continue end
					if activeWarp and model == activeWarp.model then continue end
					local phase = clock*(2.15 + (math.abs(id)%5)*.10) + id%17
					local cheer = if id == cheerId and cheerUntil > clock then 1-(cheerUntil-clock)/.92 else nil
					Pawn.pose(model, phase, 0, cheer)
				end
			end
			if heroModel then
				local turn = Art.boardYaw + math.sin(clock*1.30)*.20
				heroModel:PivotTo(CFrame.new(0,.36,-.90)*CFrame.Angles(-.13,turn,0))
				Pawn.pose(heroModel,clock*2.2,0)
			end
		end

		if activeWarp then
			local elapsed = clock - activeWarp.start
			local t = math.clamp(elapsed / .38, 0, 1)
			local ease = t * t * (3 - 2 * t)
			local arc = math.sin(t * math.pi) * 7.5
			local pos = activeWarp.origin:Lerp(activeWarp.destination, ease) + Vector3.yAxis * arc
			activeWarp.model:PivotTo(settled(pos))
			Pawn.animate(activeWarp.model, "launch", t, .75)
			if t >= 1 then
				pulse(activeWarp.destination, activeWarp.color, true)
				Pawn.pose(activeWarp.model, 0, 0)
				activeWarp = nil
			end
		end

		if not entry then return end
		local elapsed = clock - entry.start
		if elapsed < 0 then return end
		local movement = elapsed - PREP
		if reduced or movement >= STEP * entry.steps + SETTLE then
			if entry.bounced < entry.steps then
				playSound("land")
				markDestination(Game.target(entry.from, entry.steps), entry.color)
			end
			finishFlight()
			return
		end
		local progress = math.clamp(movement / STEP, 0, entry.steps)
		local beat = math.floor(progress)
		local travel = routeAt(entry.route, progress)
		local direction = routeAt(entry.route, progress + .16) - routeAt(entry.route, progress - .16)
		local yaw = math.atan2(direction.X, direction.Z)
		if movement < 0 then
			local prep = elapsed / PREP
			local approach = settled(entry.origin):Lerp(CFrame.new(entry.origin) * CFrame.Angles(0, yaw, 0), prep)
			entry.model:PivotTo(approach)
			Pawn.animate(entry.model, "launch", prep, .46)
			return
		end
		entry.shadow.Position = Vector3.new(travel.X, Art.tileTop + .017, travel.Z)
		local ending = movement >= STEP * entry.steps
		if ending then
			local ease = math.clamp((movement - STEP * entry.steps) / SETTLE, 0, 1)
			local fade = ease * ease * (3 - 2 * ease)
			entry.model:PivotTo((CFrame.new(travel - Vector3.yAxis * (.24 * (1 - fade))) * CFrame.Angles(0, yaw, 0)):Lerp(settled(travel), fade))
			Pawn.run(entry.model, progress * 1.08 + ease * .21, .64 * (1 - fade))
		else
			local strength = .64 + .36 * math.min(1, progress * 2, (entry.steps - progress) * 2)
			entry.model:PivotTo(CFrame.new(travel - Vector3.yAxis * .29) * CFrame.Angles(0, yaw, 0))
			Pawn.run(entry.model, progress * 1.08, strength)
		end
		local landed = if ending then entry.steps else beat
		if landed > 0 and landed > entry.bounced then
			entry.bounced = landed
			if ending or landed % 2 == 1 then playSound(if ending then "land" else "step") end
			local index = Game.target(entry.from, landed)
			if ending then
				markDestination(index, entry.color)
				flashTile(index, entry.color)
			end
			pulse(if ending then entry.destination else position(index), entry.color, ending)
		end
	end)

	celebrate = function(index: number, big: boolean)
		if reduced then return end
		if big then cheerId, cheerUntil = activeId, os.clock()+.92 end
		local center = Geometry.cells[index]
		local origin = Vector3.new(center.X, Art.tileTop + 1.3, center.Z)
		local count = if big then 16 else 8
		for i = 1, count do
			local angle = i * TAU / count
			local color = if i % 3 == 0 then Art.paper elseif i % 3 == 1 then Art.gold else Art.mint
			local spark = part(effects, "Result confetti", Vector3.new(.37, .13, .50), origin, color)
			local vector = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local target = origin + vector * (2.4 + i % 4 * .5) + Vector3.new(0, 1.4 + i % 3 * .4, 0)
			TweenService:Create(spark, TweenInfo.new(.29, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{CFrame = CFrame.new(target) * CFrame.Angles(i * .5, angle, i * .29)}):Play()
			task.delay(.31, function()
				if not spark.Parent then return end
				TweenService:Create(spark, TweenInfo.new(.34, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{Position = target + vector * 1.9 - Vector3.yAxis * 3.4, Transparency = 1}):Play()
			end)
			Debris:AddItem(spark, .70)
		end
	end

	local function popup(at: Vector3, message: string, tint: Color3)
		if reduced then return end
		if string.sub(message, 1, 1) == "+" then
			playSound("coins")
		end
		local anchor = Instance.new("Part")
		anchor.Name = "PopupAnchor"
		anchor.Size = Vector3.new(0.1, 0.1, 0.1)
		anchor.Position = at + Vector3.new(0, Art.tileTop + 0.5, 0)
		anchor.Transparency = 1
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.Anchored = true
		anchor.Parent = effects

		local billboard = Instance.new("BillboardGui")
		billboard.Name = "CurrencyPopup"
		billboard.Size = UDim2.fromOffset(136, 36)
		billboard.StudsOffset = Vector3.new(0, 1.5, 0)
		billboard.AlwaysOnTop = true
		billboard.MaxDistance = 450
		billboard.Adornee = anchor
		billboard.Parent = effects
		local badge = UI.box(billboard, "Badge", Art.ink, 6)
		badge.Size = UDim2.fromScale(1, 1)
		badge.BackgroundTransparency = .24
		UI.stroke(badge, tint, 1.5)
		local label = UI.label(badge, message, 19, {
			font = Enum.Font.BuilderSansExtraBold, color = tint, align = Enum.TextXAlignment.Center, ellipsis = true
		})
		label.Size = UDim2.fromScale(1, 1)
		local startClock = os.clock()
		task.spawn(function()
			while billboard.Parent do
				local elapsed = os.clock() - startClock
				if elapsed >= 1.25 then break end
				local t = elapsed / 1.25
				local lift = 1.5 + 4.2 * math.sin(t * math.pi * .5)
				local fade = if t > .65 then (t - .65) / .35 else 0
				billboard.StudsOffset = Vector3.new(0, lift, 0)
				badge.BackgroundTransparency = .24 + .76 * fade
				label.TextTransparency = fade
				RunService.RenderStepped:Wait()
			end
			billboard:Destroy()
			anchor:Destroy()
		end)
	end

	return {
		sync = sync,
		setFollow = function(enabled: boolean)
			followTurn = enabled
		end,
		stadiumMessage = function(title: string, tint: Color3)
			local textLabel = ribbonText
			if not textLabel then return end
			ribbonVersion += 1
			local revision = ribbonVersion
			textLabel.Text, textLabel.TextColor3 = title, tint
			task.delay(1.65, function()
				if ribbonVersion == revision and textLabel.Parent then
					textLabel.Text, textLabel.TextColor3 = "SOCCERPOLY", Art.mint
				end
			end)
		end,
		relocalize = function()
			ribbonVersion += 1
			if updateDisplay then updateDisplay(displaySnapshot) end
			if ribbonText then ribbonText.Text, ribbonText.TextColor3 = "SOCCERPOLY", Art.mint end
			labels.translate()
		end,
		playShot = function(outcome: string, figure: number, impact: () -> ())
			replay.play(outcome, figure, impact, reduced)
		end,
		pickTile = function(point: Vector3): number?
			if replaying then return nil end
			local camera = workspace.CurrentCamera
			if not camera then return nil end
			local ray = camera:ScreenPointToRay(point.X, point.Y)
			if math.abs(ray.Direction.Y) < .001 then return nil end
			local distance = (Art.tileTop - ray.Origin.Y) / ray.Direction.Y
			if distance < 0 then return nil end
			local hit = ray.Origin + ray.Direction * distance
			for index, tile in Geometry.cells do
				local offset = CFrame.Angles(0, Geometry.tileYaw(index), 0):VectorToObjectSpace(hit - tile)
				local dims = Geometry.tileSize(index)
				if math.abs(offset.X) <= dims.X * .5 and math.abs(offset.Z) <= dims.Y * .5 then return index end
			end
			return nil
		end,
		celebrate = celebrate,
		popup = popup,
		resetCamera = function()
			targetYaw, targetPitch, targetZoom = 0, 0, 1.0
		end,
		preview = function(model: Model)
			portraitModel, lastPortraitPose = model, -1
		end,
		reduceMotion = function(value: boolean)
			reduced = value
			if value then
				for _, model in models do Pawn.pose(model,0,0) end
				if heroModel then Pawn.pose(heroModel, 0, 0) end
				if portraitModel and portraitModel.Parent then
					portraitModel:PivotTo(CFrame.identity)
					Pawn.pose(portraitModel, 0, 0)
				end
			end
		end,
	}
end

return Arena
