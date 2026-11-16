--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("League")
local RunService = game:GetService("RunService")
local Board = require(Shared.Board)
local Geometry = require(Shared.Geometry)
local Game = require(Shared.Rules).withBoard(Board)
local Pawn = require(script.Parent.Pawn)
local Arena = {}
local hex = function(value: number): Color3 return Color3.fromHex(string.format("%06x", value)) end
local function addMark(parent: Instance, name: string, size: Vector3): Part
	local p = Instance.new("Part")
	p.Name, p.Size, p.Material = name, size, Enum.Material.Neon
	p.Anchored, p.CastShadow = true, false
	p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
	p.Parent = parent
	return p
end

function Arena.new(myId: number)
	local folder = Instance.new("Folder")
	folder.Name = "LocalTablePieces"
	folder.Parent = workspace
	local markers = Instance.new("Folder")
	markers.Name = "Markers"
	markers.Parent = folder
	local selection = Instance.new("Folder")
	selection.Name = "Selection"
	selection.Parent = folder
	local models: {[number]: Model} = {}
	local previews: {Model} = {}
	local serial = -1
	local motionSerial = 0
	local animation: {model: Model, start: number, from: number, steps: number, figure: number}? = nil
	local lastCamera: CFrame? = nil
	local oldSize: Vector2? = nil
	local reduced = false

	local function layoutCamera(camera: Camera)
		local size = camera.ViewportSize
		local aspect = math.max(0.1, size.X / math.max(1, size.Y))
		local portrait = aspect < 1.16
		local fov = 39
		-- Frame the table in the unoccluded part of the viewport.
		local usableWidth = if portrait then 0.90 else math.max(0.40, 1 - (if size.X < 800 then 325 else 377) / size.X)
		local half = math.tan(math.rad(fov / 2))
		local distance = math.max(if portrait then 92 else 113, 68 / (half * aspect * usableWidth))
		local center = Vector3.new(if portrait then 0 else distance * half * aspect * (1 - usableWidth), 0, 0)
		local inclination = if portrait then math.rad(65) else math.rad(53)
		local base = CFrame.lookAt(center + Vector3.new(0, math.sin(inclination), math.cos(inclination)) * distance, center)
		if portrait then base *= CFrame.new(0, -distance * half * 0.40, 0) end
		lastCamera = base
		oldSize = size
		camera.FieldOfView = fov
	end

	local function pawnPoint(index: number, figure: number): Vector3
		local p = Geometry.cells[index]
		return Vector3.new(p.X + (if figure % 2 == 1 then -1.68 else 1.68), 0.57, p.Z + (if figure <= 2 then 1.38 else -1.38))
	end

	local function pose(p: Vector3): CFrame return CFrame.new(p) * CFrame.Angles(0, math.rad(-16), 0) end
	local function arrow(index: number, value: number, label: string)
		local p = Geometry.cells[index]
		local accent = hex(value)
		for _, z in {-4.88, 4.88} do
			local mark = addMark(selection, "Route outline", Vector3.new(15.54, 0.15, 0.21))
			mark.Position, mark.Color = Vector3.new(p.X, 0.58, p.Z + z), accent
		end
		for _, x in {-7.8, 7.8} do
			local mark = addMark(selection, "Route outline", Vector3.new(0.21, 0.15, 9.65))
			mark.Position, mark.Color = Vector3.new(p.X + x, 0.58, p.Z), accent
		end
		local pin = addMark(selection, "Route number", Vector3.new(0.12, 0.12, 0.12))
		pin.Position, pin.Transparency = Vector3.new(p.X + 4.5, 2.2, p.Z), 1
		local info = Instance.new("BillboardGui")
		info.Size = UDim2.fromOffset(36, 29)
		info.AlwaysOnTop = true
		info.MaxDistance = 380
		info.Parent = pin
		local badge = Instance.new("TextLabel")
		badge.Size = UDim2.fromScale(1, 1)
		badge.BackgroundColor3, badge.TextColor3 = accent, hex(0x111A24)
		badge.Text = label
		badge.Font, badge.TextSize = Enum.Font.GothamBold, 14
		badge.Parent = info
		local corners = Instance.new("UICorner")
		corners.CornerRadius = UDim.new(0, 7)
		corners.Parent = badge
	end

	local function sync(snapshot: any)
		local s = snapshot.match
		selection:ClearAllChildren()
		markers:ClearAllChildren()
		if s == nil then
			for id, model in models do model:Destroy(); models[id] = nil end
			animation = nil
			if #previews == 0 then
				for i, spot in {{-34, 29}, {-14, 29}, {14, 29}, {34, 29}} do
					local model = Pawn.make(i, folder)
					model:PivotTo(pose(Vector3.new(spot[1], 0.58, spot[2])))
					table.insert(previews, model)
				end
			end
			return
		end
		for _, model in previews do model:Destroy() end
		table.clear(previews)
		local sameMatch = serial == snapshot.serial
		if not sameMatch then
			for id, model in models do model:Destroy(); models[id] = nil end
			animation = nil
		end
		local colors: {[number]: Color3} = {}
		for _, seat in s.seats do
			local model = models[seat.id]
			if not model then
				model = Pawn.make(seat.figure, folder)
				models[seat.id] = model
			end
			colors[seat.id] = hex(Board.figures[seat.figure].color)
			if not animation or animation.model ~= model then
				model:PivotTo(pose(pawnPoint(seat.position, seat.figure)))
			end
			if sameMatch and not reduced and s.motion.serial > motionSerial and s.motion.who == seat.id then
				animation = {model = model, start = os.clock(), from = s.motion.from, steps = s.motion.steps, figure = seat.figure}
				model:PivotTo(pose(pawnPoint(s.motion.from, seat.figure)))
			end
		end
		serial, motionSerial = snapshot.serial, s.motion.serial
		for i, club in s.clubs do
			if club.owner ~= 0 then
				local p = Geometry.cells[i]
				local flag = addMark(markers, "Club ownership", Vector3.new(9.5, 0.13, 0.30))
				flag.Position, flag.Color = Vector3.new(p.X, 0.58, p.Z + 4.55), colors[club.owner]
				for level = 1, club.level do
					local pip = addMark(markers, "Stadium level", Vector3.new(0.75, 0.42, 0.75))
					pip.Position, pip.Color = Vector3.new(p.X + 6.1, 0.77, p.Z + 4.05 - level), colors[club.owner]
				end
			end
		end
		local active = s.seats[s.active]
		if s.phase == "move" and active.id == myId and not active.bot then
			arrow(Game.target(active.position, s.short), 0xBFFF8A, "1")
			arrow(Game.target(active.position, s.long), 0x80C8FF, "2")
		end
	end

	RunService:BindToRenderStep("WorldDraftCamera", Enum.RenderPriority.Camera.Value + 1, function()
		local camera = workspace.CurrentCamera
		if not camera then return end
		camera.CameraType = Enum.CameraType.Scriptable
		if oldSize ~= camera.ViewportSize or not lastCamera then layoutCamera(camera) end
		camera.CFrame = lastCamera :: CFrame
		local entry = animation
		if not entry then return end
		local slides = (os.clock() - entry.start) / 0.12
		if slides >= entry.steps or reduced then
			entry.model:PivotTo(pose(pawnPoint(Game.target(entry.from, entry.steps), entry.figure)))
			animation = nil
			return
		end
		local index = math.floor(slides)
		local k = slides % 1
		local from, dest = pawnPoint(Game.target(entry.from, index), entry.figure), pawnPoint(Game.target(entry.from, index + 1), entry.figure)
		entry.model:PivotTo(pose(from:Lerp(dest, k) + Vector3.yAxis * math.sin(k * math.pi) * 0.96))
	end)
	return {
		sync = sync,
		reduceMotion = function(value: boolean) reduced = value end,
	}
end

return Arena
