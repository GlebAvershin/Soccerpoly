--!strict
local loadImage = require(script.Parent.PrintTexture)
local Paint = require(script.Parent.ReplayPanorama)
local Meshes = require(script.Parent.MeshLibrary)
local C = Color3.fromHex
local matte: EditableImage? = nil

local function plate(parent: Instance, name: string, size: Vector3, at: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, at, color
	p.Anchored, p.CastShadow, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false, false
	p.Parent = parent
	return p
end

local function printing(board: Part, size: Vector2): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face, gui.CanvasSize, gui.LightInfluence = Enum.NormalId.Front, size, 0
	gui.SizingMode, gui.Active, gui.AutoLocalize = Enum.SurfaceGuiSizingMode.FixedSize, false, false
	gui.Parent = board
	return gui
end

local function wall(parent: Folder, start: Vector3, finish: Vector3, height: number, along: number): number
	local middle = (start+finish)*.5
	local tangent = (finish-start).Unit
	local face = tangent:Cross(Vector3.yAxis)
	local span = (finish-start).Magnitude
	local pose = CFrame.lookAt(middle, middle+face)
	local sky = plate(parent, "Stadium sky", Vector3.new(span+.12,110,.16),
		pose*CFrame.new(0,height+55,.32), C("36568A"))
	local skySurface = printing(sky, Vector2.new(8,128))
	local skyFill = Instance.new("Frame")
	skyFill.Size, skyFill.BorderSizePixel, skyFill.BackgroundColor3 = UDim2.fromScale(1,1), 0, Color3.new(1,1,1)
	skyFill.Parent = skySurface
	local skyGradient = Instance.new("UIGradient")
	skyGradient.Rotation, skyGradient.Color = 90, ColorSequence.new(C("21345F"),C("345D9F"))
	skyGradient.Parent = skyFill
	local scale = if matte then height/matte.Size.Y else 1
	local repeatWidth = if matte then matte.Size.X*scale else span
	local cursor = 0
	while cursor < span-.001 do
		local offset = (along+cursor) % repeatWidth
		if repeatWidth-offset < .001 then offset = 0 end
		local length = math.min(span-cursor,repeatWidth-offset)
		local card = plate(parent, "Grandstand panorama", Vector3.new(length+.012,height,.18),
			pose*CFrame.new(span*.5-cursor-length*.5,height*.5,.3), C("40577A"))
		if matte then
			local surface = printing(card, Vector2.new(length/scale,matte.Size.Y))
			local picture = Instance.new("ImageLabel")
			picture.Name, picture.Size = "Grandstand", UDim2.fromScale(1,1)
			picture.BackgroundTransparency, picture.ImageContent = 1, Content.fromObject(matte)
			picture.ImageRectOffset = Vector2.new(math.round(offset/scale),0)
			picture.ImageRectSize = Vector2.new(math.max(1,math.round(length/scale)),matte.Size.Y)
			picture.Parent = surface
		end
		cursor += length
	end
	-- The terrace's front walk projects out of the painting. The rail and boards
	-- shift against the crowd as the camera follows the ball.
	plate(parent, "Concrete terrace", Vector3.new(span,1.2,2.2), pose*CFrame.new(0,.75,-.8), C("536674"))
	plate(parent, "Safety rail", Vector3.new(span,.11,.1), pose*CFrame.new(0,2.38,-1.8), C("B2BAC3"))
	for i = 0, math.floor(span/6) do
		plate(parent, "Railing post", Vector3.new(.09,1.2,.09),
			pose*CFrame.new(-span*.5+i*6,1.82,-1.8), C("8794A1"))
	end
	return along+span
end

local function led(parent: Folder, a: Vector3, b: Vector3)
	local center = (a+b)*.5
	local delta = b-a
	local normal = delta.Unit:Cross(Vector3.yAxis)
	local pose = CFrame.lookAt(center,center+normal)
	local count = math.max(1,math.floor(delta.Magnitude/17+.5))
	local span = delta.Magnitude/count
	for i = 1, count do
		local at = pose*CFrame.new((i-(count+1)*.5)*span,1.48,0)
		local board = plate(parent, "Pitchside LED", Vector3.new(span-.12,2.18,.31), at, C("192D36"))
		local surface = printing(board, Vector2.new(528,72))
		local fill = Instance.new("Frame")
		fill.Size, fill.BorderSizePixel, fill.BackgroundColor3 = UDim2.fromScale(1,1), 0, C("233948")
		fill.Parent = surface
		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new(C("5EAC99"),C("225065"))
		gradient.Parent = fill
		local label = Instance.new("TextLabel")
		label.Size, label.BackgroundTransparency = UDim2.fromScale(.78,.80), 1
		label.Position = UDim2.fromScale(.13,.10)
		label.Text = if i%2==0 then "CONTINENTAL CUP" else "SOCCERPOLY"
		label.TextColor3, label.Font, label.TextScaled = C("F4EFDC"), Enum.Font.BuilderSansExtraBold, true
		label.Parent = fill
		for j = 1, 2 do
			local slash = Instance.new("Frame")
			slash.Size, slash.Position = UDim2.fromScale(.019,.55), UDim2.fromScale(.046+j*.024,.225)
			slash.BorderSizePixel, slash.Rotation, slash.BackgroundColor3 = 0, 21, C("D7EA87")
			slash.Parent = fill
		end
	end
end

return function(actors: Folder)
	if not matte then matte = loadImage(Paint.grandstand) end
	local venue = Instance.new("Folder")
	venue.Name, venue.Parent = "Matchday grandstand", actors
	-- Runoff grass and camera-side pitch surround occupy the playable table's rim.
	for _, x in {-63,63} do
		plate(venue, "Runoff grass", Vector3.new(42,.14,134), CFrame.new(x,.205,0), C("336A54")).Material = Enum.Material.Grass
	end
	for _, z in {-51,51} do
		plate(venue, "Runoff grass", Vector3.new(84,.14,30), CFrame.new(0,.205,z), C("336A54")).Material = Enum.Material.Grass
	end
	local northWest, northEast = Vector3.new(-100,0,-48), Vector3.new(43,0,-48)
	local corner, eastEnd = Vector3.new(59,0,-32), Vector3.new(59,0,79)
	local along = wall(venue,northWest,northEast,39,0)
	along = wall(venue,northEast,corner,39,along)
	wall(venue,corner,eastEnd,39,along)
	led(venue,Vector3.new(-85,0,-38),Vector3.new(37,0,-38))
	led(venue,Vector3.new(37,0,-38),Vector3.new(48,0,-27))
	led(venue,Vector3.new(48,0,-27),Vector3.new(48,0,61))
	for _, z in {-29,36} do
		local mast = plate(venue, "Matchday floodlights", Vector3.new(6.4,22,3.1),
			CFrame.new(52,11,z)*CFrame.Angles(0,math.pi*.5,0), Color3.new(1,1,1))
		mast.Transparency = 1
		mast:SetAttribute("MeshPlaceholder", true)
		Meshes.apply("lights",mast)
		for i = -2,2 do
			local lamp = plate(venue, "Floodlamp", Vector3.new(.1,.63,.60),
				CFrame.new(50.4,20.5,z+i*.97), C("FFF1CA"))
			lamp.Material = Enum.Material.Neon
		end
	end
end
