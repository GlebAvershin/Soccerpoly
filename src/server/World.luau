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

local function drawTile(tray: Folder, index: number, tile: Board.Tile)
	local at = Geometry.cells[index]
	local yaw = Geometry.tileYaw(index)
	local dims = Geometry.tileSize(index)
	local width, depth = dims.X - .38, dims.Y - .38
	local pose = CFrame.new(at.X, Art.tileTop, at.Z) * CFrame.Angles(0, yaw, 0)
	local accent = Art.accent(tile.kind, tile.league)
	local cell = folder(tray, string.format("%02d %s", index, tile.name))
	mesh(cell, "Molded tile case", "tile_case", Vector3.new(width, .62, depth),
		pose * CFrame.new(0, -.33, 0), accent:Lerp(C("202C32"), .55))
	local face = mesh(cell, "Porcelain face", "tile_enamel", Vector3.new(width-.22,.28,depth-.22),
		pose * CFrame.new(0,-.12,0), C("EDE0C7"))
	face.CastShadow = false
	-- Local +Z is the face normal and local +Y points north on the pitch.
	local sideways = math.floor((index-1)/8)%2 == 0
	local sheet = part(cell, "Printed tile", Vector3.new(if sideways then depth-.72 else width-.72,
		if sideways then width-.72 else depth-.72,.03),
		CFrame.new(at.X, Art.tileTop+.060, at.Z)*CFrame.Angles(-math.pi/2,0,0), Art.paper)
	sheet.Transparency, sheet.CastShadow = 1, false
	sheet:SetAttribute("BoardIndex",index)
end

