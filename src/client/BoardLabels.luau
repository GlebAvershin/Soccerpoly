--!strict
local TextService = game:GetService("TextService")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("League")
local Board = require(shared.TourBoard)
local Geometry = require(shared.Geometry)
local Art = require(shared.Presentation)
local UI = require(script.Parent.Components)

-- Match-programme names, in screen reading order on all four sides of the pitch.
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
local widthCache: {[string]: number} = {}
local function textWidth(title: string, size: number, font: Enum.Font): number
	local key = title .. "/" .. size .. "/" .. font.Name
	if not widthCache[key] then
		widthCache[key] = TextService:GetTextSize(title, size, font, Vector2.new(4096, 256)).X
	end
	return widthCache[key]
end

local function label(parent: Instance, name: string, color: Color3, font: Enum.Font): TextLabel
	local node = Instance.new("TextLabel")
	node.Name, node.Font, node.TextColor3 = name, font, color
	node.AnchorPoint = Vector2.one * .5
	node.BackgroundTransparency, node.BorderSizePixel = 1, 0
	node.TextWrapped, node.TextScaled, node.Text = false, false, ""
	node.Parent = parent
	return node
end

-- Intersection of a scanline with the projected tile. Intersect the intervals at
-- BOTH ends of the line box so every corner of the glyph box stays on its own tile.
local function interval(poly: {Vector2}, y: number): (number, number)
	local left, right = math.huge, -math.huge
	for i, a in poly do
		local b = poly[i % 4 + 1]
		if math.abs(b.Y - a.Y) < .001 or y < math.min(a.Y, b.Y) or y > math.max(a.Y, b.Y) then continue end
		local x = a.X + (b.X - a.X) * (y - a.Y) / (b.Y - a.Y)
		left, right = math.min(left, x), math.max(right, x)
	end
	return left, right
end

local function slot(poly: {Vector2}, y: number, height: number, masks: {Rect}): (number, number)
	local l1, r1 = interval(poly, y - height * .5)
	local l2, r2 = interval(poly, y + height * .5)
	local left, right = math.ceil(math.max(l1, l2) + 1), math.floor(math.min(r1, r2) - 1)
	if right <= left then return 0, 0 end
	local free = {Vector2.new(left, right)}
	for _, rect in masks do
		if y + height * .5 <= rect.Min.Y or y - height * .5 >= rect.Max.Y
			or right <= rect.Min.X or left >= rect.Max.X then continue end
		local split = {}
		for _, span in free do
			if span.X < rect.Min.X then table.insert(split, Vector2.new(span.X, math.min(rect.Min.X, span.Y))) end
			if span.Y > rect.Max.X then table.insert(split, Vector2.new(math.max(rect.Max.X, span.X), span.Y)) end
		end
		free = split
	end
	local best = Vector2.zero
	for _, span in free do
		if span.Y-span.X > best.Y-best.X then best=span end
	end
	return (best.X+best.Y)*.5, best.Y-best.X
end

