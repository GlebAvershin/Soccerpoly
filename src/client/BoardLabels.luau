--!strict
local shared = game:GetService("ReplicatedStorage"):WaitForChild("League")
local Board = require(shared.TourBoard)
local Art = require(shared.Presentation)
local illustrate = require(script.Parent.Programme)
local UI = require(script.Parent.Components)
local typePlate = require(script.Parent.ProgrammeType)
local decode = require(script.Parent.IndexedImage)
local function inkPlate(paint)
	local ok, image=pcall(decode,paint)
	return if ok and image then Content.fromObject(image) else nil
end
local plates={inkPlate(typePlate.page1),inkPlate(typePlate.page2)}
local digits=inkPlate(typePlate.digits)
local function impression(parent, texture, position, size)
	local label=Instance.new("ImageLabel")
	label.Name,label.BackgroundTransparency,label.ImageContent="Ink",1,texture
	label.Position,label.Size,label.Parent=position,size,parent
	return label
end
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
local function line(card: Frame, name: string, y: number, height: number, font: Enum.Font, color: Color3): TextLabel
	local text = Instance.new("TextLabel")
	text.Name, text.AutoLocalize, text.BackgroundTransparency = name, false, 1
	text.Font, text.TextColor3, text.TextScaled, text.TextWrapped = font, color, true, false
	text.Size, text.Position = UDim2.fromScale(.94,height), UDim2.fromScale(.03,y)
	text.Text, text.Parent = "", card
	return text
end

-- This line always has the same centre on the paper. The physical ink stays
-- visible under pieces. Exposed lines can be typeset at native display density.
local function nativeLine(parent,original)
	local label=original:Clone()
	label:ClearAllChildren()
	label.TextTransparency,label.AnchorPoint,label.Visible=0,Vector2.new(.5,.5),false
	label.TextScaled,label.Parent=true,parent
	return label
end