local function pitch(stage: Folder)
	local field = folder(stage, "Continental Cup stadium")
	local chalk, brass, enamel = C("F4F2D8"), C("E3BE73"), C("18373A")
	local function beam(parent: Instance, name: string, a: Vector3, b: Vector3, width: number, depth: number, tint: Color3): Part
		local rod = part(parent, name, Vector3.new(width, depth, (b - a).Magnitude),
			CFrame.lookAt((a + b) / 2, b), tint)
		rod.CastShadow = false
		return rod
	end
	local function stroke(name: string, x0: number, z0: number, x1: number, z1: number, width: number, tint: Color3, y: number?)
		local level = y or .328
		beam(field, name, Vector3.new(x0, level, z0), Vector3.new(x1, level, z1), width, .028, tint)
	end
	local function disk(name: string, x: number, z: number, diameter: number, top: number, tint: Color3): Part
		local coin = part(field, name, Vector3.new(.034, diameter, diameter),
			CFrame.new(x, top - .017, z) * CFrame.Angles(0, 0, math.pi / 2), tint)
		coin.Shape, coin.CastShadow = Enum.PartType.Cylinder, false
		return coin
	end
	local function arc(name: string, x: number, z: number, radius: number, start: number, finish: number, steps: number, width: number)
		for i = 0, steps - 1 do
			local a = start + (finish - start) * i / steps
			local b = start + (finish - start) * (i + 1) / steps
			stroke(name, x + radius * math.cos(a), z + radius * math.sin(a),
				x + radius * math.cos(b), z + radius * math.sin(b), width, chalk)
		end
	end

	-- The metal reveal and the printed end rails belong to the miniature stadium.
	plate(field, "Brushed champagne reveal", 0, -.09, 0, 90.4, .46, 90.4, brass).Material = Enum.Material.Metal
	plate(field, "Enamel apron", 0, .105, 0, 89.65, .14, 89.65, enamel)
	plate(field, "Turf binding", 0, .163, 0, 84.6, .1, 72.7, C("112B27"))
	local turf = {C("1E5936"), C("266E43")}
	local strips = 14
	local stripWidth = 84 / strips
	for i = 1, strips do
		local grass = plate(field, "Mown turf", (i - (strips + 1) / 2) * stripWidth, .20, 0,
			stripWidth, .17, 72, turf[1 + (i - 1) % 2])
		grass.Material, grass.CastShadow = Enum.Material.Grass, false
	end
	stroke("Halfway line", 0, -32.5, 0, 32.5, .56, chalk)
	for _, side in {-1, 1} do
		stroke("Touchline", -37.5, side * 32.5, 37.5, side * 32.5, .58, chalk)
		stroke("Goal line", side * 37.5, -32.5, side * 37.5, 32.5, .58, chalk)
		for _, box in {{24.7, 17.1}, {32.1, 10.9}} do
			local x, z = side * box[1], box[2]
			stroke("Box", x, -z, x, z, .49, chalk)
			for _, flank in {-1, 1} do stroke("Box", x, flank * z, side * 37.5, flank * z, .49, chalk) end
		end
		local spot = 29.5 * side
		disk("Penalty spot", spot, 0, .95, .352, chalk)
		local facing = if side == 1 then math.pi else 0
		local sweep = math.acos((29.5 - 24.7) / 7.4)
		arc("Penalty arc", spot, 0, 7.4, facing - sweep, facing + sweep, 18, .46)
		for _, flank in {-1, 1} do
			local inward = if side == 1 then math.pi else 0
			arc("Corner arc", side * 37.5, flank * 32.5, 2.15, inward,
				inward + side * flank * math.pi / 2, 9, .37)
			local x, z = side * 37.82, flank * 32.8
			plate(field, "Corner flagstaff", x, 1.57, z, .16, 2.56, .16, chalk)
			local flag = plate(field, "Corner pennant", x + side * .82, 2.41, z, 1.52, .83, .075,
				if side == 1 then C("E58B72") else C("E6CC7D"))
			flag.CastShadow = false
		end
	end

	-- Masterpiece 3D Continental Championship Centerpiece
	local goldMetal = C("D4AF37")
	disk("Centre gold bezel", 0, 0, 16.8, .345, goldMetal).Material = Enum.Material.Metal
	disk("Centre circle", 0, 0, 16.4, .352, chalk)
	disk("Centre enamel", 0, 0, 15.55, .360, C("123321"))
	disk("Cup seal rim", 0, 0, 9.4, .370, goldMetal).Material = Enum.Material.Metal
	disk("Cup seal", 0, 0, 8.8, .378, C("0E291B"))

	-- 3D Sculpted Championship Star & Trophy Inlay
	local gilt = C("FFD700")
	local function engraving(x0: number, z0: number, x1: number, z1: number, width: number)
		beam(field, "Championship cup engraving", Vector3.new(x0, .398, z0), Vector3.new(x1, .398, z1), width, .028, gilt).Material = Enum.Material.Metal
	end
	engraving(-1.46, -1.68, 1.46, -1.68, .52)
	engraving(-1.29, -1.53, -.98, .02, .60)
	engraving(1.29, -1.53, .98, .02, .60)
	engraving(-.98, .02, 0, .80, .55)
	engraving(.98, .02, 0, .80, .55)
	engraving(0, .68, 0, 1.78, .50)
	engraving(-1.12, 1.91, 1.12, 1.91, .55)
	for _, side in {-1, 1} do
		engraving(side * 1.30, -1.31, side * 2.21, -1.31, .32)
		engraving(side * 2.21, -1.31, side * 1.91, -.32, .32)
		engraving(side * 1.91, -.32, side * 1.04, .02, .32)
	end
	-- 4 Gold Star Rivets around the Cup
	for _, sx in {-3.2, 3.2} do
		for _, sz in {-3.2, 3.2} do
			disk("Trophy star rivet", sx, sz, .55, .395, gilt)
		end
	end

	for _, side in {-1, 1} do
		local goal = folder(field, if side > 0 then "East goal" else "West goal")
		local function cord(name: string, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number, width: number, tint: Color3)
			beam(goal, name, Vector3.new(side * x0, y0, z0), Vector3.new(side * x1, y1, z1), width, width, tint)
		end
		local net = C("BCD2B9")
		for _, flank in {-1, 1} do
			local z = 9 * flank
			cord("Goalpost", 37.5, .30, z, 37.5, 7.60, z, .36, chalk)
			cord("Roof support", 37.5, 7.60, z, 40.15, 7.0, z, .17, chalk)
			cord("Net stay", 40.15, 7.0, z, 42, .34, z, .17, chalk)
			cord("Ground frame", 37.5, .36, z, 42, .36, z, .18, chalk)
		end
		cord("Crossbar", 37.5, 7.60, -9.16, 37.5, 7.60, 9.16, .36, chalk)
		cord("Net ridge", 40.15, 7.0, -9, 40.15, 7.0, 9, .12, net)
		cord("Rear frame", 42, .36, -9, 42, .36, 9, .17, net)
		for i = -5, 5 do
			local z = i * 1.5
			cord("Roof net", 37.50, 7.55, z, 40.15, 7.0, z, .067, net)
			cord("Rear net", 40.15, 7.0, z, 42, .36, z, .075, net)
		end
		for i = 1, 5 do
			local t = i / 6
			local x, y = 42 - 1.85 * t, .36 + 6.64 * t
			cord("Net weft", x, y, -9, x, y, 9, .078, net)
			for _, flank in {-1, 1} do cord("Side net", 37.5, y, 9 * flank, x, y, 9 * flank, .064, net) end
		end
	end

	for _, side in {-1, 1} do
		local z = side * 40.35
		local sign = plate(field, "Enamel touchline sign", 0, .208, z, 37, .10, 5.9, C("132E33"))
		local surface = Instance.new("SurfaceGui")
		surface.Face, surface.CanvasSize = Enum.NormalId.Top, Vector2.new(1480, 236)
		surface.SizingMode, surface.LightInfluence = Enum.SurfaceGuiSizingMode.FixedSize, .25
		surface.MaxDistance, surface.Active, surface.AutoLocalize = 12000, false, false
		local text = Instance.new("TextLabel")
		text.Size, text.BackgroundTransparency = UDim2.fromScale(1, 1), 1
		text.Text = if side > 0 then "CONTINENTAL CUP" else "SOCCERPOLY"
		text.FontFace = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
		text.TextSize, text.TextColor3, text.Parent = 163, C("EEE9C8"), surface
		surface.Parent = sign
		for _, flank in {-1, 1} do
			local accent = if flank == side then C("E6B373") else C("78AC90")
			stroke("Touchline inlay", flank * 20.2, z, flank * 39.6, z, .34, accent, .215)
			for i = 0, 2 do
				local x = flank * (32.6 + i * 2.6)
				stroke("Apron chevron", x - .72, z - side * 2.05, x + .72, z -.64 * side, .44, accent, .215)
			end
		end
	end
