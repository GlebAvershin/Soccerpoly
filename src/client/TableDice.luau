--!strict
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Art = require(ReplicatedStorage:WaitForChild("League").Presentation)

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

local function piece(model: Model, name: string, shape: Enum.PartType, size: Vector3, pose: CFrame, tint: Color3): Part
	local node = Instance.new("Part")
	node.Name, node.Shape, node.Size, node.CFrame, node.Color = name, shape, size, pose, tint
	node.Material, node.Anchored = Enum.Material.SmoothPlastic, true
	node.TopSurface, node.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	node.CanCollide, node.CanQuery, node.CanTouch = false, false, false
	node.Parent = model
	return node
end

local function die(parent: Folder, value: number, ivory: boolean): Model
	local model = Instance.new("Model")
	model.Name = "Die " .. value
	local resin = if ivory then C("FFF1D3") else C("A92143")
	local pip = if ivory then C("152C39") else C("FFF6DC")
	local rim = if ivory then C("BC9860") else C("60152C")
	-- Native flat faces, tangent quarter-round edges and spherical corners always
	-- have the same dimensions, including when editable-mesh memory is unavailable.
	for i, axis in axes do
		local u, v = axes[i % 3 + 1], axes[(i + 1) % 3 + 1]
		local plane = CFrame.fromMatrix(Vector3.zero, axis, u, v)
		piece(model, "Moulded face", Enum.PartType.Block, Vector3.new(HALF, CORE, CORE) * 2, plane, resin)
		for _, su in {-1, 1} do
			for _, sv in {-1, 1} do
				piece(model, "Radius edge", Enum.PartType.Cylinder, Vector3.new(CORE, RADIUS, RADIUS) * 2,
					plane + (u * su + v * sv) * CORE, resin)
			end
		end
	end
	for _, x in {-CORE, CORE} do
		for _, y in {-CORE, CORE} do
			for _, z in {-CORE, CORE} do
				piece(model, "Polished corner", Enum.PartType.Ball, Vector3.one * RADIUS * 2, CFrame.new(x, y, z), resin)
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
	local pair = {die(tray, first, true), die(tray, second, false)}
	local results = {first, second}
	local function pose(t: number)
		for i, result in results do
			local sign = if i == 1 then -1 else 1
			local remaining = (1 - t) ^ 1.55
			local at = Art.boardNear * (-11 - remaining * (7 + i)) + Art.boardRight * sign * (5.55 + remaining * 2.6)
			local hop = if t < .66 then math.sin(math.pi * t / .66) * (3.9 + i * .6)
				else math.sin(math.pi * (t - .66) / .34) * .86
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
				local t = math.clamp((os.clock() - start) / .43, 0, 1)
				pose(t)
				if t == 1 then break end
			end
		end)
	end
	Debris:AddItem(tray, 1.35)
end
