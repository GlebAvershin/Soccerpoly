--!strict
local AssetService = game:GetService("AssetService")
local Encoding = game:GetService("EncodingService")
local function decode(source): EditableImage?
	local image = AssetService:CreateEditableImage({Size = Vector2.new(source.width, source.height)})
	if not image then return nil end
	local compressed = Encoding:Base64Decode(buffer.fromstring(source.pixels))
	local rgba = Encoding:DecompressBuffer(compressed, Enum.CompressionAlgorithm.Zstd)
	image:WritePixelsBuffer(Vector2.zero, image.Size, rgba)
	return image
end

return function(source): EditableImage?
	local ok, image = pcall(decode, source)
	return if ok then image else nil
end
