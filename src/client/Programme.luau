--!strict
local loadImage = require(script.Parent.PrintTexture)
local style = require(script.Parent.ProgrammeStyle)
local paint = require(script.Parent.ProgrammePaint)
local leagues = {"spain", "england", "germany", "italy", "france"}
local thumbnails: {[string]: EditableImage} = {}
local badges: {[string]: EditableImage} = {}
local lastDetail: {key: string, background: EditableImage?}? = nil

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
				badge.SizeConstraint, badge.Size = Enum.SizeConstraint.RelativeYY, UDim2.fromScale(.78,.78)
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
	local fade = Instance.new("Frame")
	fade.Name, fade.BorderSizePixel, fade.BackgroundColor3 = "Ink wash", 0, style.ink(tile)
	fade.Position, fade.Size = UDim2.fromScale(0,.66), UDim2.fromScale(1,.34)
	fade.ZIndex, fade.Parent = 1, rail
	local wash = Instance.new("UIGradient")
	wash.Rotation, wash.Transparency, wash.Parent = 90, NumberSequence.new(1,0), fade
	return rail
end
