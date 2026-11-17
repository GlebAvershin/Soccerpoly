--!strict
local shared = game:GetService("ReplicatedStorage"):WaitForChild("League")
local Board = require(shared.TourBoard)
local Art = require(shared.Presentation)
local Meshes = require(script.Parent.MeshLibrary)
local Motion = require(script.Parent.PawnMotionData)
local Pawn = {}
local C = Color3.fromHex

type Joint = {model: Model, rest: CFrame, parent: number?}
type Rig = {Joint}
-- Map the sculpt proportions and all joint pivots through the same measurements.
local function height(y: number): number
	return if y <= .45 then y elseif y <= 2.20 then .45 + (y - .45) * 1.38 else 2.865 + (y - 2.20) * 1.035
end

local function point(x: number, y: number, z: number): Vector3
	return Vector3.new(x * .87, height(y), z * .94)
end

local rigs: {[Model]: Rig} = setmetatable({}, {__mode = "k"}) :: any

function Pawn.make(figure: number, parent: Instance, onPitch: boolean?, uniform: Color3?): Model
	local def = Board.figures[figure]
	local kit, trim, skin, hair = uniform or Art.hex(def.color), Art.hex(def.dark), Art.hex(def.skin), Art.hex(def.hair)
	local ivory, rubber = C("F2F5E4"), C("232436")
	local accent = if figure == 6 then C("F7D269") elseif figure == 4 then C("E2FF86") else ivory
	local sleeveColor = if figure == 5 then trim elseif figure == 6 then trim:Lerp(kit, .4) else kit
	local stripeColor = kit:Lerp(trim, .69)
	local model = Instance.new("Model")
	model.Name = def.name
	local container: Instance = model

	local function piece(name: string, w: number, h: number, d: number, x: number, y: number, z: number, color: Color3,
		shape: Enum.PartType?, tilt: number?): Part
		local p = Instance.new("Part")
		local stand = container == model
		local size = if stand then Vector3.new(w, h, d)
			else Vector3.new(w * .87, height(y + h * .5) - height(y - h * .5), d * .94)
		p.Name, p.Size, p.Color = name, size, color
		p.Shape = shape or Enum.PartType.Block
		p.CFrame = CFrame.new(if stand then Vector3.new(x, y, z) else point(x, y, z)) * CFrame.Angles(0, 0, tilt or 0)
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
		p.Parent = container
		return p
	end
	local function soft(name: string, w: number, h: number, d: number, x: number, y: number, z: number, color: Color3, tilt: number?): Part
		return piece(name, w, h, d, x, y, z, color, Enum.PartType.Ball, tilt)
	end
	local function joint(name: string, x: number, y: number, z: number, parentIndex: number?): Joint
		local group = Instance.new("Model")
		group.Name, group.Parent = name, model
		container = group
		return {model = group, rest = CFrame.new(point(x, y, z)), parent = parentIndex}
	end

	local root = piece("Root", .08, .08, .08, 0, 0, 0, rubber)
	root.Transparency, root.CastShadow, model.PrimaryPart = 1, false, root
	if not onPitch then
		for i, ring in {{.18, 3.16, .10}, {.08, 3.22, .23}, {.15, 3.00, .337}, {.025, 2.79, .424}} do
			local color = if i == 1 then rubber elseif i == 2 then kit elseif i == 3 then trim else trim:Lerp(kit, .42)
			local base = piece("Turntable " .. i, ring[1], ring[2], ring[2], 0, ring[3], 0, color, Enum.PartType.Cylinder, math.pi * .5)
			if i == 1 then base.Material = Enum.Material.Metal end
		end
	end

	local thighs: {Joint}, arms: {Joint}, knees: {Joint}, elbows: {Joint}, boots: {Joint} = {}, {}, {}, {}, {}
	for i, side in {-1, 1} do
		local x = side * .43
		local prefix = if side < 0 then "Left " else "Right "
		local thigh = joint(prefix .. "leg", x, 2.14, 0)
		Meshes.apply("shorts", soft("Tailored short", .81, .89, .84, x, 2.04, .005, trim, side * .044))
		if figure ~= 5 then
			piece("Short side braid", .065, .40, .18, x + side * .367, 2.04, .17, stripeColor, nil, side * .07)
		end
		thigh.model.WorldPivot = thigh.rest
		thighs[i] = thigh
		local knee = joint(prefix .. "knee", x, 1.419, .014, 4 + i)
		soft("Knee", .50, .44, .52, x * 1.07, 1.53, .03, if figure == 5 then trim else skin)
		Meshes.apply("sock", soft("Ribbed sock", .48, .91, .53, x * 1.08, 1.125, .045, if figure == 5 then trim else kit))
		for i = 0, 1 do
			soft("Sock cuff stripe", .492, .054, .55, x * 1.08, 1.405 - i * .077, .045, accent)
		end
		knee.model.WorldPivot = knee.rest
		knees[i] = knee
		local ankle = joint(prefix .. "ankle", x, .698, .014, 8 + i)
		Meshes.apply("outsole", soft("Molded outsole", .78, .18, 1.11, x * 1.15, .50, .25, rubber))
		for _, stud in {-.13, .37} do
			soft("Cleat", .42, .12, .25, x * 1.15, .44, .28 + stud, kit)
		end
		local boot = soft("Leather boot", .75, .49, 1.12, x * 1.15, .69, .26, trim:Lerp(rubber, .46))
		Meshes.apply("boot", boot)
		Meshes.apply("bootpanel", soft("Boot toe inlay", .48, .22, .10, x * 1.15, .692, .747, kit))
		piece("Heel counter", .35, .20, .055, x * 1.15, .68, -.216, stripeColor).CastShadow = false
		for seam = 1, 3 do
			soft("Boot lace", .29, .04, .067, x * 1.15, .92 - seam * .032, .22 + seam * .13, ivory).CastShadow = false
		end
		ankle.model.WorldPivot = ankle.rest
		boots[i] = ankle
	end

	local body = joint("Torso", 0, 2.18, 0)
	soft("Waist", 1.52, .74, .93, 0, 2.34, .005, trim)
	Meshes.apply("jersey", soft("Jersey", 2.24, 1.74, 1.32, 0, 3.00, 0, kit))
	soft("Neck", .61, .53, .67, 0, 3.90, -.015, skin)
	Meshes.apply("collar", soft("Woven collar", 1.10, .51, .36, 0, 3.64, .517, if figure == 5 then trim else accent))
	soft("Back neckline", 1.01, .20, .72, 0, 3.77, -.08, trim)
	if figure == 1 or figure == 3 then
		soft("Two-tone sash", .31, 1.16, .095, .07, 3.08, .627, stripeColor, if figure == 1 then .49 else -.49)
		piece("Sash piping", .053, .92, .024, .25, 3.12, .666, accent, nil, if figure == 1 then .49 else -.49).CastShadow = false
	elseif figure == 2 or figure == 4 then
		for _, height in {3.35, 3.21} do
			soft("Chest stripe", 1.47, .116, .14, 0, height, .595, stripeColor)
		end
	else
		soft("Zip seam", .067, .96, .12, 0, 3.29, .618, trim)
		soft("Zip pull", .106, .17, .09, 0, 3.63, .652, ivory)
	end
	Meshes.apply("crest", soft("Woven crest", .25, .34, .043, -.50, 3.25, .620, trim))
	piece("Crest stitch", .073, .134, .025, -.50, 3.26, .654, accent, nil, -.22).CastShadow = false
	for _, front in {true, false} do
		local width, height = if front then .57 else .96, if front then .36 else .72
		local tag = piece(if front then "Front kit number" else "Back kit number", width, height, .02,
			if front then .39 else 0, if front then 3.14 else 3.10, if front then .688 else -.683, kit)
		tag.Transparency, tag.CastShadow = 1, false
		local gui = Instance.new("SurfaceGui")
		gui.Face = if front then Enum.NormalId.Back else Enum.NormalId.Front
		gui.SizingMode, gui.CanvasSize = Enum.SurfaceGuiSizingMode.FixedSize, Vector2.new(192, 192)
		gui.LightInfluence, gui.Parent = 0, tag
		local number = Instance.new("TextLabel")
		number.Size, number.BackgroundTransparency = UDim2.fromScale(1, 1), 1
		number.Font, number.TextScaled = Enum.Font.BuilderSansExtraBold, true
		number.TextColor3, number.Text = if front then trim else ivory, def.number
		number.Parent = gui
	end
	body.model.WorldPivot = body.rest

	for i, side in {-1, 1} do
		local prefix = if side < 0 then "Left " else "Right "
		local arm = joint(prefix .. "arm", side * .96, 3.45, 0)
		local glove, coach = figure == 4, figure == 5
		Meshes.apply("sleeve", soft("Sleeve", .83, .86, .82, side * 1.10, 3.30, .005, sleeveColor, side * .27))
		soft("Contrast piping", .69, .067, .72, side * 1.24, 3.11, .02, accent, side * .27)
		soft("Sleeve cuff", .69, .16, .72, side * 1.25, 3.035, .010, trim, side * .28)
		if figure == 1 and side == -1 then
			soft("Captain armband", .68, .14, .70, -1.15, 3.29, .008, accent, -.27)
		end
		arm.model.WorldPivot = arm.rest
		arms[i] = arm
		local elbow = joint(prefix .. "elbow", side * 1.239, 3.00, .08, 2 + i)
		Meshes.apply("forearm", soft("Bent forearm", .46, .82, .53, side * 1.30, 2.73, .13, if coach then kit else skin, side * .23))
		local hand = soft("Palm", if glove then .71 else .53, .55, .60, side * 1.37, 2.42, .23, if glove then ivory else skin)
		Meshes.apply(if glove then "glove" else "hand", hand)
		if figure == 3 then
			soft("Wrist tape", .43, .104, .50, side * 1.347, 2.58, .188, accent, side * .23)
		end
		if glove then
			Meshes.apply("glovepad", soft("Keeper palm shield", .38, .34, .072, side * 1.35, 2.425, .516, trim))
			soft("Glove cuff", .59, .22, .58, side * 1.35, 2.62, .21, trim, side * .22)
			soft("Thumb padding", .22, .29, .31, side * 1.60, 2.48, .35, ivory, side * .26)
		end
		if coach and side < 0 then
			piece("Tactics tablet", .73, .82, .14, -1.26, 2.57, .58, rubber, nil, .18)
			piece("Tactics screen", .58, .66, .021, -1.26, 2.57, .66, C("87C9A4"), nil, .18)
		elseif figure == 6 and side == 1 then
			piece("Referee card", .43, .62, .07, 1.38, 2.65, .51, Art.gold, nil, -.20)
		end
		elbow.model.WorldPivot = elbow.rest
		elbows[i] = elbow
	end

	local head = joint("Head", 0, 3.97, 0)
	local face = soft("Face", 1.76, 1.62, 1.58, 0, 4.58, .042, skin)
	local chin = soft("Chin", 1.27, .82, 1.22, 0, 4.25, .12, skin)
	local nose = soft("Nose", .28, .31, .29, 0, 4.47, .766, skin:Lerp(ivory, .17))
	Meshes.apply("head", face, {chin, nose})
	Meshes.apply("smile", soft("Smile", .47, .12, .094, .020, 4.302, .738, skin:Lerp(rubber, .71)))
	for _, side in {-1, 1} do
		local x = side * .365
		Meshes.apply("ear", soft("Ear", .34, .44, .38, side * .808, 4.55, .07, skin, side * .16))
		local eyeHeight = if figure == 4 or figure == 5 then .188 else .214
		soft("Lid", .365, eyeHeight + .048, .135, x, 4.65, .701, skin:Lerp(hair, .45), side * .065)
		soft("Eyes", .324, eyeHeight, .127, x, 4.642, .713, ivory, side * .065)
		soft("Iris", .157, eyeHeight * .82, .084, x + .026, 4.641, .769, trim:Lerp(rubber, .58))
		soft("Catchlight", .056, .060, .027, x + .048, 4.680, .809, ivory).CastShadow = false
		soft("Eyebrow", .29, .087, .08, x, 4.837, .680, hair, -side * .11)
	end
	if figure == 5 then
		local cap = soft("Cap crown", 1.93, .69, 1.61, 0, 5.13, -.035, trim)
		local brim = soft("Structured brim", 1.44, .155, 1.07, 0, 5.02, .62, kit)
		Meshes.apply("cap", cap, {brim})
		soft("Embroidered cap crest", .28, .21, .08, 0, 5.22, .706, Art.gold)
	elseif figure == 2 or figure == 6 then
		local crown = soft("Side part", 1.84, .83, 1.65, 0, 5.132, -.011, hair)
		local fringe = soft("Swept fringe", 1.10, .46, .58, -.36, 5.02, .60, hair, -.20)
		Meshes.apply("sweep", crown, {fringe})
		if figure == 2 then
			Meshes.apply("braid", soft("Sculpted braid", .48, 1.46, .56, .43, 4.49, -.70, hair, .22))
			soft("Hair tie", .46, .14, .51, .41, 5.04, -.59, accent)
		else
			Meshes.apply("braid", soft("Braided bun", .67, .61, .69, .35, 5.10, -.72, hair, -.16))
		end
	elseif figure == 4 then
		Meshes.apply("fade", soft("Keeper fade", 1.78, .60, 1.62, 0, 5.105, -.065, hair))
		soft("Keeper band", 1.78, .16, 1.59, 0, 4.99, -.01, kit:Lerp(ivory, .42))
	elseif figure == 1 then
		local crown = soft("Curl base", 1.82, .70, 1.66, 0, 5.175, .015, hair)
		local curls: {Instance} = {}
		for i = -2, 2 do
			local tint = hair:Lerp(C("624638"), .12 + .07 * (i % 2))
			table.insert(curls, soft("Sculpted curl", .60, .54, .60, i * .31, 5.17 + .065 * (2 - math.abs(i)), .35, tint))
		end
		Meshes.apply("curls", crown, curls)
	else
		local crown = soft("Tapered hair", 1.88, .72, 1.65, 0, 5.133, -.021, hair)
		local fringe: {Instance} = {}
		for i = 0, 2 do
			table.insert(fringe, soft("Sculpted fringe", 1.03 - i * .13, .40, .54, -.31 + .25 * i, 5.04 + i * .041, .59, hair, -.26))
		end
		Meshes.apply("quiff", crown, fringe)
	end
	head.model.WorldPivot = head.rest
	head.model:ScaleTo(if figure == 4 then .93 elseif figure == 5 then .90 else .88)
	rigs[model] = {body, head, arms[1], arms[2], thighs[1], thighs[2], elbows[1], elbows[2],
		knees[1], knees[2], boots[1], boots[2]}
	model.Parent = parent
	return model
