--!strict
local Lighting = game:GetService("Lighting")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("League")
local Board = require(shared.TourBoard)
local Geometry = require(shared.Geometry)
local Art = require(shared.Presentation)
local C = Color3.fromHex
local SIZE = Geometry.width

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
	part(cell, "Tile edges", Vector3.new(width + .04, .53, depth + .04), pose * CFrame.new(0, -.32, 0), C("C7BDC2"))
	local face = part(cell, "Tile body", Vector3.new(width, .30, depth), pose * CFrame.new(0, -.149, 0), Art.paper)
	face.CastShadow = false
	local isCorner = (index - 1) % 8 == 0
	local innerFill = if isCorner then accent:Lerp(Art.paper, .12) else accent:Lerp(Art.paper, .50)
	part(cell, "Property color", Vector3.new(width - .10, .034, if isCorner then depth - .10 else depth * .645),
		pose * CFrame.new(0, .019, if isCorner then 0 else -depth * .176), innerFill).CastShadow = false
	local printLayer = part(cell, "Printed tile", Vector3.new(width, .02, depth), pose * CFrame.new(0, .045, 0), Art.paper)
	printLayer.CastShadow, printLayer.Transparency = false, 1
	printLayer:SetAttribute("BoardIndex", index)
	if isCorner then
		cornerProp(cell, index, pose, accent)
	elseif tile.kind == "chance" then
		local disc = mesh(cell, "Chance wheel", "chance", Vector3.new(6.45, .31, 6.45), pose * CFrame.new(0, .175, -2.9))
		disc.CastShadow = false

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
	plate(field, "Pitch rim", 0, -.07, 0, 90.4, .43, 90.4, C("727278"))
	for _, side in {-1, 1} do
		for i = -5, 5 do
			plate(field, "Dashed touchline", i * 8.05, .158, side * 43.55, 4.8, .016, .13, C("D8D0CD")).CastShadow = false
			plate(field, "Dashed touchline", side * 43.55, .158, i * 8.05, .13, .016, 4.8, C("D8D0CD")).CastShadow = false
		end
	end
	for strip = 0, 5 do
		plate(field, "Grass strip", 0, .205, (strip - 2.5) * 14, 84, .16, 14,
			if strip % 2 == 0 then C("ACBE5E") else C("A9B95A")).CastShadow = false
	end
	local line = C("CAD979")
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
end

local function surroundings(stage: Folder)
	local scene = folder(stage, "Arena surroundings")
	local back = plate(scene, "Sky backdrop", 0, -14, 0, 1900, .35, 1900, C("9AC3DE"))
	back.CastShadow = false
	local surf = Instance.new("SurfaceGui")
	surf.Face, surf.CanvasSize = Enum.NormalId.Top, Vector2.new(1024, 1024)
	surf.SizingMode, surf.LightInfluence, surf.MaxDistance = Enum.SurfaceGuiSizingMode.FixedSize, 0, 5000
	surf.Parent = back
	local fill = Instance.new("Frame")
	fill.Size, fill.BorderSizePixel, fill.BackgroundColor3 = UDim2.fromScale(1, 1), 0, Color3.new(1, 1, 1)
	fill.Parent = surf
	local grad = Instance.new("UIGradient")
	grad.Rotation = 135
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, C("87BADE")),
		ColorSequenceKeypoint.new(.42, C("87BADE")),
		ColorSequenceKeypoint.new(.58, C("D4EAED")),
		ColorSequenceKeypoint.new(1, C("D4EAED")),
	})
	grad.Parent = fill
	for _, side in {-1, 1} do
		for _, other in {-1, 1} do
			local pose = if side == other then CFrame.new(side * 80, -.85, 0) * CFrame.Angles(0, math.pi / 2, 0)
				else CFrame.new(0, -.85, other * 80)
			for col = 1, 5 do
				local height = if col <= 2 then 5 else if col < 5 then 3 else 1
				for row = 1, height do
					local tint = if col <= 2 then C("9CAA65") elseif col < 5 then C("D5DDCA") else C("E8B953")
					local at = pose * CFrame.new((col - 3) * 5.25, row * .64, 0)
					part(scene, "Club bank bond", Vector3.new(5.16, .56, 5.91), at, tint)
					part(scene, "Bond band", Vector3.new(.95, .026, 5.94), at * CFrame.new(0, .285, 0), Art.paper).CastShadow = false
				end
			end
		end
	end
end

return function()
	Lighting.ClockTime, Lighting.GeographicLatitude, Lighting.Brightness = 13.8, 31, 2.1
	Lighting.Ambient, Lighting.OutdoorAmbient = C("929296"), C("B3BED1")
	Lighting.EnvironmentDiffuseScale, Lighting.EnvironmentSpecularScale = .32, .36
	Lighting.GlobalShadows, Lighting.ShadowSoftness = true, .4
	Lighting.ExposureCompensation = -.1
	local stage = Instance.new("Folder")
	stage.Name = "WorldDraftArena"
	surroundings(stage)
	local tray = folder(stage, "Board")
	for i, band in {{-2.45, .38, C("B9B0B7")}, {-1.79, 1.10, C("7D6057")}, {-.91, .64, C("D9CED4")}, {-.40, .40, C("F1E5E8")}} do
		plate(tray, "Board layer " .. i, 0, band[1] :: number, 0, SIZE + .27, band[2] :: number, SIZE + .27, band[3] :: Color3)
	end
	pitch(stage)
	for i, tile in Board.tiles do drawTile(tray, i, tile) end
	stage.Parent = workspace
	return stage
end
