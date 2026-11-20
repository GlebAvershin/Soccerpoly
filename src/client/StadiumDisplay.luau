--!strict
local shared = game:GetService("ReplicatedStorage"):WaitForChild("League")
local Board = require(shared.TourBoard)
local Art = require(shared.Presentation)
local UI = require(script.Parent.Components)
local Print = require(script.Parent.MatchPrint)
local cupPrint = require(script.Parent.CupPrint)
local colors = UI.color

local phases = {
	move = "Roll dice", offer = "Club contract", rebuy = "Buyout", auction = "TRANSFER AUCTION",
	upgrade = "Stadium upgrade", matchday = "Matchday", bench = "On the bench", tour = "Away tour",
	championship = "Host championship", shield = "Club shield", debt = "Settlement",
}
local propertyCount = 0
for _, tile in Board.tiles do
	if tile.price > 0 then propertyCount += 1 end
end

return function(gui: SurfaceGui, translate: (string, ...any)->string)
	local root = UI.box(gui, "DisplayRoot", colors.panel)
	root.Size = UDim2.fromScale(1,1)
	local poster = UI.box(root, "Cup cover", colors.surface)
	poster.Size = UDim2.fromScale(.28,1)
	local icon = Print.mark(poster,"cup",colors.gold,114)
	icon.Position, icon.AnchorPoint = UDim2.fromScale(.5,.5), Vector2.new(.5,.5)
	if cupPrint(poster) then icon.Visible = false end
	local panel = UI.box(root, "Match report", colors.paper)
	panel.Position, panel.Size = UDim2.fromScale(.28,0), UDim2.fromScale(.72,1)
	local function line(parent: Instance, name: string, y: number, height: number, color: Color3, font: Enum.Font)
		local label = UI.label(parent,"",height,{name=name,font=font,color=color,ellipsis=true})
		label.Position, label.Size = UDim2.fromOffset(19,y), UDim2.new(1,-38,0,height)
		label.TextScaled = true
		return label
	end
	local imprint = line(panel,"Competition",10,19,colors.surface,Enum.Font.RobotoMono)
	imprint.Text = "SOCCERPOLY  /  CONTINENTAL CUP"
	local headerRule = UI.box(panel,"Running head",colors.outline)
	headerRule.Position, headerRule.Size = UDim2.fromOffset(19,39), UDim2.new(1,-38,0,2)
	local headline = line(panel,"PhaseLabel",48,56,colors.ink,Enum.Font.BuilderSansExtraBold)
	headline.FontFace = Print.display
	local subject = line(panel,"SubLabel",110,44,colors.panel,Enum.Font.BuilderSansBold)
	local footer = UI.box(panel,"Score rail",colors.panel)
	footer.Position, footer.Size = UDim2.fromOffset(0,173), UDim2.new(1,0,1,-173)
	local accent = UI.box(footer,"Seat colour",colors.gold)
	accent.Size = UDim2.new(0,7,1,0)
	local leader = line(footer,"LeaderStat",5,24,colors.text,Enum.Font.BuilderSansBold)
	local standings = line(footer,"ArenaStat",33,19,colors.muted,Enum.Font.RobotoMono)
	local function name(seat): string
		return if seat.bot then translate(seat.name) else seat.name
	end

	return function(snapshot: any)
		local s = snapshot and snapshot.match
		if not s then
			headline.Text = translate("Choose your figure")
			subject.Text = translate(Board.formats[if snapshot then snapshot.format else 1].label)
			leader.Text = translate("Starting balance · %d CR", Board.startCash)
			standings.Text = translate("%d properties",propertyCount)
			accent.BackgroundColor3 = colors.gold
			return
		end
		local signed = 0
		for _, club in s.clubs do if club.owner ~= 0 then signed += 1 end end
		standings.Text = translate("Properties signed · %d/%d",signed,propertyCount)
		if s.phase == "final" then
			local winners = {}
			local value = s.standings[1].score
			for _, standing in s.standings do
				if standing.score ~= value or (s.winner and standing.id ~= s.winner) then break end
				for _, seat in s.seats do
					if seat.id == standing.id then table.insert(winners, name(seat)); break end
				end
			end
			headline.Text = translate(if #winners > 1 then "League champions" else "Season champion")
			subject.Text = table.concat(winners,"  /  ")
			leader.Text = translate("%d CR value",value)
			accent.BackgroundColor3 = colors.gold
		else
			local seat = s.seats[s.active]
			headline.Text = translate(phases[s.phase] or "Match")
			subject.Text = name(seat)
			local topCash = -math.huge
			local richest = {}
			for _, person in s.seats do
				if person.bankrupt then continue end
				if person.cash > topCash then topCash = person.cash; table.clear(richest) end
				if person.cash == topCash then table.insert(richest,name(person)) end
			end
			leader.Text = if #richest == 1 then translate("Cash lead · %s · %d CR",richest[1],topCash)
				elseif #richest > 1 then translate("Shared cash lead · %d CR",topCash) else ""
			accent.BackgroundColor3 = Art.seatColors[s.active]
		end
	end
end
