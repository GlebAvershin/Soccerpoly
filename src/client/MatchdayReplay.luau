--!strict
local TweenService = game:GetService("TweenService")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("League")
local Art = require(shared.Presentation)
local Pawn = require(script.Parent.Pawn)
local Meshes = require(script.Parent.MeshLibrary)
local C = Color3.fromHex
local TAU = math.pi * 2
local SHOT_RELEASE, SHOT_IMPACT, SHOT_END = .29, .80, 1.66
local SHOT_START = Vector3.new(-11.5, 1.55, 2.6)

type Shot = {
	actors: Folder, ball: Model, shadow: Part, trail: Trail, shooter: Model, keeper: Model, start: number,
	outcome: string, released: boolean, resolved: boolean, impact: () -> (),
}

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

local function goal(actors: Folder)
	local fallback = Instance.new("Folder")
	fallback.Parent = actors
	local front, back, floor, top, half = 37.5, 42.4, .31, 7.6, 9
	local function cord(name: string, a: Vector3, b: Vector3, thickness: number)
		local beam = part(fallback, name, Vector3.new(thickness, thickness, (a - b).Magnitude), (a + b) * .5, Art.paper)
		beam.CFrame = CFrame.lookAt(beam.Position, b)
	end
	for _, z in {-half, half} do
		cord("Goalpost", Vector3.new(front, floor, z), Vector3.new(front, top, z), .27)
		cord("Brace", Vector3.new(front, top, z), Vector3.new(back, floor, z), .12)
	end
	cord("Crossbar", Vector3.new(front, top, -half), Vector3.new(front, top, half), .27)
	for i = -6, 6 do
		local z = half * i / 6
		cord("Net cord", Vector3.new(front, top, z), Vector3.new(back, floor, z), .055)
	end
	for i = 1, 6 do
		local t = i / 7
		local x, y = front + (back - front) * t, top - (top - floor) * t
		cord("Net weft", Vector3.new(x, y, -half), Vector3.new(x, y, half), .067)
	end
	decorated(actors, "Matchday goal", "goal", Vector3.new(5.4, 7.65, 18.5), Vector3.new(40.1, 4.10, 0), fallback)
end

local function kickMarks(parent: Instance)
	local origin = SHOT_START - Vector3.yAxis * 1.13
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

return function(effects: Folder, playSound: (string) -> ())
	local shot: Shot? = nil
	local function clear()
		if not shot then return end
		shot.ball:Destroy()
		shot.actors:Destroy()
		shot = nil
	end

	local function playShot(outcome: string, figure: number, impact: () -> (), reduced: boolean)
		if reduced then
			playSound(outcome)
			impact()
			return
		end
		if shot and not shot.resolved then shot.impact() end
		clear()
		local actors = Instance.new("Folder")
		actors.Name, actors.Parent = "Matchday players", effects
		goal(actors)
		local shooter = Pawn.make(figure, actors, true)
		local keeper = Pawn.make(4, actors, true, C("E3AE4A"))
		shooter.Name, keeper.Name = "Striker", "Goalkeeper"
		shooter:ScaleTo(2.36)
		keeper:ScaleTo(2.22)
		shooter:PivotTo(CFrame.new(-21, -.50, 2.6) * CFrame.Angles(0, math.pi * .5, 0))
		keeper:PivotTo(CFrame.new(33, -.40, 0) * CFrame.Angles(0, -math.pi * .5, 0))
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
		trail.Lifetime, trail.MinLength, trail.FaceCamera = .14, .16, true
		trail.Color = ColorSequence.new(Art.paper, Art.mint)
		trail.Transparency = NumberSequence.new(.14, 1)
		trail.WidthScale = NumberSequence.new(.86, .07)
		trail.Enabled, trail.Parent = false, pivot
		ball:PivotTo(CFrame.new(SHOT_START))
		local shadow = medallion(actors, "Ball contact shadow", Vector3.new(SHOT_START.X, .411, SHOT_START.Z), 2.6, .02, Art.ink)
		shadow.Transparency = .57
		shot = {ball = ball, actors = actors, shadow = shadow, trail = trail, shooter = shooter, keeper = keeper,
			start = os.clock(), outcome = outcome, released = false, resolved = false, impact = impact}
	end

	local function step(clock: number, reduced: boolean)
		local replay = shot
		if replay then
			local elapsed = clock - replay.start
			local saved, offside = replay.outcome == "save", replay.outcome == "offside"
			local target = if offside then Vector3.new(20, 1.00, -9) elseif saved then Vector3.new(31.6, 1.85, -1.85)
				else Vector3.new(39.7, 1.55, 1.40)
			if elapsed >= SHOT_RELEASE and not replay.released then
				replay.released = true
				replay.trail.Enabled = not reduced
				playSound("kick")
				if not reduced then kickMarks(replay.actors) end
			end
			if (reduced or elapsed >= SHOT_IMPACT) and not replay.resolved then
				replay.resolved = true
				replay.trail.Enabled = false
				playSound(replay.outcome)
				if not reduced and not offside then netImpact(replay.actors, target, saved) end
				replay.impact()
			end
			if reduced or elapsed >= SHOT_END then
				clear()
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
				local celebrating = replay.outcome == "goal" and replay.resolved
				local turnToCrowd = if celebrating then .98 * (1 - (1 - settle) ^ 3) else 0
				replay.shooter:PivotTo(CFrame.new(strikerX, -.52, 2.6) * CFrame.Angles(0, math.pi * .5 - turnToCrowd, 0))
				if celebrating then
					Pawn.animate(replay.shooter, "cheer", .18 + settle * .66)
				else
					Pawn.animate(replay.shooter, "kick", math.clamp(elapsed / .55, 0, 1))
				end
				local dive = math.clamp((elapsed - .44) / .62, 0, 1)
				local spring = math.sin(dive * math.pi)
				local keeperZ = if offside then 0 elseif saved then -2.6 else 3.05
				local lean = if offside then 0 else (if saved then .62 else -.56) * spring
				replay.keeper:PivotTo(CFrame.new(33 - (if saved then 1.8 else .3) * spring, -.44 + spring * .91, keeperZ * spring)
					* CFrame.Angles(lean, -math.pi * .5, 0))
				Pawn.animate(replay.keeper, "save", if offside then 0 else dive)
			end
		end
	end

	local function framing(camera: Camera): CFrame?
		if not shot then return nil end
		local aspect = camera.ViewportSize.X / camera.ViewportSize.Y
		local portrait = aspect < .9
		local fov = if portrait then 29 else 23
		local distance = math.max(88, 68 / (2 * math.tan(math.rad(fov) * .5) * aspect * .87))
		local orbit = Vector3.new(if portrait then .53 else .25, if portrait then .42 else .34, 1).Unit
		local target = Vector3.new(9, 4, 0)
		camera.FieldOfView = fov
		camera.Focus = CFrame.new(target)
		return CFrame.lookAt(target + orbit * distance, target)
	end

	return {play = playShot, step = step, framing = framing, clear = clear}
end
