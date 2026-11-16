--!strict
local Lighting = game:GetService("Lighting")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("League")
local Board = require(shared.Board)
local Geometry = require(shared.Geometry)
local Art = require(shared.Presentation)
local C = Color3.fromHex
local ink, paper, slate = Art.ink, Art.paper, Art.slate
local metal = Enum.Material.Metal

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name, f.Parent = name, parent
	return f
end

local function part(parent: Instance, name: string, size: Vector3, pose: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, pose, color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
	p.Parent = parent
	return p
end

local function plate(parent: Instance, name: string, x: number, z: number, y: number, w: number, d: number,
	h: number, color: Color3, material: Enum.Material?): Part
	return part(parent, name, Vector3.new(w, h, d), CFrame.new(x, y, z), color, material)
end

local function beam(parent: Instance, name: string, a: Vector3, b: Vector3, w: number, color: Color3, material: Enum.Material?): Part
	local delta = b - a
	local up = if math.abs(delta.Unit.Y) > .98 then Vector3.xAxis else Vector3.yAxis
	return part(parent, name, Vector3.new(w, w, delta.Magnitude), CFrame.lookAt((a + b) * .5, b, up), color, material)
end

local function drawTile(tray: Instance, index: number, tile: Board.Tile)
	local cell = Geometry.cells[index]
	local accent = Art.accent(tile.kind, tile.league)
	local tileFolder = folder(tray, string.format("%02d %s", index, tile.name))
	plate(tileFolder, "Bezel", cell.X, cell.Z, .16, 16.5, 10.62, .30, ink)
	plate(tileFolder, "Championship enamel", cell.X, cell.Z, .35, 16.2, 10.28, .39, accent:Lerp(slate, .35))
	local face = if tile.price > 0 then paper else paper:Lerp(accent, .25)
	local top = plate(tileFolder, "Printed tile", cell.X, cell.Z, Art.tileTop - .10, Art.tileWidth, Art.tileDepth, .20, face)
	top:SetAttribute("BoardIndex", index)
	plate(tileFolder, "Color inlay", cell.X, cell.Z - 4.50, Art.tileTop + .01, 15.4, .55, .025, accent).CastShadow = false
	local x, z = cell.X + 6.48, cell.Z - 3.23
	if tile.kind == "kickoff" then
		plate(tileFolder, "Kickoff marker foot", x, z, Art.tileTop + .14, 1.02, .84, .28, ink)
		beam(tileFolder, "Kickoff pennant staff", Vector3.new(x, Art.tileTop + .20, z), Vector3.new(x, Art.tileTop + 2.82, z), .12, ink)
		plate(tileFolder, "Kickoff pennant", x - .56, z, Art.tileTop + 2.33, 1.18, .14, .85, accent)
	elseif tile.kind == "goalDeck" or tile.kind == "offsideDeck" then
		for stack = 0, 2 do
			part(tileFolder, "Card deck", Vector3.new(1.62, .20, 2.32),
				CFrame.new(x, Art.tileTop + .14 + stack * .16, z) * CFrame.Angles(0, stack * .13, 0),
				if stack % 2 == 0 then accent else paper)
		end
	elseif tile.kind == "matchday" then
		local football = plate(tileFolder, "Matchday ball", x, z, Art.tileTop + .64, 1.32, 1.32, 1.32, paper)
		football.Shape = Enum.PartType.Ball
		for _, side in {-1, 1} do
			local panel = plate(tileFolder, "Ball stitching", x + side * .42, z, Art.tileTop + 1.01, .56, .74, .40, ink)
			panel.Shape = Enum.PartType.Ball
		end
	end
	-- Letters are composited in screen space by BoardLabels so they retain sharp edges.
end

local function pitch(parent: Instance)
	local field = folder(parent, "Pitch and goals")
	plate(field, "Runoff", 0, 0, .18, 69, 32.7, .25, C("137152"))
	local grass, darkGrass = C("249F66"), C("198357")
	for stripe = 0, 11 do
		plate(field, "Mown strip", -31.5 + (stripe + .5) * 5.25, 0, .305,
			5.25, 29.4, .07, if stripe % 2 == 0 then grass else darkGrass).CastShadow = false
	end
	for _, side in {-1, 1} do
		local z = side * 16.06
		for index = -2, 2 do
			local tint = if index % 2 == 0 then C("CFECC9") else C("4F987B")
			plate(field, "Sideline panel", index * 10.1, z, .47, 9.72, .25, .38, tint).CastShadow = false
		end
		for _, x in {-26, 26} do
			plate(field, "Technical bench base", x, z * 1.035, .51, 6.8, 1.3, .36, ink)
			for seat = -2, 2 do
				plate(field, "Bench seat", x + seat * 1.04, z * 1.036, .75, .86, .70, .26, paper).CastShadow = false
			end
		end
	end
	local lineY = .356
	local paint = C("D4F6DB")
	local function mark(ax: number, az: number, bx: number, bz: number, width: number?)
		beam(field, "Pitch marking", Vector3.new(ax, lineY, az), Vector3.new(bx, lineY, bz), width or .10, paint).CastShadow = false
	end
	local function ring(cx: number, radius: number, first: number, sweep: number, count: number)
		for i = 0, count - 1 do
			local a, b = first + i * sweep / count, first + (i + 1) * sweep / count
			mark(cx + math.cos(a) * radius, math.sin(a) * radius, cx + math.cos(b) * radius, math.sin(b) * radius)
		end
	end
	mark(0, -14, 0, 14)
	ring(0, 4.5, 0, 2 * math.pi, 32)
	plate(field, "Center spot", 0, 0, lineY + .02, .30, .30, .05, paint).CastShadow = false
	for _, side in {-1, 1} do
		mark(-31 * side, 14 * side, 31 * side, 14 * side)
		mark(31 * side, -14, 31 * side, 14)
		for _, box in {{21.5, 8.4}, {27.4, 4.8}} do
			mark(box[1] * side, -box[2], box[1] * side, box[2])
			for _, endline in {-1, 1} do mark(box[1] * side, box[2] * endline, 31 * side, box[2] * endline) end
		end
		local front, back, floor, crossbar = 31 * side, 33.8 * side, .41, 2.78
		local net = C("9FD5C9")
		for _, post in {-3.2, 3.2} do
			beam(field, "Goalpost", Vector3.new(front, floor, post), Vector3.new(front, crossbar, post), .19, paper)
			beam(field, "Goal brace", Vector3.new(front, crossbar, post), Vector3.new(back, floor + .31, post), .11, paper)
		end
		beam(field, "Crossbar", Vector3.new(front, crossbar, -3.2), Vector3.new(front, crossbar, 3.2), .19, paper)
		for z = -3, 3, .6 do
			beam(field, "Net cord", Vector3.new(front, crossbar - .07, z), Vector3.new(back, floor + .31, z), .035, net).CastShadow = false
		end
		for row = 0, 5 do
			local t = row / 5
			local x, y = front + (back - front) * t, crossbar - .07 - (crossbar - floor - .38) * t
			beam(field, "Net weft", Vector3.new(x, y, -3.2), Vector3.new(x, y, 3.2), .038, net).CastShadow = false
		end
	end
end

local function terraces(stage: Instance)
	local stands = folder(stage, "Grandstands")
	for _, side in {-1, 1} do
		for section = -3, 3 do
			local x = section * 9.1
			plate(stands, "Concrete caisson", x, side * 22.5, .28, 8.72, 6.55, .83, slate)
			for tier = 1, 4 do
				local y, z = .63 + tier * .40, side * (18.7 + tier * 1.42)
				plate(stands, "Riser", x, z, y - .23, 8.52, 1.51, .65, ink)
				local tint = if (tier + section) % 3 == 0 then C("A7D7B9") else C("348976")
				for seat = -2, 2 do
					plate(stands, "Molded seat", x + seat * 1.62, z, y + .13, 1.39, .84, .22, tint).CastShadow = false
				end
			end
			plate(stands, "Aisle light", x - 4.33, side * 21.9, 1.32, .17, 5.65, .14, Art.mint, Enum.Material.Neon).CastShadow = false
		end
		for _, wing in {-1, 1} do
			local x, z = wing * 38.0, side * 18.4
			plate(stands, "Entry portal", x, z, .69, 5.2, 4.6, 1.18, slate)
			plate(stands, "Player tunnel", x, z, 1.01, 3.2, 4.85, .61, ink)
			plate(stands, "Tunnel canopy", x, z, 1.54, 5.0, 4.6, .24, C("6C9293"), metal)
			plate(stands, "Tunnel light", x, z - side * 2.26, 1.54, 4.55, .08, .09, Art.mint, Enum.Material.Neon).CastShadow = false
		end
	end
end

local function surroundings(stage: Folder)
	local scene = folder(stage, "Arena surroundings")
	plate(scene, "Matte backdrop", 0, 0, -6, 700, 700, 1.5, C("13272E")).CastShadow = false
	plate(scene, "Floating concrete podium", 0, 0, -4.83, 140, 93, .70, C("203F44"))
	for _, side in {-1, 1} do
		local x = 63.5 * side
		for _, z in {-34, 27} do
			local base, top = Vector3.new(x, -3.0, z), Vector3.new(x, 7.7, z)
			beam(scene, "Floodlight spine", base, top, .36, C("729397"), metal)
			for brace = 0, 4 do
				local a = base + Vector3.new(0, brace * 1.85, -0.55)
				beam(scene, "Tower truss", a, a + Vector3.new(0, 1.85, 1.1), .14, C("729397"), metal).CastShadow = false
			end
			local head = CFrame.lookAt(top, Vector3.new(x * .30, 0, z * .4))
			part(scene, "Floodlight wing", Vector3.new(5.6, .96, .60), head, slate, metal)
			for bulb = -2, 2 do
				part(scene, "Floodlight lens", Vector3.new(.86, .61, .16), head * CFrame.new(bulb * 1.03, 0, -.36),
					C("DBFFF2"), Enum.Material.Neon).CastShadow = false
			end
		end
	end
end

local function build()
	Lighting.ClockTime, Lighting.GeographicLatitude, Lighting.Brightness = 15.2, 19, 2.2
	Lighting.Ambient, Lighting.OutdoorAmbient = C("7E9595"), C("A1B7B4")
	Lighting.EnvironmentDiffuseScale, Lighting.EnvironmentSpecularScale = .41, .57
	Lighting.GlobalShadows, Lighting.ShadowSoftness = true, .38
	local stage = Instance.new("Folder")
	stage.Name = "WorldDraftArena"
	surroundings(stage)
	local tray = folder(stage, "Board")
	plate(tray, "Table foot", 0, 0, -3.9, 123, 81.4, .82, ink)
	plate(tray, "Anodized table body", 0, 0, -2.44, 127, 84.4, 2.1, C("24454F"), metal)
	plate(tray, "Championship line", 0, 0, -1.27, 126.8, 84.2, .25, Art.gold, metal)
	plate(tray, "Table lip", 0, 0, -.57, 126.6, 84, 1.16, C("346569"))
	plate(tray, "Recessed plane", 0, 0, -.02, 122.8, 79.4, .39, ink)
	local center = folder(stage, "Continental Cup stadium")
	plate(center, "Stadium foundations", 0, 0, .03, 84.6, 54.5, .44, C("214C4C"))
	pitch(center)
	terraces(center)
	for index, tile in Board.tiles do drawTile(tray, index, tile) end
	stage.Parent = workspace
	return stage
end

return build
