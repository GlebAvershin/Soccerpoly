--!strict
local shared = game:GetService("ReplicatedStorage"):WaitForChild("League")
local Board = require(shared.TourBoard)
local Art = require(shared.Presentation)
local Meshes = require(script.Parent.MeshLibrary)
local Portraits = require(script.Parent.PlayerSculptData)
local Motion = require(script.Parent.PawnMotionData)
local Pawn = {}
local C = Color3.fromHex

type Joint = {model: Model, rest: CFrame, parent: number?}
type Rig = {Joint}
local profiles: {[Model]: number} = setmetatable({}, {__mode = "k"}) :: any
local rigs: {[Model]: Rig} = setmetatable({}, {__mode = "k"}) :: any

function Pawn.make(figure: number, parent: Instance, onPitch: boolean?, uniform: Color3?): Model
	local def = Board.figures[figure]
	local keeper = uniform ~= nil
	local sculpt = if keeper then "goalkeeper" else def.model
	local profile = Portraits[sculpt]
	local width, stature = if keeper then 1.05 else def.width, if keeper then 1.02 else def.height
	local kit, trim, skin = uniform or Art.hex(def.kit), Art.hex(def.dark), if keeper then C("955C43") else Art.hex(def.skin)
	local ivory, rubber = C("F2F5E4"), C("191D28")
	local accent = if keeper then C("FFF2D0") else Art.hex(def.color)
	local printColor = if figure == 1 or figure == 5 or figure == 6 then trim else ivory
	local sleeveColor = if figure == 3 or figure == 5 then trim else kit
	local function height(y: number): number
		local stretched = if y <= .45 then y elseif y <= 2.20 then .45 + (y - .45) * 1.38 else 2.865 + (y - 2.20) * 1.035
		return .45 + (stretched - .45) * stature
	end
	local function point(x: number, y: number, z: number): Vector3
		return Vector3.new(x * .87 * width, height(y), z * .94)
	end
	local model = Instance.new("Model")
	model.Name = def.name
	local container: Instance = model

	local function piece(name: string, w: number, h: number, d: number, x: number, y: number, z: number, color: Color3,
		shape: Enum.PartType?, tilt: number?): Part
		local p = Instance.new("Part")
		local stand = container == model
		local size = if stand then Vector3.new(w, h, d)
			else Vector3.new(w * .87 * width, height(y + h * .5) - height(y - h * .5), d * .94)
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
		soft("Short side piping", .067, .55, .23, x + side * .346, 2.05, .16, accent, side * .06).CastShadow = false
		thigh.model.WorldPivot = thigh.rest
		thighs[i] = thigh
		local knee = joint(prefix .. "knee", x, 1.419, .014, 4 + i)
		soft("Knee", .50, .44, .52, x * 1.07, 1.53, .03, skin)
		Meshes.apply("sock", soft("Ribbed sock", .48, .91, .53, x * 1.08, 1.125, .045, kit))
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
		piece("Heel counter", .35, .20, .055, x * 1.15, .68, -.216, accent).CastShadow = false
		for seam = 1, 3 do
			soft("Boot lace", .29, .04, .067, x * 1.15, .92 - seam * .032, .22 + seam * .13, ivory).CastShadow = false
		end
		ankle.model.WorldPivot = ankle.rest
		boots[i] = ankle
	end

	local body = joint("Torso", 0, 2.18, 0)
	local shirt = soft("Jersey", 2.24, 1.74, 1.32, 0, 3.00, 0, if keeper then kit else Color3.new(1, 1, 1))
	if keeper then
		Meshes.apply("jersey", shirt)
	else
		local fallbackShirt = soft("Jersey fallback", 2.20, 1.69, 1.27, 0, 3.00, 0, kit)
		shirt.Transparency = 1
		shirt:SetAttribute("MeshPlaceholder", true)
		Meshes.apply(def.model .. "_jersey", shirt, {fallbackShirt})
	end
	soft("Neck", .65, .56, .69, 0, 3.81, -.012, skin)
	Meshes.apply("collar", soft("Woven collar", .80, .23, .26, 0, 3.72, .447, trim))
	Meshes.apply("crest", soft("Table crest", .21, .26, .044, -.47, 3.24, .635, trim))
	piece("Crest centre", .053, .092, .033, -.47, 3.25, .660, accent, nil, -.22).CastShadow = false
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
		number.TextColor3, number.Text = printColor, if keeper then "01" else def.number
		number.Parent = gui
	end
	body.model.WorldPivot = body.rest

	for i, side in {-1, 1} do
		local prefix = if side < 0 then "Left " else "Right "
		local arm = joint(prefix .. "arm", side * .96, 3.45, 0)
		local glove = keeper
		Meshes.apply("sleeve", soft("Sleeve", .83, .86, .82, side * 1.10, 3.30, .005, sleeveColor, side * .27))
		soft("Contrast piping", .69, .067, .72, side * 1.24, 3.11, .02, accent, side * .27)
		soft("Sleeve cuff", .69, .16, .72, side * 1.25, 3.035, .010, trim, side * .28)
		if (figure == 1 or figure == 2) and side == -1 and not keeper then
			soft("Captain armband", .68, .14, .70, -1.15, 3.29, .008, accent, -.27)
		end
		arm.model.WorldPivot = arm.rest
		arms[i] = arm
		local elbow = joint(prefix .. "elbow", side * 1.239, 3.00, .08, 2 + i)
		Meshes.apply("forearm", soft("Bent forearm", .46, .82, .53, side * 1.30, 2.73, .13, skin, side * .23))
		local hand = soft("Palm", if glove then .71 else .49, .55, if glove then .60 else .53, side * 1.37, 2.42, .23, if glove then ivory else skin)
		Meshes.apply(if glove then "glove" elseif side < 0 then "hand_left" else "hand_right", hand)
		if figure == 3 then
			soft("Wrist tape", .43, .104, .50, side * 1.347, 2.58, .188, accent, side * .23)
		end
		if glove then
			Meshes.apply("glovepad", soft("Keeper palm shield", .38, .34, .072, side * 1.35, 2.425, .516, trim))
			soft("Glove cuff", .59, .22, .58, side * 1.35, 2.62, .21, trim, side * .22)
			soft("Thumb padding", .22, .29, .31, side * 1.60, 2.48, .35, ivory, side * .26)
		end
		elbow.model.WorldPivot = elbow.rest
		elbows[i] = elbow
	end

	local head = joint("Head", 0, 3.97, 0)
	local w, h, d = table.unpack(profile.size)
	local x, y, z = table.unpack(profile.center)
	local face = soft("Face", w * 1.44, h * 1.21, d * 1.48, x * 1.44, 4.59 + y * 1.21, z * 1.48, skin)
	face.CastShadow = true
	face:SetAttribute("MeshPlaceholder", true)
	face.Transparency = 1
	local fallback = soft("Face fallback", 1.48, 1.46, 1.33, 0, 4.60, 0, skin)
	local hair = soft("Hair fallback", 1.43, .57, 1.32, 0, 5.081, -.12, C("2C2327"))
	face.Color = Color3.new(1, 1, 1)
	Meshes.apply(sculpt, face, {fallback, hair})
	head.model.WorldPivot = head.rest
	profiles[model] = figure
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

local mirror = {1, 2, 4, 3, 6, 5, 8, 7, 10, 9, 12, 11}

local function reflectX(pose: CFrame): CFrame
	local x, y, z, a, b, c, d, e, f, g, h, i = pose:GetComponents()
	return CFrame.new(-x, y, z, a, -b, -c, -d, e, f, -g, h, i)
end

function Pawn.animate(model: Model, name: string, progress: number, weight: number?)
	local rig = rigs[model]
	if not rig then return end
	local def = Board.figures[profiles[model]]
	local reflected = name == "kick" and def.leftFoot
	local clip = if name == "cheer" then clips[def.model] else clips[name]
	local before, after, alpha = frameAt(clip, progress)
	local blend = weight or 1
	local at, scale = model:GetPivot(), model:GetScale()
	local transforms: {CFrame} = {}
	for i, joint in rig do
		local index = if reflected then mirror[i] else i
		local motion = CFrame.identity:Lerp(before[index]:Lerp(after[index], alpha), blend)
		if reflected then motion = reflectX(motion) end
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