end

local clips: {[string]: {{CFrame}}} = {}
for name, samples in Motion do
	local frames = {}
	for i, sample in samples do
		local joints = {}
		for index = 1, #sample, 7 do
			table.insert(joints, CFrame.new(sample[index], sample[index + 1], sample[index + 2],
				sample[index + 3], sample[index + 4], sample[index + 5], sample[index + 6]))
		end
		frames[i] = joints
	end
	clips[name] = frames
end

local function frameAt(clip: {{CFrame}}, progress: number): ({CFrame}, {CFrame}, number)
	local position = 1 + math.clamp(progress, 0, 1) * (#clip - 1)
	local lower = math.floor(position)
	return clip[lower], clip[math.min(lower + 1, #clip)], position - lower
end

function Pawn.animate(model: Model, name: string, progress: number, weight: number?)
	local rig = rigs[model]
	if not rig then return end
	local before, after, alpha = frameAt(clips[name], progress)
	local blend = weight or 1
	local at, scale = model:GetPivot(), model:GetScale()
	local transforms: {CFrame} = {}
	for i, joint in rig do
		local motion = CFrame.identity:Lerp(before[i]:Lerp(after[i], alpha), blend)
		local parentIndex = joint.parent
		local base = if parentIndex then transforms[parentIndex] else at
		local localRest = if parentIndex then joint.rest.Position - rig[parentIndex].rest.Position else joint.rest.Position
		local pose = base * CFrame.new((localRest + motion.Position) * scale) * motion.Rotation
		transforms[i] = pose
		joint.model:PivotTo(pose)
	end
end

function Pawn.pose(model: Model, phase: number, running: number, celebration: number?)
	local cycle = (phase / (2 * math.pi)) % 1
	if celebration then
		Pawn.animate(model, "cheer", celebration)
	elseif running > 0 then
		Pawn.animate(model, "stride", cycle, math.clamp(running, 0, 1))
	else
		Pawn.animate(model, "idle", cycle)
	end
end

function Pawn.run(model: Model, cycle: number, strength: number)
	local rig = rigs[model]
	if not rig then return end
	local phase = cycle % 1
	Pawn.animate(model, "stride", phase, strength)
	local at, scale = model:GetPivot(), model:GetScale()
	for i = 1, 2 do
		local thigh, knee, ankle = rig[4 + i], rig[8 + i], rig[10 + i]
		local hip = thigh.rest.Position
		local rest = ankle.rest.Position
		local step = (phase + (i - 1) * .5) % 1
		-- During contact the foot moves backward at a constant rate relative to the body.
		local swing = math.clamp((step - .57) / .43, 0, 1)
		local forward = if step <= .57 then 1 - 2 * step / .57 else -1 + 2 * swing * swing * (3 - 2 * swing)
		local lift = math.sin(math.pi * swing) ^ 1.2
		local target = rest + Vector3.new(0, (.11 + .55 * lift) * strength, forward * .82 * strength)
		local offset = target - hip
		local upper = (knee.rest.Position - hip).Magnitude
		local lower = (rest - knee.rest.Position).Magnitude
		local distance = math.clamp(offset.Magnitude, .01, upper + lower - .002)
		local reach = offset.Unit
		local pole = (Vector3.zAxis - reach * reach.Z).Unit
		local hinge = (distance * distance + upper * upper - lower * lower) / (2 * distance)
		local bent = hip + reach * hinge + pole * math.sqrt(math.max(0, upper * upper - hinge * hinge))
		local foot = hip + reach * distance
		local function orient(start: Vector3, finish: Vector3): CFrame
			local up = (start - finish).Unit
			return at * CFrame.fromMatrix(start * scale, Vector3.xAxis, up)
		end
		thigh.model:PivotTo(orient(hip, bent))
		knee.model:PivotTo(orient(bent, foot))
		ankle.model:PivotTo(at * CFrame.new(foot * scale) * CFrame.Angles(.21 * math.sin(swing * math.pi) * strength, 0, 0))
	end
end

return Pawn
