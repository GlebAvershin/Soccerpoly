--!strict
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Art = require(ReplicatedStorage:WaitForChild("League").Presentation)

local localPlayer = Players.LocalPlayer
local C = Color3.fromHex
local HALF = 3.2
local RADIUS = .68
local CORE = HALF - RADIUS

local normalToFace: {[Vector3]: Enum.NormalId} = {
	[Vector3.yAxis] = Enum.NormalId.Top,
	[-Vector3.yAxis] = Enum.NormalId.Bottom,
	[Vector3.xAxis] = Enum.NormalId.Right,
	[-Vector3.xAxis] = Enum.NormalId.Left,
	[Vector3.zAxis] = Enum.NormalId.Back,
	[-Vector3.zAxis] = Enum.NormalId.Front,
}

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
	resinA: Color3, pipA: Color3, rimA: Color3, reflA: number, matA: Enum.Material,
	resinB: Color3, pipB: Color3, rimB: Color3, reflB: number, matB: Enum.Material,
}

local SKINS: {[string]: DiceSkinPalette} = {
	ivory_classic = {
		resinA = C("FFFBF0"), pipA = C("122430"), rimA = C("D4AF37"), reflA = 0.08, matA = Enum.Material.SmoothPlastic,
		resinB = C("9E1B32"), pipB = C("FFF8E8"), rimB = C("E5C158"), reflB = 0.12, matB = Enum.Material.SmoothPlastic,
	},
	carbon_stealth = {
		resinA = C("15181E"), pipA = C("00E5FF"), rimA = C("37474F"), reflA = 0.06, matA = Enum.Material.SmoothPlastic,
		resinB = C("2E1A11"), pipB = C("FF9100"), rimB = C("5D4037"), reflB = 0.08, matB = Enum.Material.SmoothPlastic,
	},
	neon_cyber = {
		resinA = C("0A0E1A"), pipA = C("FF007F"), rimA = C("00F5D4"), reflA = 0.22, matA = Enum.Material.Glass,
		resinB = C("310557"), pipB = C("00F5D4"), rimB = C("F43F5E"), reflB = 0.25, matB = Enum.Material.Glass,
	},
	gold_championship = {
		resinA = C("FFD700"), pipA = C("7A0000"), rimA = C("FFF8DC"), reflA = 0.45, matA = Enum.Material.Metal,
		resinB = C("E8EDF2"), pipB = C("FFD700"), rimB = C("94A3B8"), reflB = 0.35, matB = Enum.Material.Metal,
	},
	obsidian_gold = {
		resinA = C("0C0E12"), pipA = C("FFD700"), rimA = C("D4AF37"), reflA = 0.48, matA = Enum.Material.Glass,
		resinB = C("D4AF37"), pipB = C("0C0E12"), rimB = C("FFF8DC"), reflB = 0.40, matB = Enum.Material.Metal,
	},
}

local function piece(model: Model, name: string, shape: Enum.PartType, size: Vector3, pose: CFrame, tint: Color3, mat: Enum.Material?): Part
	local node = Instance.new("Part")
	node.Name, node.Shape, node.Size, node.CFrame, node.Color = name, shape, size, pose, tint
	node.Material = mat or Enum.Material.SmoothPlastic
	node.Anchored = true
	node.TopSurface, node.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	node.CanCollide, node.CanQuery, node.CanTouch = false, false, false
	node.Parent = model
	return node
end

local function spawnDiceImpact(parent: Folder, p1: Vector3, p2: Vector3, tint: Color3)
	for _, pos in {p1, p2} do
		local shockwave = Instance.new("Part")
		shockwave.Name, shockwave.Shape = "DiceImpactWave", Enum.PartType.Cylinder
		shockwave.Size = Vector3.new(0.04, 1.2, 1.2)
		shockwave.CFrame = CFrame.new(pos.X, Art.tileTop + 0.032, pos.Z) * CFrame.Angles(0, 0, math.pi / 2)
		shockwave.Material, shockwave.Color = Enum.Material.Neon, Art.gold
		shockwave.Transparency = 0.35
		shockwave.Anchored, shockwave.CanCollide = true, false
		shockwave.Parent = parent

		TweenService:Create(shockwave, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.02, 5.2, 5.2),
			Transparency = 1,
		}):Play()
		Debris:AddItem(shockwave, 0.30)
	end
end

