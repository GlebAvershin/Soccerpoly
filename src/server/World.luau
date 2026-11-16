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

local function decoration(parent: Instance, name: string, shape: string, size: Vector3, pose: CFrame): Folder
	local group = folder(parent, name)
	local marker = part(group, name, size, pose, Color3.new(1, 1, 1))
	marker.Transparency = 1
	marker:SetAttribute("MeshShape", shape)
	marker:SetAttribute("MeshPlaceholder", true)
	return folder(group, "Fallback")
end

local function drawTile(tray: Instance, index: number, tile: Board.Tile)
	local cell = Geometry.cells[index]
	local accent = Art.accent(tile.kind, tile.league)
	local base = Vector3.new(cell.X, Art.tileTop, cell.Z)
	local tileFolder = folder(tray, string.format("%02d %s", index, tile.name))
	plate(tileFolder, "Bezel", cell.X, cell.Z, .13, 16.62, 16.62, .25, C("574C45"))
	plate(tileFolder, "League edge", cell.X, cell.Z, .34, 16.20, 16.20, .39, accent:Lerp(Art.ink, .21))
	local face = if tile.price > 0 then paper:Lerp(accent, .12) else paper:Lerp(accent, .50)
	local top = plate(tileFolder, "Printed tile", cell.X, cell.Z, Art.tileTop - .20, Art.tileWidth, Art.tileDepth, .40, face)
	top:SetAttribute("BoardIndex", index)
	top:SetAttribute("MeshShape", "enamel")

	local side = math.floor((index - 1) / 6)
	local edge = CFrame.new(base + Vector3.yAxis * .018) * CFrame.Angles(0, side * math.pi * .5, 0)
	part(tileFolder, "Color inlay", Vector3.new(15.1, .046, 1.36),
		edge * CFrame.new(0, 0, 6.92), accent:Lerp(Art.ink, .12)).CastShadow = false

	local symbol = base - Art.boardNear * 3.22 - Art.boardRight * 2.75
	local x, z = symbol.X, symbol.Z
	if tile.league > 0 then
		local hue = Art.hex(Art.clubColors[index])
		local shieldPose = CFrame.lookAt(symbol + Vector3.yAxis * 1.72, symbol + Vector3.yAxis * 1.72 - Art.boardNear)
		local outer = part(tileFolder, "Club shield", Vector3.new(3.85, .36, 4.22),
			shieldPose * CFrame.Angles(1.38, 0, 0), paper)
		outer:SetAttribute("MeshShape", "crest")
		local shield = part(tileFolder, "Club enamel", Vector3.new(3.41, .37, 3.66),
			shieldPose * CFrame.Angles(1.38, 0, 0) * CFrame.new(0, .18, 0), hue)
		shield:SetAttribute("MeshShape", "crest")
		local letters = part(tileFolder, "Shield type", Vector3.new(2.94, 1.31, .05),
			shieldPose * CFrame.new(0, .30, .49), hue)
		letters.Transparency, letters.CastShadow = 1, false
		local printFace = Instance.new("SurfaceGui")
		printFace.Face, printFace.CanvasSize, printFace.SizingMode = Enum.NormalId.Back, Vector2.new(175, 75), Enum.SurfaceGuiSizingMode.FixedSize
		printFace.LightInfluence, printFace.Parent = 0, letters
		local mark = Instance.new("TextLabel")
		mark.Size, mark.BackgroundTransparency, mark.TextScaled = UDim2.fromScale(1, 1), 1, true
		mark.TextColor3, mark.Font, mark.Text, mark.Parent = paper, Enum.Font.BuilderSansExtraBold, tile.code, printFace
	elseif tile.kind == "kickoff" then
		plate(tileFolder, "Kickoff podium", x, z, Art.tileTop + .19, 4.3, 3.2, .38, ink)
		beam(tileFolder, "Pennant mast", Vector3.new(x, Art.tileTop + .28, z), Vector3.new(x, Art.tileTop + 4.8, z), .15, paper)
		part(tileFolder, "Kickoff banner", Vector3.new(3.20, 1.51, .14), CFrame.new(x + .97, Art.tileTop + 3.79, z), accent)
	elseif tile.kind == "goalDeck" or tile.kind == "offsideDeck" then
		for stack = 0, 2 do
			part(tileFolder, "Card deck", Vector3.new(2.83, .26, 3.72),
				CFrame.new(x, Art.tileTop + .17 + stack * .23, z) * CFrame.Angles(0, stack * .12, 0),
				if stack % 2 == 0 then accent else paper)
		end
	elseif tile.kind == "matchday" then
		local fallback = decoration(tileFolder, "Matchday miniature", "ball", Vector3.one * 3.08, CFrame.new(x, Art.tileTop + 1.53, z))
		plate(fallback, "Football", x, z, Art.tileTop + 1.53, 3.0, 3.0, 3.0, paper).Shape = Enum.PartType.Ball
	elseif tile.kind == "venue" then
		local fallback = decoration(tileFolder, "Stadium miniature", "arena", Vector3.new(5.8, 2.42, 4.9), CFrame.new(x, Art.tileTop + 1.21, z))
		plate(fallback, "Ground", x, z, Art.tileTop + .46, 5.66, 4.70, .89, Art.field)
		for _, wing in {-1, 1} do
			plate(fallback, "Mini grandstand", x + wing * 2.12, z, Art.tileTop + 1.34, 1.32, 4.4, 1.26, paper)
		end
	elseif tile.kind == "commercial" then
		for i = 1, 3 do
			part(tileFolder, "Contract booklet", Vector3.new(3.61, .28, 4.33),
				CFrame.new(x, Art.tileTop + .15 + i * .26, z) * CFrame.Angles(0, .44 + i * .12, 0), if i == 3 then accent else paper)
		end
	end
