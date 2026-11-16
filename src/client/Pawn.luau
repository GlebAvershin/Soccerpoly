--!strict
local shared = game:GetService("ReplicatedStorage"):WaitForChild("League")
local Board = require(shared.Board)
local Art = require(shared.Presentation)
local Pawn = {}

function Pawn.make(figure: number, parent: Instance): Model
	local def = Board.figures[figure]
	local kit, trim, skin, hair = Art.hex(def.color), Art.hex(def.dark), Art.hex(def.skin), Art.hex(def.hair)
	local white, black = Art.paper, Color3.fromHex("233A4D")
	local model = Instance.new("Model")
	model.Name = def.name

	local function piece(name: string, size: Vector3, x: number, y: number, z: number, c: Color3, shape: Enum.PartType?, angle: number?): Part
		local p = Instance.new("Part")
		p.Name, p.Size, p.Color = name, size, c
		p.Shape = shape or Enum.PartType.Block
		p.CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, 0, angle or 0)
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
		p.Parent = model
		return p
	end

	local function oval(name: string, w: number, h: number, d: number, x: number, y: number, z: number, c: Color3, angle: number?): Part
		return piece(name, Vector3.new(w, h, d), x, y, z, c, Enum.PartType.Ball, angle)
	end

	local function bar(name: string, w: number, h: number, d: number, x: number, y: number, z: number, c: Color3, angle: number?): Part
		return piece(name, Vector3.new(w, h, d), x, y, z, c, nil, angle)
	end

	local root = bar("Root", .08, .08, .08, 0, 0, 0, black)
	root.Transparency, root.CastShadow, model.PrimaryPart = 1, false, root
	piece("Collector stand", Vector3.new(.24, 3.62, 3.62), 0, .14, 0, trim, Enum.PartType.Cylinder, math.pi / 2)
	piece("Color ring", Vector3.new(.14, 3.54, 3.54), 0, .31, 0, kit, Enum.PartType.Cylinder, math.pi / 2)
	piece("Inset badge", Vector3.new(.08, 3.15, 3.15), 0, .39, 0, white:Lerp(kit, .25), Enum.PartType.Cylinder, math.pi / 2)

	for _, side in {-1, 1} do
		local x = side * .43
		oval("Boot", .87, .50, 1.16, x, .63, .24, black)
		oval("Boot sole", .87, .15, 1.17, x, .49, .25, white)
		oval("Knee sock", .62, 1.06, .65, x, 1.20, .02, kit)
		bar("Sock piping", .46, .13, .06, x, 1.37, .318, white)
		oval("Knee", .61, .58, .64, x, 1.70, .01, skin)
		oval("Shorts", .91, .82, .93, x, 2.08, .015, trim)
	end
	oval("Jersey shoulder cut", 2.34, 1.80, 1.24, 0, 2.99, 0, kit)
	oval("Jersey waist", 1.73, 1.11, 1.13, 0, 2.59, 0.01, kit:Lerp(trim, .18))
	oval("Neckline", .8, .31, .79, 0, 3.81, .005, trim)
	oval("Neck", .54, .53, .55, 0, 3.91, 0, skin)
	for _, side in {-1, 1} do
		local glove = figure == 4
		local outward = if glove then .19 else 0
		oval("Jersey cuff", .72, .84, .77, side * 1.12, 3.19, 0, kit:Lerp(white, .10), side * .28)
		oval("Forearm", .49, .86, .55, side * (1.28 + outward), 2.72, .09, skin, side * .28)
		oval("Hand", .57, .58, .61, side * (1.36 + outward), 2.40 + outward, .14, if glove then white else skin)
	end

	local tag = bar("Number plate", .94, .57, .043, 0, 2.93, .615, trim)
	tag.CastShadow = false
	local gui = Instance.new("SurfaceGui")
	gui.Face, gui.SizingMode, gui.CanvasSize = Enum.NormalId.Back, Enum.SurfaceGuiSizingMode.FixedSize, Vector2.new(128, 75)
	gui.LightInfluence, gui.Parent = 0, tag
	local text = Instance.new("TextLabel")
	text.Size, text.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	text.Font, text.TextScaled, text.TextColor3, text.Text = Enum.Font.GothamBlack, true, white, def.number
	text.Parent = gui

	oval("Sculpted head", 1.87, 1.76, 1.60, 0, 4.61, 0, skin)
	oval("Nose", .30, .25, .27, 0, 4.51, .79, skin:Lerp(white, .20))
	oval("Smile", .38, .10, .09, 0, 4.22, .674, skin:Lerp(trim, .72))
	for _, side in {-1, 1} do
		oval("Ear", .34, .43, .43, side * .87, 4.61, .055, skin)
		oval("Eye", .21, .26, .09, side * .36, 4.73, .738, black)
		oval("Eye catchlight", .062, .067, .035, side * .36 + .027, 4.79, .785, white)
		oval("Brow", .27, .095, .08, side * .36, 4.951, .701, hair, side * .12)
	end

	if figure == 5 then
		oval("Coach cap crown", 1.95, .73, 1.66, 0, 5.36, .02, trim)
		oval("Coach cap peak", 1.57, .16, .87, 0, 5.22, .65, kit)
		bar("Tactics clipboard", .74, .92, .15, -1.31, 2.56, .42, white, .18)
		bar("Clipboard clip", .30, .16, .17, -1.38, 2.97, .50, trim, .18)
	elseif figure == 2 or figure == 6 then
		oval("Swept hair crown", 1.94, .95, 1.66, 0, 5.175, -.08, hair)
		oval("Swept fringe", .94, .43, .57, -.38, 5.20, .63, hair, -.17)
		oval("Hair bun", .82, .88, .82, .46, 4.94, -.66, hair)
		if figure == 6 then
			bar("Referee card", .50, .67, .07, 1.39, 2.65, .45, Art.gold, -.17)
		else
			oval("Hair tie", .64, .18, .57, .42, 5.10, -.47, kit)
		end
	elseif figure == 1 or figure == 4 then
		oval("Curl base", 1.93, .69, 1.63, 0, 5.218, -.075, hair)
		for index = -2, 2 do
			oval("Sculpted curl", .58, .61, .61, index * .32, 5.38 + .06 * (2 - math.abs(index)), .34, hair:Lerp(black, .10 * (index % 2)))
		end
		if figure == 4 then oval("Keeper headband", 1.9, .18, 1.67, 0, 5.035, .01, kit) end
	else
		oval("Layered fringe", 1.96, .75, 1.61, -.04, 5.23, -.09, hair)
		oval("Swept lock", 1.25, .45, .46, -.25, 5.22, .63, hair, -.27)
	end
	model.Parent = parent
	return model
end

return Pawn
