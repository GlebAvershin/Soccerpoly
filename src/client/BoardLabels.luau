--!strict
local shared = game:GetService("ReplicatedStorage"):WaitForChild("League")
local Board = require(shared.TourBoard)
local Art = require(shared.Presentation)
local illustrate = require(script.Parent.Programme)
local UI = require(script.Parent.Components)
local style = require(script.Parent.ProgrammeStyle)
local names = {
	SEV={"Sevilla","Севилья"}, ATM={"Atlético","Атлетико"}, FCB={"Barça","Барса"}, RMA={"Real Madrid","Реал"},
	ARS={"Arsenal","Арсенал"}, LIV={"Liverpool","Ливерпуль"}, MCI={"Man City","Ман Сити"}, MUN={"Man Utd","МЮ"},
	ACM={"Milan","Милан"}, INT={"Inter","Интер"}, JUV={"Juve","Юве"}, NAP={"Napoli","Наполи"},
	B04={"Bayer","Байер"}, RBL={"Leipzig","Лейпциг"}, BVB={"Dortmund","Дортмунд"}, BAY={"Bayern","Бавария"},
	OL={"Lyon","Лион"}, OM={"Marseille","Марсель"}, ASM={"Monaco","Монако"}, PSG={"PSG","ПСЖ"},
	SB={"Bernabéu","Бернабеу"}, OT={"Trafford","Траффорд"}, SS={"San Siro","Сан-Сиро"}, AA={"Allianz","Альянц"},
	KO={"Kickoff","Старт"}, TAX={"Tax","Сбор"}, CH={"Chance","Шанс"}, TOUR={"Away","Выезд"},
	CUP={"Cup","Кубок"}, BENCH={"Bench","Скамья"},
}
local function band(parent: Frame, name: string, y: number, height: number, font: Font, color: Color3): TextLabel
	local text = Instance.new("TextLabel")
	text.Name, text.AutoLocalize, text.BackgroundTransparency = name, false, 1
	text.FontFace, text.TextColor3 = font, color
	text.TextWrapped = false
	text.TextScaled = true
	text.Position, text.Size = UDim2.fromScale(.035, y), UDim2.fromScale(.93, height)
	text.Text, text.Parent = "", parent
	return text
end

local function intersects(a: Rect, b: Rect): boolean
	return a.Min.X < b.Max.X and a.Max.X > b.Min.X and a.Min.Y < b.Max.Y and a.Max.Y > b.Min.Y
end

-- Reserve a visible panorama on shallow side cards. Deeper end cards can
-- use the extra space for artwork after both lines reach their target height.
local function setLayout(entry, compact: boolean)
	local artHeight = if entry.buyable then .45 else .55
	local nameHeight = if entry.buyable then .32 else .40
	local priceY, priceHeight = .775,.21
	local name = entry.name
	if compact and entry.buyable then
		priceHeight = math.min(.502, 6.35 / entry.part.Size.Y)
		nameHeight = math.min(.38, 5.4 / entry.part.Size.Y)
		priceY = .99 - priceHeight
		artHeight = priceY - nameHeight - .006
	end
	local inset = if compact then .028 else .035
	entry.poster.Size = UDim2.fromScale(1,artHeight)
	entry.title.Position, entry.title.Size = UDim2.fromScale(inset,artHeight), UDim2.fromScale(1-2*inset,nameHeight)
	entry.cost.Position, entry.cost.Size = UDim2.fromScale(inset,priceY), UDim2.fromScale(1-2*inset,priceHeight)
	entry.owner.Position, entry.owner.Size = UDim2.fromScale(0,artHeight), UDim2.fromScale(.026,1-artHeight)
	entry.title.Text, entry.nativeTitle.Text = name, name
	for _, rule in entry.rules do rule.Visible = not compact end
	entry.compact = compact
end

