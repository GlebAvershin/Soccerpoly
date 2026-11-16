--!strict
local Lighting = game:GetService("Lighting")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("League")
local Board = require(shared.Board)
local Geometry = require(shared.Geometry)
local Art = require(shared.Presentation)
local Map = require(script.Parent.MapData)
local C = Color3.fromHex
local ink, paper, slate = Art.ink, Art.paper, Art.slate

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name, f.Parent = name, parent
	return f
end

local function part(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name, p.Size, p.Position, p.Color = name, size, position, color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
	p.Parent = parent
	return p
end

local function plate(parent: Instance, name: string, x: number, z: number, y: number, w: number, d: number,
	h: number, color: Color3, material: Enum.Material?): Part
	return part(parent, name, Vector3.new(w, h, d), Vector3.new(x, y, z), color, material)
end

local function disc(parent: Instance, name: string, x: number, y: number, z: number, diameter: number, height: number, color: Color3): Part
	local p = part(parent, name, Vector3.new(height, diameter, diameter), Vector3.new(x, y, z), color)
	p.Shape = Enum.PartType.Cylinder
	p.CFrame *= CFrame.Angles(0, 0, math.pi / 2)
	return p
end

local function surface(target: BasePart, face: Enum.NormalId, w: number, h: number): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name, gui.Face = "Artwork", face
	gui.SizingMode, gui.CanvasSize = Enum.SurfaceGuiSizingMode.FixedSize, Vector2.new(w, h)
	gui.LightInfluence, gui.ZOffset = 0, .10
	gui.Parent = target
	return gui
end

local function printPlate(target: Part, w: number, h: number): SurfaceGui
	-- A Top SurfaceGui starts along the part's negative Z axis.
	target.Size = Vector3.new(target.Size.Z, target.Size.Y, target.Size.X)
	target.CFrame *= CFrame.Angles(0, -math.pi / 2, 0)
	return surface(target, Enum.NormalId.Top, w, h)
end

local function frame(parent: Instance, x: number, y: number, w: number, h: number, color: Color3, radius: number?): Frame
	local f = Instance.new("Frame")
	f.Position, f.Size = UDim2.fromScale(x, y), UDim2.fromScale(w, h)
	f.BackgroundColor3, f.BorderSizePixel = color, 0
	if radius then
		local corner = Instance.new("UICorner")
		corner.CornerRadius, corner.Parent = UDim.new(0, radius), f
	end
	f.Parent = parent
	return f
end

local function label(parent: Instance, name: string, msg: string, x: number, y: number, w: number, h: number,
	color: Color3, font: Enum.Font, center: boolean?): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.Size, t.Position = UDim2.fromScale(w, h), UDim2.fromScale(x, y)
	t.BackgroundTransparency = 1
	t.Font, t.Text, t.TextColor3, t.TextScaled = font, msg, color, true
	t.TextXAlignment = if center then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left
	t.Parent = parent
	return t
end

local function drawTile(tray: Instance, index: number, tile: Board.Tile)
	local p = Geometry.cells[index]
	local accent = Art.accent(tile.kind, tile.league)
	local tileFolder = folder(tray, string.format("%02d %s", index, tile.name))
	plate(tileFolder, "Inset shadow", p.X, p.Z, 0.06, 16.38, 10.42, 0.19, slate:Lerp(ink, .45))
	plate(tileFolder, "Molded rim", p.X, p.Z, 0.26, 16.08, 10.09, 0.43, accent:Lerp(ink, .27))
	local top = plate(tileFolder, "Printed tile", p.X, p.Z, Art.tileTop - 0.11, Art.tileWidth, Art.tileDepth, 0.22, paper)
	top:SetAttribute("BoardIndex", index)
	local sg = printPlate(top, 344, 215)
	local faceColor = if tile.league > 0 then paper else paper:Lerp(accent, .22)
	frame(sg, .027, .037, .946, .926, faceColor, 16)
	frame(sg, .027, .037, .946, .092, accent, 8)
	if tile.price > 0 then
		local title = string.gsub(tile.name, " ", "\n", 1)
		label(sg, "PropertyName", title, .064, .167, .872, .54, ink, Enum.Font.GothamBlack, true)
		frame(sg, .125, .743, .20, .156, accent, 7)
		label(sg, "Crest", tile.code, .134, .764, .182, .115, ink, Enum.Font.GothamBlack, true)
		label(sg, "Value", tostring(tile.price) .. " CR", .366, .719, .51, .205, C("365367"), Enum.Font.GothamBold)
	else
		frame(sg, .065, .235, .195, .58, accent, 13)
		label(sg, "Crest", Art.sign[tile.kind], .069, .327, .184, .37, ink, Enum.Font.GothamBlack, true)
		label(sg, "EventName", Art.shortStop[tile.kind], .297, .203, .65, .34, ink, Enum.Font.GothamBlack)
		local value = if tile.kind == "kickoff" then "+" .. Board.kickoffCash .. " CR"
			elseif tile.kind == "matchday" then "Play for a cup" else "Draw a card"
		label(sg, "Value", value, .30, .555, .635, .255, C("365367"), Enum.Font.GothamBold)
	end
end

local function atlas(parent: Instance)
	local field = folder(parent, "Atlas diorama")
	local ocean = Art.sea
	plate(field, "Atlas inner frame", 0, -0.7, -0.01, 84.8, 54, 0.55, C("426F86"))
	plate(field, "Ocean", 0, -0.7, 0.23, 83.2, 52.6, 0.15, ocean)
	for x = -38, 38, 7.6 do
		plate(field, "Longitude", x, -1, .310, .05, 50, .015, C("A7D8E1")).CastShadow = false
	end
	for z = -24, 23, 4.7 do
		plate(field, "Latitude", 0, z, .310, 81, .05, .015, C("A7D8E1")).CastShadow = false
	end
	local width, depth, offset = 78, 36, -5.1
	local dx, dz = width / Map.columns, depth / Map.rows
	for _, span in Map.spans do
		local row, col, length = span[1], span[2], span[3]
		local height = .38 + .21 * math.noise(row * .21, col * .19)
		local color = C("6BAA91"):Lerp(C("B0CE88"), math.clamp(.57 + math.noise(col * .15, row * .2), 0, 1))
		plate(field, "Land relief", -width / 2 + (col + length / 2) * dx, offset - depth / 2 + (row + .5) * dz,
			.32 + height / 2, length * dx, dz, height, color)
	end
	-- The five leagues are all represented in Europe on this edition of the world map.
	local europeX = 9 * width / 360
	local europeZ = offset - depth / 2 + (83 - 48) * depth / 141
	disc(field, "Europe plinth", europeX, .83, europeZ, 2.2, .22, ink)
	disc(field, "Europe emblem", europeX, 1.03, europeZ, 1.55, .22, Art.gold)
	plate(field, "Europe pin", europeX, 1.52, europeZ, .27, .27, .88, paper)
	plate(field, "Europe flag", europeX + .42, 1.84, europeZ, .72, .15, .45, Art.gold)

	local ad = plate(field, "Scoreboard enamel", 0, 19.1, .42, 31.6, 7.8, .30, slate)
	local sign = printPlate(ad, 480, 120)
	frame(sign, .024, .06, .952, .88, ink, 21)
	label(sign, "Tournament", "CONTINENTAL CUP", .11, .195, .78, .59, paper, Enum.Font.GothamBlack, true)
	for _, x in {-33.4, 33.4} do
		plate(field, "Warm-up pitch", x, 19.4, .45, 12.3, 7.9, .25, Art.field)
		for j = -2, 2, 2 do
			plate(field, "Pitch stripes", x + j * 1.85, 19.4, .584, 1.63, 7.35, .035, C("409681")).CastShadow = false
		end
		plate(field, "Halfway line", x, 19.4, .611, .074, 7.14, .030, paper).CastShadow = false
		for _, side in {-1, 1} do
			plate(field, "Touchline", x, 19.4 + side * 3.53, .609, 11.64, .075, .03, paper).CastShadow = false
			for _, post in {-1, 1} do
				plate(field, "Goalpost", x + 5.63 * side, 19.4 + post * 1.09, 1.07, .13, .13, .98, paper)
			end
			plate(field, "Crossbar", x + 5.63 * side, 19.4, 1.55, .13, 2.25, .13, paper)
		end
	end
end

local function surroundings(stage: Folder)
	local scenery = folder(stage, "Stadium surroundings")
	plate(scenery, "Table felt", 0, 0, -5.2, 650, 650, 1.2, C("4D968B")).CastShadow = false
	plate(scenery, "Outer concourse", 0, 0, -4.47, 154, 108, .5, C("BAE1C7"))
	local crowd = {C("FABB6D"), C("79BAD9"), C("EB8874"), C("CBD883"), C("6DB6A7"), C("DFCCA8")}
	for rank = 1, 3 do
		local z = -46 - rank * 2.65
		plate(scenery, "Grandstand terrace", 0, z, -3.93 + rank * .51, 113, 2.53, .89, C("426C79"))
		for block = -6, 6 do
			if block ~= 0 then
				local hue = crowd[(block + 2 * rank) % #crowd + 1]
				local bench = plate(scenery, "Terrace seating", block * 8.1, z + .13, -3.45 + rank * .51,
					7.4, 1.46, .24, hue)
				bench.CastShadow = false
			end
		end
	end
	for _, sign in {-1, 1} do
		plate(scenery, "Tunneled entrance", 66 * sign, -11, -3.78, 4.7, 43, 1.05, slate)
		plate(scenery, "Entrance canopy", 66 * sign, -11, .23, 5.4, 40, .28, C("7CADAF"))
		for z = -27, 7, 8.5 do
			plate(scenery, "Canopy stanchion", 66 * sign, z, -1.91, .28, .29, 4.18, ink)
		end
		for _, sz in {-1, 1} do
			local x, z = sign * 64.3, sz * 43.8
			disc(scenery, "Light tower plinth", x, -3.86, z, 3.55, .84, slate)
			disc(scenery, "Light tower", x, .24, z, .38, 7.7, C("73929E"))
			plate(scenery, "Floodlight housing", x, z, 4.18, 4.4, .76, 1.30, slate)
			for i = -2, 2 do
				plate(scenery, "Floodlight glass", x + i * .76, z + .39, 4.21, .59, .12, .80, C("FFEBC4"))
			end
		end
	end
end

local function build()
	Lighting.ClockTime, Lighting.GeographicLatitude, Lighting.Brightness = 14.2, 22, 2.35
	Lighting.Ambient, Lighting.OutdoorAmbient = C("A1B5C5"), C("ADBEC6")
	Lighting.EnvironmentDiffuseScale, Lighting.EnvironmentSpecularScale = .30, .50
	Lighting.GlobalShadows = true
	local stage = Instance.new("Folder")
	stage.Name = "WorldDraftArena"
	surroundings(stage)
	local tray = folder(stage, "Board")
	plate(tray, "Table foot", 0, 0, -3.66, 125.5, 83.5, 1.10, ink)
	plate(tray, "Table body", 0, 0, -2.36, 127.2, 84.8, 1.72, C("355F77"))
	plate(tray, "Painted edge", 0, 0, -1.42, 126.6, 84.2, .34, Art.gold)
	plate(tray, "Edge lip", 0, 0, -.68, 125, 83.4, 1.18, C("6D9FA9"))
	plate(tray, "Recessed play surface", 0, 0, -.17, 119.5, 78.2, .33, slate)
	for _, x in {-60.95, 60.95} do
		plate(tray, "Long touchline", x, 0, .04, .15, 76.3, .08, paper)
	end
	for _, z in {-39.8, 39.8} do
		plate(tray, "Short touchline", 0, z, .04, 121.7, .15, .08, paper)
	end
	atlas(stage)
	for index, tile in Board.tiles do drawTile(tray, index, tile) end
	stage.Parent = workspace
	return stage
end

return build
