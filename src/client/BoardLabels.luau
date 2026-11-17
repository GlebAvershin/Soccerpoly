--!strict
local shared = game:GetService("ReplicatedStorage"):WaitForChild("League")
local Board = require(shared.TourBoard)
local Geometry = require(shared.Geometry)
local Art = require(shared.Presentation)
local UI = require(script.Parent.Components)

type Print = {name: TextLabel, value: TextLabel, stripe: Frame, transform: CFrame, width: number, depth: number, }

local function text(parent: Instance, name: string): TextLabel
	local label = Instance.new("TextLabel")
	label.Name, label.AnchorPoint, label.BackgroundTransparency = name, Vector2.one * .5, 1
	label.Font, label.TextColor3 = Enum.Font.BuilderSansExtraBold, Art.ink
	label.TextScaled, label.TextWrapped = true, true
	label.TextStrokeColor3, label.TextStrokeTransparency = Art.paper, .76
	local size = Instance.new("UITextSizeConstraint")
	size.MinTextSize, size.MaxTextSize, size.Parent = 5, 18, label
	label.Parent = parent
	return label
end

return function(root: Frame, translate: (string) -> string)
	local layer = UI.box(root, "BoardPrint")
	layer.Size, layer.Interactable = UDim2.fromScale(1, 1), false
	local prints: {Print} = {}
	for index, cell in Geometry.cells do
		local dimensions = Geometry.tileSize(index)
		local tile = UI.box(layer, "Cell" .. index)
		tile.Size = UDim2.fromScale(1, 1)
		local stripe = UI.box(tile, "Ownership mark", Art.paper, 1)
		stripe.AnchorPoint, stripe.Visible = Vector2.one * .5, false
		prints[index] = {
			name = text(tile, "Club name"), value = text(tile, "Club cost"), stripe = stripe,
			transform = CFrame.new(cell.X, Art.tileTop + .05, cell.Z) * CFrame.Angles(0, Geometry.tileYaw(index), 0),
			width = dimensions.X, depth = dimensions.Y,
		}
	end
	local match: any
	local compact = false
	local function refresh()
		for i, entry in prints do
			local tile = Board.tiles[i]
			local owner = if match then match.clubs[i].owner else 0
			local value = if owner ~= 0 then match.gates[i] else tile.price
			entry.name.Text = if compact then tile.code else string.upper(translate(tile.name))
			entry.value.Text = if value > 0 then tostring(value) .. (if compact then "" else " CR") else ""
			entry.stripe.Visible = owner ~= 0
			if owner ~= 0 then
				for j, seat in match.seats do
					if seat.id == owner then
						entry.stripe.BackgroundColor3 = Art.seatColors[j]
						break
					end
				end
			end
		end
	end
	refresh()
	return {
		translate = refresh,
		update = function(data: any)
			match = if data.match then {clubs = data.match.clubs, seats = data.match.seats, gates = data.gates} else nil
			refresh()
		end,
		project = function(camera: Camera)
			local small = camera.ViewportSize.X < 650
			if small ~= compact then
				compact = small
				refresh()
			end
			for i, info in prints do
				local pose, width, depth = info.transform, info.width, info.depth
				local left = camera:WorldToScreenPoint(pose * Vector3.new(-width * .5, 0, 0))
				local right = camera:WorldToScreenPoint(pose * Vector3.new(width * .5, 0, 0))
				local dx, dy = right.X - left.X, right.Y - left.Y
				local yaw = math.deg(if dx >= 0 then math.atan2(dy, dx) else math.atan2(-dy, -dx))
				local pixels = math.sqrt(dx ^ 2 + dy ^ 2)
				local function place(label: GuiObject, offset: number, scale: number, h: number)
					local point = camera:WorldToScreenPoint(pose * Vector3.new(0, 0, offset * depth))
					label.Position, label.Size = UDim2.fromOffset(point.X, point.Y), UDim2.fromOffset(pixels * scale, h)
					label.Rotation = yaw
				end
				local height = math.max(8, pixels * .30)
				local corner = (i - 1) % 8 == 0
				local kind = Board.tiles[i].kind
				local positions = if corner then .23 elseif kind == "tax" or kind == "chance" then .24 else .055
				place(info.name, positions, if corner then .92 else .91, height)
				place(info.value, .325, .77, height)
				place(info.stripe, .177, .84, math.max(1.35, pixels * .044))
			end
		end,
	}
end
