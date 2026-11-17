--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local GuiService = game:GetService("GuiService")

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
	local row = math.floor((ordinal - 1) / 3)
	local onRow = math.min(3, total - row * 3)
	local col = (ordinal - 1) % 3
	-- Put the front row on the artwork. Additional seats fan towards the far
	-- edge, keeping the title and price clear on the player's current square.
	local x = tile.X + (col - (onRow - 1) * .5) * math.min(4.85,width * .32)
	local z = tile.Z - depth * (.20 + row * .22)
	return Vector3.new(x, Art.tileTop + .04 - Art.figureScale * .376, z)
end

local function settled(point: Vector3): CFrame
	return CFrame.new(point) * CFrame.Angles(0, Art.boardYaw + .08, 0)
end

local function decorated(parent: Instance, name: string, shape: string, size: Vector3, at: Vector3, fallback: Instance)
	local marker = part(parent, name, size, at, Color3.new(1, 1, 1))
	marker.Transparency = 1
	marker:SetAttribute("MeshPlaceholder", true)
	Meshes.apply(shape, marker, {fallback})
end

local function clubStadium(parent: Folder, p: Vector3, level: number, color: Color3, index: number)
	local inside = CFrame.Angles(0, Geometry.tileYaw(index), 0):VectorToWorldSpace(Vector3.new(0, 0, -4))
	local x, z = p.X + inside.X, p.Z + inside.Z
	local fallback = Instance.new("Folder")
	fallback.Parent = parent
	local function stadiumPart(name: string, width: number, height: number, depth: number, px: number, y: number, pz: number, tint: Color3)
		return part(fallback, name, Vector3.new(width, height, depth), Vector3.new(px, y, pz), tint)
	end
	stadiumPart("Stadium foundations", 2.83, .31, 2.58, x, .86, z, Art.ink)
	stadiumPart("Stadium pitch", 2.62, .12, 2.38, x, 1.06, z, Art.field)
	stadiumPart("Halfway line", .05, .04, 1.98, x, 1.14, z, Art.paper)
	for _, side in {-1, 1} do
		local px = x + side * 1.18
		stadiumPart("Terrace", .45, .22 + level * .26, 2.40, px, 1.22, z, color)
		if level >= 2 then stadiumPart("Stadium canopy", .65, .13, 2.60, px, 1.79, z, Art.paper) end
	end
	local height = if level >= 2 then 1.31 else .79
	decorated(parent, "Club stadium", if level >= 2 then "arena" else "academy",
		Vector3.new(3.7 + .45 * level, height + .33 * level, 3.56), Vector3.new(x, Art.tileTop + height * .5, z), fallback)
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

