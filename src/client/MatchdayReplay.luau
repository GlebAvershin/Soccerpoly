--!strict
local TweenService = game:GetService("TweenService")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("League")
local Art = require(shared.Presentation)
local Goal = require(script.Parent.ReplayGoal)
local stadiumSet = require(script.Parent.ReplayStadium)
local Board = require(shared.TourBoard)
local Pawn = require(script.Parent.Pawn)
local Meshes = require(script.Parent.MeshLibrary)
local C = Color3.fromHex
local TAU = math.pi * 2
local SHOT_RELEASE, SHOT_IMPACT, SHOT_END = .29, .80, 1.66
local BALL_RADIUS, TURF = 1.02, .34
local KEEPER_SCALE, STRIKER_SCALE = 1.44, 1.48

type Shot = {
	actors: Folder, ball: Model, shadow: Part, trail: Trail, shooter: Model, keeper: Model, start: number,
	outcome: string, figure: number, released: boolean, resolved: boolean, impact: () -> (),
	origin: Vector3, target: Vector3, elapsed: number, net: (number) -> (), flag: ((number) -> ())?,
	hiddenPieces: {[BasePart]: number}, added: {RBXScriptConnection},
}

local function phase(t: number, start: number, finish: number): number
	return math.clamp((t-start)/(finish-start), 0, 1)
end

local function smooth(t: number): number
	return t*t*(3-2*t)
end

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

local function decorated(parent: Instance, name: string, shape: string, size: Vector3, at: Vector3, fallback: Instance)
	local marker = part(parent, name, size, at, Color3.new(1, 1, 1))
	marker.Transparency = 1
	marker:SetAttribute("MeshPlaceholder", true)
	Meshes.apply(shape, marker, {fallback})
end

local function kickMarks(parent: Instance, origin: Vector3)
	origin = Vector3.new(origin.X, TURF+.08, origin.Z)
	for i = 1, 7 do
		local angle = i * TAU / 7
		local direction = Vector3.new(math.cos(angle) - .65, 0, math.sin(angle))
		local chip = part(parent, "Boot impact", Vector3.new(.30, .062, .15), origin + direction * .50, Art.mint)
		chip.Transparency = .20
		TweenService:Create(chip, TweenInfo.new(.29, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Position = origin + direction * (1.1 + i % 3 * .5) + Vector3.yAxis * .51, Transparency = 1}):Play()
		task.delay(.31, function() chip:Destroy() end)
	end
end