end

local function pitch(parent: Instance)
	local field = folder(parent, "Pitch and goals")
	local depth = Art.pitchDepthScale
	plate(field, "Runoff", 0, 0, .18, 69, 32.7 * depth, .25, C("5D823B"))
	local grass, darkGrass = C("569247"), C("538B48")
	for stripe = 0, 11 do
		plate(field, "Mown strip", -31.5 + (stripe + .5) * 5.25, 0, .305,
			5.25, 29.4 * depth, .07, if stripe % 2 == 0 then grass else darkGrass).CastShadow = false
	end
	for _, side in {-1, 1} do
		local z = side * 16.06 * depth
		for index = -2, 2 do
			local tint = if index % 2 == 0 then C("CFECC9") else C("4F987B")
			plate(field, "Sideline panel", index * 10.1, z, .47, 9.72, .25, .38, tint).CastShadow = false
		end
		for _, x in {-26, 26} do
			local fallback = decoration(field, "Technical area", "dugout", Vector3.new(6.65, 1.23, 1.69),
				CFrame.new(x, .98, side * 17.17 * depth) * CFrame.Angles(0, if side == 1 then 0 else math.pi, 0))
			plate(fallback, "Technical bench base", x, z * 1.035, .51, 6.8, 1.3, .36, ink)
			for seat = -2, 2 do
				plate(fallback, "Bench seat", x + seat * 1.04, z * 1.036, .75, .86, .70, .26, paper).CastShadow = false
			end
		end
	end
	local lineY = .356
	local paint = C("F2F4D8")
	local function mark(ax: number, az: number, bx: number, bz: number, width: number?)
		beam(field, "Pitch marking", Vector3.new(ax, lineY, az * depth), Vector3.new(bx, lineY, bz * depth), width or .16, paint).CastShadow = false
	end
	local function ring(cx: number, radius: number, first: number, sweep: number, count: number)
		for i = 0, count - 1 do
			local a, b = first + i * sweep / count, first + (i + 1) * sweep / count
			mark(cx + math.cos(a) * radius, math.sin(a) * radius / depth, cx + math.cos(b) * radius, math.sin(b) * radius / depth)
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
		local front, back, floor, crossbar = 31 * side, 34.8 * side, .41, 6.15
		local halfGoal = 5.78
		local net = C("E2EBE3")
		local fallback = decoration(field, "Goal assembly", "goal", Vector3.new(4.46, 5.94, 12.20),
			CFrame.new(32.9 * side, 3.38, 0) * CFrame.Angles(0, if side == 1 then 0 else math.pi, 0))
		for _, post in {-halfGoal, halfGoal} do
			beam(fallback, "Goalpost", Vector3.new(front, floor, post), Vector3.new(front, crossbar, post), .19, paper)
			beam(fallback, "Goal brace", Vector3.new(front, crossbar, post), Vector3.new(back, floor + .31, post), .11, paper)
		end
		beam(fallback, "Crossbar", Vector3.new(front, crossbar, -halfGoal), Vector3.new(front, crossbar, halfGoal), .19, paper)
		for z = -5.4, 5.4, .9 do
			beam(fallback, "Net cord", Vector3.new(front, crossbar - .07, z), Vector3.new(back, floor + .31, z), .035, net).CastShadow = false
		end
		for row = 0, 5 do
			local t = row / 5
			local x, y = front + (back - front) * t, crossbar - .07 - (crossbar - floor - .38) * t
			beam(fallback, "Net weft", Vector3.new(x, y, -halfGoal), Vector3.new(x, y, halfGoal), .038, net).CastShadow = false
		end
	end