local function die(parent: Folder, value: number, isFirst: boolean, skinKey: string?): Model
	local model = Instance.new("Model")
	model.Name = "Die " .. value
	local palette = SKINS[skinKey or "ivory_classic"] or SKINS.ivory_classic
	local resin = if isFirst then palette.resinA else palette.resinB
	local pip = if isFirst then palette.pipA else palette.pipB
	local rim = if isFirst then palette.rimA else palette.rimB
	local refl = if isFirst then palette.reflA else palette.reflB
	local mat = if isFirst then palette.matA else palette.matB

	local root = piece(model, "DieCore", Enum.PartType.Block, Vector3.one * (HALF * 2), CFrame.identity, resin, mat)
	root.Reflectance = refl
	root.CastShadow = true
	model.PrimaryPart = root

	-- Smooth beveled edge and corner shells
	for i, axis in axes do
		local u, v = axes[i % 3 + 1], axes[(i + 1) % 3 + 1]
		local plane = CFrame.fromMatrix(Vector3.zero, axis, u, v)
		for _, su in {-1, 1} do
			for _, sv in {-1, 1} do
				local edgePart = piece(model, "Radius edge", Enum.PartType.Cylinder, Vector3.new(CORE, RADIUS, RADIUS) * 2,
					plane + (u * su + v * sv) * CORE, resin, mat)
				edgePart.Reflectance = refl
			end
		end
	end
	for _, x in {-CORE, CORE} do
		for _, y in {-CORE, CORE} do
			for _, z in {-CORE, CORE} do
				local cornerPart = piece(model, "Polished corner", Enum.PartType.Ball, Vector3.one * RADIUS * 2, CFrame.new(x, y, z), resin, mat)
				cornerPart.Reflectance = refl
			end
		end
	end

	-- High-DPI Vector SurfaceGuis for each of the 6 faces (sub-pixel perfect pips)
	for valueOnFace, face in faces do
		local faceId = normalToFace[face.normal]
		if not faceId then continue end

		local sg = Instance.new("SurfaceGui")
		sg.Name = "Face_" .. valueOnFace
		sg.Face = faceId
		sg.Adornee = root
		sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		sg.CanvasSize = Vector2.new(256, 256)
		sg.LightInfluence = 0.32
		sg.Active, sg.AlwaysOnTop = false, false
		sg.Parent = model

		local card = Instance.new("Frame")
		card.Name = "FaceCard"
		card.Size = UDim2.fromScale(1, 1)
		card.BackgroundColor3 = resin
		card.BackgroundTransparency = 0.05
		card.Parent = sg

		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, 24)
		cardCorner.Parent = card

		local cardBorder = Instance.new("UIStroke")
		cardBorder.Color = rim
		cardBorder.Thickness = 3.5
		cardBorder.Transparency = 0.15
		cardBorder.Parent = card

		local dotDiameter = if valueOnFace == 1 then 0.28 else 0.18
		for _, dot in face.dots do
			local pipFrame = Instance.new("Frame")
			pipFrame.Name = "Pip"
			pipFrame.AnchorPoint = Vector2.new(0.5, 0.5)
			pipFrame.Position = UDim2.fromScale(0.5 + dot[1] * 0.28, 0.5 + dot[2] * 0.28)
			pipFrame.Size = UDim2.fromScale(dotDiameter, dotDiameter)
			pipFrame.BackgroundColor3 = pip
			pipFrame.Parent = card

			local pipCorner = Instance.new("UICorner")
			pipCorner.CornerRadius = UDim.new(0.5, 0)
			pipCorner.Parent = pipFrame

			local pipRim = Instance.new("UIStroke")
			pipRim.Color = rim
			pipRim.Thickness = 2.0
			pipRim.Transparency = 0.25
			pipRim.Parent = pipFrame

			if valueOnFace == 1 then
				local star = Instance.new("TextLabel")
				star.Name = "AceStar"
				star.BackgroundTransparency = 1
				star.Size = UDim2.fromScale(1, 1)
				star.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Heavy)
				star.TextColor3 = rim
				star.TextScaled = true
				star.Text = "★"
				star.Parent = pipFrame
			end
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
	local impactSpawned = false

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
			local support = CORE * (math.abs(orientation.RightVector.Y) + math.abs(orientation.UpVector.Y)
				+ math.abs(orientation.LookVector.Y)) + RADIUS
			pair[i]:PivotTo(CFrame.new(at + Vector3.yAxis * (.285 + support + hop)) * orientation)
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
				if t >= 0.98 and not impactSpawned then
					impactSpawned = true
					if pair[1].PrimaryPart and pair[2].PrimaryPart then
						spawnDiceImpact(tray, pair[1].PrimaryPart.Position, pair[2].PrimaryPart.Position, Art.gold)
					end
				end
				if t == 1 then break end
			end
		end)
	end
	Debris:AddItem(tray, 1.85)
end