-- The board camera's right axis stays parallel to the touchlines. Intersect the
-- top and bottom edges of each projected strip to inscribe a pixel-aligned rect.
local function projectBand(camera: Camera, part: BasePart, original: GuiObject): Rect
	local offset, size = original.Position, original.Size
	local x0 = part.Size.X * (offset.X.Scale - .5)
	local x1 = x0 + part.Size.X * size.X.Scale
	local y0 = part.Size.Y * (.5 - offset.Y.Scale)
	local y1 = y0 - part.Size.Y * size.Y.Scale
	local basis = part.CFrame
	local function point(x: number, y: number): Vector3
		return camera:WorldToViewportPoint(basis:PointToWorldSpace(Vector3.new(x, y, part.Size.Z * .5)))
	end
	local tl, tr = point(x0,y0), point(x1,y0)
	local bl, br = point(x0,y1), point(x1,y1)
	local left, right = math.ceil(math.max(tl.X,bl.X)), math.floor(math.min(tr.X,br.X))
	local top, bottom = math.ceil(tl.Y), math.floor(bl.Y)
	return Rect.new(left,top,math.max(left+1,right),math.max(top+1,bottom))
end

return function(root: Frame, translate: (string)->string)
	local hud = assert(root:FindFirstAncestorOfClass("ScreenGui"))
	local playerGui = hud.Parent
	local group = Instance.new("Folder")
	group.Name, group.Parent = "BoardPrint", playerGui

	-- WorldToViewportPoint uses device-safe coordinates, including the portion
	-- behind the top bar. Keep the board print separate from controls' safe insets.
	local overlay = Instance.new("ScreenGui")
	overlay.Name, overlay.ResetOnSpawn, overlay.AutoLocalize = "Programme typography", false, false
	overlay.ScreenInsets, overlay.DisplayOrder = Enum.ScreenInsets.DeviceSafeInsets, hud.DisplayOrder - 1
	overlay.ClipToDeviceSafeArea = false
	overlay.Parent = playerGui
	local arrow = UI.box(overlay, "Turn arrow")
	arrow.Size, arrow.AnchorPoint = UDim2.fromOffset(15,10), Vector2.new(.5,1)
	arrow.Visible, arrow.ZIndex = false, 5
	for i, angle in {-37,37} do
		local arm = UI.box(arrow, "Arm", Art.mint, 2)
		arm.AnchorPoint, arm.Rotation = Vector2.new(.5,.5), angle
		arm.Size = UDim2.fromOffset(4,9)
		arm.Position = UDim2.fromScale(if i==1 then .35 else .65,.5)
		UI.stroke(arm,Art.ink)
	end
	hud.Destroying:Connect(function()
		overlay:Destroy()
		group:Destroy()
	end)
	local sheets = {}
	local match, gates = nil, nil
	local visible = true

	local function setCopy(i, entry)
		local tile = Board.tiles[i]
		local language = if translate("Kickoff") == "Kickoff" then 1 else 2
		local owner = if match then match.clubs[i].owner else 0
		local name = names[tile.code][language]
		local price = if tile.price == 0 then "" else tostring(if owner ~= 0 then gates[i] else tile.price)
		if entry.name ~= name then
			entry.name = name
			setLayout(entry,entry.compact == true)
		end
		entry.cost.Text, entry.nativeCost.Text = price, price
		entry.owner.Visible = owner ~= 0
		if owner ~= 0 then
			for seatIndex, seat in match.seats do
				if seat.id == owner then entry.owner.BackgroundColor3 = Art.seatColors[seatIndex] break end
			end
		end
	end
	local function refresh()
		for i, entry in sheets do setCopy(i, entry) end
	end
	local function attach(part: Instance)
		if not part:IsA("BasePart") then return end
		local i = part:GetAttribute("BoardIndex")
		if typeof(i) ~= "number" or sheets[i] then return end
		local tile = Board.tiles[i]
		local buyable = tile.price > 0
		local sheet = Instance.new("SurfaceGui")
		sheet.Face, sheet.Adornee, sheet.Name = Enum.NormalId.Back, part, "Cell"..i
		sheet.AutoLocalize, sheet.Active, sheet.AlwaysOnTop, sheet.LightInfluence = false, false, false, 0
		sheet.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		-- Sharp high-definition canvas size (44 pixels per stud, 2x original)
		sheet.CanvasSize = Vector2.new(math.round(part.Size.X * 44), math.round(part.Size.Y * 44))
		sheet.MaxDistance, sheet.Enabled, sheet.Parent = 12000, visible, group
		local card = UI.box(sheet, "Printed programme", style.ink(tile))
		card.Size, card.ClipsDescendants = UDim2.fromScale(1,1), true
		local poster = illustrate(card,tile)
		poster.Size = UDim2.fromScale(1, if buyable then .45 else .55)
		local color = style.title
		local title = band(card, "Club name", if buyable then .45 else .55, if buyable then .32 else .40, style.clubFace, color)
		local cost = band(card, "Club cost", .775, .21, style.amountFace, style.price)
		cost.Visible = buyable
		local rules = {}
		if buyable then
			for _, x in {.105,.685} do
				local rule = UI.box(card, "Price rule", style.price)
				rule.Position, rule.Size = UDim2.fromScale(x,.88), UDim2.fromScale(.21,.015)
				rule.BackgroundTransparency = .62
				table.insert(rules,rule)
			end
		end
		local mark = UI.box(card, "Owner", Art.gold)
		mark.Position, mark.Size = UDim2.fromScale(0,.44), UDim2.fromScale(.026,.56)
		local frame = UI.box(overlay, sheet.Name)
		frame.Size, frame.Interactable = UDim2.fromScale(1,1), false
		local function display(source: GuiObject): GuiObject
			local copy = source:Clone()
			copy.Visible, copy.Parent = false, frame
			return copy
		end
		local nativeTitle, nativeCost = display(title), display(cost)
		local layers = {{print=poster, native=display(poster)}, {print=title, native=nativeTitle}}
		if buyable then table.insert(layers, {print=cost, native=nativeCost}) end
		local entry = {part=part, surface=sheet, title=title, cost=cost, nativeTitle=nativeTitle,
			nativeCost=nativeCost, owner=mark, layers=layers, poster=poster, rules=rules, buyable=buyable, compact=nil}
		sheets[i] = entry
		setCopy(i, entry)
	end
	task.spawn(function()
		local board = workspace:WaitForChild("WorldDraftArena"):WaitForChild("Board")
		board.DescendantAdded:Connect(attach)
		for _, part in board:GetDescendants() do attach(part) end
	end)
	return {
		update=function(data)
			match, gates = data.match, data.gates
			refresh()
		end,
		translate=refresh,
		layout=function(camera: Camera, masks: {Rect}, compact: boolean)
			for _, entry in sheets do
				if entry.compact ~= compact then
					setLayout(entry,compact)
				end
				for _, layer in entry.layers do
					local target = projectBand(camera, entry.part, layer.print)
					local glyph = layer.native
					glyph.Position = UDim2.fromOffset(target.Min.X,target.Min.Y)
					glyph.Size = UDim2.fromOffset(target.Width,target.Height)
					local painted = target
					if glyph:IsA("TextLabel") and glyph.TextBounds.X > 0 then
						local centre = (target.Min + target.Max) * .5
						local extent = glyph.TextBounds * .5 + Vector2.one
						painted = Rect.new(centre - extent, centre + extent)
					end
					local exposed = true
					for _, mask in masks do
						if intersects(painted,mask) then exposed = false break end
					end
					-- The printed copy sits on the tile behind a passing player.
					glyph.Visible, layer.print.Visible = exposed, not exposed
				end
			end
		end,
		markTurn=function(point: Vector3?)
			arrow.Visible = point ~= nil
			if point then arrow.Position = UDim2.fromOffset(math.round(point.X),math.round(point.Y)-3) end
		end,
		show=function(on: boolean)
			visible, overlay.Enabled = on, on
			for _,entry in sheets do entry.surface.Enabled = on end
		end,
	}
end
