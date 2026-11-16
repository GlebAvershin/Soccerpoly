--!strict
local TextService = game:GetService("TextService")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("League")
local Board = require(shared.Board)
local Geometry = require(shared.Geometry)
local Art = require(shared.Presentation)
local UI = require(script.Parent.Components)

type PrintedCell = {
	frame: Frame, title: TextLabel, value: TextLabel, outline: UIStroke,
	full: string, compact: string, price: string, tint: Color3,
	width: number, height: number, minimumNameWidth: number,
}
local NAME_FONT = Enum.Font.BuilderSansBold
local CENTER = Enum.TextXAlignment.Center

local function lineBreak(name: string): string
	local best, span = name, math.huge
	for gap in string.gmatch(name, "() ") do
		local left, right = string.sub(name, 1, gap - 1), string.sub(name, gap + 1)
		local a = TextService:GetTextSize(left, 18, NAME_FONT, Vector2.new(800, 32)).X
		local b = TextService:GetTextSize(right, 18, NAME_FONT, Vector2.new(800, 32)).X
		if math.max(a, b) < span then
			best, span = left .. "\n" .. right, math.max(a, b)
		end
	end
	return if #name >= 12 then best else name
end

local function create(root: Frame, translate: (string) -> string)
	local layer = UI.box(root, "BoardLabels")
	layer.Size = UDim2.fromScale(1, 1)
	local printed: {PrintedCell} = {}
	for index, tile in Board.tiles do
		local accent = Art.accent(tile.kind, tile.league)
		local tint = if tile.league > 0 then Art.hex(Art.clubColors[index]) else accent
		local frame = UI.box(layer, "Cell" .. index,
			if tile.price > 0 then Color3.fromHex("FFFAED") else Art.paper:Lerp(accent, .29), 3)
		local outline = UI.stroke(frame, tint:Lerp(Art.ink, .36), .8)
		frame.AnchorPoint, frame.Visible = Vector2.new(.5, .5), false
		local title = UI.label(frame, "", 12, {name = "Title", font = NAME_FONT, color = Art.ink, align = CENTER})
		title.TextTruncate, title.TextWrapped = Enum.TextTruncate.None, false
		local value = UI.label(frame, "", 12, {name = "Price", font = NAME_FONT, color = Color3.fromHex("FFFBEE"), align = CENTER, ellipsis = true})
		value.TextSize, value.BackgroundColor3 = 9, tint:Lerp(Art.ink, .48)
		value.BackgroundTransparency = 0
		UI.round(value, 3)
		local price = if tile.price > 0 then tostring(tile.price) .. " CR" elseif tile.kind == "kickoff" then "+" .. Board.kickoffCash .. " CR" else ""
		value.Text = price
		printed[index] = {frame = frame, title = title, value = value, outline = outline, full = "", compact = tile.code, price = price, tint = tint,
			width = 0, height = 0, minimumNameWidth = 0}
	end

	local function translateLabels()
		for i, cell in printed do
			local tile = Board.tiles[i]
			local name = translate(if tile.price > 0 then tile.name else Art.shortStop[tile.kind])
			cell.full = lineBreak(name)
			cell.width = 0
			cell.minimumNameWidth = math.ceil(TextService:GetTextSize(cell.full, 8, NAME_FONT, Vector2.new(1000, 1000)).X) + 6
			cell.title:SetAttribute("FullName", name)
		end
	end
	translateLabels()

	return {
		translate = translateLabels,
		show = function(value: boolean) layer.Visible = value end,
		owners = function(match: any)
			local colors = {}
			if match then
				for _, seat in match.seats do colors[seat.id] = Art.hex(Board.figures[seat.figure].color) end
			end
			for index, cell in printed do
				local owned = match and colors[match.clubs[index].owner]
				cell.outline.Color = owned or cell.tint:Lerp(Art.ink, .36)
				cell.outline.Thickness = if owned then 1.55 else .8
			end
		end,
		project = function(camera: Camera)
			local roomy = camera.ViewportSize.X >= 750 and camera.ViewportSize.Y >= 650
			for i, cell in printed do
				local at = Geometry.cells[i]
				local center = Vector3.new(at.X, Art.tileTop + .045, at.Z)
				local spot, visible = camera:WorldToScreenPoint(center + Art.boardNear * 3.64)
				cell.frame.Visible = visible
				if not visible then continue end
				local left = camera:WorldToScreenPoint(center - Art.boardRight * 8.03)
				local right = camera:WorldToScreenPoint(center + Art.boardRight * 8.03)
				local near = camera:WorldToScreenPoint(center + Art.boardNear * 8.5)
				local far = camera:WorldToScreenPoint(center - Art.boardNear * 8.5)
				local width = math.max(if roomy then cell.minimumNameWidth else 19, math.floor(math.abs(right.X - left.X) * 1.01))
				local projectedHeight = math.abs(near.Y - far.Y)
				local wraps = cell.full:find("\n", 1, true) ~= nil
				local showPrice = if i == 1 then width >= 34 and projectedHeight >= 29
					else cell.price ~= "" and width >= 58 and projectedHeight >= 54
				local priceHeight = if showPrice then 10 else 0
				local height = if wraps then math.max(if roomy then 24 elseif width >= 42 then 22 else 15, math.floor(projectedHeight * .67))
					else math.max(15, math.floor(projectedHeight * .49)) + priceHeight
				cell.frame.Position = UDim2.fromOffset(math.round(spot.X), math.round(spot.Y))
				if cell.width == width and cell.height == height then continue end
				cell.width, cell.height = width, height
				local bounds = Vector2.new(width - 4, height - priceHeight - 2)
				local textSize = 14
				local nameWidth = width
				while textSize >= 8 do
					local size = TextService:GetTextSize(cell.full, textSize, NAME_FONT, Vector2.new(1000, 1000))
					if size.X <= bounds.X and size.Y <= bounds.Y then
						nameWidth = math.min(width, math.max(if showPrice then 36 else 24, math.ceil(size.X) + 6))
						break
					end
					textSize -= 1
				end
				cell.title.Text = if textSize >= 8 then cell.full else cell.compact
				cell.title.TextSize = if textSize >= 8 then textSize else math.clamp(math.floor(width / 3), 7, 11)
				cell.frame.Size = UDim2.fromOffset(nameWidth, height)
				cell.title.Size = UDim2.fromOffset(nameWidth - 4, bounds.Y)
				cell.title.Position = UDim2.fromOffset(2, 1)
				cell.value.Visible = priceHeight > 0
				if priceHeight > 0 then
					cell.value.Position, cell.value.Size = UDim2.new(0, 3, 1, -priceHeight - 1), UDim2.new(1, -6, 0, priceHeight - 1)
				end
			end
		end,
	}
end

return create
