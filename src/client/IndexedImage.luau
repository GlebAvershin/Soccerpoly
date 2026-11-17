--!strict
local AssetService = game:GetService("AssetService")
local EncodingService = game:GetService("EncodingService")
export type Paint = {width: number, height: number, palette: string, pixels: string}

local function texture(paint: Paint): EditableImage?
	local dims = Vector2.new(paint.width, paint.height)
	local image = AssetService:CreateEditableImage({Size = dims})
	if not image then return nil end
	local entries = EncodingService:Base64Decode(buffer.fromstring(paint.palette))
	local indices = EncodingService:Base64Decode(buffer.fromstring(paint.pixels))
	local rgba = buffer.create(paint.width * paint.height * 4)
	local colors = {}
	for i = 0, buffer.len(entries) / 3 - 1 do
		colors[i] = bit32.bor(buffer.readu16(entries, i * 3), bit32.lshift(buffer.readu8(entries, i * 3 + 2), 16), 0xFF000000)
	end
	for i = 0, buffer.len(indices) - 1 do
		buffer.writeu32(rgba, i * 4, colors[buffer.readu8(indices, i)])
	end
	image:WritePixelsBuffer(Vector2.zero, dims, rgba)
	return image
end

return texture
