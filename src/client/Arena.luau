--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local GuiService = game:GetService("GuiService")

local shared = ReplicatedStorage:WaitForChild("League")
local Board = require(shared.Board)
local Geometry = require(shared.Geometry)
local Art = require(shared.Presentation)
local Game = require(shared.Rules).withBoard(Board, require(shared.EventCards))
local View = require(script.Parent.ViewLayout)
local Pawn = require(script.Parent.Pawn)
local Meshes = require(script.Parent.MeshLibrary)
local BoardLabels = require(script.Parent.BoardLabels)
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
	local base = Vector3.new(tile.X, Art.tileTop + .03, tile.Z) - Art.boardNear * 2.04
	local total, ordinal = count or 1, slot or 1
	local cols, rows = math.min(total, 3), math.ceil(total / 3)
	local row = math.floor((ordinal - 1) / 3)
	local onRow = math.min(cols, total - row * 3)
	local col = (ordinal - 1) % 3
	return base + Art.boardRight * ((col - (onRow - 1) * .5) * 4.85)
		- Art.boardNear * ((row - (rows - 1) * .5) * 4.15)
end

local function settled(point: Vector3): CFrame
	return CFrame.new(point) * CFrame.Angles(0, Art.boardYaw + .08, 0)
end

local function route(selection: Folder, index: number, color: Color3): Vector3
	local p = Geometry.cells[index]
	local y = Art.tileTop + .035
	for _, sx in {-1, 1} do
		for _, sz in {-1, 1} do
			local x, z = p.X + sx * 7.85, p.Z + sz * 7.85
			part(selection, "Route bracket", Vector3.new(3.0, .10, .43), Vector3.new(x - sx * 1.34, y, z), color, Enum.Material.Neon)
			part(selection, "Route bracket", Vector3.new(.43, .10, 2.35), Vector3.new(x, y, z - sz * .99), color, Enum.Material.Neon)
		end
	end
	return Vector3.new(p.X, y + 1.75, p.Z) - Art.boardRight * 6.8 - Art.boardNear * 4.0
end

local function decorated(parent: Instance, name: string, shape: string, size: Vector3, at: Vector3, fallback: Instance)
	local marker = part(parent, name, size, at, Color3.new(1, 1, 1))
	marker.Transparency = 1
	marker:SetAttribute("MeshPlaceholder", true)
	Meshes.apply(shape, marker, {fallback})
end

local function clubStadium(parent: Folder, p: Vector3, level: number, color: Color3)
	local x, z = p.X + 5.95, p.Z - 2.95
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
		if level == 2 then stadiumPart("Stadium canopy", .65, .13, 2.60, px, 1.79, z, Art.paper) end
	end
	local height = if level == 2 then 1.31 else .79
	decorated(parent, "Club stadium", if level == 2 then "arena" else "academy",
		Vector3.new(3.06, height, 2.51), Vector3.new(x, Art.tileTop + height * .5, z), fallback)
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

type Flight = {model: Model, shadow: Part, start: number, from: number, steps: number, origin: Vector3, destination: Vector3, color: Color3, bounced: number}
local PREP, STEP, SETTLE = .10, .105, .15
local SHOT_RELEASE, SHOT_IMPACT, SHOT_END = .29, .80, 1.51
local SHOT_START = Vector3.new(-11.5, 1.55, 2.6)
type Shot = {
	actors: Folder, ball: Model, shadow: Part, trail: Trail, shooter: Model, keeper: Model, start: number,
	outcome: string, scorer: number, released: boolean, resolved: boolean, impact: () -> (),
}

function Arena.landingAfter(steps: number): number
	return PREP + steps * STEP
end

