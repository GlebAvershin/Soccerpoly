--!strict
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Art = require(ReplicatedStorage:WaitForChild("League").Presentation)

local localPlayer = Players.LocalPlayer
local C = Color3.fromHex
local HALF = 3.2
local RADIUS = .68
local CORE = HALF - RADIUS
local PIP_LIP = .072
local faces = {
	{normal = Vector3.yAxis, top = CFrame.identity, dots = {{0, 0}}},
	{normal = Vector3.xAxis, top = CFrame.Angles(0, 0, math.pi / 2), dots = {{-1, -1}, {1, 1}}},
	{normal = Vector3.zAxis, top = CFrame.Angles(-math.pi / 2, 0, 0), dots = {{-1, -1}, {0, 0}, {1, 1}}},
	{normal = -Vector3.zAxis, top = CFrame.Angles(math.pi / 2, 0, 0), dots = {{-1, -1}, {1, -1}, {-1, 1}, {1, 1}}},
	{normal = -Vector3.xAxis, top = CFrame.Angles(0, 0, -math.pi / 2), dots = {{-1, -1}, {1, -1}, {0, 0}, {-1, 1}, {1, 1}}},
	{normal = -Vector3.yAxis, top = CFrame.Angles(math.pi, 0, 0), dots = {{-1, -1}, {1, -1}, {-1, 0}, {1, 0}, {-1, 1}, {1, 1}}},
}
local axes = {Vector3.xAxis, Vector3.yAxis, Vector3.zAxis}

type DiceSkinPalette = {
	resinA: Color3, pipA: Color3, rimA: Color3, reflA: number,
	resinB: Color3, pipB: Color3, rimB: Color3, reflB: number,
}

local SKINS: {[string]: DiceSkinPalette} = {
	ivory_classic = {
		resinA = C("FFF5E2"), pipA = C("122430"), rimA = C("D4AF37"), reflA = 0.06,
		resinB = C("9C1A38"), pipB = C("FFF8E8"), rimB = C("7A142C"), reflB = 0.10,
	},
	carbon_stealth = {
		resinA = C("1A1E24"), pipA = C("00E5FF"), rimA = C("37474F"), reflA = 0.04,
		resinB = C("382115"), pipB = C("FF9100"), rimB = C("4E342E"), reflB = 0.05,
	},
	neon_cyber = {
		resinA = C("0F172A"), pipA = C("FF007F"), rimA = C("00F5D4"), reflA = 0.16,
		resinB = C("3B0764"), pipB = C("00F5D4"), rimB = C("F43F5E"), reflB = 0.18,
	},
	gold_championship = {
		resinA = C("FFD700"), pipA = C("8B0000"), rimA = C("FFF8DC"), reflA = 0.35,
		resinB = C("E2E8F0"), pipB = C("FFD700"), rimB = C("94A3B8"), reflB = 0.28,
	},
	obsidian_gold = {
		resinA = C("111317"), pipA = C("FFD700"), rimA = C("D4AF37"), reflA = 0.40,
		resinB = C("D4AF37"), pipB = C("111317"), rimB = C("FFF8DC"), reflB = 0.35,
	},
}

local function piece(model: Model, name: string, shape: Enum.PartType, size: Vector3, pose: CFrame, tint: Color3): Part
	local node = Instance.new("Part")
	node.Name, node.Shape, node.Size, node.CFrame, node.Color = name, shape, size, pose, tint
	node.Material, node.Anchored = Enum.Material.SmoothPlastic, true
	node.TopSurface, node.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	node.CanCollide, node.CanQuery, node.CanTouch = false, false, false
	node.Parent = model
	return node
end

