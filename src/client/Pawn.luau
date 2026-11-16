--!strict
local Board = require(game:GetService("ReplicatedStorage"):WaitForChild("League").Board)
local Pawn = {}
local function hex(value: number): Color3 return Color3.fromHex(string.format("%06x", value)) end

function Pawn.make(figure: number, parent: Instance): Model
	local def = Board.figures[figure]
	local model = Instance.new("Model")
	model.Name = def.name
	local kit, trim, skin, hair = hex(def.color), hex(def.dark), hex(def.skin), hex(def.hair)
	local ivory = Color3.fromHex("EEF4EB")
	local black = Color3.fromHex("121B28")
	local function piece(name: string, w: number, h: number, d: number, x: number, y: number, z: number, c: Color3, shape: Enum.PartType?, tilt: number?, material: Enum.Material?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = shape or Enum.PartType.Block
		p.Size = Vector3.new(w, h, d)
		p.CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, 0, tilt or 0)
		p.Color = c
		p.Material = material or Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
		p.CastShadow = name ~= "Sole" and name ~= "Mark"
		p.Parent = model
		return p
	end
	local root = piece("Root", 0.10, 0.10, 0.10, 0, 0, 0, black)
	root.Transparency = 1
	model.PrimaryPart = root
	local disk = piece("Plinth", 0.34, 3.9, 3.9, 0, 0.19, 0, trim, Enum.PartType.Cylinder, math.pi / 2, Enum.Material.Metal)
	piece("Team ring", 0.10, 3.7, 3.7, 0, 0.40, 0, kit, Enum.PartType.Cylinder, math.pi / 2, Enum.Material.Neon)
	for _, sign in {-1, 1} do
		local x = sign * 0.49
		piece("Stud boot", 0.70, 0.36, 1.10, x, 0.66, 0.16, black)
		piece("Sole", 0.72, 0.11, 1.12, x, 0.46, 0.16, ivory)
		piece("Sock", 0.58, 1.04, 0.61, x, 1.29, 0, kit)
		piece("Sock stripe", 0.61, 0.14, 0.64, x, 1.58, 0, ivory)
		piece("Leg", 0.60, 0.36, 0.65, x, 1.91, 0, skin)
		piece("Shorts", 0.82, 0.70, 0.92, x, 2.36, 0, trim)
		local armAngle = sign * (if figure == 4 then 0.43 else 0.19)
		piece("Sleeve", 0.58, 0.63, 0.72, sign * 1.20, 3.62, 0, kit, nil, armAngle)
		piece("Arm", 0.44, 0.74, 0.54, sign * (if figure == 4 then 1.56 else 1.31), 3.05, 0.07, skin, nil, armAngle)
		piece("Hand", 0.49, 0.32, 0.59, sign * (if figure == 4 then 1.74 else 1.36), 2.67, 0.10,
			if figure == 4 then ivory else skin, Enum.PartType.Ball)
	end
	piece("Jersey", 1.87, 1.48, 1.01, 0, 3.32, 0, kit)
	piece("Collar", 0.69, 0.22, 0.64, 0, 4.07, 0.05, trim)
	local tag = piece("Jersey number", 1.14, 0.76, 0.037, 0, 3.32, 0.522, trim)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(130, 90)
	gui.LightInfluence = 0
	gui.Parent = tag
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBlack
	text.TextScaled = true
	text.TextColor3 = ivory
	text.Text = def.number
	text.Parent = gui
	piece("Head", 1.44, 1.25, 1.21, 0, 4.79, 0, skin)
	piece("Nose", 0.24, 0.21, 0.16, 0, 4.72, 0.64, skin:Lerp(ivory, 0.13))
	piece("Smile", 0.32, 0.075, 0.04, 0, 4.44, 0.618, trim)
	for _, sign in {-1, 1} do
		piece("Ear", 0.28, 0.38, 0.36, sign * 0.77, 4.80, 0.01, skin, Enum.PartType.Ball)
		piece("Eye", 0.17, 0.23, 0.045, sign * 0.33, 4.90, 0.62, black)
		piece("Eye glint", 0.052, 0.060, 0.02, sign * 0.33 + 0.017, 4.95, 0.647, ivory)
	end
	if figure == 1 then
		piece("Top curls", 1.52, 0.55, 1.18, 0, 5.43, -0.02, hair, Enum.PartType.Ball)
		for i = -1, 1 do piece("Curl", 0.57, 0.52, 0.53, i * 0.46, 5.34 + 0.06 * (i % 2), 0.40, hair, Enum.PartType.Ball) end
	elseif figure == 2 then
		piece("Swept hair", 1.59, 0.48, 1.24, 0, 5.37, -0.03, hair, nil, -0.10)
		piece("Ponytail", 0.72, 0.91, 0.62, -0.10, 4.76, -0.78, hair, Enum.PartType.Ball)
		piece("Hair tie", 0.49, 0.31, 0.30, -0.10, 5.12, -0.74, kit)
	elseif figure == 3 then
		piece("Swept fringe", 1.60, 0.43, 1.26, -0.05, 5.35, -0.03, hair, nil, 0.10)
		piece("Fringe", 0.60, 0.24, 0.29, -0.45, 5.19, 0.51, hair, nil, 0.20)
	else
		piece("Crop", 1.54, 0.23, 1.24, 0, 5.40, -0.04, hair)
		for i = -2, 2 do piece("Loc", 0.35, 0.39, 0.46, i * 0.27, 5.50, 0.37, hair, Enum.PartType.Ball) end
		piece("Headband", 1.48, 0.13, 1.23, 0, 5.21, 0.01, kit)
	end
	disk.Name = "Figure base"
	model.Parent = parent
	return model
end
return Pawn