local function netImpact(parent: Instance, at: Vector3, saved: boolean)
	local effect = Instance.new("Folder")
	effect.Name, effect.Parent = if saved then "Glove impact" else "Goal net burst", parent
	local warm, cool = if saved then C("83DDF6") else Art.gold, if saved then Art.paper else Art.mint
	-- Paint the impact on the plane of the net. A fan of shallow dashes avoids covering the ball.
	local center = Vector3.new(at.X - .27, math.max(at.Y, 1.65), at.Z)
	for i = 1, 12 do
		local angle = i * TAU / 12
		local ray = Vector3.new(0, math.sin(angle), math.cos(angle))
		local lamp = part(effect, "Impact streak", Vector3.new(.055, .055, if saved then .57 else .97),
			center + ray * .83, if i % 3 == 0 then cool else warm, Enum.Material.Neon)
		lamp.CFrame = CFrame.lookAt(lamp.Position, lamp.Position + ray)
		TweenService:Create(lamp, TweenInfo.new(.37, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{Position = center + ray * (if saved then 2.15 else 3.08), Transparency = 1}):Play()
	end
	if saved then return end
	for i = 1, 18 do
		local angle = i * TAU / 18
		local scatter = Vector3.new(-.62 - (i % 3) * .16, 0, math.sin(angle)) * (2.8 + i % 5)
		local chip = part(effect, "Goal streamer", Vector3.new(.11, .68, .25), center + Vector3.yAxis * 1.18,
			if i % 4 == 0 then C("B797FF") elseif i % 3 == 0 then warm else cool, Enum.Material.Neon)
		local target = center + scatter + Vector3.yAxis * (2.3 + i % 4 * .76)
		TweenService:Create(chip, TweenInfo.new(.38, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{CFrame = CFrame.new(target) * CFrame.Angles(angle, angle * .73, i * .21)}):Play()
		task.delay(.34, function()
			if chip.Parent then
				TweenService:Create(chip, TweenInfo.new(.40, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{Position = target + scatter * .38 - Vector3.yAxis * 2.4, Transparency = 1}):Play()
			end
		end)
	end
end

local function keeperPose(keeper: Model, elapsed: number, outcome: string)
	local dive = outcome ~= "offside"
	local coil = smooth(phase(elapsed, .16, .42))
	local launch = if dive then smooth(phase(elapsed, .42, .85)) else 0
	local land = if dive then smooth(phase(elapsed, .84, 1.15)) else 0
	local brace = smooth(phase(elapsed, 1.20, SHOT_END))
	local rotation = -math.rad(70)*launch - math.rad(10)*land + math.rad(12)*land*brace
	local hip = 3.27 * KEEPER_SCALE
	local y = hip - .30 - .68*coil + 2.04*launch - 3.17*land + .26*land*brace
	local startZ = if outcome == "goal" then -4.2 elseif dive then -.4 else 0
	local z = startZ + 5.5*launch + 1.1*land
	keeper:PivotTo(CFrame.new(34.5-1.8*launch-.6*land, y, z) * CFrame.Angles(0, -math.pi*.5, 0)
		* CFrame.Angles(0, 0, rotation) * CFrame.new(0, -hip, 0))
	Pawn.animate(keeper, "save", .06 + .16*coil + .31*launch + .20*land + .05*land*brace)
end

local function strikerPose(model: Model, figure: number, elapsed: number, celebrate: boolean)
	local approach = smooth(phase(elapsed, 0, SHOT_RELEASE))
	local follow = smooth(phase(elapsed, SHOT_RELEASE, .65))
	local recovery = phase(elapsed, SHOT_IMPACT, SHOT_END)
	local shootingLane = if Board.figures[figure].leftFoot then 1.7 else 3.5
	local turn = if celebrate then 1.25*smooth(recovery) else 0
	local lift = if celebrate and figure == 2 then math.sin(math.pi*phase(recovery, 0, .74))*.84 else 0
	model:PivotTo(CFrame.new(-19+5.7*approach+1.25*follow, -.28+lift, shootingLane)
		* CFrame.Angles(0, math.pi*.5-turn, 0))
	if celebrate then
		local transition = smooth(math.clamp(recovery * 4.5, 0, 1))
		Pawn.crossfade(model, "kick", 1, "cheer", .10 + recovery * .82, transition)
	else
		Pawn.animate(model, "kick", math.clamp(elapsed/.60, 0, 1))
	end
end

local function markOffside(parent: Folder): (number) -> ()
	local official = Pawn.make(4, parent, true, C("F17B47"))
	official.Name = "Assistant referee"
	for _, name in {"Left elbow", "Right elbow"} do
		local arm = official:FindFirstChild(name) :: Model
		local glove = arm:FindFirstChild("Palm") :: BasePart
		local hand = part(arm, "Hand", Vector3.new(.36,.46,.34), glove.Position, C("955C43"))
		hand.Shape, hand.CFrame = Enum.PartType.Ball, glove.CFrame
		for _, detail in {"Palm","Keeper palm shield","Glove cuff","Thumb padding"} do
			local piece = arm:FindFirstChild(detail)
			if piece then piece:Destroy() end
		end
	end
	official:ScaleTo(1.24)
	official:PivotTo(CFrame.new(28, -.18, -18.3) * CFrame.Angles(0, -.22, 0))
	Pawn.animate(official, "idle", .25, .3)
	local shoulder = official:FindFirstChild("Right arm") :: Model
	local elbow = official:FindFirstChild("Right elbow") :: Model
	local palm = elbow:FindFirstChild("Hand") :: BasePart
	local base = shoulder:GetPivot()
	local forearm = base:ToObjectSpace(elbow:GetPivot())
	local palmOffset = elbow:GetPivot():PointToObjectSpace(palm.Position)
	local flag = Instance.new("Model")
	flag.Name, flag.Parent = "Assistant flag", parent
	local shaft = part(flag, "Flag staff", Vector3.new(.14,3.5,.14), Vector3.yAxis*1.75, C("263243"))
	local grip = part(flag, "Grip", Vector3.new(.22,.65,.22), Vector3.zero, Art.ink)
	flag.PrimaryPart = grip
	for col = 0, 3 do
		local x = .32 + .62*col
		for row = 0, 1 do
			local panel = part(flag, "Woven check", Vector3.new(.64,.78,.075),
				Vector3.new(x, 2.22+.77*row-.07*col, .14*math.sin(col*1.1)),
				if (row+math.floor(col/2))%2 == 0 then C("FBAD31") else C("FA543D"))
			panel.CFrame *= CFrame.Angles(0,.18*math.cos(col*1.1),-.09)
		end
	end
	shaft.CastShadow = true
	local line = part(parent, "Offside line", Vector3.new(.16,.035,34), Vector3.new(28,TURF+.085,0), C("FFC75D"), Enum.Material.Neon)
	line.Transparency = 1
	return function(elapsed: number)
		local lift = smooth(phase(elapsed, SHOT_IMPACT-.10, SHOT_IMPACT+.21))
		local raised = base * CFrame.Angles(-.22, 0, math.rad(147)*lift)
		shoulder:PivotTo(raised)
		local elbowPose = raised*forearm
		elbow:PivotTo(elbowPose)
		local hand = elbowPose:PointToWorldSpace(palmOffset)
		flag:PivotTo(CFrame.new(hand) * CFrame.Angles(0,-.22,math.rad(-136+129*lift)))
		line.Transparency = 1-.77*lift
	end
end

local function hideTable(): ({[BasePart]: number}, {RBXScriptConnection})
	local hidden: {[BasePart]: number} = {}
	local added: {RBXScriptConnection} = {}
	local function hide(piece: Instance)
		if piece:IsA("BasePart") then
			hidden[piece] = piece.LocalTransparencyModifier
			piece.LocalTransparencyModifier = 1
		end
	end
	local function group(container: Instance?)
		if not container then return end
		for _, piece in container:GetDescendants() do hide(piece) end
		table.insert(added, container.DescendantAdded:Connect(hide))
	end
	local arena = workspace:FindFirstChild("WorldDraftArena")
	local stadium = arena and arena:FindFirstChild("Continental Cup stadium")
	if stadium then
		group(stadium:FindFirstChild("West goal"))
		group(stadium:FindFirstChild("East goal"))
	end
	group(if arena then arena:FindFirstChild("Board") else nil)
	local localPieces = workspace:FindFirstChild("LocalTablePieces")
	group(if localPieces then localPieces:FindFirstChild("Markers") else nil)
	return hidden, added
end

return function(effects: Folder, playSound: (string) -> ())
	local shot: Shot? = nil
	local function clear()
		if not shot then return end
		for _, connection in shot.added do connection:Disconnect() end
		for piece, transparency in shot.hiddenPieces do
			if piece.Parent then piece.LocalTransparencyModifier = transparency end
		end
		shot.ball:Destroy()
		shot.actors:Destroy()
		shot = nil
	end

	local function playShot(outcome: string, figure: number, impact: () -> (), reduced: boolean)
		if shot and not shot.resolved then shot.impact() end
		clear()
		if reduced then
			playSound(outcome)
			impact()
			return
		end
		local actors = Instance.new("Folder")
		actors.Name, actors.Parent = "Matchday players", effects
		stadiumSet(actors)
		local net = Goal.make(actors)
		local shooter = Pawn.make(figure, actors, true)
		local keeper = Pawn.make(4, actors, true, C("EBB449"))
		shooter.Name, keeper.Name = "Striker", "Goalkeeper"
		shooter:ScaleTo(STRIKER_SCALE)
		keeper:ScaleTo(KEEPER_SCALE)
		-- Sample actual extremities in their contact poses. The release point follows
		-- the selected player's stature, footwear, preferred foot and baked kick.
		strikerPose(shooter, figure, SHOT_RELEASE, false)
		local foot = shooter:FindFirstChild(if Board.figures[figure].leftFoot then "Left ankle" else "Right ankle") :: Model
		local boot = foot:FindFirstChild("Molded outsole") :: BasePart
		local origin = Vector3.new(boot.Position.X+boot.Size.Z*.39+BALL_RADIUS*.72, TURF+BALL_RADIUS, boot.Position.Z)
		local target = Goal.target - Vector3.xAxis*BALL_RADIUS
		if outcome == "save" then
			keeperPose(keeper, SHOT_IMPACT, outcome)
			local left = (keeper:FindFirstChild("Left elbow") :: Model):FindFirstChild("Palm") :: BasePart
			local right = (keeper:FindFirstChild("Right elbow") :: Model):FindFirstChild("Palm") :: BasePart
			local glove = if right.Position.Z > left.Position.Z then right else left
			target = glove.Position - Vector3.xAxis*(BALL_RADIUS+glove.Size.Z*.31)
		elseif outcome == "offside" then
			target = Vector3.new(41, TURF+BALL_RADIUS, -16.4)
		end
		strikerPose(shooter, figure, 0, false)
		keeperPose(keeper, 0, outcome)
		local flag = if outcome == "offside" then markOffside(actors) else nil
		if flag then flag(0) end
		local hidden, added = hideTable()
		local ball = Instance.new("Model")
		ball.Name, ball.Parent = "Matchday ball", effects
		local pivot = part(ball, "Ball pivot", Vector3.one * .05, Vector3.zero, Art.paper)
		pivot.Transparency, ball.PrimaryPart = 1, pivot
		local fallback = Instance.new("Folder")
		fallback.Parent = ball
		local core = part(fallback, "Ball", Vector3.one * BALL_RADIUS * 2, Vector3.zero, Art.paper)
		core.Shape = Enum.PartType.Ball
		for i = 1, 5 do
			local angle = i * TAU / 5
			local marking = part(fallback, "Panel", Vector3.one * .58, Vector3.new(math.cos(angle) * .82, .38 * (-1) ^ i, math.sin(angle) * .82), Art.ink)
			marking.Shape = Enum.PartType.Ball
		end
		decorated(ball, "Stitched football", "ball", Vector3.one * BALL_RADIUS * 2, Vector3.zero, fallback)
		local top, bottom = Instance.new("Attachment"), Instance.new("Attachment")
		top.Position, bottom.Position = Vector3.yAxis * .53, -Vector3.yAxis * .53
		top.Parent, bottom.Parent = pivot, pivot
		local trail = Instance.new("Trail")
		trail.Name, trail.Attachment0, trail.Attachment1 = "Ball flight", top, bottom
		trail.Lifetime, trail.MinLength, trail.FaceCamera = .105, .16, true
		trail.Color = ColorSequence.new(Art.paper, Art.mint)
		trail.Transparency = NumberSequence.new(.14, 1)
		trail.WidthScale = NumberSequence.new(.86, .07)
		trail.Enabled, trail.Parent = false, pivot
		ball:PivotTo(CFrame.new(origin))
		local shadow = medallion(actors, "Ball contact shadow", Vector3.new(origin.X, .411, origin.Z), 1.84, .02, Art.ink)
		shadow.Transparency = .57
		shot = {ball = ball, actors = actors, shadow = shadow, trail = trail, shooter = shooter, keeper = keeper,
			start = os.clock(), outcome = outcome, figure = figure, released = false, resolved = false, impact = impact,
			origin = origin, target = target, elapsed = 0, net = net, flag = flag, hiddenPieces = hidden, added = added}
	end

	local function step(clock: number, reduced: boolean)
		local replay = shot
		if not replay then return end
		local elapsed = clock - replay.start
		replay.elapsed = elapsed
		local saved, offside = replay.outcome == "save", replay.outcome == "offside"
		if elapsed >= SHOT_RELEASE and not replay.released and not reduced then
			replay.released = true
			replay.trail.Enabled = true
			playSound("kick")
			kickMarks(replay.actors, replay.origin)
		end
		if (reduced or elapsed >= SHOT_IMPACT) and not replay.resolved then
			replay.resolved = true
			playSound(replay.outcome)
			if not reduced and not offside then netImpact(replay.actors, replay.target, saved) end
			replay.impact()
		end
		if reduced or elapsed >= SHOT_END then clear(); return end
		local flight = phase(elapsed, SHOT_RELEASE, SHOT_IMPACT)
		local settle = phase(elapsed, SHOT_IMPACT, SHOT_END)
		local after = math.max(elapsed-SHOT_IMPACT, 0)
		local travel = replay.origin:Lerp(replay.target, flight)
		travel += Vector3.new(0, 4*flight*(1-flight)*(if saved then 1.4 else 2.45), 2.2*math.sin(math.pi*flight))
		if replay.resolved then
			if saved then
				local parry = 1-(1-settle)^1.6
				travel += Vector3.new(-14,0,11)*parry
				travel = Vector3.new(travel.X, math.max(TURF+BALL_RADIUS,
					replay.target.Y+5*after-13*after*after), travel.Z)
			elseif offside then
				travel += Vector3.new(3.4,0,-2.0)*(1-(1-settle)^2)
			else
				replay.net(after)
				local press = math.max(0, 4.3*math.exp(-after*5.8)*math.sin(after*17))
				local drop = smooth(phase(after, .08, .59))
				travel += Vector3.new(press-2.3*drop, (TURF+BALL_RADIUS-replay.target.Y)*drop, -.75*drop)
			end
		end
		replay.trail.Enabled = replay.released and (not replay.resolved or (saved and after < .23))
		replay.ball:PivotTo(CFrame.new(travel) * CFrame.Angles(flight*7+settle*3, 0, flight*3))
		replay.shadow.Position = Vector3.new(travel.X, TURF+.071, travel.Z)
		replay.shadow.Transparency = .47+math.clamp((travel.Y-1.4)*.055, 0, .38)
		strikerPose(replay.shooter, replay.figure, elapsed, replay.outcome == "goal" and replay.resolved)
		keeperPose(replay.keeper, elapsed, replay.outcome)
		if replay.flag then replay.flag(elapsed) end
	end

	local function framing(camera: Camera): CFrame?
		if not shot then return nil end
		local aspect = camera.ViewportSize.X / math.max(1, camera.ViewportSize.Y)
		local portrait = math.clamp((1.28-aspect)/.72, 0, 1)
		local track = smooth(phase(shot.elapsed, SHOT_RELEASE+.015, SHOT_IMPACT+.06))
		local startTarget = Vector3.new(7-15*portrait, 4.15, 0)
		local endTarget = Vector3.new(30.7, 4.25, if shot.outcome == "offside" then -2.5 else 2)
		local target = startTarget:Lerp(endTarget, track)
		local orbit = Vector3.new(-.87-1.75*portrait, .52+.33*portrait, 1).Unit
		local fov = 32+4*portrait
		local width = (59-27*portrait)*(1-track) + (40-10*portrait)*track
		local distance = math.max(45, width/(2*math.tan(math.rad(fov)*.5)*aspect*.84))
		if shot.resolved and (shot.outcome == "goal" or shot.outcome == "save") then
			local trauma = math.clamp(1 - (shot.elapsed - SHOT_IMPACT) / .34, 0, 1)
			if trauma > 0 then
				local shake = trauma * trauma
				local t = shot.elapsed * 42
				local kickX = math.sin(t * 1.6) * .55 * shake
				local kickY = math.cos(t * 2.1) * .42 * shake
				target += Vector3.new(0, kickY, kickX)
			end
		end
		camera.FieldOfView, camera.Focus = fov, CFrame.new(target)
		return CFrame.lookAt(target+orbit*distance, target)
	end

	return {play = playShot, step = step, framing = framing, clear = clear}
end