return function(root: Frame, translate: (string)->string)
	local group = Instance.new("Folder")
	group.Name, group.Parent = "BoardPrint",root:FindFirstAncestorOfClass("ScreenGui").Parent
	local overlay=UI.box(root,"Programme typography")
	overlay.Size,overlay.Interactable=UDim2.fromScale(1,1),false
	local sheets = {}
	local match: any = nil
	local gates: any = nil
	local visible = true
	local function refresh()
		local language = if translate("Kickoff")=="Kickoff" then 1 else 2
		for index, entry in sheets do
			local tile = Board.tiles[index]
			entry.title.Text = names[tile.code][language]
			entry.nameText.Text=entry.title.Text
			if entry.ink then
				entry.ink.ImageRectOffset = Vector2.new((language-1)*256, (typePlate.rows[tile.code]%16)*64)
			end
			local owner = if match then match.clubs[index].owner else 0
			entry.cost.Text = if tile.price>0 then tostring(if owner~=0 then gates[index] else tile.price) else ""
			entry.costText.Text=entry.cost.Text
			if entry.numerals then
				local value=entry.cost.Text
				local width=entry.glyphWidth
				for k,glyph in entry.numerals do
					glyph.Visible=k<=#value
					if k<=#value then
						glyph.ImageRectOffset=Vector2.new(32*tonumber(value:sub(k,k)),0)
						glyph.Position=UDim2.fromScale(.5+(k-1-#value*.5)*width,0)
					end
				end
			end
			entry.mark.Visible = owner~=0
			if owner~=0 then
				for j,seat in match.seats do
					if seat.id==owner then entry.mark.BackgroundColor3=Art.seatColors[j] break end
				end
			end
		end
	end
	local function attach(part: Instance)
		if not part:IsA("BasePart") then return end
		local i = part:GetAttribute("BoardIndex")
		if typeof(i)~="number" or sheets[i] then return end
		local tile = Board.tiles[i]
		local sheet = Instance.new("SurfaceGui")
		sheet.Face, sheet.Adornee, sheet.Name = Enum.NormalId.Back,part,"Cell"..i
		sheet.AutoLocalize, sheet.Active, sheet.AlwaysOnTop, sheet.LightInfluence = false,false,false,0
		sheet.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		sheet.CanvasSize = Vector2.new(math.round(part.Size.X*9),math.round(part.Size.Y*9))
		sheet.MaxDistance, sheet.Enabled, sheet.Parent = 12000,visible,group
		local card = UI.box(sheet,"Printed programme", Color3.fromHex(if tile.price>0 then "FAF1DD" else "213542"))
		card.Size, card.ClipsDescendants = UDim2.fromScale(1,1),true
		local poster = illustrate(card,tile)
		local ink = Color3.fromHex(if tile.price>0 then "172D39" else "FFF0CA")
		local buyable=tile.price>0
		poster.Size = UDim2.fromScale(1, if buyable then .40 else .55)
		local title = line(card,"Club name",if buyable then .405 else .56,if buyable then .37 else .41,Enum.Font.BuilderSansExtraBold,ink)
		local cost = line(card,"Club cost",.79,.20,Enum.Font.BuilderSansBold,ink)
		cost.Visible=buyable
		local mark=UI.box(card,"Owner",Art.gold)
		mark.Position,mark.Size=UDim2.fromScale(0,.49),UDim2.fromScale(.027,.51)
		local row = typePlate.rows[tile.code]
		local plate=plates[math.floor(row/16)+1]
		local inkPrint
		if plate then
			inkPrint=impression(title,plate,UDim2.fromScale(0,0),UDim2.fromScale(1,1))
			inkPrint.ImageRectSize=Vector2.new(256,64)
			title.TextTransparency=1
		end
		local numerals
		local glyphWidth = .5 * cost.Size.Y.Scale*sheet.CanvasSize.Y / (cost.Size.X.Scale*sheet.CanvasSize.X)
		if buyable and digits then
			numerals={}
			for k=1,6 do
				local unit=impression(cost,digits,UDim2.fromScale(0,0),UDim2.fromScale(glyphWidth,1))
				unit.ImageRectSize=Vector2.new(32,64)
				numerals[k]=unit
			end
			cost.TextTransparency=1
		end
		local native=UI.box(overlay,"Cell"..i)
		native.Size=UDim2.fromScale(1,1)
		local nameText,costText=nativeLine(native,title),nativeLine(native,cost)
		sheets[i]={part=part,nameText=nameText,costText=costText,surface=sheet,title=title,cost=cost,mark=mark,ink=inkPrint,numerals=numerals,glyphWidth=glyphWidth}
		refresh()
	end
	task.spawn(function()
		local board=workspace:WaitForChild("WorldDraftArena"):WaitForChild("Board")
		board.DescendantAdded:Connect(attach)
		for _,part in board:GetDescendants() do attach(part) end
	end)
	return {
		update=function(data: any) match,gates=data.match,data.gates refresh() end,
		translate=refresh,
		layout=function(camera: Camera, masks: {Rect})
			for i,entry in sheets do
				local part=entry.part
				local center=camera:WorldToScreenPoint(part.Position)
				local across=camera:WorldToScreenPoint(part.Position+part.CFrame.RightVector*part.Size.X)
				local down=camera:WorldToScreenPoint(part.Position-part.CFrame.UpVector*part.Size.Y)
				local dx,dy=across.X-center.X,across.Y-center.Y
				local length=math.sqrt(dx*dx+dy*dy)
				local height=math.abs(dx*(down.Y-center.Y)-dy*(down.X-center.X))/math.max(1,length)
				local angle=math.deg(math.atan2(dy,dx))
				for _,pair in {{entry.nameText,entry.title},{entry.costText,entry.cost}} do
					local glyph,original=pair[1],pair[2]
					if glyph==entry.costText and Board.tiles[i].price==0 then continue end
					local y=original.Position.Y.Scale + original.Size.Y.Scale*.5
					local at=camera:WorldToScreenPoint(part.Position+part.CFrame.UpVector*part.Size.Y*(.5-y))
					local w,h=length*.87,height*original.Size.Y.Scale
					local x0,y0,x1,y1=at.X-w*.5,at.Y-h*.5,at.X+w*.5,at.Y+h*.5
					local exposed=x0>=0 and y0>=0 and x1<=root.AbsoluteSize.X and y1<=root.AbsoluteSize.Y
					if exposed then
						for _,rect in masks do
							if x0<rect.Max.X and x1>rect.Min.X and y0<rect.Max.Y and y1>rect.Min.Y then
								exposed=false
								break
							end
						end
					end
					glyph.Position,glyph.Size=UDim2.fromOffset(at.X,at.Y),UDim2.fromOffset(w,h)
					glyph.Rotation,glyph.Visible=angle,exposed
					original.Visible=not exposed
				end
			end
		end,
		show=function(on: boolean)
			visible=on
			overlay.Visible=on
			for _,entry in sheets do entry.surface.Enabled=on end
		end,
	}
end