return function(root: Frame, translate: (string) -> string)
	local layer = UI.box(root, "BoardPrint")
	layer.Size, layer.Interactable, layer.ClipsDescendants = UDim2.fromScale(1, 1), false, true
	local prints = {}
	for i, cell in Geometry.cells do
		local tile = Board.tiles[i]
		local frame = UI.box(layer, "Cell" .. i)
		frame.Size = UDim2.fromScale(1, 1)
		local pose = CFrame.new(cell.X, Art.tileTop + .12, cell.Z) * CFrame.Angles(0, Geometry.tileYaw(i), 0)
		local dims = Geometry.tileSize(i) * .5 - Vector2.one * .54
		local bounds = {}
		for _, uv in {Vector2.new(-1,-1), Vector2.new(1,-1), Vector2.new(1,1), Vector2.new(-1,1)} do
			table.insert(bounds, pose * Vector3.new(uv.X*dims.X, 0, uv.Y*dims.Y))
		end
		local isClub = tile.league > 0
		local title = label(frame, "Club name", if isClub then Art.paper else Art.printInk, Enum.Font.BuilderSansBold)
		local cost = label(frame, "Club cost", if isClub then Color3.fromHex("C8DCD9") else Art.printInk, Enum.Font.BuilderSansMedium)
		local owner = UI.box(frame, "Ownership mark", Art.paper, 2)
		owner.AnchorPoint, owner.Visible = Vector2.one * .5, false
		prints[i] = {name=title, value=cost, mark=owner, corners=bounds, owned=false, title="", code=tile.code,
			at=pose * Vector3.new(0, 0, if isClub then 0 else dims.Y * .42)}
	end
	local landmarks: {[number]: {Vector3}} = {}
	task.spawn(function()
		local stage = workspace:WaitForChild("WorldDraftArena")
		for _, part in stage:WaitForChild("Board"):GetDescendants() do
			if not part:IsA("BasePart") then continue end
			local pose, size = part:GetAttribute("LandmarkPose"), part:GetAttribute("LandmarkSize")
			if typeof(pose) ~= "CFrame" or typeof(size) ~= "Vector3" then continue end
			local corners = {}
			for _, x in {-1,1} do
				for _, y in {-1,1} do
					for _, z in {-1,1} do
						table.insert(corners, pose * (size * Vector3.new(x,y,z) * .5))
					end
				end
			end
			landmarks[part:GetAttribute("BoardIndex")] = corners
		end
	end)
	local russian = false
	local function refreshLanguage()
		russian = translate("Kickoff") ~= "Kickoff"
		for i, entry in prints do
			local tile = Board.tiles[i]
			entry.title = names[tile.code][if russian then 2 else 1]
			entry.name.Text = entry.title
		end
	end
	refreshLanguage()
	local function project(camera: Camera, portrait: boolean, focused: boolean, masks: {Rect})
		local hud = root:FindFirstChild("Scoreboard") :: GuiObject?
		local hudAt = if hud and hud.Visible then hud.AbsolutePosition-root.AbsolutePosition else Vector2.zero
		local hudEnd = if hud and hud.Visible then hudAt+hud.AbsoluteSize else Vector2.zero
		local function clear(x: number, y: number, w: number, h: number): boolean
			return x-w*.5 >= 0 and x+w*.5 <= root.AbsoluteSize.X and y-h*.5 >= 0 and y+h*.5 <= root.AbsoluteSize.Y
				and (x+w*.5 < hudAt.X or x-w*.5 > hudEnd.X or y-h*.5 > hudEnd.Y)
		end
		for i, entry in prints do
			local poly = {}
			local ymin, ymax = math.huge, -math.huge
			for _, point in entry.corners do
				local p = camera:WorldToScreenPoint(point)
				table.insert(poly, Vector2.new(p.X,p.Y))
				ymin, ymax = math.min(ymin,p.Y), math.max(ymax,p.Y)
			end
			local prop = landmarks[i]
			if prop then
				local lo, hi = Vector2.one*math.huge, Vector2.one*-math.huge
				for _, corner in prop do
					local p = camera:WorldToScreenPoint(corner)
					local xy = Vector2.new(p.X,p.Y)
					lo, hi = lo:Min(xy), hi:Max(xy)
				end
				table.insert(masks,Rect.new(lo,hi))
			end
			local mid = camera:WorldToScreenPoint(entry.at)
			local height = ymax-ymin
			local size = math.clamp(math.floor(height * .265), 10, if focused then 18 else 16)
			local two = Board.tiles[i].price > 0 and height >= (if portrait then 41 else 44)
			local valueSize = math.clamp(math.floor(size*.83), 9, 13)
			local titleY = math.round(mid.Y - (if two then valueSize*.45+1 else 0))
			local x, w = slot(poly,titleY,size+2,masks)
			local title = entry.title
			if w < textWidth(title, size, entry.name.Font) then
				-- Pan vertically inside this tile before using its shortened name.
				for _, delta in {.16, -.16, .26, -.26} do
					local candidate = math.round(mid.Y+height*delta)
					local nx,nw = slot(poly,candidate,size+2,masks)
					if nw > w + 3 then x,w,titleY=nx,nw,candidate end
				end
			end
			while size > 11 and textWidth(title,size,entry.name.Font)+2 > w do
				size -= 1
				x,w = slot(poly,titleY,size+2,masks)
			end
			if textWidth(title,size,entry.name.Font)+2 > w then
				title = if entry.code == "RMA" and not russian then "Real" else entry.code
			end
			while size > 8 and textWidth(title,size,entry.name.Font)+2 > w do
				size -= 1
				x,w = slot(poly,titleY,size+2,masks)
			end
			local wantedWidth = textWidth(title,size,entry.name.Font) + 2
			local fits = wantedWidth <= w
			if fits then
				x = math.clamp(mid.X, x-(w-wantedWidth)*.5, x+(w-wantedWidth)*.5)
				w = wantedWidth
			end
			entry.name.Text, entry.name.TextSize = title, size
			entry.name.Position = UDim2.fromOffset(x,titleY)
			entry.name.Size = UDim2.fromOffset(math.max(1,w),size+2)
			entry.name.Visible = fits and clear(x,titleY,w,size+2)
			local vy = titleY + math.ceil((size+valueSize)*.5) + 3
			local vx, vw = slot(poly,vy,valueSize+2,masks)
			local costWidth = textWidth(entry.value.Text,valueSize,entry.value.Font) + 2
			if vw >= costWidth then
				vx = math.clamp(x, vx-vw*.5+costWidth*.5, vx+vw*.5-costWidth*.5)
				vw = costWidth
			end
			entry.value.TextSize, entry.value.Position = valueSize, UDim2.fromOffset(vx,vy)
			entry.value.Size = UDim2.fromOffset(vw,valueSize+2)
			entry.value.Visible = entry.name.Visible and two and textWidth(entry.value.Text,valueSize,entry.value.Font)+2 <= vw
				and clear(vx,vy,vw,valueSize+2)
			local my = titleY - size*.5 - 3
			local mx, mw = slot(poly,my,2,masks)
			entry.mark.Position, entry.mark.Size = UDim2.fromOffset(mx,my), UDim2.fromOffset(math.min(mw,13),2)
			entry.mark.Visible = entry.owned and entry.name.Visible and mw > 4 and clear(mx,my,math.min(mw,13),2)
			if prop then table.remove(masks) end
		end
	end
	local function update(data: any)
		local match = data.match
		for i, entry in prints do
			local tile = Board.tiles[i]
			local owner = if match then match.clubs[i].owner else 0
			entry.owned = owner ~= 0
			entry.value.Text = if tile.price > 0 then tostring(if entry.owned then data.gates[i] else tile.price) else ""
			if entry.owned then
				for j, seat in match.seats do
					if seat.id == owner then entry.mark.BackgroundColor3 = Art.seatColors[j] break end
				end
			end
		end
	end
	update({})
	return {translate=refreshLanguage, update=update, project=project, show=function(visible: boolean) layer.Visible=visible end}
end
