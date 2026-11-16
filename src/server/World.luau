--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local shared = ReplicatedStorage:WaitForChild("League")
local Board = require(shared.Board)
local Geometry = require(shared.Geometry)
local Map = require(script.Parent.MapData)

local C = Color3.fromHex
local rgb = Color3.fromRGB
local function part(parent: Instance, name: string, size: Vector3, pos: Vector3, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = pos
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function plate(parent: Instance, name: string, x: number, z: number, y: number, w: number, d: number, h: number, color: Color3, material: Enum.Material?): Part
	return part(parent, name, Vector3.new(w, h, d), Vector3.new(x, y, z), color, material)
end

local function surface(target: BasePart, face: Enum.NormalId, w: number, h: number): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Artwork"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(w, h)
	gui.LightInfluence = 0
	gui.Parent = target
	return gui
end

local function label(parent: Instance, msg: string, x: number, y: number, w: number, h: number, color: Color3, font: Enum.Font): TextLabel
	local t = Instance.new("TextLabel")
	t.Size, t.Position = UDim2.fromScale(w, h), UDim2.fromScale(x, y)
	t.BackgroundTransparency = 1
	t.Font = font
	t.Text = msg
	t.TextColor3 = color
	t.TextScaled = true
	t.Parent = parent
	return t
end

local function line(parent: Instance, name: string, a: Vector3, b: Vector3, width: number, color: Color3)
	local piece = part(parent, name, Vector3.new(width, 0.07, (b - a).Magnitude), (a + b) / 2, color)
	piece.CFrame = CFrame.lookAt(piece.Position, b)
end

local function build()
	Lighting.ClockTime = 16.25
	Lighting.Brightness = 2.4
	Lighting.Ambient = rgb(89, 102, 131)
	Lighting.OutdoorAmbient = rgb(138, 152, 173)
	Lighting.EnvironmentDiffuseScale = 0.27
	Lighting.EnvironmentSpecularScale = 0.65
	Lighting.GlobalShadows = true

	local stage = Instance.new("Folder")
	stage.Name = "WorldDraftArena"
	local tray = Instance.new("Folder")
	tray.Name = "Board"
	tray.Parent = stage
	local base = C("#0B1323")
	local navy = C("#142338")
	local mint = C("#BFFF8A")
	local soft = C("#C8D5E5")
	local gold = C("#FFD47A")
	local ground = plate(stage, "Concrete plaza", 0, 0, -5.3, 420, 300, 2, C("#0B1423"), Enum.Material.Slate)
	ground.CastShadow = false
	plate(tray, "Mount", 0, 0, -3.42, 125, 84, 1.7, C("#18283C"))
	plate(tray, "Floating trim", 0, 0, -2.55, 124, 83, 0.22, C("#3B6E7C"), Enum.Material.Neon)
	plate(tray, "Tabletop", 0, 0, -1.48, 122, 81, 2.0, navy)
	plate(tray, "Frame", 0, 0, -0.47, 119.3, 78.8, 0.34, C("#2C4760"))
	plate(tray, "Play surface", 0, 0, -0.22, 118, 77.2, 0.30, base)
	for _, z in {-38.75, 38.75} do
		plate(tray, "Edge inlay", 0, z, -0.23, 117.8, 0.18, 0.14, C("#65CCD2"), Enum.Material.Neon)
	end

	local field = Instance.new("Folder")
	field.Name = "Natural Earth relief"
	field.Parent = stage
	local ocean = C("#142F43")
	plate(field, "Ocean inset", 0, -1, -0.04, 84, 53.4, 0.18, ocean)
	for x = -39, 39, 6.5 do plate(field, "Meridian", x, -1, 0.06, 0.07, 51, 0.02, C("#27485A")) end
	for z = -25, 24, 4.9 do plate(field, "Parallel", 0, z, 0.06, 81, 0.07, 0.02, C("#27485A")) end

	local mapWidth, mapDepth = 78, 34
	local mapZ = -4.5
	local dx, dz = mapWidth / Map.columns, mapDepth / Map.rows
	for _, span in Map.spans do
		local row, col, length = span[1], span[2], span[3]
		local height = 0.22 + 0.10 * math.noise(row * 0.27, col * 0.17)
		local color = C("#287062"):Lerp(C("#5B9571"), math.clamp(0.38 + math.noise(col * 0.15, row * 0.2), 0, 1))
		plate(field, "Land", -mapWidth / 2 + (col + length / 2) * dx, mapZ - mapDepth / 2 + (row + 0.5) * dz,
			0.09 + height / 2, length * dx, dz, height, color)
	end

	local function atlasPoint(lon: number, lat: number): Vector3
		return Vector3.new((lon / 360) * mapWidth, 0.39, mapZ - mapDepth / 2 + (83 - lat) / 141 * mapDepth)
	end
	local pins = {
		{2, -3.7, 40.4}, {3, -8.6, 41.2}, {5, -0.1, 51.5}, {7, -6.0, 37.4}, {9, 4.5, 51.9},
		{11, 135.5, 34.7}, {13, -17.4, 14.7}, {15, 126.98, 37.6}, {17, -77.0, -12.0},
		{19, 151.2, -33.9}, {21, -43.2, -22.9}, {23, 18.4, -33.9},
	}
	for _, row in pins do
		local index, lon, lat = row[1], row[2], row[3]
		local pin, cell = atlasPoint(lon, lat), Geometry.cells[index]
		local accent = Color3.fromHex(string.format("%06x", Board.leagues[Board.tiles[index].league].color))
		local target = Vector3.new(cell.X * 0.81, 0.39, cell.Z * 0.78)
		line(field, "Transfer route", pin, target, 0.063, accent:Lerp(ocean, 0.56))
		local bulb = part(field, Board.tiles[index].city, Vector3.new(0.48, 0.48, 0.48), pin + Vector3.yAxis * 0.11, accent, Enum.Material.Neon)
		bulb.Shape = Enum.PartType.Ball
	end
	local banner = plate(field, "World Draft wordmark", 0, 19.8, 0.17, 53, 8.2, 0.19, C("#112638"))
	local word = surface(banner, Enum.NormalId.Top, 920, 160)
	label(word, "F O O T B O L A P O L I A", 0.04, 0.08, 0.92, 0.58, C("#E3F2E7"), Enum.Font.GothamBlack)
	label(word, "T H E   W O R L D   D R A F T      /      C O N T I N E N T A L   C U P", 0.1, 0.71, 0.8, 0.19, C("#94D2B4"), Enum.Font.GothamMedium)
	for _, mark in {{-30, 19.8}, {30, 19.8}} do
		plate(field, "Pitch marking", mark[1], mark[2], 0.11, 2.8, 0.13, 0.10, mint, Enum.Material.Neon)
	end

	local center = Vector3.new(0, 0, 0)
	for i, tile in Board.tiles do
		local p = Geometry.cells[i]
		local accent = if tile.league > 0 then rgb(
			math.floor(Board.leagues[tile.league].color / 65536),
			math.floor(Board.leagues[tile.league].color / 256) % 256,
			Board.leagues[tile.league].color % 256
		) else Color3.fromHex(string.format("%06x", Geometry.colors[tile.kind]))
		local tiles = Instance.new("Folder")
		tiles.Name = string.format("%02d %s", i, tile.name)
		tiles.Parent = tray
		plate(tiles, "Shadow", p.X, p.Z, 0.05, 16.15, 10.25, 0.24, accent:Lerp(base, 0.68))
		local tilePlate = plate(tiles, "Enamel", p.X, p.Z, 0.32, 15.55, 9.65, 0.42, accent:Lerp(navy, 0.89))
		plate(tiles, "Color strip", p.X, p.Z - 4.62, 0.53, 15.55, 0.38, 0.09, accent, Enum.Material.Neon)
		local sg = surface(tilePlate, Enum.NormalId.Top, 340, 210)
		label(sg, string.format("%02d  /  %s", i, if tile.league > 0 then Board.leagues[tile.league].code else "WORLD"), 0.06, 0.13, 0.88, 0.13, accent, Enum.Font.GothamBold)
		label(sg, string.upper(tile.code), 0.1, 0.28, 0.8, 0.40, if tile.league > 0 then soft else accent, Enum.Font.GothamBlack)
		local note = if tile.kind == "club" then string.upper(tile.city) .. "  ·  " .. tile.price
			elseif tile.kind == "kickoff" then "KICKOFF  ·  +140"
			elseif tile.kind == "tactics" then "TACTICS CARD"
			elseif tile.kind == "matchday" then "CUP CHANCE" else "BONUS  ·  +" .. tile.award
		label(sg, note, 0.07, 0.74, 0.86, 0.13, soft, Enum.Font.GothamMedium)
		local nextPos = Geometry.cells[i % #Geometry.cells + 1]
		local arrowPos = p:Lerp(nextPos, 0.5)
		plate(tray, "Lane marker", arrowPos.X, arrowPos.Z, 0.17, 0.28, 0.28, 0.08, gold, Enum.Material.Neon)
	end

	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do
			local x, z = sx * 67, sz * 45
			plate(stage, "Floodlight footing", x, z, -3.7, 5, 5, 1.10, navy)
			part(stage, "Floodlight tower", Vector3.new(0.9, 13, 0.9), Vector3.new(x, 2.6, z), C("#24384C"), Enum.Material.Metal)
			local rig = part(stage, "Floodlight housing", Vector3.new(5.3, 2.4, 0.85), Vector3.new(x, 9.1, z), navy)
			rig.CFrame = CFrame.lookAt(rig.Position, center)
			for column = -2, 2 do
				for row = -1, 1 do
					local px = part(stage, "Floodlight LED", Vector3.new(0.74, 0.44, 0.24), rig.Position, soft, Enum.Material.Neon)
					px.CFrame = rig.CFrame * CFrame.new(column * 0.95, row * 0.58, -0.49)
				end
			end
		end
		for rank = 1, 3 do
			local x = sx * (69 + rank * 3.5)
			local rail = plate(stage, "Grandstand terrace", x, 0, -3.6 + rank * 0.55, 3.15, 75, 1.05, C("#142138"))
			plate(stage, "Terrace trim", rail.Position.X, 0, rail.Position.Y + 0.55, 0.18, 72, 0.11, C("#2D6475"))
		end
	end
	stage.Parent = workspace
	return stage
end
return build