local function die(parent: Folder, value: number, isFirst: boolean, skinKey: string?): Model
	local model = Instance.new("Model")
	model.Name = "Die " .. value
	local palette = SKINS[skinKey or "ivory_classic"] or SKINS.ivory_classic
	local resin = if isFirst then palette.resinA else palette.resinB
	local pip = if isFirst then palette.pipA else palette.pipB
	local rim = if isFirst then palette.rimA else palette.rimB
	local refl = if isFirst then palette.reflA else palette.reflB
	local root = piece(model, "DieCore", Enum.PartType.Block, Vector3.one * 0.1, CFrame.identity, resin)
	root.Transparency = 1
	model.PrimaryPart = root
	-- Native flat faces, tangent quarter-round edges and spherical corners always
	-- have the same dimensions, including when editable-mesh memory is unavailable.
	for i, axis in axes do
		local u, v = axes[i % 3 + 1], axes[(i + 1) % 3 + 1]
		local plane = CFrame.fromMatrix(Vector3.zero, axis, u, v)
		local facePart = piece(model, "Moulded face", Enum.PartType.Block, Vector3.new(HALF, CORE, CORE) * 2, plane, resin)
		facePart.Reflectance = refl
		for _, su in {-1, 1} do
			for _, sv in {-1, 1} do
				local edgePart = piece(model, "Radius edge", Enum.PartType.Cylinder, Vector3.new(CORE, RADIUS, RADIUS) * 2,
					plane + (u * su + v * sv) * CORE, resin)
				edgePart.Reflectance = refl
			end
		end
	end
	for _, x in {-CORE, CORE} do
		for _, y in {-CORE, CORE} do
			for _, z in {-CORE, CORE} do
				local cornerPart = piece(model, "Polished corner", Enum.PartType.Ball, Vector3.one * RADIUS * 2, CFrame.new(x, y, z), resin)
				cornerPart.Reflectance = refl
			end
		end
	end

	for valueOnFace, face in faces do
		local normal = face.normal
		local vertical = if math.abs(normal.Y) > .5 then Vector3.zAxis else Vector3.yAxis
		local horizontal = vertical:Cross(normal)
		local plane = CFrame.fromMatrix(normal * HALF, normal, vertical, normal:Cross(vertical))
		local diameter = if valueOnFace == 1 then 1.90 else 1.31
		for _, dot in face.dots do
			local pos = plane + horizontal * (dot[1] * 1.60) + vertical * (dot[2] * 1.60)
			local bezel = piece(model, "Pip socket", Enum.PartType.Cylinder, Vector3.new(.072, diameter + .20, diameter + .20),
				pos + normal * .026, rim)
			bezel.CastShadow = false
			bezel.Reflectance = 0.15
			local inlay = piece(model, "Enamel pip", Enum.PartType.Cylinder, Vector3.new(.048, diameter, diameter),
				pos + normal * (PIP_LIP - .024), pip)
			inlay.CastShadow = false
		end
	end
	model.WorldPivot, model.Parent = CFrame.identity, parent
	return model
end

return function(parent: Folder, first: number, second: number, reduced: boolean)
	local old = parent:FindFirstChild("Dice roll")
	if old then old:Destroy() end
	local tray = Instance.new("Folder")
	tray.Name = "Dice roll"
	local skinKey = if localPlayer then (localPlayer:GetAttribute("CareerEquippedDice") :: string?) else "ivory_classic"
	local pair = {die(tray, first, true, skinKey), die(tray, second, false, skinKey)}
	local results = {first, second}
	local function pose(t: number)
		for i, result in results do
			local sign = if i == 1 then -1 else 1
			local remaining = (1 - t) ^ 1.55
			local at = Art.boardNear * (-11 - remaining * (7 + i)) + Art.boardRight * sign * (5.55 + remaining * 2.6)
			local hop: number
			if t < .58 then
				hop = math.sin(math.pi * t / .58) * (3.8 + i * .5)
			elseif t < .84 then
				hop = math.sin(math.pi * (t - .58) / .26) * 1.15
			else
				hop = math.sin(math.pi * (t - .84) / .16) * 0.28
			end
			local settled = CFrame.Angles(0, Art.boardYaw + sign * .23, 0) * faces[result].top
			local tumble = CFrame.Angles(remaining * math.pi * (1.55 + i * .23), sign * remaining * 2.16,
				sign * remaining * 2.72)
			local orientation = tumble * settled
			-- Project the rounded shell onto the ground normal to keep its edges above the grass throughout the roll.
			local support = CORE * (math.abs(orientation.RightVector.Y) + math.abs(orientation.UpVector.Y)
				+ math.abs(orientation.LookVector.Y)) + RADIUS
			pair[i]:PivotTo(CFrame.new(at + Vector3.yAxis * (.285 + support + PIP_LIP + hop)) * orientation)
		end
	end
	pose(if reduced then 1 else 0)
	tray.Parent = parent
	if not reduced then
		task.spawn(function()
			local start = os.clock()
			while tray.Parent do
				RunService.RenderStepped:Wait()
				if not tray.Parent then break end
				local t = math.clamp((os.clock() - start) / .52, 0, 1)
				pose(t)
				if t == 1 then break end
			end
		end)
	end
	Debris:AddItem(tray, 1.85)
end