end

local function terraces(stage: Instance)
	local stands = folder(stage, "Grandstands")
	for _, side in {-1, 1} do
		for section = -3, 3 do
			local x = section * 9.1
			local fallback = decoration(stands, "Seating block", "stand", Vector3.new(8.65, 3.30, 8.88),
				CFrame.new(x, 1.91, side * 31.1) * CFrame.Angles(0, if side == 1 then 0 else math.pi, 0))
			plate(fallback, "Concrete caisson", x, side * 31.1, .28, 8.72, 6.55, .83, slate)
			for tier = 1, 4 do
				local y, z = .63 + tier * .40, side * (27.1 + tier * 1.42)
				plate(fallback, "Riser", x, z, y - .23, 8.52, 1.51, .65, ink)
				local tint = if (tier + section) % 3 == 0 then C("A7D7B9") else C("348976")
				for seat = -2, 2 do
					plate(fallback, "Molded seat", x + seat * 1.62, z, y + .13, 1.39, .84, .22, tint).CastShadow = false
				end
			end
			plate(fallback, "Aisle light", x - 4.33, side * 30.8, 1.32, .17, 5.65, .14, Art.mint, Enum.Material.Neon).CastShadow = false
		end
		for _, wing in {-1, 1} do
			local x, z = wing * 38.1, side * 26.4
			local fallback = decoration(stands, "Player entrance", "tunnel", Vector3.new(5.08, 2.08, 4.54),
				CFrame.new(x, 1.33, z) * CFrame.Angles(0, if side == 1 then 0 else math.pi, 0))
			plate(fallback, "Entry portal", x, z, .69, 5.2, 4.6, 1.18, slate)
			plate(fallback, "Player tunnel", x, z, 1.01, 3.2, 4.85, .61, ink)
			plate(fallback, "Tunnel canopy", x, z, 1.54, 5.0, 4.6, .24, C("6C9293"), metal)
			plate(fallback, "Tunnel light", x, z - side * 2.26, 1.54, 4.55, .08, .09, Art.mint, Enum.Material.Neon).CastShadow = false
		end
	end
end

