--!strict
local TextService = game:GetService("TextService")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("League")
local Board = require(shared.Board)
local Geometry = require(shared.Geometry)
local Art = require(shared.Presentation)
local UI = require(script.Parent.Components)

type PrintedCell = {frame: Frame, title: TextLabel, value: TextLabel, full: string, compact: string, price: string}
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
		local frame = UI.box(layer, "Cell" .. index)
		frame.AnchorPoint, frame.Visible = Vector2.new(.5, .5), false
		local title = UI.label(frame, "", 16, {name = "Title", font = NAME_FONT, color = Art.ink, align = CENTER, ellipsis = true})
		title.TextTruncate, title.TextWrapped = Enum.TextTruncate.None, true
		title.TextScaled = true
		local limit = Instance.new("UITextSizeConstraint")
		limit.MinTextSize, limit.MaxTextSize, limit.Parent = 9, 19, title
		local value = UI.label(frame, "", 12, {name = "Price", font = NAME_FONT, color = Color3.fromHex("345457"), align = CENTER, ellipsis = true})
		local price = if tile.price > 0 then tostring(tile.price) .. " CR" elseif tile.kind == "kickoff" then "+" .. Board.kickoffCash .. " CR" else ""
		value.Text = price
		printed[index] = {frame = frame, title = title, value = value, full = "", compact = tile.code, price = price}
	end

	local function translateLabels()
		for i, cell in printed do
			local tile = Board.tiles[i]
			local name = translate(if tile.price > 0 then tile.name else Art.shortStop[tile.kind])
			cell.full = lineBreak(name)
			cell.title:SetAttribute("FullName", name)
		end
	end
	translateLabels()

	return {
		translate = translateLabels,
		project = function(camera: Camera)
			for i, cell in printed do
				local at = Geometry.cells[i]
				local spot = Vector3.new(at.X, Art.tileTop + .03, at.Z + 1.48)
				local center, onScreen = camera:WorldToScreenPoint(spot)
				cell.frame.Visible = onScreen
				if not onScreen then continue end
				local left = camera:WorldToScreenPoint(spot - Vector3.xAxis * 7.05)
				local right = camera:WorldToScreenPoint(spot + Vector3.xAxis * 7.05)
				local near = camera:WorldToScreenPoint(spot + Vector3.zAxis * 3.4)
				local far = camera:WorldToScreenPoint(spot - Vector3.zAxis * 3.4)
				local width = math.floor(math.abs(right.X - left.X))
				local height = math.floor(math.abs(far.Y - near.Y))
				local full = width >= 48 and height >= 26
				local priceHeight = if full and height >= 35 and cell.price ~= "" then 13 else 0
				local name = if full then cell.full else cell.compact
				if cell.title.Text ~= name then cell.title.Text = name end
				cell.frame.Position = UDim2.fromOffset(math.floor(center.X + .5), math.floor(center.Y + .5))
				cell.frame.Size = UDim2.fromOffset(math.max(15, width), math.max(12, height))
				cell.title.Size = UDim2.new(1, 0, 1, -priceHeight)
				cell.value.Visible = priceHeight > 0
				if priceHeight > 0 then
					cell.value.Position, cell.value.Size = UDim2.new(0, 0, 1, -priceHeight), UDim2.new(1, 0, 0, priceHeight)
				end
			end
		end,
	}
end

return create
