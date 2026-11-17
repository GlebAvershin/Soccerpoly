--!strict
local paint = require(script.Parent.ProgrammePaint)
local decode = require(script.Parent.IndexedImage)
local images: {[string]: EditableImage} = {}
local unavailable: {[string]: boolean} = {}
local Ink = Color3.fromHex

-- Shirt colours used for the woven trim at the foot of each club illustration.
local fabrics = {
	SEV={"F1E8D5","C43D43"}, ATM={"BD3448","F1E9D7"}, FCB={"263B78","A73051"}, RMA={"EDE4CC","AA8742"},
	ARS={"C63B39","F6EBDB"}, LIV={"9C202F","EACF91"}, MCI={"91BFD8","F6EDDD"}, MUN={"BA3033","252B39"},
	ACM={"942C33","242A32"}, INT={"294E9D","202B36"}, JUV={"292D32","EFE6D6"}, NAP={"4D9EC4","F2E9DC"},
	B04={"D44341","242D33"}, RBL={"F1E8DC","C63745"}, BVB={"F2C939","212B32"}, BAY={"BD3544","ECE3D2"},
	OL={"EDE5D5","AD3440"}, OM={"EDE7D8","5DA7C6"}, ASM={"AC313C","F5EADB"}, PSG={"263C62","C54145"},
}

return function(parent: Instance, tile: any): Frame
	local key = if tile.league>0 then tile.code else tile.kind
	local fabric = fabrics[tile.code] or {"233847","D4AC68"}
	local rail = Instance.new("Frame")
	rail.Name, rail.Size, rail.BorderSizePixel = "Programme illustration", UDim2.fromScale(1,1), 0
	rail.BackgroundColor3, rail.ClipsDescendants, rail.Parent = Ink(fabric[1]), true, parent
	if not images[key] and not unavailable[key] then
		local ok, image = pcall(decode, paint[key])
		if ok and image then images[key]=image else unavailable[key]=true end
	end
	local image = images[key]
	if image then
		local poster = Instance.new("ImageLabel")
		poster.Name, poster.BackgroundTransparency = "Lithograph", 1
		poster.Size, poster.ScaleType = UDim2.fromScale(1,1), Enum.ScaleType.Crop
		poster.ImageContent, poster.Parent = Content.fromObject(image), rail
	else
		local shade = Instance.new("UIGradient")
		shade.Rotation, shade.Color, shade.Parent = 33, ColorSequence.new(Ink(fabric[1]),Ink(fabric[2])), rail
		-- A printed pitch diagram still identifies the programme if editable
		-- images are unavailable on this device.
		local function chalk(name, x, y, width, height, circle)
			local field=Instance.new("Frame")
			field.Name,field.BackgroundTransparency=name,1
			field.Position,field.Size=UDim2.fromScale(x,y),UDim2.fromScale(width,height)
			field.Parent=rail
			local outline=Instance.new("UIStroke")
			outline.Thickness,outline.Color,outline.Parent=2,Ink("FEF1D8"),field
			if circle then
				local curve=Instance.new("UICorner")
				curve.CornerRadius,curve.Parent=UDim.new(.5,0),field
			end
		end
		chalk("Touchlines",.13,.16,.74,.58,false)
		chalk("Centre circle",.43,.27,.14,.35,true)
		chalk("Penalty area",.13,.27,.12,.36,false)
		chalk("Penalty area",.75,.27,.12,.36,false)
	end
	for i=0,5 do
		local tab = Instance.new("Frame")
		tab.BorderSizePixel, tab.BackgroundColor3 = 0, Ink(fabric[i%2+1])
		tab.Position, tab.Size, tab.Parent = UDim2.fromScale(i/6,.91), UDim2.fromScale(1/6+.001,.09), rail
	end
	return rail
end