local function surroundings(stage: Folder)
	local scene = folder(stage, "Arena surroundings")
	local backdrop = plate(scene, "Studio backdrop", 0, 0, -9, 1200, 1200, .32, C("18344D"))
	backdrop.CastShadow = false
	local backdropFace = Instance.new("SurfaceGui")
	backdropFace.Face, backdropFace.CanvasSize = Enum.NormalId.Top, Vector2.new(1024, 1024)
	backdropFace.SizingMode, backdropFace.LightInfluence = Enum.SurfaceGuiSizingMode.FixedSize, .2
	backdropFace.Parent = backdrop
	local sweep = Instance.new("Frame")
	sweep.Size, sweep.BorderSizePixel, sweep.BackgroundColor3 = UDim2.fromScale(1, 1), 0, Color3.new(1, 1, 1)
	sweep.Parent = backdropFace
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = -53
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, C("152D49")), ColorSequenceKeypoint.new(.38, C("355A79")),
		ColorSequenceKeypoint.new(.60, C("50778F")), ColorSequenceKeypoint.new(1, C("214365")),
	})
	gradient.Parent = sweep
	plate(scene, "Concrete podium", 0, 0, -4.40, 128.9, 128.9, .52, C("4B5666"))
	for _, side in {-1, 1} do
		local x = 42.2 * side
		for _, z in {-37.6, 37.6} do
			local base, top = Vector3.new(x, .24, z), Vector3.new(x, 7.72, z)
			local toward = Vector3.new(-x, 0, -z).Unit
			local fallback = decoration(scene, "Floodlight tower", "lights", Vector3.new(4.07, 7.60, 1.65),
				CFrame.lookAt(Vector3.new(x, 4.03, z), Vector3.new(x, 4.03, z) - toward))
			beam(fallback, "Floodlight spine", base, top, .36, C("729397"), metal)
			for brace = 0, 4 do
				local a = base + Vector3.new(0, brace * 1.85, -0.55)
				beam(fallback, "Tower truss", a, a + Vector3.new(0, 1.85, 1.1), .14, C("729397"), metal).CastShadow = false
			end
			local head = CFrame.lookAt(top, Vector3.new(x * .30, 0, z * .4))
			part(fallback, "Floodlight wing", Vector3.new(5.6, .96, .60), head, slate, metal)
			for bulb = -2, 2 do
				part(fallback, "Floodlight lens", Vector3.new(.86, .61, .16), head * CFrame.new(bulb * 1.03, 0, -.36),
					C("DBFFF2"), Enum.Material.Neon).CastShadow = false
			end
			local bounce = part(scene, "Floodlight glow", Vector3.one * .16, CFrame.new(top), paper)
			bounce.Transparency = 1
			local light = Instance.new("PointLight")
			light.Brightness, light.Range, light.Color = 0.64, 17, C("DCF0FA")
			light.Parent = bounce
		end
	end
end

local function build()
	Lighting.ClockTime, Lighting.GeographicLatitude, Lighting.Brightness = 14.7, 24, 2.18
	Lighting.Ambient, Lighting.OutdoorAmbient = C("69788F"), C("A1B5C7")
	Lighting.EnvironmentDiffuseScale, Lighting.EnvironmentSpecularScale = .39, .56
	Lighting.GlobalShadows, Lighting.ShadowSoftness = true, .34
	Lighting.ExposureCompensation = -.16
	local stage = Instance.new("Folder")
	stage.Name = "WorldDraftArena"
	surroundings(stage)
	local tray = folder(stage, "Board")
	local cabinet = decoration(tray, "Machined cabinet", "table", Vector3.new(127.52, 4.21, 127.52), CFrame.new(0, -1.98, 0))
	plate(cabinet, "Table foot", 0, 0, -3.9, 123, 123, .82, ink)
	plate(cabinet, "Anodized table body", 0, 0, -2.44, 127, 127, 2.1, C("24454F"), metal)
	plate(cabinet, "Championship line", 0, 0, -1.27, 126.8, 126.8, .25, Art.gold, metal)
	plate(cabinet, "Table lip", 0, 0, -.57, 126.6, 126.6, 1.16, C("346569"))
	plate(cabinet, "Recessed plane", 0, 0, -.02, 122.8, 122.8, .39, ink)
	local center = folder(stage, "Continental Cup stadium")
	plate(center, "Stadium foundations", 0, 0, .03, 84.6, 84.6, .44, C("CAD4BA"))
	for _, side in {-1, 1} do
		for _, x in {-38.7, 38.7} do
			plate(center, "Entrance paving", x, side * 32.4, .255, 5.4, 12.3, .075, C("E4E5D1")).CastShadow = false
		end
		plate(center, "Concourse ribbon", 0, side * 38.6, .268, 69.0, 2.0, .08, C("EDE0C5")).CastShadow = false
	end
	pitch(center)
	terraces(center)
	for index, tile in Board.tiles do drawTile(tray, index, tile) end
	stage.Parent = workspace
	return stage
end

return build
