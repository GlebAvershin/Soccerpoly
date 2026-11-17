--!strict
local Lighting = game:GetService("Lighting")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("League")
local Board = require(shared.TourBoard)
local Geometry = require(shared.Geometry)
local Art = require(shared.Presentation)
local C = Color3.fromHex

local function folder(parent: Instance, name: string): Folder
	local node = Instance.new("Folder")
	node.Name, node.Parent = name, parent
	return node
end

local function part(parent: Instance, name: string, size: Vector3, pose: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, pose, color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function plate(parent: Instance, name: string, x: number, y: number, z: number, w: number, h: number, d: number, color: Color3): Part
	return part(parent, name, Vector3.new(w, h, d), CFrame.new(x, y, z), color)
end

local function mesh(parent: Instance, name: string, shape: string, size: Vector3, pose: CFrame, color: Color3?): Part
	local marker = part(parent, name, size, pose, color or Art.paper)
	marker:SetAttribute("MeshShape", shape)
	return marker
end

local function cornerProp(parent: Instance, index: number, pose: CFrame, accent: Color3)
	if index == 1 then
		part(parent, "Kickoff plinth", Vector3.new(5.25, .42, 2.7), pose * CFrame.new(0, .27, -1), C("849B47"))
		for _, side in {-1, 1} do
			part(parent, "Pennant mast", Vector3.new(.14, 4.5, .14), pose * CFrame.new(side * 2.1, 2.25, -1), Art.paper)
		end
		part(parent, "Pennant", Vector3.new(4.25, 1.34, .16), pose * CFrame.new(0, 3.25, -1), C("90A648"))
	elseif index == 9 then
		mesh(parent, "Football", "ball", Vector3.one * 4.3, pose * CFrame.new(0, 2.35, -1))
		part(parent, "Terminal", Vector3.new(5.85, .36, 5.85), pose * CFrame.new(0, .18, -1), accent:Lerp(Art.ink, .25))
	elseif index == 17 then
		mesh(parent, "Continental Cup arena", "champions", Vector3.new(10.2, 4.91, 9.45), pose * CFrame.new(0, 2.53, -1.05))
		part(parent, "Championship podium", Vector3.new(9.2, .56, 8.9), pose * CFrame.new(0, .28, -1.05), C("84A042"))
	else
		mesh(parent, "Substitutes' bench", "dugout", Vector3.new(8.0, 3.97, 4.6), pose * CFrame.new(0, 2, -1))
	end
end

local function drawTile(tray: Folder, index: number, tile: Board.Tile)
	local at = Geometry.cells[index]
	local yaw = Geometry.tileYaw(index)
	local dims = Geometry.tileSize(index)
	local width, depth = dims.X - .105, dims.Y - .105
	local pose = CFrame.new(at.X, Art.tileTop, at.Z) * CFrame.Angles(0, yaw, 0)
	local accent = Art.accent(tile.kind, tile.league)
	local cell = folder(tray, string.format("%02d %s", index, tile.name))
	local isCorner = (index - 1) % 8 == 0
	local surfaceColor = if tile.league > 0 then Art.tile:Lerp(accent, .09) else Art.tile
	mesh(cell, "Molded tile case", "tile_case", Vector3.new(width, .53, depth),
		pose * CFrame.new(0, -.31, 0), accent:Lerp(Art.ink, .70))
	local face = mesh(cell, "Porcelain face", "tile_enamel", Vector3.new(width - .26, .26, depth - .25),
		pose * CFrame.new(0, -.10, 0), surfaceColor)
	face.CastShadow = false
	local insetDepth = if isCorner then depth * .66 elseif tile.price > 0 and tile.league > 0 then depth * .23 else depth * .56
	local insetOffset = -.5 * depth + .5 * insetDepth + .17
	local insetTint = accent:Lerp(Art.ink, if tile.league > 0 then .60 else .76)
	mesh(cell, "League enamel inlay", "tile_enamel", Vector3.new(width - .33, .066, insetDepth),
		pose * CFrame.new(0, .061, insetOffset), insetTint).CastShadow = false
	if tile.league > 0 then
		for _, side in {-1, 1} do
			part(cell, "League trim", Vector3.new(width * .19, .045, .135),
				pose * CFrame.new(side * width * .36, .043, insetOffset + insetDepth * .5 + .18), accent).CastShadow = false
		end
	end
	local printLayer = part(cell, "Printed tile", Vector3.new(width, .02, depth), pose * CFrame.new(0, .045, 0), Art.paper)
	printLayer.CastShadow, printLayer.Transparency = false, 1
	printLayer:SetAttribute("BoardIndex", index)
	if isCorner then
		cornerProp(cell, index, pose, accent)
	elseif tile.kind == "chance" then
		mesh(cell, "Chance cards", "event_card", Vector3.new(5.9, .71, 6.20),
			pose * CFrame.new(0, .43, -2.95)).CastShadow = false
	elseif tile.kind == "tax" then
		for page = 1, 3 do
			part(cell, "Tax notice", Vector3.new(2.95, .12, 3.30), pose * CFrame.new(0, .16 + page * .09, -2.55)
				* CFrame.Angles(0, -.22 + page * .08, 0), if page == 3 then Art.paper else C("C9AC78"))
		end
	elseif tile.kind == "venue" then
		mesh(cell, "Miniature stadium", "arena", Vector3.new(5.15, 2.3, 4.2), pose * CFrame.new(0, 1.20, -2.72), accent)
	end
end

local function pitch(stage: Folder)
	local field = folder(stage, "Continental Cup stadium")
	plate(field, "Pitch rim", 0, -.07, 0, 90.4, .43, 90.4, C("23253A"))
	for _, side in {-1, 1} do
		for i = -5, 5 do
			plate(field, "Dashed touchline", i * 8.05, .158, side * 43.55, 4.8, .016, .13, C("A9E464")).CastShadow = false
			plate(field, "Dashed touchline", side * 43.55, .158, i * 8.05, .13, .016, 4.8, C("A9E464")).CastShadow = false
		end
	end
	for strip = 0, 5 do
		plate(field, "Grass strip", 0, .205, (strip - 2.5) * 14, 84, .16, 14,
			if strip % 2 == 0 then C("417959") else C("34694E")).CastShadow = false
	end
	local line = C("C9E2CB")
	plate(field, "Halfway line", 0, .298, 0, .42, .029, 65, line).CastShadow = false
	for _, side in {-1, 1} do
		plate(field, "Sideline", 0, .30, side * 32.5, 75, .028, .38, line).CastShadow = false
		plate(field, "Goal line", side * 37.5, .3, 0, .38, .029, 65, line).CastShadow = false
		plate(field, "Penalty line", side * 28.6, .30, 0, .32, .030, 28, line).CastShadow = false
		for _, endLine in {-1, 1} do
			plate(field, "Penalty area", side * 32.95, .30, endLine * 14, 9.1, .029, .32, line).CastShadow = false
		end
	end
	for i = 0, 35 do
		local angle = i * math.pi / 18
		part(field, "Center circle", Vector3.new(1.4, .035, .30),
			CFrame.new(math.sin(angle) * 7.8, .31, math.cos(angle) * 7.8) * CFrame.Angles(0, angle, 0), line).CastShadow = false
	end
	local mark = mesh(field, "Footbolapolia field stencil", "pitch_mark", Vector3.new(8, .027, 8),
		CFrame.new(0, .332, 0) * CFrame.Angles(0, math.rad(17), 0), C("B2D28F"))
	mark.CastShadow = false
end

local function ribbon(parent: Folder, name: string, pose: CFrame, width: number)
	local board = part(parent, name, Vector3.new(width, 2.08, .15), pose, C("181B2B"))
	local surface = Instance.new("SurfaceGui")
	surface.Face, surface.LightInfluence, surface.CanvasSize = Enum.NormalId.Back, 0, Vector2.new(640, 56)
	surface.SizingMode, surface.Parent = Enum.SurfaceGuiSizingMode.FixedSize, board
	local word = Instance.new("TextLabel")
	word.Name = "Message"
	word.Text, word.Font, word.TextScaled = "FOOTBOLAPOLIA", Enum.Font.BuilderSansExtraBold, true
	word.TextColor3, word.BackgroundTransparency = Art.mint, 1
	word.Size, word.Parent = UDim2.fromScale(1, 1), surface
end

local function surroundings(stage: Folder)
	local scene = folder(stage, "Arena surroundings")
	local back = plate(scene, "Night backdrop", 0, -8.5, 0, 2048, .35, 2048, C("191824"))
	back.CastShadow = false
	local surface = Instance.new("SurfaceGui")
	surface.Face, surface.CanvasSize = Enum.NormalId.Top, Vector2.new(1024, 1024)
	surface.SizingMode, surface.LightInfluence, surface.MaxDistance = Enum.SurfaceGuiSizingMode.FixedSize, 0, 5000
	surface.Parent = back
	local fill = Instance.new("Frame")
	fill.Size, fill.BorderSizePixel, fill.BackgroundColor3 = UDim2.fromScale(1, 1), 0, Color3.new(1, 1, 1)
	fill.Parent = surface
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 25
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, C("121421")),
		ColorSequenceKeypoint.new(.39, C("1D1C30")),
		ColorSequenceKeypoint.new(.53, C("302D47")),
		ColorSequenceKeypoint.new(.68, C("242339")),
		ColorSequenceKeypoint.new(1, C("141726")),
	})
	gradient.Parent = fill
	local pad = plate(scene, "Arena ground shadow", 0, -7.65, 0, 159, .18, 159, C("171926"))
	pad.CastShadow = false
	pad.Transparency = .25

	for _, x in {-43, -15, 15, 43} do
		mesh(scene, "North terrace", "night_stand", Vector3.new(26, 7.2, 10.8),
			CFrame.new(x, 1.25, -69.3) * CFrame.Angles(0, math.pi, 0)).CastShadow = false
	end
	for _, z in {-41, -13, 15} do
		mesh(scene, "West terrace", "night_stand", Vector3.new(26, 6.2, 10.6),
			CFrame.new(-69.8, .65, z) * CFrame.Angles(0, -math.pi * .5, 0)).CastShadow = false
	end
	for _, x in {-66.0, 66.0} do
		mesh(scene, "Floodlight tower", "lights", Vector3.new(7.8, 14.7, 5.0), CFrame.new(x, 4.35, -68.5)).CastShadow = false
		local rig = plate(scene, "Floodlight accent", x, 11.01, -65.95, 5.5, .26, .18, C("C5C7FF"))
		rig.Material, rig.CastShadow = Enum.Material.Neon, false
	end
	ribbon(scene, "Live stadium ribbon", CFrame.new(22.2, 5.12, -64.6), 34)
	ribbon(scene, "Front stadium ribbon", CFrame.new(0, -1.70, 72.25), 36)
end

return function()
	Lighting.ClockTime, Lighting.GeographicLatitude, Lighting.Brightness = 9.7, 39, 2.6
	Lighting.Ambient, Lighting.OutdoorAmbient = C("9690AA"), C("BFC7E0")
	Lighting.EnvironmentDiffuseScale, Lighting.EnvironmentSpecularScale = .34, .46
	Lighting.GlobalShadows, Lighting.ShadowSoftness = true, .62
	Lighting.ExposureCompensation = -.04
	local stage = Instance.new("Folder")
	stage.Name = "WorldDraftArena"
	surroundings(stage)
	local tray = folder(stage, "Board")
	mesh(tray, "Octagonal arena plinth", "arena_plinth", Vector3.new(144.3, 4.8, 144.3), CFrame.new(0, -2.65, 0))
	pitch(stage)
	for i, tile in Board.tiles do drawTile(tray, i, tile) end
	stage.Parent = workspace
	return stage
end
