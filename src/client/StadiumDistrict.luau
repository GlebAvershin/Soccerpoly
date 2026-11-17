--!strict
local loadImage = require(script.Parent.PrintTexture)
return function(ground: Instance)
	local image = loadImage(require(script.Parent.DistrictPaint).district)
	if not image then return end
	local surface = Instance.new("SurfaceGui")
	surface.Name, surface.Face = "Matchday district", Enum.NormalId.Top
	surface.SizingMode, surface.CanvasSize = Enum.SurfaceGuiSizingMode.FixedSize, image.Size
	surface.Active, surface.LightInfluence, surface.MaxDistance = false, 0, 12000
	local print = Instance.new("ImageLabel")
	print.Name, print.BackgroundTransparency = "Concourse", 1
	print.Size, print.ImageContent = UDim2.fromScale(1,1), Content.fromObject(image)
	print.Parent, surface.Parent = surface, ground
end
