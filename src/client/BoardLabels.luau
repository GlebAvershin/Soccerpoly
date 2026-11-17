--!strict
local shared = game:GetService("ReplicatedStorage"):WaitForChild("League")
local Board = require(shared.TourBoard)
local Geometry = require(shared.Geometry)
local Art = require(shared.Presentation)
local UI = require(script.Parent.Components)

type Print = {
	name: TextLabel, value: TextLabel, league: TextLabel, stripe: Frame,
	transform: CFrame, width: number, depth: number,
}

local mobileTitles = {
	SEV = "Sevilla", ARS = "Arsenal", ACM = "Milan", INT = "Inter", JUV = "Juve",
	NAP = "Napoli", RMA = "Real", FCB = "Barça", BAY = "Bayern", ASM = "Monaco",
	OM = "OM", OL = "Lyon", SB = "Bernabéu", OT = "Trafford", SS = "San Siro", AA = "Allianz",
}
local mobileEvents = {
	kickoff = "Kickoff", chance = "Chance", tax = "Tax", tour = "Away", championship = "Cup", bench = "Bench",
}

local shortTitles = {
	["Bayer Leverkusen"] = "Leverkusen",
	["Olympique Lyonnais"] = "Lyon",
	["Olympique de Marseille"] = "Marseille",
	["Paris Saint-Germain"] = "Paris SG",
	["Borussia Dortmund"] = "Borussia\nDortmund",
	["Manchester United"] = "Manchester\nUnited",
	["Manchester City"] = "Manchester\nCity",
	["Santiago Bernabéu"] = "Santiago\nBernabéu",
	["Atlético Madrid"] = "Atlético\nMadrid",
	["FC Barcelona"] = "Barcelona",
	["Liverpool FC"] = "Liverpool",
}

local function text(parent: Instance, name: string, color: Color3, maxSize: number, font: Enum.Font): TextLabel
	local label = Instance.new("TextLabel")
	label.Name, label.AnchorPoint, label.BackgroundTransparency = name, Vector2.one * .5, 1
	label.Font, label.TextColor3 = font, color
	label.TextScaled, label.TextWrapped = true, true
	local size = Instance.new("UITextSizeConstraint")
	size.MinTextSize, size.MaxTextSize, size.Parent = 5, maxSize, label
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
		local stripe = UI.box(tile, "Ownership mark", Art.paper, 2)
		stripe.AnchorPoint, stripe.Visible = Vector2.one * .5, false
		local price = text(tile, "Club cost", Art.paper, 16, Enum.Font.BuilderSansBold)
		local holding = Instance.new("UICorner")
		holding.CornerRadius, holding.Parent = UDim.new(0, 2), price
		price.BackgroundColor3 = Art.printInk
		prints[index] = {
			name = text(tile, "Club name", Art.printInk, 18, Enum.Font.BuilderSansExtraBold),
			value = price, league = text(tile, "League mark", Art.printInk, 11, Enum.Font.BuilderSansExtraBold), stripe = stripe,
			transform = CFrame.new(cell.X, Art.tileTop + .09, cell.Z) * CFrame.Angles(0, Geometry.tileYaw(index), 0),
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
			local translated = translate(tile.name)
			local title = if translated == tile.name then shortTitles[tile.name] or translated else translated
			if compact then
				local concise = if tile.price == 0 then mobileEvents[tile.kind] else mobileTitles[tile.code]
				local length = utf8.len(translated)
				title = if concise and translated == tile.name then concise elseif length and length < 9 then translated else tile.code
			end
			entry.name.Text = title
			entry.value.Text = if value > 0 then tostring(value) .. (if compact then "" else " CR") else ""
			entry.value.BackgroundTransparency = if value > 0 then 0 else 1
			entry.league.Text = if not compact and tile.league > 0 then Board.leagues[tile.league].code else ""
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
		show = function(visible: boolean)
			layer.Visible = visible
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
				local function place(label: GuiObject, offset: number, scale: number, height: number)
					local point = camera:WorldToScreenPoint(pose * Vector3.new(0, 0, offset * depth))
					label.Position, label.Size = UDim2.fromOffset(point.X, point.Y), UDim2.fromOffset(pixels * scale, height)
					label.Rotation = yaw
				end
				local tile = Board.tiles[i]
				local corner = (i - 1) % 8 == 0
				local titleDepth = if corner then .36 elseif tile.price == 0 then .30 elseif tile.kind == "venue" then .128 else -.055
				local nameHeight = pixels * (if tile.league > 0 then .47 else .33)
				place(info.name, titleDepth, .91, math.max(10, nameHeight))
				place(info.value, .340, if compact then .53 else .60, math.max(7, pixels * .213))
				place(info.league, -.375, .66, math.max(7, pixels * .176))
				place(info.stripe, .447, .78, math.max(1.4, pixels * .044))
			end
		end,
	}
end
