--!strict
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Art = require(ReplicatedStorage:WaitForChild("League").Presentation)
local Meshes = require(script.Parent.MeshLibrary)

local faces = {
	{normal = Vector3.yAxis, top = CFrame.identity, dots = {{0, 0}}},
	{normal = Vector3.xAxis, top = CFrame.Angles(0, 0, math.pi / 2), dots = {{-1, -1}, {1, 1}}},
	{normal = Vector3.zAxis, top = CFrame.Angles(-math.pi / 2, 0, 0), dots = {{-1, -1}, {0, 0}, {1, 1}}},
	{normal = -Vector3.zAxis, top = CFrame.Angles(math.pi / 2, 0, 0), dots = {{-1, -1}, {1, -1}, {-1, 1}, {1, 1}}},
	{normal = -Vector3.xAxis, top = CFrame.Angles(0, 0, -math.pi / 2), dots = {{-1, -1}, {1, -1}, {0, 0}, {-1, 1}, {1, 1}}},
	{normal = -Vector3.yAxis, top = CFrame.Angles(math.pi, 0, 0), dots = {{-1, -1}, {1, -1}, {-1, 0}, {1, 0}, {-1, 1}, {1, 1}}},
}
local function part(model: Model, name: string, size: Vector3, pose: CFrame, tint: Color3): Part
	local node = Instance.new("Part")
	node.Name, node.Size, node.CFrame, node.Color = name, size, pose, tint
	node.Material, node.Anchored = Enum.Material.SmoothPlastic, true
	node.CanCollide, node.CanQuery, node.CanTouch = false, false, false
	node.Parent = model
	return node
end

local function die(parent: Folder, value: number): Model
	local model = Instance.new("Model")
	model.Name = "Die " .. value
	local body = part(model, "Beveled shell", Vector3.one * 5.15, CFrame.identity, Color3.fromHex("D51F58"))
	Meshes.apply("die", body)
	for _, face in faces do
		local normal = face.normal
		local vertical = if math.abs(normal.Y) > .5 then Vector3.zAxis else Vector3.yAxis
		local horizontal = vertical:Cross(normal)
		for _, dot in face.dots do
			local at = normal * 2.576 + horizontal * (dot[1] * 1.12) + vertical * (dot[2] * 1.12)
			local mark = part(model, "Ivory pip", Vector3.new(.10, .77, .77),
				CFrame.fromMatrix(at, normal, vertical, normal:Cross(vertical)), Color3.fromHex("FFF3DD"))
			mark.Shape, mark.CastShadow = Enum.PartType.Cylinder, false
		end
	end
	model.WorldPivot, model.Parent = CFrame.identity, parent
	return model
end

return function(parent: Folder, first: number, second: number, reduced: boolean)
	local old = parent:FindFirstChild("Dice roll")
	if old then old:Destroy() end
	local tray = Instance.new("Folder")
	tray.Name, tray.Parent = "Dice roll", parent
	local pair = {die(tray, first), die(tray, second)}
	-- A settled face uses the server result. The tumble only controls its presentation.
	local function pose(t: number)
		for i, result in {first, second} do
			local sign = if i == 1 then -1 else 1
			local at = Art.boardNear * (-12 + 8 * (t - 1)) + Art.boardRight * sign * (4.25 - (1 - t) * 2.1)
			local hop = math.sin(math.pi * t) * (1 - t) * 12
			local settled = CFrame.Angles(0, .16 * sign, 0) * faces[result].top
			local flip = CFrame.Angles((1 - t) * math.pi * 2.1, sign * (1 - t) * 1.75, (1 - t) * 2.6)
			pair[i]:PivotTo(CFrame.new(at + Vector3.yAxis * (2.86 + hop)) * flip * settled)
		end
	end
	pose(if reduced then 1 else 0)
	if not reduced then
		task.spawn(function()
			local clock = os.clock()
			while tray.Parent do
				local t = math.clamp((os.clock() - clock) / .42, 0, 1)
				pose(t)
				if t == 1 then break end
				task.wait()
			end
		end)
	end
	Debris:AddItem(tray, 1.35)
end
