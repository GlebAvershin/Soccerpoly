--!strict
local AssetService = game:GetService("AssetService")
local EncodingService = game:GetService("EncodingService")
export type Paint = {width: number, height: number, palette: string, pixels: string}

local function texture(paint: Paint): EditableImage?
	local sample = 1
	local image: EditableImage? = nil
	local dims = Vector2.new(paint.width, paint.height)
	for _, step in {1, 2} do
		dims = Vector2.new(paint.width / step, paint.height / step)
		local ok, allocation = pcall(AssetService.CreateEditableImage, AssetService, {Size = dims})
		if ok and allocation then
			sample, image = step, allocation
			break
		end
	end
	if not image then return nil end
	local entries = EncodingService:Base64Decode(buffer.fromstring(paint.palette))
	local packed = EncodingService:Base64Decode(buffer.fromstring(paint.pixels))
	local indices = EncodingService:DecompressBuffer(packed, Enum.CompressionAlgorithm.Zstd)
	local rgba = buffer.create(dims.X * dims.Y * 4)
	local colors = {}
	for i = 0, buffer.len(entries) / 3 - 1 do
		colors[i] = bit32.bor(buffer.readu16(entries, i * 3), bit32.lshift(buffer.readu8(entries, i * 3 + 2), 16), 0xFF000000)
	end
	for y = 0, dims.Y - 1 do
		local source = y * sample * paint.width
		local destination = y * dims.X * 4
		for x = 0, dims.X - 1 do
			buffer.writeu32(rgba, destination + x * 4, colors[buffer.readu8(indices, source + x * sample)])
		end
	end
	image:WritePixelsBuffer(Vector2.zero, dims, rgba)
	return image
end

return texture
