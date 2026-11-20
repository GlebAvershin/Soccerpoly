--!strict
local loadImage = require(script.Parent.PrintTexture)
local paint = require(script.Parent.ProgrammePaint)
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

return function(parent: Instance, tile, detail: boolean?, index: number?): Frame
	local key = if tile.price > 0 then tile.code else tile.kind
	if tile.kind == "chance" then
		key = if index == 13 then "chanceWest" elseif index == 21 then "chanceEast" else "chance"
	end
	local rail = Instance.new("Frame")
	rail.Name, rail.Size = "Programme illustration", UDim2.fromScale(1, 1)
	rail.BackgroundColor3 = Color3.fromHex("334958")
	rail.ClipsDescendants, rail.BorderSizePixel, rail.Parent = true, 0, parent

	local image: EditableImage?
	if detail then
		-- The open dossier holds one high-resolution illustration.
		if not lastDetail or lastDetail.key ~= key then
			lastDetail = {key = key, background = loadImage(paint.stadium[key])}
		end
		image = lastDetail and lastDetail.background
	end
	if not image then
		if not thumbnails[key] then thumbnails[key] = loadImage(paint.board[key]) end
		image = thumbnails[key]
	end
	if image then
		ink(rail, "Lithograph", image).ScaleType = Enum.ScaleType.Crop
		if tile.league > 0 then
			if not badges[key] then badges[key] = loadImage(paint.kit[key]) end
			local badgeArt = badges[key]
			if badgeArt then
				local badge = ink(rail, "Embroidered kit", badgeArt)
				badge.ZIndex = 2
				badge.AnchorPoint, badge.SizeConstraint = Vector2.new(.5,.5), Enum.SizeConstraint.RelativeYY
				local function fitBadge()
					local size = rail.AbsoluteSize
					if size.X <= 0 or size.Y <= 0 then return end
					local side = math.min(size.Y*.92,size.X*.77)
					local x = if size.X < size.Y*1.8 then .5 else math.max(.24,(side*.5+1)/size.X)
					badge.Position, badge.Size = UDim2.fromScale(x,.5), UDim2.fromScale(side/size.Y,side/size.Y)
				end
				rail:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitBadge)
				fitBadge()
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
