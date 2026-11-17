--!strict
local shared = game:GetService("ReplicatedStorage"):WaitForChild("League")
local Board = require(shared.TourBoard)
local Art = require(shared.Presentation)
local illustrate = require(script.Parent.Programme)
local UI = require(script.Parent.Components)
local style = require(script.Parent.ProgrammeStyle)
local headline = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold)
local numberFace = Font.new("rbxasset://fonts/families/BuilderMono.json", Enum.FontWeight.SemiBold)
local terraceFace = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
local names = {
	SEV={"Sevilla","Севилья"}, ATM={"Atlético","Атлетико"}, FCB={"Barça","Барса"}, RMA={"Real Madrid","Реал"},
	ARS={"Arsenal","Арсенал"}, LIV={"Liverpool","Ливерпуль"}, MCI={"Man City","Ман Сити"}, MUN={"Man Utd","МЮ"},
	ACM={"Milan","Милан"}, INT={"Inter","Интер"}, JUV={"Juve","Юве"}, NAP={"Napoli","Наполи"},
	B04={"Bayer","Байер"}, RBL={"Leipzig","Лейпциг"}, BVB={"Dortmund","Дортмунд"}, BAY={"Bayern","Бавария"},
	OL={"Lyon","Лион"}, OM={"Marseille","Марсель"}, ASM={"Monaco","Монако"}, PSG={"Paris SG","ПСЖ"},
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

-- The paper also carries the type in focus view or behind a figure.
-- Use comparable printed type sizes across the shallow and deep tiles.
local function setLayout(entry, compact: boolean)
	local artHeight = if entry.buyable then .45 else .55
	local nameHeight = if entry.buyable then .32 else .40
	local priceY, priceHeight = .775,.21
	local name = entry.name
	if compact and entry.buyable then
		priceHeight = (if entry.landscape then 6.35 else 5.7) / entry.part.Size.Y
		nameHeight = (if entry.landscape then 5.4 else 5.35) / entry.part.Size.Y
		priceY = .99 - priceHeight
		artHeight = priceY - nameHeight - .012
	end
	local inset = if compact then .012 else .035
	-- External captions free the face for the stadium art and the printed fallback.
	local rail = compact and not entry.corner
	entry.poster.Size = UDim2.fromScale(1, if rail then 1 else artHeight)
	entry.title.Position, entry.title.Size = UDim2.fromScale(inset,artHeight), UDim2.fromScale(1-2*inset,nameHeight)
	entry.cost.Position, entry.cost.Size = UDim2.fromScale(inset,priceY), UDim2.fromScale(1-2*inset,priceHeight)
	entry.owner.Position, entry.owner.Size = UDim2.fromScale(0,artHeight), UDim2.fromScale(.026,1-artHeight)
	entry.title.FontFace = if compact then terraceFace else headline
	entry.nativeTitle.FontFace = entry.title.FontFace
	entry.title.Text, entry.nativeTitle.Text = name, name
	entry.title.BackgroundTransparency = if rail then 0 else 1
	entry.cost.BackgroundTransparency = if rail then 0 else 1
	entry.keyline.Enabled = rail
	entry.amountLine.Enabled = rail
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

-- Neighbouring north and south captions alternate rows. Their maximum width
-- leaves a clear path for the adjacent tile's vertical leader.
local function compactBands(entry, face: Rect, viewport: Vector2): (Rect, Rect?, Rect?)
	local height = math.clamp(math.round(math.min(viewport.X,viewport.Y)*.049),17,23)
	local priceHeight = math.round(height*.94)
	local amountWidth = math.ceil(priceHeight*1.95)
	local titleWidth = math.clamp(math.round(height*(.55*(utf8.len(entry.name) or #entry.name)+.55)),32,math.round(height*4.6))
	if entry.horizontal then
		local width = math.min(math.floor(face.Width*2-2),titleWidth)
		local x = math.round((face.Min.X+face.Max.X-width)*.5)
		local anchor = if entry.north then face.Min.Y else face.Max.Y
		local gap = 3 + (entry.index%2)*(height+2)
		local y = if entry.north then anchor-gap-height else anchor+gap
		local tip = if entry.north then y+height else y
		local mid = math.floor((face.Min.X+face.Max.X)*.5)
		local line = Rect.new(mid-1,math.min(anchor,tip),mid+1,math.max(anchor,tip))
		-- The pawn track is on the pitch-facing edge. Put each price against the rim.
		local priceY = if entry.north then face.Min.Y else face.Max.Y-priceHeight
		return Rect.new(x,y,x+width,y+height),Rect.new(face.Min.X,priceY,face.Max.X,priceY+priceHeight),line
	end

	-- Hang the name from the outside of the illustrated tile. Its natural width
	-- leaves short names on the rim. The small price badge sits at the opposite
	-- end, so the centre of the stadium print remains visible between them.
	local rimInset = if entry.landscape then 5 else titleWidth-6
	local x = if entry.east then face.Max.X+rimInset-titleWidth else face.Min.X-rimInset
	x = math.clamp(x,2,math.max(2,viewport.X-titleWidth-2))
	local y = math.round((face.Min.Y+face.Max.Y-height)*.5)
	local title = Rect.new(x,y,x+titleWidth,y+height)
	local priceX = if entry.east then math.min(face.Min.X+5,x-3)-amountWidth else math.max(face.Max.X-5,title.Max.X+3)
	local priceY = math.round((face.Min.Y+face.Max.Y-priceHeight)*.5)
	return title,Rect.new(priceX,priceY,priceX+amountWidth,priceY+priceHeight),nil
end

-- Keep a side ticket in the same row when a walking or parked pawn crosses
-- its normal position. Only occupied rows move, and each stays on its own side.
local function clearSideBand(bandRect: Rect, masks: {Rect}, east: boolean, viewport: Vector2, neighbour: Rect?): Rect
	local lo = if east then math.ceil(viewport.X*.5)+2 else 2
	local hi = (if east then viewport.X-2 else math.floor(viewport.X*.5)-2)-bandRect.Width
	if hi < lo then return bandRect end
	local candidates = {bandRect.Min.X}
	local function edges(mask: Rect)
		if bandRect.Min.Y < mask.Max.Y and bandRect.Max.Y > mask.Min.Y then
			table.insert(candidates,mask.Min.X-bandRect.Width-3)
			table.insert(candidates,mask.Max.X+3)
		end
	end
	for _, mask in masks do edges(mask) end
	if neighbour then edges(neighbour) end
	local best, distance = bandRect, math.huge
	for _, edge in candidates do
		local x = math.clamp(math.round(edge),lo,hi)
		local travel = math.abs(x-bandRect.Min.X)
		if travel >= distance then continue end
		local candidate = Rect.new(x,bandRect.Min.Y,x+bandRect.Width,bandRect.Max.Y)
		if neighbour and intersects(candidate,neighbour) then continue end
		local clear = true
		for _, mask in masks do
			if intersects(candidate,mask) then clear = false break end
		end
		if clear then
			best, distance = candidate, travel
			if travel == 0 then break end
		end
	end
	return best
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
		sheet.CanvasSize = Vector2.new(math.round(part.Size.X*22), math.round(part.Size.Y*22))
		sheet.MaxDistance, sheet.Enabled, sheet.Parent = 12000, visible, group
		local card = UI.box(sheet, "Printed programme", style.ink(tile))
		card.Size, card.ClipsDescendants = UDim2.fromScale(1,1), true
		local poster = illustrate(card,tile)
		poster.Size = UDim2.fromScale(1, if buyable then .45 else .55)
		local color = style.title
		local title = band(card, "Club name", if buyable then .45 else .55, if buyable then .32 else .40, headline, color)
		local cost = band(card, "Club cost", .775, .21, numberFace, style.price)
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
		local slot = (i-1)%8
		local edge = math.floor((i-1)/8)
		local horizontal = slot > 0 and (edge == 1 or edge == 3)
		local accent = Art.accent(tile.kind,tile.league)
		local leader = UI.box(frame, "Caption leader", accent)
		leader.Visible, nativeTitle.ZIndex = false, 3
		nativeTitle.BorderSizePixel, nativeTitle.BackgroundColor3 = 0, card.BackgroundColor3
		title.BackgroundColor3, title.ZIndex = card.BackgroundColor3, 3
		cost.BackgroundColor3, cost.ZIndex, nativeCost.ZIndex = card.BackgroundColor3, 3, 3
		UI.round(nativeTitle,4)
		UI.round(nativeCost,4)
		local keyline = UI.stroke(nativeTitle,accent)
		keyline.Transparency = .5
		local amountLine = UI.stroke(nativeCost,style.price)
		amountLine.Transparency = .67
		local cap = Instance.new("UITextSizeConstraint")
		cap.MaxTextSize, cap.Parent = 100, nativeTitle
		local layers = {{print=poster, native=display(poster)}, {print=title, native=nativeTitle}}
		if buyable then table.insert(layers, {print=cost, native=nativeCost}) end
		local entry = {part=part, surface=sheet, title=title, cost=cost, nativeTitle=nativeTitle,
			nativeCost=nativeCost, owner=mark, layers=layers, poster=poster, rules=rules, buyable=buyable, compact=nil,
			index=i, horizontal=horizontal, north=edge==1, east=edge==0, corner=slot==0, cap=cap, leader=leader, keyline=keyline, amountLine=amountLine}
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
				local landscape = compact and camera.ViewportSize.X > camera.ViewportSize.Y
				if entry.compact ~= compact or entry.landscape ~= landscape then
					entry.landscape = landscape
					setLayout(entry,compact)
				end
				local face = if compact and not entry.corner then projectBand(camera,entry.part,entry.poster.Parent) else nil
				local caption, priceTag, line
				if face then
					caption, priceTag, line = compactBands(entry,face,camera.ViewportSize)
					if not entry.horizontal and #masks>0 then
						caption = clearSideBand(caption,masks,entry.east,camera.ViewportSize,nil)
						if priceTag and entry.buyable then
							priceTag = clearSideBand(priceTag,masks,entry.east,camera.ViewportSize,caption)
						end
					end
				end
				entry.hit, entry.priceHit, entry.leader.Visible = nil, nil, false
				for _, layer in entry.layers do
					local target = projectBand(camera, entry.part, layer.print)
					local glyph = layer.native
					local plaque = face ~= nil and glyph == entry.nativeTitle
					if plaque and caption then
						target = caption
						entry.cap.MaxTextSize = math.max(12, target.Height-1)
					elseif glyph == entry.nativeTitle then
						entry.cap.MaxTextSize = 100
					elseif glyph == entry.nativeCost then
						if priceTag then target = priceTag end
						glyph.BackgroundTransparency = if priceTag then .055 else 1
						glyph.BackgroundColor3 = entry.title.BackgroundColor3
					end
					glyph.Position = UDim2.fromOffset(target.Min.X,target.Min.Y)
					glyph.Size = UDim2.fromOffset(target.Width,target.Height)
					local painted = target
					if not face and glyph:IsA("TextLabel") and glyph.TextBounds.X > 0 then
						local centre = (target.Min + target.Max) * .5
						local extent = glyph.TextBounds * .5 + Vector2.one
						painted = Rect.new(centre - extent, centre + extent)
					end
					local exposed = true
					for _, mask in masks do
						if intersects(painted,mask) then exposed = false break end
					end
					if glyph == entry.nativeTitle then
						glyph.BackgroundTransparency = if plaque then .045 else 1
					end
					if plaque and exposed then
						entry.hit = target
						if line then
							entry.leader.Position = UDim2.fromOffset(line.Min.X,line.Min.Y)
							entry.leader.Size = UDim2.fromOffset(line.Width,line.Height)
							entry.leader.Visible = true
							for _, mask in masks do
								if intersects(line,mask) then entry.leader.Visible = false break end
							end
						end
					elseif exposed and glyph == entry.nativeCost and priceTag then
						entry.priceHit = target
					end
					glyph.Visible, layer.print.Visible = exposed, not exposed
				end
			end
		end,
		markTurn=function(point: Vector3?)
			arrow.Visible = point ~= nil
			if point then arrow.Position = UDim2.fromOffset(math.round(point.X),math.round(point.Y)-3) end
		end,
		pickCaption=function(point: Vector3): number?
			local camera = workspace.CurrentCamera
			if not visible or not camera then return nil end
			local ray = camera:ScreenPointToRay(point.X,point.Y)
			local p = camera:WorldToViewportPoint(ray.Origin+ray.Direction*100)
			for index, entry in sheets do
				for _, hit in {entry.hit,entry.priceHit} do
					if p.X>=hit.Min.X and p.X<hit.Max.X and p.Y>=hit.Min.Y and p.Y<hit.Max.Y then
						return index
					end
				end
			end
			return nil
		end,
		show=function(on: boolean)
			visible, overlay.Enabled = on, on
			for _,entry in sheets do entry.surface.Enabled = on end
		end,
	}
end