function Arena.new(myId: number, root: Frame, translate: (string) -> string, playSound: (string) -> ())
	local labels = BoardLabels(root, translate)
	task.defer(function()
		local stage = workspace:WaitForChild("WorldDraftArena", 12)
		if stage then Meshes.decorate(stage) end
	end)
	local localParts = Instance.new("Folder")
	localParts.Name, localParts.Parent = "LocalTablePieces", workspace
	local markers = Instance.new("Folder")
	markers.Name, markers.Parent = "Markers", localParts
	local selection = Instance.new("Folder")
	selection.Name, selection.Parent = "Selection", localParts
	local effects = Instance.new("Folder")
	effects.Name, effects.Parent = "Motion effects", localParts

	local tags: {TextLabel} = {}
	local tagPositions: {Vector3} = {}
	for key, tint in Art.route do
		local tag = UI.label(root, tostring(key), 14, {
			font = Enum.Font.BuilderSansBold, color = Art.ink, align = Enum.TextXAlignment.Center, ellipsis = true, name = "RouteBadge" .. key,
		})
		tag.AnchorPoint, tag.Size, tag.Visible = Vector2.new(.5, 1), UDim2.fromOffset(24, 22), false
		tag.BackgroundColor3, tag.BackgroundTransparency = Art.hex(tint), 0
		UI.round(tag, 6)
		UI.stroke(tag, Art.ink, 2)
		table.insert(tags, tag)
	end
	local models: {[number]: Model} = {}
	local activeId = 0
	local cheerId, cheerUntil = 0, 0
	local posed: Model? = nil
	local shot: Shot? = nil
	local function clearShot()
		if not shot then return end
		shot.ball:Destroy()
		shot.actors:Destroy()
		shot = nil
	end
	local previews: {Model} = {}
	local heroModel: Model? = nil
	local portraitModel: Model? = nil
	local lastPortraitPose = -1
	local heroFigure = 0
	local lastIdlePose = -1
	local serial, lastMotion = -1, 0
	local signature = ""
	local cue = ""
	local activeFlight: Flight? = nil
	local reduced = GuiService.ReducedMotionEnabled
	local oldSize: Vector2? = nil
	local oldRoot: Vector2? = nil
	local cameraPose: CFrame? = nil
	local cameraTarget: CFrame? = nil
	local replayCamera = CFrame.identity
	local replayFraming = false
	local labelsVisible = true
	local cameraNudge = Vector3.zero
	local projectedCamera: CFrame? = nil
	local finalTile = 0

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
		local usable = if root.AbsoluteSize.X > 1 then root.AbsoluteSize else size
		local mode = View.mode(usable)
		local aspect = size.X / size.Y
		local fov = 28
		local tangent = math.tan(math.rad(fov) / 2)
		local rail = mode == "rail"
		local top = if mode == "portrait" then 135 elseif rail then 112 elseif usable.X < 920 then 102 else 68
		local screenTop = math.max(0, size.Y - usable.Y) + top
		local screenBottom = size.Y - (if rail then 11 else View.dockHeight(usable, mode) + 12)
		local screenRight = if rail then usable.X - View.railWidth(usable) - 14 else size.X - 12
		local width = math.max(.48, (screenRight - 12) * 2 / size.X)
		local height = math.max(.42, (screenBottom - screenTop) * 2 / size.Y)
		local targetX = (screenRight + 12) / size.X - 1
		local targetY = 1 - (screenTop + screenBottom) / size.Y
		local yaw = Art.boardYaw
		local angle = math.rad(if mode == "portrait" then 45 elseif rail then 34 else 33)
		local orbit = Vector3.new(math.sin(yaw) * math.cos(angle), math.sin(angle), math.cos(yaw) * math.cos(angle))
		local distance = math.max(Geometry.width * 1.40 / (tangent * aspect * width), Geometry.depth * .92 / (tangent * height))
		local base = CFrame.identity
		for pass = 1, 4 do
			base = CFrame.lookAt(orbit * distance, Vector3.zero)
			local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
			for _, x in {-Geometry.width * .514, Geometry.width * .514} do
				for _, z in {-Geometry.depth * .514, Geometry.depth * .514} do
					-- Reserve top clearance for the far-side figurines.
					local y = if x < 0 and z < 0 then 7.4 else Art.tileTop
					local corner = base:PointToObjectSpace(Vector3.new(x, y, z))
					local scale = -corner.Z * tangent
					local nx, ny = corner.X / (scale * aspect), corner.Y / scale
					minX, minY, maxX, maxY = math.min(minX, nx), math.min(minY, ny), math.max(maxX, nx), math.max(maxY, ny)
				end
			end
			if pass == 4 then
				base *= CFrame.new(((minX + maxX) * .5 - targetX) * distance * tangent * aspect,
					((minY + maxY) * .5 - targetY) * distance * tangent, 0)
			else
				distance *= math.clamp(math.max((maxX - minX) / width, (maxY - minY) / height), .80, 1.4)
			end
		end
		cameraTarget = base
		local replayAngle = math.rad(if mode == "portrait" then 38 else 25)
		local replayYaw = math.rad(if mode == "portrait" then 36 else 23)
		local orbitShot = Vector3.new(math.sin(replayYaw) * math.cos(replayAngle), math.sin(replayAngle),
			math.cos(replayYaw) * math.cos(replayAngle))
		local focalPoint = Vector3.new(6, 3.5, 1)
		local shotDistance = math.max(68 / (tangent * aspect * width), 35 / (tangent * height))
		replayCamera = CFrame.lookAt(focalPoint + orbitShot * shotDistance, focalPoint)
			* CFrame.new(-targetX * shotDistance * tangent * aspect, -targetY * shotDistance * tangent, 0)
		oldSize, oldRoot, camera.FieldOfView = size, root.AbsoluteSize, fov
		projectedCamera = nil
		if not cameraPose or reduced then cameraPose = cameraTarget end
	end

	local function pulse(at: Vector3, color: Color3, impact: boolean)
		if reduced then return end
		local glow = medallion(effects, "Landing pulse", at + Vector3.new(0, .014, 0), 1.2, .032, color)
		glow.Material, glow.Transparency = Enum.Material.Neon, if impact then .34 else .62
		local reach = if impact then 6.2 else 3.2
		TweenService:Create(glow, TweenInfo.new(if impact then .31 else .17, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Size = Vector3.new(.025, reach, reach), Transparency = 1}):Play()
		Debris:AddItem(glow, .36)
	end

	local function savedDecor(s: any)
		local bits = {}
		for i, club in s.clubs do
			if club.owner ~= 0 then table.insert(bits, i .. ":" .. club.owner .. "/" .. club.level) end
		end
		for _, seat in s.seats do table.insert(bits, seat.id .. "/" .. seat.figure .. "/" .. seat.trophies) end
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
				if club.level > 0 then clubStadium(markers, p, club.level, color) end
			end
		end
	end

	local function sync(snapshot: any)
		local s = snapshot.match
		labels.owners(s)
		if s == nil then
			activeId, cheerId = 0, 0
			clearShot()
			finishFlight()
			if cue ~= "" then selection:ClearAllChildren() end
			table.clear(tagPositions)
			cue, signature, finalTile = "", "", 0
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
			finishFlight()
			for id, model in models do model:Destroy(); models[id] = nil end
			signature, finalTile = "", 0
		end
		local moved = sameMatch and s.motion.serial > lastMotion
		if moved then finishFlight() end
		local tileCounts: {[number]: number} = {}
		local tileSlots: {[number]: number} = {}
		for _, seat in s.seats do
			tileCounts[seat.position] = (tileCounts[seat.position] or 0) + 1
		end
		for _, seat in s.seats do
			local model = models[seat.id]
			if not model then
				model = Pawn.make(seat.figure, localParts)
				model:ScaleTo(Art.figureScale)
				models[seat.id] = model
			end
			local slot = (tileSlots[seat.position] or 0) + 1
			tileSlots[seat.position] = slot
			local destination = position(seat.position, slot, tileCounts[seat.position])
			if moved and s.motion.who == seat.id and not reduced then
				local at = model:GetPivot().Position
				local color = Art.hex(Board.figures[seat.figure].color)
				local shadow = medallion(effects, "Travel shadow", at, 4.55, .022, Art.ink)
				shadow.Transparency = .51
				activeFlight = {model = model, shadow = shadow, from = s.motion.from, steps = s.motion.steps,
					start = os.clock(), origin = at, destination = destination, color = color, bounced = -1}
				finalTile = seat.position
			elseif not activeFlight or activeFlight.model ~= model then
				model:PivotTo(settled(destination))
			end
		end
		serial, lastMotion = snapshot.serial, s.motion.serial
		savedDecor(s)
		local active = s.seats[s.active]
		activeId = if s.phase == "final" then 0 else active.id
		local first, second = 0, 0
		if (s.phase == "move" or s.phase == "bench") and active.id == myId and not active.bot then
			first = Game.target(active.position, s.short)
			if s.phase == "move" then second = Game.target(active.position, s.long) end
		end
		local nextCue = first .. "/" .. second
		if nextCue ~= cue then
			cue = nextCue
			selection:ClearAllChildren()
			table.clear(tagPositions)
			if first > 0 then
				tagPositions[1] = route(selection, first, Art.hex(Art.route[1]))
				if second > 0 then tagPositions[2] = route(selection, second, Art.hex(Art.route[2])) end
			end
		end
	end

	RunService:BindToRenderStep("WorldDraftCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local camera = workspace.CurrentCamera
		if not camera or camera.ViewportSize.X < 2 or camera.ViewportSize.Y < 2 then return end
		camera.CameraType = Enum.CameraType.Scriptable
		if oldSize ~= camera.ViewportSize or oldRoot ~= root.AbsoluteSize or not cameraTarget then layout(camera) end
		local nudge = Vector3.zero
		local entry = activeFlight
		local inReplay = shot ~= nil and not reduced
		if shot and inReplay then
			local flight = math.clamp((os.clock() - shot.start - SHOT_RELEASE) / (SHOT_IMPACT - SHOT_RELEASE), 0, 1)
			nudge = Vector3.new(5.0 * flight - 2.0, .2, 0)
		elseif entry and not reduced and finalTile > 0 then
			local spot = Geometry.cells[finalTile]
			nudge = Vector3.new(spot.X, 0, spot.Z) * .045
		end
		cameraNudge = if reduced then Vector3.zero else cameraNudge:Lerp(nudge, 1 - math.exp(-7 * dt))
		local cameraFrame = if inReplay then replayCamera else cameraTarget :: CFrame
		cameraPose = if reduced then cameraFrame else (cameraPose or cameraFrame):Lerp(cameraFrame, 1 - math.exp(-(if inReplay then 15 else 11) * dt))
		camera.CFrame = (cameraPose :: CFrame) + cameraNudge
		camera.Focus = CFrame.new(cameraNudge + (if inReplay then Vector3.new(6, 3.5, 1) else Vector3.zero))
		replayFraming = inReplay or ((cameraPose :: CFrame).Position - (cameraTarget :: CFrame).Position).Magnitude > 15
		if labelsVisible == replayFraming then
			labelsVisible = not replayFraming
			labels.show(labelsVisible)
			projectedCamera = nil
		end
		if labelsVisible and projectedCamera ~= camera.CFrame then
			projectedCamera = camera.CFrame
			labels.project(camera)
		end
		for key, tag in tags do
			local at = tagPositions[key]
			if at and not replayFraming then
				local point, onScreen = camera:WorldToScreenPoint(at)
				tag.Position, tag.Visible = UDim2.fromOffset(point.X, point.Y), onScreen
			elseif tag.Visible then
				tag.Visible = false
			end
		end

		local clock = os.clock()
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

		if shot then
			local replay = shot
			local elapsed = clock - replay.start
			local saved, offside = replay.outcome == "save", replay.outcome == "offside"
			local target = if offside then Vector3.new(20, 1.00, -9) elseif saved then Vector3.new(27, 1.75, -.85)
				else Vector3.new(33.4, 1.40, .9)
			if elapsed >= SHOT_RELEASE and not replay.released then
				replay.released = true
				replay.trail.Enabled = not reduced
				playSound("kick")
			end
			if (reduced or elapsed >= SHOT_IMPACT) and not replay.resolved then
				replay.resolved = true
				replay.trail.Enabled = false
				replay.impact()
				if replay.outcome == "goal" then cheerId, cheerUntil = replay.scorer, clock + .92 end
				if not reduced then pulse(target, if offside then Art.gold elseif saved then Art.paper else Art.mint, not saved) end
			end
			if reduced or elapsed >= SHOT_END then
				clearShot()
			else
				local t = math.clamp((elapsed - SHOT_RELEASE) / (SHOT_IMPACT - SHOT_RELEASE), 0, 1)
				local settle = math.clamp((elapsed - SHOT_IMPACT) / (SHOT_END - SHOT_IMPACT), 0, 1)
				local travel = SHOT_START:Lerp(target, 1 - (1 - t) ^ 1.35)
				travel += Vector3.yAxis * (math.sin(t * math.pi) * (if saved then 2.4 else 3.7))
				if saved then
					travel += Vector3.new(-8, -.6, -5) * settle + Vector3.yAxis * (math.sin(settle * math.pi) * 2.1)
				elseif not offside then
					travel += Vector3.new(-1.35, -.38, .48) * settle + Vector3.yAxis * (math.sin(settle * math.pi) * .82)
				end
				replay.ball:PivotTo(CFrame.new(travel) * CFrame.Angles(t * 7 + settle * 3, 0, t * 3))
				replay.shadow.Position = Vector3.new(travel.X, .411, travel.Z)
				replay.shadow.Transparency = .49 + math.clamp((travel.Y - 1.4) * .065, 0, .36)
				local approach = math.clamp(elapsed / SHOT_RELEASE, 0, 1)
				local strikerX = -21 + 6 * approach + 2 * settle
				replay.shooter:PivotTo(CFrame.new(strikerX, -.52, 2.6) * CFrame.Angles(0, math.pi * .5, 0))
				if replay.outcome == "goal" and replay.resolved then
					Pawn.animate(replay.shooter, "cheer", .18 + settle * .66)
				else
					Pawn.animate(replay.shooter, "kick", math.clamp(elapsed / .55, 0, 1))
				end
				local dive = math.clamp((elapsed - .44) / .62, 0, 1)
				local spring = math.sin(dive * math.pi)
				local keeperZ = if offside then 0 elseif saved then -2.6 else 3.05
				replay.keeper:PivotTo(CFrame.new(29.5 - (if saved then 1.8 else .3) * spring, -.44 + spring * .91, keeperZ * spring)
					* CFrame.Angles(0, -math.pi * .5, 0))
				Pawn.animate(replay.keeper, "save", if offside then 0 else dive)
			end
		end

		if not entry then return end
		local elapsed = clock - entry.start
		local movement = elapsed - PREP
		if reduced or movement >= STEP * entry.steps + SETTLE then
			if entry.bounced < entry.steps then playSound("land") end
			finishFlight()
			return
		end
		local beat = math.clamp(math.floor(movement / STEP), 0, entry.steps - 1)
		local k = math.clamp(movement / STEP - beat, 0, 1)
		local a = if beat == 0 then entry.origin else position(Game.target(entry.from, beat))
		local b = if beat + 1 == entry.steps then entry.destination else position(Game.target(entry.from, beat + 1))
		local travel = a:Lerp(b, k * k * (3 - 2 * k))
		local direction = b - a
		local yaw = math.atan2(direction.X, direction.Z)
		if movement < 0 then
			local prep = elapsed / PREP
			entry.model:PivotTo(CFrame.new(a - direction.Unit * (.36 * math.sin(math.pi * prep))) * CFrame.Angles(.13 * prep, yaw, 0))
			Pawn.animate(entry.model, "launch", prep)
			return
		end
		local hop = math.sin(math.pi * k)
		local lean = -.26 * hop
		entry.shadow.Position = Vector3.new(travel.X, Art.tileTop + .017, travel.Z)
		entry.shadow.Transparency = .53 + .22 * hop
		local ending = movement >= STEP * entry.steps
		if ending then
			local ease = math.clamp((movement - STEP * entry.steps) / SETTLE, 0, 1)
			entry.model:PivotTo((CFrame.new(b) * CFrame.Angles(.12 * math.sin(math.pi * ease), yaw, 0)):Lerp(settled(b), ease))
			Pawn.animate(entry.model, "land", ease)
		else
			entry.model:PivotTo(CFrame.new(travel + Vector3.yAxis * (hop ^ 1.30 * 1.51)) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(lean, 0, 0))
			Pawn.pose(entry.model, (beat + k + .3) * math.pi, 1)
		end
		local landed = if ending then entry.steps else beat
		if landed > 0 and landed > entry.bounced then
			entry.bounced = landed
			if ending or landed % 2 == 1 then playSound(if ending then "land" else "step") end
			pulse(if ending then entry.destination else position(Game.target(entry.from, landed)), entry.color, ending)
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

	local function playShot(outcome: string, scorer: number, figure: number, impact: () -> ())
		if reduced then
			impact()
			return
		end
		if shot and not shot.resolved then shot.impact() end
		clearShot()
		local actors = Instance.new("Folder")
		actors.Name, actors.Parent = "Matchday players", effects
		local shooter = Pawn.make(figure, actors, true)
		local keeper = Pawn.make(4, actors, true, C("E3AE4A"))
		shooter.Name, keeper.Name = "Striker", "Goalkeeper"
		shooter:ScaleTo(2.36)
		keeper:ScaleTo(2.22)
		shooter:PivotTo(CFrame.new(-21, -.50, 2.6) * CFrame.Angles(0, math.pi * .5, 0))
		keeper:PivotTo(CFrame.new(29.5, -.44, 0) * CFrame.Angles(0, -math.pi * .5, 0))
		local ball = Instance.new("Model")
		ball.Name, ball.Parent = "Matchday ball", effects
		local pivot = part(ball, "Ball pivot", Vector3.one * .05, Vector3.zero, Art.paper)
		pivot.Transparency, ball.PrimaryPart = 1, pivot
		local fallback = Instance.new("Folder")
		fallback.Parent = ball
		local core = part(fallback, "Ball", Vector3.one * 2.86, Vector3.zero, Art.paper)
		core.Shape = Enum.PartType.Ball
		for i = 1, 5 do
			local angle = i * TAU / 5
			local marking = part(fallback, "Panel", Vector3.one * .84, Vector3.new(math.cos(angle) * .85, .50 * (-1) ^ i, math.sin(angle) * .85), Art.ink)
			marking.Shape = Enum.PartType.Ball
		end
		decorated(ball, "Stitched football", "ball", Vector3.one * 2.86, Vector3.zero, fallback)
		local top, bottom = Instance.new("Attachment"), Instance.new("Attachment")
		top.Position, bottom.Position = Vector3.yAxis * .53, -Vector3.yAxis * .53
		top.Parent, bottom.Parent = pivot, pivot
		local trail = Instance.new("Trail")
		trail.Name, trail.Attachment0, trail.Attachment1 = "Ball flight", top, bottom
		trail.Lifetime, trail.MinLength, trail.FaceCamera = .16, .18, true
		trail.Color = ColorSequence.new(Art.gold, Art.paper)
		trail.Transparency = NumberSequence.new(.25, 1)
		trail.Enabled, trail.Parent = false, pivot
		ball:PivotTo(CFrame.new(SHOT_START))
		local shadow = medallion(actors, "Ball contact shadow", Vector3.new(SHOT_START.X, .411, SHOT_START.Z), 2.6, .02, Art.ink)
		shadow.Transparency = .57
		shot = {ball = ball, actors = actors, shadow = shadow, trail = trail, shooter = shooter, keeper = keeper,
			start = os.clock(), outcome = outcome, scorer = scorer, released = false, resolved = false, impact = impact}
	end

	return {
		sync = sync,
		relocalize = function()
			labels.translate()
			projectedCamera = nil
		end,
		pickTile = function(point: Vector3): number?
			if replayFraming then return nil end
			local camera = workspace.CurrentCamera
			if not camera then return nil end
			local ray = camera:ScreenPointToRay(point.X, point.Y)
			if math.abs(ray.Direction.Y) < .001 then return nil end
			local distance = (Art.tileTop - ray.Origin.Y) / ray.Direction.Y
			if distance < 0 then return nil end
			local hit = ray.Origin + ray.Direction * distance
			for index, tile in Geometry.cells do
				if math.abs(tile.X - hit.X) <= Art.tileWidth * .5 and math.abs(tile.Z - hit.Z) <= Art.tileDepth * .5 then
					return index
				end
			end
			return nil
		end,
		celebrate = celebrate,
		playShot = playShot,
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