end

local function ribbon(parent: Folder, name: string, pose: CFrame, width: number)
	local board = part(parent, name, Vector3.new(width, 2.08, .15), pose, C("181B2B"))
	local surface = Instance.new("SurfaceGui")
	surface.AutoLocalize = false
	surface.Face, surface.LightInfluence, surface.CanvasSize = Enum.NormalId.Back, 0, Vector2.new(1920, 168)
	surface.SizingMode, surface.Parent = Enum.SurfaceGuiSizingMode.FixedSize, board
	local word = Instance.new("TextLabel")
	word.Name = "Message"
	word.Text, word.Font, word.TextScaled = "★ SOCCERPOLY CONTINENTAL CUP ★", Enum.Font.BuilderSansExtraBold, true
	word.TextColor3, word.BackgroundTransparency = Art.mint, 1
	word.Size, word.Parent = UDim2.fromScale(1, 1), surface
end

local function surroundings(stage: Folder)
	local scene = folder(stage, "Arena surroundings")
	local back = plate(scene, "Night backdrop", 0, -8.5, 0, 2048, .35, 2048, C("191824"))
	back.CastShadow = false
	local surface = Instance.new("SurfaceGui")
	surface.AutoLocalize = false
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
		ColorSequenceKeypoint.new(.39, C("182B32")),
		ColorSequenceKeypoint.new(.53, C("1A2C34")),
		ColorSequenceKeypoint.new(.68, C("1C3035")),
		ColorSequenceKeypoint.new(1, C("141726")),
	})
	gradient.Parent = fill
	local district = plate(scene, "Stadium district", 0, -8.02, 0, 255, .08, 255, C("192C34"))
	district.CastShadow = false
	local pad = plate(scene, "Arena ground shadow", 0, -7.65, 0, 146, .18, 146, C("233830"))
	pad.CastShadow = false
	pad.Transparency = .25

	for _, x in {-43, -15, 15, 43} do
		mesh(scene, "North terrace", "night_stand", Vector3.new(26, 7.2, 10.8),
			CFrame.new(x, 1.25, -69.3) * CFrame.Angles(0, math.pi, 0)).CastShadow = false
	end
	for _, side in {-1,1} do
		for _, z in {-42,-14,14,42} do
			mesh(scene, if side < 0 then "West terrace" else "East terrace", "night_stand", Vector3.new(26,6.2,10.6),
				CFrame.new(side*69.8,.65,z) * CFrame.Angles(0,side*math.pi*.5,0)).CastShadow = false
		end
	end
	-- Low foreground seating keeps the southern row of cards visible in overview.
	for _, x in {-42,-14,14,42} do
		mesh(scene, "South terrace", "night_stand", Vector3.new(26,3.0,7.4),
			CFrame.new(x,-1.95,69.7)).CastShadow = false
	end
	for _, side in {-1,1} do
		for _, endLine in {-1,1} do
			mesh(scene, "Turnstile pavilion", "gatehouse", Vector3.new(8.4,6.7,8.4),
				CFrame.new(side*65.1,.15,endLine*65.1)).CastShadow = false
		end
	end
	for _, x in {-66.0, 66.0} do
		mesh(scene, "Floodlight tower", "lights", Vector3.new(8.2, 16.0, 5.4), CFrame.new(x, 4.9, -68.5)).CastShadow = false
		local rig = plate(scene, "Floodlight accent", x, 11.75, -65.7, 5.8, .36, .22, C("E4EAFF"))
		rig.Material, rig.CastShadow = Enum.Material.Neon, false
		-- Real stadium spotlight + subtle volumetric cone illuminating the pitch
		local lamp = Instance.new("SpotLight")
		lamp.Face, lamp.Color, lamp.Brightness = Enum.NormalId.Back, C("F8F2E4"), 1.65
		lamp.Range, lamp.Angle, lamp.Shadows = 160, 72, false
		lamp.Parent = rig
		local beamOrigin = Instance.new("Attachment")
		beamOrigin.Position, beamOrigin.Parent = Vector3.zero, rig
		local beamTarget = plate(scene, "Floodlight focus", x * .22, .6, -12, .1, .1, .1, C("FFFFFF"))
		beamTarget.Transparency, beamTarget.CastShadow = 1, false
		local targetAtt = Instance.new("Attachment")
		targetAtt.Parent = beamTarget
		local cone = Instance.new("Beam")
		cone.Name, cone.Attachment0, cone.Attachment1 = "Stadium light beam", beamOrigin, targetAtt
		cone.Width0, cone.Width1 = 5.4, 34
		cone.FaceCamera, cone.LightEmission, cone.LightInfluence = true, 1, 0
		cone.Color = ColorSequence.new(C("DDE8FF"), C("E7CE9C"))
		cone.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, .86),
			NumberSequenceKeypoint.new(.45, .94),
			NumberSequenceKeypoint.new(1, 1),
		})
		cone.Parent = rig
	end

	-- Architectural Jumbotron LED Screen over North Terrace
	local jumbotronRig = folder(scene, "Stadium Jumbotron")
	local jPose = CFrame.new(0, 20.5, -55.0) * CFrame.Angles(math.rad(6.0), 0, 0)
	plate(jumbotronRig, "Jumbotron Truss L", -33.5, 13.0, -55.8, 1.6, 24.0, 1.6, C("242C38")).Material = Enum.Material.Metal
	plate(jumbotronRig, "Jumbotron Truss R", 33.5, 13.0, -55.8, 1.6, 24.0, 1.6, C("242C38")).Material = Enum.Material.Metal
	plate(jumbotronRig, "Jumbotron Beam Top", 0, 31.2, -55.8, 69.0, 1.5, 1.6, C("242C38")).Material = Enum.Material.Metal
	plate(jumbotronRig, "Jumbotron Beam Bottom", 0, 9.8, -55.8, 69.0, 1.5, 1.6, C("242C38")).Material = Enum.Material.Metal

	-- Cast cup above the broadcast clock. The enamel base stays visible on every device.
	local crest = folder(jumbotronRig, "Continental Cup crest")
	plate(crest, "Enamel plinth", 0, 32.5, -55.8, 8.4, 1.15, 4.8, C("1C403A")).Material = Enum.Material.Metal
	local cast = mesh(crest, "Continental Cup", "continental_silverware", Vector3.new(9.07, 7, 6.15),
		CFrame.new(0, 36.55, -55.8), Color3.new(1, 1, 1))
	cast.Material, cast.Transparency = Enum.Material.Metal, 1
	cast:SetAttribute("MeshPlaceholder", true)
	local fallback = folder(crest, "Fallback")
	local bowl = plate(fallback, "Cup bowl", 0, 36.9, -55.8, 5.4, 4.2, 4.9, C("DAB35D"))
	bowl.Shape, bowl.Material = Enum.PartType.Ball, Enum.Material.Metal
	plate(fallback, "Cup stem", 0, 34.2, -55.8, 1.05, 2.4, 1.05, C("DAB35D")).Material = Enum.Material.Metal

	-- Top Floodlight Gantry with 10 High-Powered Stadium Spotlights
	for idx, fx in {-28, -21, -14, -7, 0, 7, 14, 21, 28} do
		local lamp = plate(jumbotronRig, "Jumbotron Spot "..idx, fx, 32.2, -55.4, 2.0, 1.1, .8, C("EDF4FF"))
		lamp.Material = Enum.Material.Neon
	end

	local jHousing = part(jumbotronRig, "Jumbotron Housing", Vector3.new(66.4, 22.0, .85), jPose * CFrame.new(0, 0, -.45), C("0A0F14"))
	jHousing.Material = Enum.Material.Metal
	local jBezel = part(jumbotronRig, "Jumbotron Bezel", Vector3.new(65.2, 21.0, .22), jPose * CFrame.new(0, 0, -.05), C("D4AF37"))
	jBezel.Material = Enum.Material.Metal

	-- Neon Accent Rails for broadcast ambiance
	plate(jumbotronRig, "Jumbotron Neon Top", 0, 30.5, -54.6, 64.0, .35, .25, C("9DB77E")).Material = Enum.Material.Neon
	plate(jumbotronRig, "Jumbotron Neon Bottom", 0, 10.5, -54.6, 64.0, .35, .25, C("DBB577")).Material = Enum.Material.Neon

	local jumbotronBoard = part(jumbotronRig, "Jumbotron Screen", Vector3.new(64.0, 20.0, .1), jPose * CFrame.new(0, 0, .08), C("080C10"))
	local jumbotronGui = Instance.new("SurfaceGui")
	jumbotronGui.Name = "JumbotronDisplay"
	jumbotronGui.AutoLocalize = false
	jumbotronGui.Face = Enum.NormalId.Back
	jumbotronGui.LightInfluence = 0
	jumbotronGui.CanvasSize = Vector2.new(768, 240)
	jumbotronGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	jumbotronGui.Parent = jumbotronBoard

	ribbon(scene, "Live stadium ribbon", CFrame.new(22.2, 5.12, -64.6), 34)
	ribbon(scene, "Front stadium ribbon", CFrame.new(0, -1.70, 72.25), 36)
