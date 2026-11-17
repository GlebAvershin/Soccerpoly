--!strict
local loadImage = require(script.Parent.PrintTexture)

return function(field: Instance)
	local image = loadImage(require(script.Parent.TurfPaint))
	if not image then return end
	-- The print is below the chalk and shares the world axes of the football pitch.
	local anchor = Instance.new("Part")
	anchor.Name = "Painted grass"
	anchor.Size = Vector3.new(84, 72, .02)
	anchor.CFrame = CFrame.new(0, .290, 0) * CFrame.Angles(-math.pi / 2, 0, 0)
	anchor.Transparency, anchor.Anchored, anchor.CastShadow = 1, true, false
	anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = false, false, false
	local surface = Instance.new("SurfaceGui")
	surface.Name, surface.Face = "Mown playing surface", Enum.NormalId.Back
	surface.SizingMode, surface.CanvasSize = Enum.SurfaceGuiSizingMode.FixedSize, image.Size
	surface.LightInfluence, surface.MaxDistance, surface.Active = .48, 12000, false
	local print = Instance.new("ImageLabel")
	print.Name, print.BackgroundTransparency = "Grass nap", 1
	print.Size, print.ImageContent = UDim2.fromScale(1, 1), Content.fromObject(image)
	print.Parent, surface.Parent, anchor.Parent = surface, anchor, field
	for _, grass in field:GetChildren() do
		if grass:IsA("BasePart") and grass.Name == "Mown turf" then
			grass.LocalTransparencyModifier = 1
		end
	end
end
