--!strict
local loadImage = require(script.Parent.PrintTexture)
local cached: EditableImage? = nil

return function(parent: GuiObject): ImageLabel?
	if not cached then cached = loadImage(require(script.Parent.CupPrintData)) end
	if not cached then return nil end
	local label = Instance.new("ImageLabel")
	label.Name = "Continental Cup lithograph"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.ScaleType = Enum.ScaleType.Crop
	label.ImageContent = Content.fromObject(cached)
	label.Parent = parent
	return label
end