end

return function()
	Lighting.ClockTime, Lighting.GeographicLatitude, Lighting.Brightness = 9.7, 39, 2.75
	Lighting.Ambient, Lighting.OutdoorAmbient = C("939F9B"), C("C6CDC1")
	Lighting.EnvironmentDiffuseScale, Lighting.EnvironmentSpecularScale = .42, .58
	Lighting.GlobalShadows, Lighting.ShadowSoftness = true, .54
	Lighting.ExposureCompensation = -.02
	for _, effect in Lighting:GetChildren() do
		if effect:IsA("PostEffect") or effect:IsA("Atmosphere") then effect:Destroy() end
	end
	local bloom = Instance.new("BloomEffect")
	bloom.Name, bloom.Intensity, bloom.Size, bloom.Threshold = "StadiumBloom", .14, 16, 1.25
	bloom.Parent = Lighting
	local grading = Instance.new("ColorCorrectionEffect")
	grading.Name, grading.Brightness, grading.Contrast, grading.Saturation = "BroadcastGrade", .015, .045, .035
	grading.Parent = Lighting
	local haze = Instance.new("Atmosphere")
	haze.Name, haze.Density, haze.Offset, haze.Haze, haze.Glare = "NightHaze", .12, .12, .35, .10
	haze.Color, haze.Decay = C("252D4A"), C("141728")
	haze.Parent = Lighting
	local stage = Instance.new("Folder")
	stage.Name = "WorldDraftArena"
	surroundings(stage)
	local tray = folder(stage, "Board")
	mesh(tray, "Octagonal arena plinth", "arena_plinth", Vector3.new(Art.plinthWidth, 4.8, Art.plinthWidth), CFrame.new(0, -2.65, 0))
	pitch(stage)
	for i, tile in Board.tiles do drawTile(tray, i, tile) end
	stage.Parent = workspace
	return stage
end
