--!strict
local AssetService = game:GetService("AssetService")
local Encoding = game:GetService("EncodingService")
local paint = require(script.Parent.ProgrammePaint)
local leagues = {"spain", "england", "germany", "italy", "france"}
local thumbnails: {[string]: EditableImage} = {}
local badges: {[string]: EditableImage} = {}
local lastDetail: {key: string, background: EditableImage?}? = nil

local function decode(source): EditableImage?
	local image = AssetService:CreateEditableImage({Size = Vector2.new(source.width, source.height)})
	if not image then return nil end
	local compressed = Encoding:Base64Decode(buffer.fromstring(source.pixels))
	local rgba = Encoding:DecompressBuffer(compressed, Enum.CompressionAlgorithm.Zstd)
	image:WritePixelsBuffer(Vector2.zero, image.Size, rgba)
	return image
end

local function loadImage(source): EditableImage?
	local ok, image = pcall(decode, source)
	return if ok then image else nil
end

local function ink(parent: Frame, name: string, image: EditableImage): ImageLabel
	local picture = Instance.new("ImageLabel")
	picture.Name, picture.BackgroundTransparency = name, 1
	picture.Size, picture.ResampleMode = UDim2.fromScale(1, 1), Enum.ResamplerMode.Default
	picture.ImageContent, picture.Parent = Content.fromObject(image), parent
	return picture
end

return function(parent: Instance, tile, detail: boolean?): Frame
	local key = if tile.league > 0 then tile.code else tile.kind
	local rail = Instance.new("Frame")
	rail.Name, rail.Size = "Programme illustration", UDim2.fromScale(1, 1)
	rail.BackgroundColor3 = Color3.fromHex("334958")
	rail.ClipsDescendants, rail.BorderSizePixel, rail.Parent = true, 0, parent

	local region = leagues[tile.league] or key
	local image: EditableImage?
	if detail then
		-- Reuse one HD panorama for clubs in the same league.
		if not lastDetail or lastDetail.key ~= region then
			lastDetail = {key = region, background = loadImage(paint.stadium[region])}
		end
		image = lastDetail and lastDetail.background
	end
	if not image then
		if not thumbnails[region] then thumbnails[region] = loadImage(paint.board[region]) end
		image = thumbnails[region]
	end
	if image then
		ink(rail, "Lithograph", image).ScaleType = Enum.ScaleType.Crop
		if tile.league > 0 then
			if not badges[key] then badges[key] = loadImage(paint.kit[key]) end
			local badgeArt = badges[key]
			if badgeArt then
				local badge = ink(rail, "Embroidered kit", badgeArt)
				badge.AnchorPoint, badge.Position = Vector2.new(.5,.5), UDim2.fromScale(.32,.5)
				badge.SizeConstraint, badge.Size = Enum.SizeConstraint.RelativeYY, UDim2.fromScale(1,1)
			end
		end
	else
		-- Keep the pitch motif readable even if the device refuses an editable image.
		local field = Instance.new("Frame")
		field.BackgroundTransparency = 1
		field.Size, field.Position, field.Parent = UDim2.fromScale(.75, .68), UDim2.fromScale(.125, .16), rail
		local outline = Instance.new("UIStroke")
		outline.Color, outline.Thickness, outline.Parent = Color3.fromHex("E7DCC2"), 2, field
		local circle = field:Clone()
		circle.SizeConstraint, circle.Size, circle.Position = Enum.SizeConstraint.RelativeYY, UDim2.fromScale(.56, .56), UDim2.fromScale(.5, .5)
		circle.AnchorPoint, circle.Parent = Vector2.new(.5, .5), field
		local corner = Instance.new("UICorner")
		corner.CornerRadius, corner.Parent = UDim.new(.5, 0), circle
	end
	return rail
end
