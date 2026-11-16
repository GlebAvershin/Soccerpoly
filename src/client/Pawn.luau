--!strict
local shared = game:GetService("ReplicatedStorage"):WaitForChild("League")
local Board = require(shared.Board)
local Art = require(shared.Presentation)
local Meshes = require(script.Parent.MeshLibrary)
local Motion = require(script.Parent.PawnMotionData)
local Pawn = {}
local C = Color3.fromHex

type Joint = {model: Model, rest: CFrame}
type Rig = {Joint}
local rigs: {[Model]: Rig} = setmetatable({}, {__mode = "k"}) :: any

function Pawn.make(figure: number, parent: Instance): Model
	local def = Board.figures[figure]
	local kit, trim, skin, hair = Art.hex(def.color), Art.hex(def.dark), Art.hex(def.skin), Art.hex(def.hair)
	local ivory, rubber = C("F2F5E4"), C("152528")
	local model = Instance.new("Model")
	model.Name = def.name
	local container: Instance = model

	local function piece(name: string, w: number, h: number, d: number, x: number, y: number, z: number, color: Color3,
		shape: Enum.PartType?, tilt: number?): Part
		local p = Instance.new("Part")
		p.Name, p.Size, p.Color = name, Vector3.new(w, h, d), color
		p.Shape, p.CFrame = shape or Enum.PartType.Block, CFrame.new(x, y, z) * CFrame.Angles(0, 0, tilt or 0)
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
		p.Parent = container
		return p
	end
	local function soft(name: string, w: number, h: number, d: number, x: number, y: number, z: number, color: Color3, tilt: number?): Part
		return piece(name, w, h, d, x, y, z, color, Enum.PartType.Ball, tilt)
	end
	local function joint(name: string, x: number, y: number, z: number): Joint
		local group = Instance.new("Model")
		group.Name, group.Parent = name, model
		container = group
		return {model = group, rest = CFrame.new(x, y, z)}
	end

	local root = piece("Root", .08, .08, .08, 0, 0, 0, rubber)
	root.Transparency, root.CastShadow, model.PrimaryPart = 1, false, root
	for i, ring in {{.19, 3.45, .12}, {.09, 3.39, .26}, {.07, 3.19, .33}} do
		local color = if i == 1 then trim elseif i == 2 then kit else C("DFE6D9")
		local base = piece("Turntable " .. i, ring[1], ring[2], ring[2], 0, ring[3], 0, color, Enum.PartType.Cylinder, math.pi * .5)
		if i == 1 then base.Material = Enum.Material.Metal end
	end

	local legs, arms = {}, {}
	for _, side in {-1, 1} do
		local x = side * .43
		local leg = joint(if side < 0 then "Left leg" else "Right leg", x, 2.09, 0)
		Meshes.apply("shorts", soft("Tailored short", .88, .95, .91, x, 2.03, .005, trim, side * .07))
		soft("Knee", .62, .62, .64, x * 1.10, 1.63, .03, if figure == 5 then trim else skin)
		soft("Ribbed sock", .59, 1.05, .64, x * 1.13, 1.18, .045, if figure == 5 then trim else kit)
		soft("Sock band", .58, .15, .65, x * 1.13, 1.46, .05, ivory)
		soft("Studded sole", .76, .19, 1.08, x * 1.15, .50, .25, rubber)
		Meshes.apply("boot", soft("Leather boot", .74, .49, 1.06, x * 1.15, .69, .24, trim:Lerp(rubber, .35)))
		for seam = 1, 3 do
			soft("Boot lace", .29, .04, .067, x * 1.15, .92 - seam * .032, .22 + seam * .13, ivory).CastShadow = false
		end
		leg.model.WorldPivot = leg.rest
		table.insert(legs, leg)
	end

	local body = joint("Torso", 0, 2.18, 0)
	soft("Waist", 1.67, .90, 1.04, 0, 2.34, .005, trim)
	Meshes.apply("jersey", soft("Jersey", 2.23, 1.72, 1.36, 0, 3.01, 0, kit))
	soft("Collar ribbing", .87, .27, .80, 0, 3.82, 0, trim)
	soft("Neck", .56, .48, .61, 0, 3.94, 0, skin)
	soft("Chest piping", 1.38, .105, .12, 0, 3.36, .622, ivory)
	soft("Woven crest", .25, .33, .10, -.50, 3.24, .626, trim)
	soft("Crest embroidery", .13, .12, .025, -.50, 3.30, .686, Art.gold).CastShadow = false
	local tag = piece("Player number", .68, .52, .04, .21, 3.08, .669, kit)
	tag.Transparency, tag.CastShadow = 1, false
	local gui = Instance.new("SurfaceGui")
	gui.Face, gui.SizingMode, gui.CanvasSize = Enum.NormalId.Back, Enum.SurfaceGuiSizingMode.FixedSize, Vector2.new(256, 192)
	gui.LightInfluence, gui.Parent = 0, tag
	local text = Instance.new("TextLabel")
	text.Size, text.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	text.Font, text.TextScaled, text.TextColor3, text.Text = Enum.Font.BuilderSansExtraBold, true, trim, def.number
	text.Parent = gui
	body.model.WorldPivot = body.rest

	for _, side in {-1, 1} do
		local arm = joint(if side < 0 then "Left arm" else "Right arm", side * .96, 3.45, 0)
		local glove, coach = figure == 4, figure == 5
		soft("Sleeve", .78, .86, .85, side * 1.06, 3.30, .005, kit:Lerp(ivory, .09), side * .27)
		soft("Sleeve cuff", .69, .19, .72, side * 1.25, 3.03, .010, trim, side * .28)
		soft("Bent forearm", .50, .83, .58, side * 1.30, 2.73, .13, if coach then kit else skin, side * .23)
		soft("Palm", if glove then .68 else .53, .51, .60, side * 1.37, 2.42, .23, if glove then ivory else skin)
		if glove then soft("Glove cuff", .59, .22, .58, side * 1.35, 2.62, .21, trim, side * .22) end
		if coach and side < 0 then
			piece("Tactics tablet", .73, .82, .14, -1.26, 2.57, .58, rubber, nil, .18)
			piece("Tactics screen", .58, .66, .021, -1.26, 2.57, .66, C("87C9A4"), nil, .18)
		elseif figure == 6 and side == 1 then
			piece("Referee card", .43, .62, .07, 1.38, 2.65, .51, Art.gold, nil, -.20)
		end
		arm.model.WorldPivot = arm.rest
		table.insert(arms, arm)
	end

	local head = joint("Head", 0, 3.97, 0)
	local face = soft("Face", 1.76, 1.62, 1.58, 0, 4.58, .042, skin)
	local chin = soft("Chin", 1.27, .82, 1.22, 0, 4.25, .12, skin)
	local nose = soft("Nose", .28, .31, .29, 0, 4.47, .766, skin:Lerp(ivory, .17))
	Meshes.apply("head", face, {chin, nose})
	soft("Smile", .43, .084, .092, 0, 4.25, .726, skin:Lerp(rubber, .58))
	for _, side in {-1, 1} do
		local x = side * .377
		soft("Ear", .32, .44, .36, side * .819, 4.53, .06, skin)
		soft("Eyes", .29, .24, .108, x, 4.65, .70, ivory)
		soft("Iris", .153, .19, .078, x + .032, 4.64, .755, trim:Lerp(rubber, .58))
		soft("Catchlight", .049, .05, .021, x + .057, 4.687, .792, ivory).CastShadow = false
		soft("Eyebrow", .29, .087, .08, x, 4.875, .678, hair, -side * .11)
	end
	if figure == 5 then
		local cap = soft("Cap crown", 1.93, .69, 1.61, 0, 5.13, -.035, trim)
		local brim = soft("Structured brim", 1.44, .155, 1.07, 0, 5.02, .62, kit)
		Meshes.apply("cap", cap, {brim})
		soft("Embroidered cap crest", .28, .21, .08, 0, 5.22, .706, Art.gold)
	elseif figure == 2 or figure == 6 then
		local crown = soft("Side part", 1.83, .83, 1.57, 0, 5.018, -.08, hair)
		local fringe = soft("Swept fringe", 1.10, .46, .58, -.36, 5.02, .60, hair, -.20)
		Meshes.apply("sweep", crown, {fringe})
		soft(if figure == 2 then "Ponytail" else "Bun", .74, if figure == 2 then 1.38 else .82, .76, .42, 4.69, -.68, hair, .29)
		soft("Hair tie", .64, .15, .67, .37, 5.00, -.51, kit)
	elseif figure == 1 or figure == 4 then
		local crown = soft("Curl base", 1.82, .70, 1.66, 0, 5.175, .015, hair)
		local curls: {Instance} = {}
		for i = -2, 2 do
			local tint = hair:Lerp(C("624638"), .12 + .07 * (i % 2))
			table.insert(curls, soft("Sculpted curl", .60, .54, .60, i * .31, 5.17 + .065 * (2 - math.abs(i)), .35, tint))
		end
		Meshes.apply("curls", crown, curls)
		if figure == 4 then soft("Keeper band", 1.83, .17, 1.58, 0, 4.95, .02, kit) end
	else
		local crown = soft("Tapered hair", 1.86, .70, 1.53, 0, 5.02, -.13, hair)
		local fringe: {Instance} = {}
		for i = 0, 2 do
			table.insert(fringe, soft("Sculpted fringe", 1.03 - i * .13, .40, .54, -.31 + .25 * i, 5.04 + i * .041, .59, hair, -.26))
		end
		Meshes.apply("sweep", crown, fringe)
	end
	head.model.WorldPivot = head.rest
	rigs[model] = {body, head, arms[1], arms[2], legs[1], legs[2]}
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

function Pawn.pose(model: Model, phase: number, running: number, celebration: number?)
	local rig = rigs[model]
	if not rig then return end
	local cycle = (phase / (2 * math.pi)) % 1
	local clip = if celebration then clips.cheer elseif running > 0 then clips.stride else clips.idle
	local before, after, weight = frameAt(clip, celebration or cycle)
	local blend = if celebration or clip == clips.idle then 1 else math.clamp(running, 0, 1)
	local at, scale = model:GetPivot(), model:GetScale()
	for i, joint in rig do
		local motion = CFrame.identity:Lerp(before[i]:Lerp(after[i], weight), blend)
		joint.model:PivotTo(at * CFrame.new((joint.rest.Position + motion.Position) * scale) * motion.Rotation)
	end
end

return Pawn