function Arena.new(myId: number, root: Frame, translate: (string) -> string, playSound: (string) -> ())
	local labels = BoardLabels(root, translate)
	local ribbonText: TextLabel? = nil
	local ribbonVersion = 0
	task.defer(function()
		local stage = workspace:WaitForChild("WorldDraftArena", 12)
		if not stage then return end
		Meshes.decorate(stage)
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
	local replay = MatchdayReplay(effects, playSound)
	local replaying = false

	local models: {[number]: Model} = {}
	local activeId = 0
	local cheerId, cheerUntil = 0, 0
	local posed: Model? = nil
	local previews: {Model} = {}
	local heroModel: Model? = nil
	local portraitModel: Model? = nil
	local lastPortraitPose = -1
	local heroFigure = 0
	local lastIdlePose = -1
	local serial, lastMotion, lastRoll = -1, 0, 0
	local signature = ""
	local activeFlight: Flight? = nil
	local reduced = GuiService.ReducedMotionEnabled
	local oldSize: Vector2? = nil
	local oldRoot: Vector2? = nil
	local overview: CFrame? = nil
	local portraitCamera = false
	local followTurn = true
	local focusOrbit = Vector3.zero
	local focusDistance = 0
	local boardPose: CFrame? = nil
	local lastInkPose: CFrame? = nil
	local lastInkTime = 0

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
		local angle = math.rad(if portraitCamera then 53 else 40)
		local orbit = Vector3.zAxis * math.cos(angle) + Vector3.yAxis * math.sin(angle)
		local span = Geometry.width
		local width = if portraitCamera then .86 else .85
		local height = if size.Y < 550 then .60 else .718
		local distance = math.max(span / (2 * tangent * aspect * width), span * math.sin(angle) / (2 * tangent * height))
		local base = CFrame.lookAt(orbit * distance, Vector3.zero)
		local half = Geometry.width * .5
		local near = base:PointToObjectSpace(Vector3.new(half, Art.tileTop, half))
		local far = base:PointToObjectSpace(Vector3.new(-half, Art.tileTop, -half))
		local centerY = (near.Y / -near.Z + far.Y / -far.Z) * .5
		local targetY = if portraitCamera then .07 else -.071
		overview = base * CFrame.new(0, (centerY - targetY * tangent) * distance, 0)
		focusOrbit, focusDistance = orbit, distance * .55
		boardPose = nil
		oldSize, oldRoot, camera.FieldOfView = size, root.AbsoluteSize, fov
	end

	local function focusedBoard(): CFrame?
		local pawn = models[activeId]
		if not (portraitCamera and followTurn and pawn) then return nil end
		local point = pawn:GetPivot().Position
		-- Keep the action at the outside of frame so neighboring tiles and the pitch are in view.
		local clamped = Vector3.new(math.clamp(point.X, -36, 36), Art.tileTop, math.clamp(point.Z, -37, 37))
		return CFrame.lookAt(clamped + focusOrbit * focusDistance, clamped)
	end

	local function pulse(at: Vector3, color: Color3, impact: boolean)
		if reduced then return end
		local glow = medallion(effects, "Landing pulse", Vector3.new(at.X, Art.tileTop + .038, at.Z), 1.2, .032, color)
		glow.Material, glow.Transparency = Enum.Material.Neon, if impact then .34 else .62
		local reach = if impact then 6.2 else 3.2
		TweenService:Create(glow, TweenInfo.new(if impact then .31 else .17, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Size = Vector3.new(.025, reach, reach), Transparency = 1}):Play()
		Debris:AddItem(glow, .36)
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

	local function savedDecor(s: any)
		local bits = {}
		for i, club in s.clubs do
			if club.owner ~= 0 then table.insert(bits, i .. ":" .. club.owner .. "/" .. club.level .. "/" .. tostring(club.shield)) end
		end
		for _, seat in s.seats do table.insert(bits, seat.id .. "/" .. seat.figure .. "/" .. seat.trophies) end
		table.insert(bits, tostring(s.festival or 0))
		local key = table.concat(bits, "|")
		if key == signature then return end
		signature = key
		markers:ClearAllChildren()
		local colors: {[number]: Color3} = {}
		for slot, seat in s.seats do
			local color = Art.hex(Board.figures[seat.figure].color)
			colors[seat.id] = color
			if seat.trophies > 0 then trophy(markers, Vector3.new((slot - (#s.seats + 1) * .5) * 4.1, .43, 38.15), color) end
		end
		for i, club in s.clubs do
			if club.owner ~= 0 then
				local p, color = Geometry.cells[i], colors[club.owner]
				part(markers, "Club ownership", Vector3.new(11.6, .12, .42),
					Vector3.new(p.X, Art.tileTop + .020, p.Z + 4.67), color)
				if Board.tiles[i].league > 0 then clubStadium(markers, p, club.level, color, i) end
				if s.festival == i then trophy(markers, Vector3.new(p.X, Art.tileTop, p.Z) + Art.boardRight * 2.8, color) end
				if club.shield then
					local badge = part(markers, "Club protection", Vector3.new(2.42, .23, 2.64), p + Vector3.new(2.6, 1.7, 0), C("F4C65E"))
					badge.CFrame *= CFrame.Angles(1.37, 0, 0)
					Meshes.apply("crest", badge)
				end
			end
		end
	end

	local function sync(snapshot: any)
		local s = snapshot.match
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
			playSound("dice")
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
			local destination = position(seat.position, slot, tileCounts[seat.position])
			if moved and s.motion.who == seat.id and s.motion.steps > 0 and not reduced then
				local at = model:GetPivot().Position
				local color = Art.hex(Board.figures[seat.figure].color)
				local shadow = medallion(effects, "Travel shadow", Vector3.new(at.X, Art.tileTop + .025, at.Z), 3.88, .022, Art.ink)
				shadow.Transparency = .62
				local route = {at}
				for i = 1, s.motion.steps - 1 do
					table.insert(route, position(Game.target(s.motion.from, i)))
				end
				table.insert(route, destination)
				activeFlight = {model = model, shadow = shadow, from = s.motion.from, steps = s.motion.steps, route = route,
					start = os.clock() + ROLL_LEAD, origin = at, destination = destination, color = color, bounced = 0}
			elseif not activeFlight or activeFlight.model ~= model then
				model:PivotTo(settled(destination))
			end
		end
		serial, lastMotion = snapshot.serial, s.motion.serial
		savedDecor(s)
		local active = s.seats[s.active]
		activeId = if s.phase == "final" then 0 else active.id
	end

	RunService:BindToRenderStep("WorldDraftCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local camera = workspace.CurrentCamera
		if not camera or camera.ViewportSize.X < 2 or camera.ViewportSize.Y < 2 then return end
		camera.CameraType = Enum.CameraType.Scriptable
		if oldSize ~= camera.ViewportSize or oldRoot ~= root.AbsoluteSize or not overview then layout(camera) end
		local entry = activeFlight
		local clock = os.clock()
		replay.step(clock, reduced)
		local frame = replay.framing(camera)
		if replaying ~= (frame ~= nil) then
			replaying = frame ~= nil
			labels.show(not replaying)
			matchPawns.Parent = if replaying then nil else localParts
		end
		if frame then
			camera.CFrame = frame
		else
			local focus = focusedBoard()
			local target = focus or (overview :: CFrame)
			local last = boardPose or (overview :: CFrame)
			boardPose = if (last.Position - target.Position).Magnitude < .08 or reduced
				then target else last:Lerp(target, 1 - math.exp(-dt * 9))
			camera.CFrame, camera.Focus, camera.FieldOfView = boardPose :: CFrame, CFrame.identity, Art.boardFov
			if camera.CFrame~=lastInkPose or clock-lastInkTime>=.09 then
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
				labels.layout(camera,silhouettes)
			end
		end
		local portrait = portraitModel
		if portrait and not portrait.Parent then portraitModel = nil end
		local portraitFrame = math.floor(clock * 24)
		if portrait and portrait.Parent and not reduced and portraitFrame ~= lastPortraitPose then
			lastPortraitPose = portraitFrame
			portrait:PivotTo(CFrame.Angles(0, math.sin(clock * 1.55) * .19, 0))
			Pawn.pose(portrait, clock * 2.5, 0)
		end
		local focus = models[if cheerUntil > clock then cheerId else activeId]
		if entry and focus == entry.model then focus = nil end
		if posed and posed ~= focus and posed.Parent and (not entry or posed ~= entry.model) then Pawn.pose(posed, 0, 0) end
		posed = focus
		if not reduced then
			if focus then
				local cheer = if cheerUntil > clock then 1 - (cheerUntil - clock) / .92 else nil
				Pawn.pose(focus, clock * 2.8, 0, cheer)
			elseif heroModel then
				local poseFrame = math.floor(clock * 30)
				if poseFrame ~= lastIdlePose then
					lastIdlePose = poseFrame
					local turn = Art.boardYaw + math.sin(clock * 1.30) * .20
					heroModel:PivotTo(CFrame.new(0, .36, -.90) * CFrame.Angles(0, turn, 0) * CFrame.Angles(-.13, 0, 0))
					Pawn.pose(heroModel, clock * 2.2, 0)
				end
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
			if ending then markDestination(index, entry.color) end
			pulse(if ending then entry.destination else position(index), entry.color, ending)
		end
	end)

	local function celebrate(index: number, big: boolean)
		if reduced then return end
		local center = Geometry.cells[index]
		local origin = Vector3.new(center.X, Art.tileTop + 1.3, center.Z)
		for i = 1, if big then 14 else 6 do
			local angle = i * TAU / 14
			local color = if i % 3 == 0 then Art.paper elseif i % 3 == 1 then Art.gold else Art.mint
			local spark = part(effects, "Result confetti", Vector3.new(.37, .13, .50), origin, color)
			local vector = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local target = origin + vector * (2.3 + i % 4) + Vector3.new(0, 1.4 + i % 3, 0)
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
					textLabel.Text, textLabel.TextColor3 = "FOOTBOLAPOLIA", Art.mint
				end
			end)
		end,
		relocalize = function()
			ribbonVersion += 1
			if ribbonText then ribbonText.Text, ribbonText.TextColor3 = "FOOTBOLAPOLIA", Art.mint end
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
		preview = function(model: Model)
			portraitModel, lastPortraitPose = model, -1
		end,
		reduceMotion = function(value: boolean)
			reduced = value
			if value then
				if posed then Pawn.pose(posed, 0, 0) end
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
