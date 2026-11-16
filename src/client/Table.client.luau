--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Localize = game:GetService("LocalizationService")
local GuiService = game:GetService("GuiService")
local Input = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("League")
local Board = require(shared.Board)
local Edition = require(shared.EventCards)
local Rules = require(shared.Rules)
local Game = Rules.withBoard(Board, Edition)
local Art = require(shared.Presentation)
local View = require(script.Parent.ViewLayout)
local ResultBanner = require(script.Parent.ResultBanner)
local Pawn = require(script.Parent.Pawn)
local Arena = require(script.Parent.Arena)
local TableAudio = require(script.Parent.TableAudio)
local UI = require(script.Parent.Components)
local copy = require(script.Parent.Copy)
local colors = UI.color
local GOLD, BOLD, BLACK = colors.gold, Enum.Font.BuilderSansBold, Enum.Font.BuilderSansExtraBold
local CENTER, RIGHT = Enum.TextXAlignment.Center, Enum.TextXAlignment.Right
local function hex(v: number): Color3 return Color3.fromHex(string.format("%06x", v)) end
local russian = string.sub(string.lower(Localize.RobloxLocaleId), 1, 2) == "ru"
local soundOn, musicOn, reducePreference = true, true, false
local function reduced(): boolean return reducePreference or GuiService.ReducedMotionEnabled end
local function t(key: string, ...: any): string return copy(key, russian, ...) end
local snapshot: any = nil
local remote: RemoteEvent? = nil

local gui = Instance.new("ScreenGui")
gui.Name = "WorldDraftHUD"
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = Player:WaitForChild("PlayerGui")
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
end)
local root = UI.box(gui, "Viewport")
root.Size = UDim2.fromScale(1, 1)
local audio = TableAudio()
local tableView = Arena.new(Player.UserId, root, t, audio.play)
local resultBanner = ResultBanner.new(root)
GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function()
	tableView.reduceMotion(reduced())
end)

local mark = UI.box(root, "Masthead", colors.background, 10)
UI.stroke(mark, colors.outline)
local shield = UI.box(mark, "Shield", colors.mint, 7)
shield.Size, shield.Position = UDim2.fromOffset(38, 36), UDim2.fromOffset(8, 7)
local monogram = UI.label(shield, "FP", 17, {font = BLACK, align = CENTER, color = colors.ink, ellipsis = true})
monogram.Size = UDim2.fromScale(1, 1)
local mast = UI.label(mark, "Footbolapolia", 18, {font = BLACK, color = colors.text, ellipsis = true})
mast.Size, mast.Position = UDim2.new(1, -60, 0, 21), UDim2.fromOffset(54, 5)
local tagline = UI.label(mark, "", 12, {font = BOLD, color = colors.muted, ellipsis = true})
tagline.Size, tagline.Position = UDim2.new(1, -60, 0, 15), UDim2.fromOffset(54, 27)

local scores = UI.box(root, "Scoreboard")
local panel = UI.box(root, "MatchPanel", colors.panel, 13)
panel.Active = true
UI.stroke(panel, colors.outline)
local topLine = UI.box(panel, "KickoffLine", colors.mint, 1)
topLine.Size, topLine.Position = UDim2.new(1, -26, 0, 2), UDim2.fromOffset(13, 0)
local phase = UI.label(panel, "", 11, {font = BOLD, color = colors.mint, ellipsis = true, name = "Phase"})
phase.Position, phase.Size = UDim2.fromOffset(14, 12), UDim2.new(0.75, -15, 0, 20)
local countdown = UI.label(panel, "", 15, {font = BOLD, color = GOLD, align = RIGHT, ellipsis = true, name = "Countdown"})
countdown.Position, countdown.Size = UDim2.new(0.75, 0, 0, 12), UDim2.new(0.25, -14, 0, 20)
local body = UI.scroll(panel, "MatchBody")
body.Position = UDim2.fromOffset(10, 37)
local actions = UI.box(panel, "Actions")
actions.AnchorPoint, actions.Position = Vector2.new(0, 1), UDim2.new(0, 12, 1, -12)

local dialogShade = UI.button(root, "DismissBackdrop", "", 1, nil, Color3.new())
dialogShade.Size, dialogShade.BackgroundTransparency, dialogShade.Visible, dialogShade.Modal = UDim2.fromScale(1, 1), 0.36, false, true
dialogShade.Active, dialogShade.AutoButtonColor, dialogShade.ZIndex = true, false, 10
local dialog = UI.box(dialogShade, "Dialog", colors.panel, 16)
dialog.AnchorPoint, dialog.Position, dialog.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.new(0.94, 0, 0.88, 0)
dialog.Active = true
UI.stroke(dialog, colors.outline)
local constraint = Instance.new("UISizeConstraint")
constraint.MaxSize = Vector2.new(530, 590)
constraint.Parent = dialog
local dialogTitle = UI.label(dialog, "", 17, {font = BLACK, color = colors.mint, ellipsis = true})
dialogTitle.Size, dialogTitle.Position = UDim2.new(1, -135, 0, 32), UDim2.fromOffset(18, 8)
local dialogBody = UI.scroll(dialog, "Content")
dialogBody.Position = UDim2.fromOffset(13, 50)
local replyActions = UI.box(dialog, "TradeActions")
replyActions.AnchorPoint, replyActions.Position = Vector2.new(0, 1), UDim2.new(0, 13, 1, -12)
replyActions.Size = UDim2.new(1, -26, 0, 44)
replyActions.Visible = false
local opened = ""
local primary: (() -> ())? = nil
local alternate: (() -> ())? = nil
local mode = "dock"
local inspected, tradePartner = 0, 0
local tradeHelp: TextLabel? = nil
local abilityNames = {
	route = "Through pass", goal = "Clinical finish", kickoff = "Fast break",
	gate = "Safe hands", upgrade = "Training plan", var = "VAR review",
}
local abilityDetails = {
	route = "Pay %d CR to change your short route by one step.",
	goal = "Your next shot on target pays +%d CR, even if saved.",
	kickoff = "Your next crossing of Kickoff pays +%d CR.",
	gate = "Cut the next visiting fee by up to %d CR.",
	upgrade = "Get %d CR for your next club signing or save %d CR on an upgrade, whichever comes first.",
	var = "Cancel an Offside card or earn %d CR extra on a Goal card, whichever comes first.",
}
local function abilityText(power: string): string
	if power == "upgrade" then return t(abilityDetails[power], Board.abilityAmounts.signing, Board.abilityAmounts.upgrade) end
	return t(abilityDetails[power], Board.abilityAmounts[power])
end
type TradeIntent = {buyer: number, offered: number, requested: number, option: number}
local function send(verb: string, value: (number | TradeIntent)?)
	local channel, data = remote, snapshot
	if not channel or not data then return end
	audio.play("select")
	if verb == "tradeAccept" or verb == "tradeDecline" then
		if data.trade and workspace:GetServerTimeNow() < data.trade.expires then
			channel:FireServer(verb, data.trade.token)
		end
		return
	end
	local revision = if verb == "bid" and data.auction then data.auction.token else data.version
	local function dispatch()
		if not snapshot then return end
		local current = if verb == "bid" and snapshot.auction then snapshot.auction.token else snapshot.version
		if current == revision then channel:FireServer(verb, revision, value) end
	end
	if data.match and data.match.phase ~= "final" then
		local delay = data.availableAt - workspace:GetServerTimeNow()
		if delay > 0 then
			task.delay(delay + 0.04, dispatch)
			return
		end
	end
	dispatch()
end

local function sessionName(id: number): string
	if id == Player.UserId then return t("You") end
	if snapshot and snapshot.match then
		for _, seat in snapshot.match.seats do if seat.id == id then return seat.name end end
	end
	return "—"
end

local function preferencesLine(parent: Instance, name: string, label: string, press: () -> ())
	UI.button(parent, name, label, 42, press)
end
local render: () -> ()
local function propertyGroup(tile: Board.Tile): string
	if tile.league > 0 then
		local league = Board.leagues[tile.league]
		return if russian then league.ru else league.name
	end
	return t(if tile.kind == "venue" then "Independent stadiums" else "Commercial rights")
end

local function propertySummary(tile: Board.Tile, gate: number, level: number): string
	if tile.league > 0 then return t("Price %d  /  Gate %d  /  Stadium %d", tile.price, gate, level) end
	return t("Price %d  /  Fee %d", tile.price, gate)
end

local function drawDialog()
	local s = snapshot and snapshot.match
	local inTrade = opened == "trade" or opened == "tradeClubs"
	local myMove = s and s.phase == "move" and s.seats[s.active].id == Player.UserId
	if (inTrade and (not myMove or s.tradeUsed)) or (opened == "tradeReply" and not (snapshot and snapshot.trade)) or (opened == "power" and (not myMove or s.seats[s.active].ability ~= "ready")) then
		opened = ""
	end
	tradeHelp = nil
	replyActions.Visible = opened == "tradeReply"
	replyActions:ClearAllChildren()
	dialogShade.Visible = opened ~= ""
	if opened == "" then return end
	dialogTitle.Text = t(if opened == "rules" then "HOW TO PLAY" elseif opened == "cell" then "BOARD CELL"
		elseif inTrade or opened == "tradeReply" then "CLUB DEAL" elseif opened == "power" then "FIGURE POWER" else "PROPERTY LEDGER")
	constraint.MaxSize = if opened == "cell" or opened == "power" then Vector2.new(390, 320) else Vector2.new(530, 590)
	local offset = dialogBody.CanvasPosition
	dialogBody.Size = UDim2.new(1, -26, 1, if replyActions.Visible then -114 else -62)
	dialogBody:ClearAllChildren()
	UI.stack(dialogBody, if replyActions.Visible then 5 else 10)
	UI.pad(dialogBody, 5, 2, 9)
	if opened == "cell" then
		local tile = Board.tiles[inspected]
		local club = if s then s.clubs[inspected] else {owner = 0, level = 0}
		local accent = Art.accent(tile.kind, tile.league)
		local card = UI.box(dialogBody, "CellDetails", colors.paper, 12)
		card.AutomaticSize, card.Size = Enum.AutomaticSize.Y, UDim2.new(1, 0, 0, 0)
		UI.pad(card, 14, 13)
		UI.stack(card, 4)
		UI.stroke(card, accent, 3)
		if tile.price > 0 then
			local group = propertyGroup(tile)
			if tile.city ~= "" then group ..= "  /  " .. tile.city end
			UI.label(card, group, 13, {font = BOLD, color = colors.panel})
		end
		UI.label(card, t(tile.name), 23, {font = BLACK, color = colors.ink})
		if tile.price > 0 then
			local gate = if club.owner == 0 then tile.gate else snapshot.gates[inspected]
			UI.label(card, propertySummary(tile, gate, club.level), 14, {color = colors.ink})
			UI.label(card, if club.owner == 0 then t("Free") else t("Owner: %s", sessionName(club.owner)), 14, {font = BOLD, color = colors.panel})
			if tile.league == 0 then
				UI.label(card, t("Own both in this group to double the fee."), 13, {color = colors.ink})
			elseif s and club.owner == Player.UserId and club.level == 1 and not Game.setComplete(s, club.owner, tile.league) then
				UI.label(card, t("Complete the league to upgrade to level 2."), 13, {color = colors.ink})
			end
			if myMove and club.owner == Player.UserId and not snapshot.trade then
				local index = inspected
				if not s.tradeUsed and tile.league > 0 then
					if Game.canTransfer(s, Player.UserId, index) then
						UI.button(dialogBody, "ClubDeal", t("Offer sale or swap"), 44, function()
							opened, tradePartner = "trade", 0
							dialogBody.CanvasPosition = Vector2.zero
							drawDialog()
						end, colors.mint, colors.ink)
					else
						UI.label(dialogBody, t("A stadium upgrade in this league blocks trades."), 13, {color = colors.muted})
					end
				end
				if not s.soldThisTurn then
					if club.level > 0 then
						UI.button(dialogBody, "SellUpgrades", t("Sell upgrades · +%d CR", math.floor(club.level * Board.upgradeCost / 2)), 44,
							function() send("sellUpgrades", index) end)
					end
					UI.button(dialogBody, "SellProperty", t("Sell to the bank · +%d CR", Game.sellValue(s, index)), 44,
						function() send("sell", index) end, GOLD, colors.ink)
				end
			end
		else
			local text = if tile.kind == "goalDeck" then t("Draw a reward from the Goal deck.")
				elseif tile.kind == "offsideDeck" then t("Draw a penalty or bench card.")
				elseif tile.kind == "matchday" then t("A goal wins a cup and a cash bonus. A safe play keeps your budget steady.")
				else t("Each move shows two destinations. Crossing Kickoff pays 140 CR.")
			UI.label(card, text, 14, {color = colors.ink})
		end
	elseif opened == "power" then
		local seat = s.seats[s.active]
		local power = Board.figureAbilities[seat.figure]
		UI.label(dialogBody, t(abilityNames[power]), 22, {font = BLACK})
		UI.label(dialogBody, abilityText(power), 16, {color = colors.text})
		if power == "route" then
			local destination = Board.tiles[Game.target(seat.position, Game.shortAfterPower(s.short))]
			UI.label(dialogBody, t("New destination · %s", t(destination.name)), 14, {font = BOLD, color = colors.mint})
		end
		UI.label(dialogBody, t("One use per season."), 13, {color = colors.muted})
		local canActivate = power ~= "route" or seat.cash >= Board.abilityAmounts.route
		local label = if power == "route" then t("Activate · %d CR", Board.abilityAmounts.route) else t("Activate")
		UI.button(dialogBody, "ActivatePower", label, 44, if canActivate then function() send("ability") end else nil,
			if canActivate then colors.mint else colors.surface, if canActivate then colors.ink else colors.muted)
	elseif opened == "tradeClubs" then
		UI.label(dialogBody, t("Choose a club to offer"), 17, {font = BOLD})
		for i, tile in Board.tiles do
			if Game.canTransfer(s, Player.UserId, i) then
				UI.button(dialogBody, "TradeClub" .. i, t(tile.name), 44, function()
					inspected, tradePartner, opened = i, 0, "trade"
					dialogBody.CanvasPosition = Vector2.zero
					drawDialog()
				end)
			end
		end
	elseif opened == "trade" then
		local index = inspected
		UI.label(dialogBody, t(Board.tiles[index].name), 22, {font = BLACK})
		tradeHelp = UI.label(dialogBody, t("Offers run for up to %d seconds and close when you move.", Board.tradeSeconds), 13, {color = colors.muted})
		if tradePartner == 0 then
			UI.label(dialogBody, t("Choose a player"), 14, {font = BOLD})
			for _, seat in s.seats do
				if seat.id ~= Player.UserId then
					UI.button(dialogBody, "TradePlayer" .. seat.id, seat.name .. (if seat.bot then " · " .. t("Bot") else ""), 44, function()
						tradePartner = seat.id
						dialogBody.CanvasPosition = Vector2.zero
						drawDialog()
					end)
				end
			end
		else
			local buyer = tradePartner
			local cash = 0
			for _, seat in s.seats do if seat.id == buyer then cash = seat.cash break end end
			local function propose(requested: number, option: number)
				if snapshot.deadline - workspace:GetServerTimeNow() < Board.tradeMinimumReply then return end
				send("trade", {buyer = buyer, offered = index, requested = requested, option = option})
			end
			UI.button(dialogBody, "ChangeTradePlayer", t("Player · %s", sessionName(buyer)), 44, function()
				tradePartner = 0
				dialogBody.CanvasPosition = Vector2.zero
				drawDialog()
			end)
			UI.label(dialogBody, t("Sell for credits"), 14, {font = BOLD})
			local row = UI.box(dialogBody, "TradePrices")
			row.Size = UDim2.new(1, 0, 0, 44)
			local width = 1 / #Board.tradeRates
			for option in Board.tradeRates do
				local price = Game.tradePrice(index, option)
				if price then
					local button = UI.button(row, "TradePrice" .. option, string.format("%d CR", price), 44,
						if cash >= price then function() propose(0, option) end else nil,
						if cash >= price then colors.mint else colors.surface, if cash >= price then colors.ink else colors.muted)
					button.Position, button.Size = UDim2.fromScale((option - 1) * width, 0), UDim2.new(width, -4, 1, 0)
				end
			end
			for i, tile in Board.tiles do
				if Game.canTransfer(s, buyer, i) then
					local difference = Game.swapDifference(index, i)
					local sellerCash = s.seats[s.active].cash
					local affordable = cash >= difference and sellerCash >= -difference
					local label = t("Swap for %s", t(tile.name))
					if difference ~= 0 then label ..= string.format("  /  %+d CR", difference) end
					UI.button(dialogBody, "TradeSwap" .. i, label, 44, if affordable then function() propose(i, 0) end else nil,
						colors.surface, if affordable then colors.text else colors.muted)
				end
			end
		end
	elseif opened == "tradeReply" then
		local deal = snapshot.trade
		local terms = deal.terms
		UI.label(dialogBody, t("Offer from %s", sessionName(terms.seller)), 14, {font = BOLD, color = colors.mint})
		local receive = t(Board.tiles[terms.offered].name)
		local give = if terms.requested == 0 then string.format("%d CR", terms.price) else t(Board.tiles[terms.requested].name)
		if terms.requested ~= 0 then
			if terms.price < 0 then receive ..= string.format(" + %d CR", -terms.price) end
			if terms.price > 0 then give ..= string.format(" + %d CR", terms.price) end
		end
		UI.label(dialogBody, t("You receive %s", receive), 19, {font = BLACK})
		UI.label(dialogBody, t("You give %s", give), 16, {color = colors.text})
		local accept = UI.button(replyActions, "TradeAccept", t("Accept"), 44, function() send("tradeAccept") end, colors.mint, colors.ink)
		accept.Size = UDim2.new(.5, -4, 1, 0)
		local decline = UI.button(replyActions, "TradeDecline", t("Decline"), 44, function() send("tradeDecline") end)
		decline.Position, decline.Size = UDim2.new(.5, 4, 0, 0), UDim2.new(.5, -4, 1, 0)

	elseif opened == "rules" then
		local topics = {
			{"1. Pick either route", "Each move shows two destinations. Crossing Kickoff pays 140 CR."},
			{"2. Collect a league", "Own all three clubs to double fees and unlock level 2 stadiums."},
			{"Auctions", "When an asset goes unsold, each player can submit one sealed bid. The highest bid wins. In a tie, priority starts after the player who opened the auction."},
			{"Stadiums and rights", "Own both assets in a group to double their fees. Before moving, tap an asset you own to sell it to the bank once per turn."},
			{"Club deals", "Before moving, offer one club for credits or another club. The other player must accept. A stadium upgrade in either league blocks a deal."},
			{"Figure powers", "Each figure has one power per season. Activate it before moving. Most powers wait for their next eligible event."},
			{"Goal, offside and bench", "The Goal deck pays bonuses. Offside can cost credits or send you to the bench. Next turn, take the short route or pay 50 CR for both choices."},
			{"3. Beat the final whistle", "After 8 rounds, cash, clubs, stadiums, leagues and cups decide the winner. Everyone plays to the end."},
		}
		UI.label(dialogBody, t("Tap any cell to see its full details."), 14, {font = BOLD, color = colors.mint})
		for _, topic in topics do
			local card = UI.box(dialogBody, topic[1], colors.surface, 9)
			card.Size, card.AutomaticSize = UDim2.new(1, 0, 0, 0), Enum.AutomaticSize.Y
			UI.pad(card, 12, 9)
			UI.stack(card, 5)
			UI.label(card, t(topic[1]), 15, {font = BOLD})
			UI.label(card, t(topic[2]), 13, {color = colors.muted})
		end
		preferencesLine(dialogBody, "Language", if russian then "Language: Русский  /  EN" else "Language: English  /  RU", function()
			russian = not russian
			tableView.relocalize()
			render()
		end)
		preferencesLine(dialogBody, "Audio", t(if soundOn then "Sound: on" else "Sound: off"), function()
			soundOn = not soundOn
			audio.setEnabled(soundOn)
			drawDialog()
		end)
		preferencesLine(dialogBody, "Music", t(if musicOn then "Music: on" else "Music: off"), function()
			musicOn = not musicOn
			audio.setMusic(musicOn)
			drawDialog()
		end)
		preferencesLine(dialogBody, "Motion", t(if reduced() then "Motion: reduced" else "Motion: full"), function()
			reducePreference = not reducePreference
			tableView.reduceMotion(reduced())
			resultBanner.hide()
			drawDialog()
		end)
	else
		UI.label(dialogBody, t("Complete three clubs for a 160 CR portfolio bonus."), 13, {color = colors.muted})
		local match = snapshot and snapshot.match
		local function ledgerGroup(indices: {number})
			local first = Board.tiles[indices[1]]
			local group = propertyGroup(first)
			local owned = 0
			if match then
				for _, index in indices do
					if match.clubs[index].owner == Player.UserId then owned += 1 end
				end
			end
			local progress = if match then t("%s · %d/%d owned", group, owned, #indices) else group
			UI.label(dialogBody, progress, 14, {font = BOLD, color = Art.accent(first.kind, first.league)})
			for _, i in indices do
				local tile = Board.tiles[i]
				local club = if match then match.clubs[i] else {owner = 0, level = 0}
				local card = UI.box(dialogBody, tile.code, colors.surface, 8)
				card.Size, card.AutomaticSize = UDim2.new(1, 0, 0, 0), Enum.AutomaticSize.Y
				UI.pad(card, 10, 8)
				UI.stack(card, 3)
				local name = t(tile.name)
				if tile.city ~= "" then name ..= "  /  " .. tile.city end
				UI.label(card, name, 14, {font = BOLD})
				local gate = if club.owner ~= 0 then snapshot.gates[i] else tile.gate
				UI.label(card, propertySummary(tile, gate, club.level), 12, {color = colors.muted})
				UI.label(card, if club.owner == 0 then t("Free") else t("Owner: %s", sessionName(club.owner)), 12,
					{color = if club.owner == Player.UserId then colors.mint else colors.muted})
			end
		end
		for _, indices in Board.members do ledgerGroup(indices) end
		ledgerGroup(Board.assetGroups.venue)
		ledgerGroup(Board.assetGroups.commercial)
	end
	dialogBody.CanvasPosition = offset
end

local function show(name: string)
	opened = if opened == name then "" else name
	dialogBody.CanvasPosition = Vector2.zero
	drawDialog()
end
dialogShade.Activated:Connect(function() show(opened) end)
local rulesButton = UI.button(root, "Rules", "?", 40, function() show("rules") end)
local clubsButton = UI.button(root, "Clubs", "", 40, function() show("clubs") end)
local closeButton = UI.button(dialog, "Close", "", 40, function() show(opened) end)
closeButton.AnchorPoint, closeButton.Position, closeButton.Size = Vector2.new(1, 0), UDim2.new(1, -12, 0, 9), UDim2.fromOffset(104, 40)

local function arrange()
	local size = root.AbsoluteSize
	mode = View.mode(size)
	mark.Position = UDim2.fromOffset(10, 6)
	mark.Size = UDim2.fromOffset(math.clamp(size.X - 161, 179, 256), 50)
	rulesButton.Size = UDim2.fromOffset(if size.X < 420 then 42 else 76, 44)
	clubsButton.Size = UDim2.fromOffset(if size.X < 420 then 65 else 91, 44)
	rulesButton.AnchorPoint, clubsButton.AnchorPoint = Vector2.new(1, 0), Vector2.new(1, 0)
	rulesButton.Position = UDim2.new(1, -10, 0, 9)
	clubsButton.Position = UDim2.new(1, if size.X < 420 then -59 else -93, 0, 9)
	if mode == "rail" then
		panel.AnchorPoint, panel.Position = Vector2.new(1, 0), UDim2.new(1, -10, 0, 60)
		panel.Size = UDim2.new(0, View.railWidth(size), 1, -70)
		scores.AnchorPoint, scores.Position = Vector2.zero, UDim2.fromOffset(10, 61)
		scores.Size = UDim2.new(1, -View.railWidth(size) - 28, 0, 75)
	else
		panel.AnchorPoint, panel.Position = Vector2.new(.5, 1), UDim2.new(.5, 0, 1, -10)
		panel.Size = UDim2.fromOffset(math.max(1, math.min(956, size.X - 20)), View.dockHeight(size, mode))
		if size.X >= 920 then
			scores.AnchorPoint, scores.Position = Vector2.zero, UDim2.fromOffset(276, 9)
			scores.Size = UDim2.new(1, -466, 0, 41)
		else
			scores.AnchorPoint, scores.Position = Vector2.new(.5, 0), UDim2.new(.5, 0, 0, 62)
			scores.Size = UDim2.fromOffset(math.max(1, size.X - 20), 91)
		end
	end
end

local function spendText(s: any, seat: any, index: number): string
	local tile, club = Board.tiles[index], s.clubs[index]
	if tile.price > 0 then
		local kickoff = Board.kickoffCash + (if seat.ability == "armed" and Board.figureAbilities[seat.figure] == "kickoff" then Board.abilityAmounts.kickoff else 0)
		local budget = seat.cash + (if index < seat.position then kickoff else 0)
		if club.owner == 0 then
			return if budget < tile.price then t("May go to auction") else t("Sign · %d CR", tile.price)
		end
		if club.owner == seat.id then return t(if tile.league > 0 then "Your club" else "Your asset") end
		local discount = if seat.ability == "armed" and Board.figureAbilities[seat.figure] == "gate" then Board.abilityAmounts.gate else 0
		return t("Gate · −%d CR", math.max(0, math.min(budget, snapshot.gates[index]) - discount))
	elseif tile.kind == "goalDeck" or tile.kind == "offsideDeck" then
		return t("Draw a card")
	elseif tile.kind == "matchday" then
		return t("Play for a cup")
	elseif tile.kind == "kickoff" then
		return t("%+d CR · KICKOFF", Board.kickoffCash + (if seat.ability == "armed" and Board.figureAbilities[seat.figure] == "kickoff" then Board.abilityAmounts.kickoff else 0))
	end
	return string.format("+%d CR", tile.award)
end

local function storyCard(s: any)
	local last = s.last
	local card = UI.box(body, "StoryCard", colors.background, 9)
	card.Size, card.AutomaticSize = UDim2.new(1, 0, 0, 0), Enum.AutomaticSize.Y
	UI.pad(card, 10, 7)
	UI.stack(card, 4)
	UI.label(card, t("MATCH FEED"), 10, {font = BOLD, color = colors.muted})
	local name, tile = sessionName(last.who), Board.tiles[last.tile]
	local template = ({
		buy = "%s signed %s", league = "%s completed %s", upgrade = "%s invested in %s",
		skip = "%s passed on %s", gate = "%s paid gate at %s",
		auctionWon = "%s won the auction for %s", auctionLeague = "%s won the auction for %s",
		sold = "%s sold %s", soldUpgrades = "%s sold upgrades at %s", release = "%s returned from the bench",
	})[last.kind] or "%s landed on %s"
	if last.kind == "start" then
		UI.label(card, t("The transfer window is open."), 14)
	elseif last.kind == "auctionEmpty" then
		UI.label(card, t("%s is still available", tile.name), 14)
	elseif last.kind == "tradeSale" or last.kind == "tradeSwap" then
		local sent = t(tile.name)
		local received = if last.kind == "tradeSale" then string.format("%d CR", last.amount) else t(Board.tiles[last.otherTile].name)
		if last.kind == "tradeSwap" then
			if last.amount < 0 then sent ..= string.format(" + %d CR", -last.amount) end
			if last.amount > 0 then received ..= string.format(" + %d CR", last.amount) end
		end
		UI.label(card, t("%s sent %s to %s for %s", name, sent, sessionName(last.other), received), 14, {font = BOLD})
	elseif last.kind == "var" then
		UI.label(card, t("%s canceled an Offside card", name), 14, {font = BOLD, color = colors.mint})
	elseif last.card > 0 then
		local info = Edition.cards[last.card]
		local detail = if info.kind == "bench" then "" else string.format("  /  %+d CR", last.amount)
		UI.label(card, (if russian then info.ru else info.title) .. detail, 14, {font = BOLD, color = if last.amount < 0 then colors.pink else GOLD})
		UI.label(card, t("%s drew a card", name) .. " · " .. (if russian then info.ruBody else info.body), 12, {color = colors.muted})
	elseif last.kind == "goal" or last.kind == "save" or last.kind == "offside" or last.kind == "safe" then
		local outcome = ({goal = "Goal! Cup awarded", save = "Saved by the keeper", offside = "Offside · goal disallowed", safe = "Safe play"})[last.kind]
		UI.label(card, t(outcome) .. string.format("  /  %+d CR", last.amount), 14,
			{font = BOLD, color = if last.amount < 0 then colors.pink else GOLD})
		UI.label(card, name, 12, {color = colors.muted})
	else
		local title = t(tile.name)
		if last.kind == "league" then title = if russian then Board.leagues[tile.league].ru else Board.leagues[tile.league].name end
		local delta = if last.amount == 0 then "" else string.format("  /  %+d CR", last.amount)
		if last.kind == "offer" or last.kind == "invest" then delta = "" end
		UI.label(card, (if last.kind == "release" then t(template, name) else t(template, name, title)) .. delta, 14)
	end
	if last.crossed then UI.label(card, t("%+d CR · KICKOFF", Board.kickoffCash), 12, {font = BOLD, color = colors.mint}) end
	if last.power and last.kind ~= "var" then
		UI.label(card, t("Power used · %s", t(abilityNames[last.power])), 12, {font = BOLD, color = colors.mint})
	end
end

local function footer(height: number)
	actions:ClearAllChildren()
	if mode == "dock" and height > 0 then
		actions.AnchorPoint, actions.Position = Vector2.new(1, 1), UDim2.new(1, -13, 1, -13)
		actions.Size = UDim2.new(.49, -15, 0, height)
		body.Size = UDim2.new(.51, -9, 1, -47)
	else
		actions.AnchorPoint, actions.Position = Vector2.new(0, 1), UDim2.new(0, 12, 1, -12)
		actions.Size = UDim2.new(1, -24, 0, height)
		body.Size = UDim2.new(1, -19, 1, -(45 + height + (if height > 0 then 8 else 0)))
	end
end

local function title(titleText: string, description: string?)
	UI.label(body, t(titleText), 23, {font = BLACK, name = "Headline"})
	if description then UI.label(body, t(description), 13, {color = colors.muted}) end
end

local function scorecards(s: any)
	for _, child in scores:GetChildren() do if child:IsA("Frame") then child:Destroy() end end
	if not s then return end
	local width = scores.AbsoluteSize.X
	local compact = mode == "rail"
	local cardHeight = if compact then 35 else 42
	local gap = if width < 500 then 4 else 6
	local columns = if #s.seats > 4 and width < 620 and root.AbsoluteSize.X < 920 then 3 else #s.seats
	for i, seat in s.seats do
		local color = hex(Board.figures[seat.figure].color)
		local active = s.active == i and s.phase ~= "final"
		local frame = UI.box(scores, "Seat" .. i, if active then colors.surface else colors.background, 8)
		frame.Size = UDim2.new(1 / columns, -gap, 0, cardHeight)
		frame.Position = UDim2.new(((i - 1) % columns) / columns, 0, 0, math.floor((i - 1) / columns) * (cardHeight + 4))
		UI.stroke(frame, if active then color else colors.outline, if active then 1.5 else 1)
		local wide = width / columns >= 94
		if wide then
			local badge = UI.box(frame, "Shirt", color, 5)
			badge.Position, badge.Size = UDim2.fromOffset(5, 5), UDim2.fromOffset(26, cardHeight - 10)
			UI.label(badge, Board.figures[seat.figure].number, 13, {color = colors.ink, font = BLACK, align = CENTER, ellipsis = true}).Size = UDim2.fromScale(1, 1)
		end
		local info = UI.box(frame, "Score")
		local inset = if wide then 36 else 5
		info.Position = UDim2.fromOffset(inset, if compact then 0 else 3)
		info.Size = UDim2.new(1, -inset - 5, 1, 0)
		local name = UI.label(info, sessionName(seat.id) .. (if seat.bot and wide then " · " .. t("BOT") else ""), 12,
			{color = if active then color else colors.muted, font = BOLD, ellipsis = true})
		name.Size = UDim2.new(1, 0, 0, 15)
		local cash = tostring(seat.cash) .. " CR"
		if seat.trophies > 0 and wide then cash ..= "  ·  " .. t("%d cups", seat.trophies) end
		local balance = UI.label(info, cash, 15, {font = BLACK, ellipsis = true})
		balance.Position, balance.Size = UDim2.fromOffset(0, 15), UDim2.new(1, 0, 0, 18)
	end
end

local function lobbyPanel(data: any)
	local selected = nil
	local taken = {}
	for _, person in data.lobby do
		if person.id == Player.UserId then selected = person.figure else taken[person.figure] = true end
	end
	if not selected then
		title("Table full", "A place opens when a player leaves.")
		footer(0)
		return
	end
	footer(96)
	local figure = Board.figures[selected]
	local figureColor = hex(figure.color)
	local feature = UI.box(body, "FootballerCard", colors.surface, 12)
	feature.Size = UDim2.new(1, 0, 0, if mode == "dock" then 103 else 88)
	UI.stroke(feature, figureColor:Lerp(colors.outline, 0.54))
	local textArea = UI.box(feature, "FootballerDetails")
	textArea.Position, textArea.Size = UDim2.new(0, 11, 0, if mode == "dock" then 16 else 5), UDim2.new(0.60, -11, 1, -16)
	UI.stack(textArea, 3)
	UI.label(textArea, "#" .. figure.number .. "  /  " .. t("Choose your figure"), 10, {font = BOLD, color = figureColor})
	UI.label(textArea, figure.name, 20, {font = BLACK})
	UI.label(textArea, t(abilityNames[Board.figureAbilities[selected]]), 13, {font = BOLD, color = figureColor})
	UI.label(body, abilityText(Board.figureAbilities[selected]), 13, {color = colors.muted})
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "FootballerPreview"
	viewport.BackgroundTransparency = 1
	viewport.Position, viewport.Size = UDim2.new(0.56, 0, 0, 2), UDim2.new(0.44, -4, 1, -4)
	viewport.LightColor, viewport.Ambient, viewport.LightDirection = hex(0xFFFFFF), hex(0xC5DCFA), Vector3.new(-2, -5, -6)
	viewport.Parent = feature
	local camera = Instance.new("Camera")
	camera.FieldOfView = 35
	camera.CFrame = CFrame.lookAt(Vector3.new(4.6, 4.10, 9.55), Vector3.new(0, 2.78, 0))
	camera.Parent, viewport.CurrentCamera = viewport, camera
	tableView.preview(Pawn.make(selected, viewport))

	local row = UI.box(actions, "FigurePicker")
	row.Size = UDim2.new(1, 0, 0, 43)
	for i, candidate in Board.figures do
		local available = i ~= selected and not taken[i]
		local b = UI.button(row, "Figure" .. i, candidate.number, 43, if available then function() send("figure", i) end else nil,
			if i == selected then hex(candidate.color) else colors.surface,
			if i == selected then colors.ink elseif available then hex(candidate.color) else colors.muted)
		local count = #Board.figures
		b.Position, b.Size = UDim2.new((i - 1) / count, 0, 0, 0), UDim2.new(1 / count, -4, 0, 43)
	end
	local isHost = data.host == Player.UserId
	if isHost then primary = function() send("start") end end
	local start = UI.button(actions, "StartSeason", t(if isHost then "Start season" else "Waiting for the host"), 48, primary,
		if isHost then colors.mint else colors.surface, if isHost then colors.ink else colors.muted)
	start.Position = UDim2.fromOffset(0, 48)
end

local function routePanel(s: any, seat: any)
	local canOffer = false
	if not s.tradeUsed then
		for i in Board.tiles do
			if Game.canTransfer(s, Player.UserId, i) then
				canOffer = true
				break
			end
		end
	end
	local power = Board.figureAbilities[seat.figure]
	if canOffer or seat.ability == "ready" then
		local row = UI.box(body, "RouteUtilities")
		row.Size = UDim2.new(1, 0, 0, 44)
		local split = canOffer and seat.ability == "ready"
		if canOffer then
			local deal = UI.button(row, "ClubDeals", t("Club deals"), 44, function() show("tradeClubs") end)
			if split then deal.Size = UDim2.new(.5, -4, 1, 0) end
		end
		if seat.ability == "ready" then
			local activate = UI.button(row, "FigurePower", t(abilityNames[power]), 44, function() show("power") end, colors.surface, colors.mint)
			if split then activate.Position, activate.Size = UDim2.new(.5, 4, 0, 0), UDim2.new(.5, -4, 1, 0) end
		end
	end
	if snapshot.trade then
		UI.label(body, t("Offer sent. You can move now."), 13, {color = GOLD})
	elseif seat.ability == "armed" then
		UI.label(body, t("Armed · %s", t(abilityNames[power])), 12, {color = colors.mint})
	end
	title("Choose a route")
	if snapshot.variant == "coach" and s.round == 1 then
		UI.label(body, t("Coach tip: a free club pays you when rivals visit."), 13, {color = colors.mint, name = "CoachHint"})
	end
	footer(78)
	for i, route in {{s.short, "short", colors.mint}, {s.long, "long", colors.blue}} do
		local steps, verb, color = route[1] :: number, route[2] :: string, route[3] :: Color3
		local index = Game.target(seat.position, steps)
		local target = Board.tiles[index]
		local cost = spendText(s, seat, index)
		local function choose() send(verb) end
		if i == 1 then primary = choose else alternate = choose end
		local b = UI.button(actions, if i == 1 then "RouteShort" else "RouteLong", "", 78, choose, colors.background, colors.text)
		b.Position, b.Size = UDim2.new(.5 * (i - 1), if i == 1 then 0 else 4, 0, 0), UDim2.new(.5, -4, 0, 78)
		UI.stroke(b, color, 1.2)
		local indexBadge = UI.box(b, "Route number", color, 5)
		indexBadge.Size, indexBadge.Position = UDim2.fromOffset(21, 20), UDim2.fromOffset(8, 7)
		UI.label(indexBadge, tostring(i), 13, {font = BLACK, color = colors.ink, align = CENTER, ellipsis = true}).Size = UDim2.fromScale(1, 1)
		local stepLabel = UI.label(b, if steps == 1 then t("1 step") else t("%d steps", steps), 12,
			{font = BOLD, color = color, ellipsis = true, name = "Steps"})
		stepLabel.Position, stepLabel.Size = UDim2.fromOffset(35, 7), UDim2.new(1, -40, 0, 19)
		local destination = UI.label(b, t(target.name), if mode == "dock" then 17 else 14,
			{font = BOLD, color = colors.text, ellipsis = true, name = "Destination"})
		destination.Position = UDim2.fromOffset(8, 28)
		destination.Size = UDim2.new(1, -14, 0, 28)
		destination.TextTruncate, destination.TextWrapped = Enum.TextTruncate.None, true
		local budget = UI.label(b, cost, 12, {font = BOLD, color = colors.muted, name = "Stake", ellipsis = true})
		budget.Position, budget.Size = UDim2.fromOffset(8, 57), UDim2.new(1, -14, 0, 16)
	end
	storyCard(s)
end

local function contractPanel(s: any, seat: any)
	local offer = s.phase == "offer"
	local tile, club = Board.tiles[seat.position], s.clubs[seat.position]
	title(if offer then (if tile.league > 0 then "Sign this club?" else "Buy this asset?") else "Upgrade your stadium?")
	local card = UI.box(body, "Contract", colors.surface, 9)
	card.Size, card.AutomaticSize = UDim2.new(1, 0, 0, 0), Enum.AutomaticSize.Y
	UI.pad(card, 10, 6)
	UI.stack(card, 2)
	local group = propertyGroup(tile)
	if tile.city ~= "" then group ..= "  /  " .. tile.city end
	UI.label(card, group, 11, {font = BOLD, color = Art.accent(tile.kind, tile.league)})
	UI.label(card, t(tile.name), 21, {font = BLACK})
	UI.label(card, if offer then t("Gate +%d CR each visit from a rival.", tile.gate) else t("Level %d → %d · gate +%d CR", club.level,
		club.level + 1, Board.upgradeGate * (if Game.setComplete(s, seat.id, tile.league) then 2 else 1)), 13, {color = colors.mint})
	footer(50)
	primary, alternate = function() send(if offer then "buy" else "upgrade") end, function() send("skip") end
	local b = UI.button(actions, if offer then "SignClub" else "Upgrade", t(if offer then "Sign · %d CR" else "Upgrade · %d CR",
		if offer then tile.price else Game.upgradePrice(seat)), 50, primary, colors.mint, colors.ink)
	b.Size = UDim2.new(0.67, -4, 0, 50)
	local skip = UI.button(actions, "Skip", t(if offer then "Send to auction" else "Pass"), 50, alternate)
	skip.Size, skip.Position = UDim2.new(0.33, -4, 0, 50), UDim2.new(0.67, 4, 0, 0)
end

local function benchPanel(s: any, seat: any)
	title("On the bench")
	local target = Board.tiles[Game.target(seat.position, s.short)]
	UI.label(body, t("Short route to %s", t(target.name)), 14, {font = BOLD, color = colors.mint})
	footer(52)
	primary = function() send("short") end
	if seat.cash >= Board.benchFee then alternate = function() send("release") end end
	local short = UI.button(actions, "BenchShort", t("Take short route"), 52, primary, colors.mint, colors.ink)
	local release = UI.button(actions, "BenchRelease", t("Pay %d CR for both routes", Board.benchFee), 52, alternate)
	short.Size = UDim2.new(.5, -4, 0, 52)
	release.Size, release.Position = UDim2.new(.5, -4, 0, 52), UDim2.new(.5, 4, 0, 0)
end

local function auctionPanel(s: any, auction: any)
	local tile = Board.tiles[auction.tile]
	local mine = nil
	local total, ready = 0, 0
	local minimum = Game.auctionMinimum(auction.tile)
	for i, seat in s.seats do
		if seat.cash >= minimum then
			total += 1
			if auction.responded[i] then ready += 1 end
		end
		if not seat.bot and seat.id == Player.UserId then mine = i end
	end
	local amount = if mine then s.seats[mine].cash else 0
	local status = if not mine then t("Watching the auction") elseif amount < minimum then t("Budget below %d CR", minimum)
		elseif auction.responded[mine] then t("Decision received") else t("One sealed bid. Highest offer wins.")
	title(tile.name)
	UI.label(body, status, 14, {font = BOLD, color = colors.mint})
	UI.label(body, t("%d/%d players ready", ready, total), 12, {color = colors.muted})
	local eligible = mine ~= nil and amount >= minimum and not auction.responded[mine]
	footer(if eligible then 52 else 0)
	if not eligible then return end
	primary = function() send("bid", 1) end
	if amount >= tile.price then alternate = function() send("bid", 2) end end
	local pass = UI.button(actions, "AuctionPass", t("Pass"), 52, function() send("bid", 0) end)
	local minimumBid = UI.button(actions, "AuctionMinimum", t("Bid · %d CR", minimum), 52, primary, colors.mint, colors.ink)
	local listBid = UI.button(actions, "AuctionListPrice", t("Bid · %d CR", tile.price), 52, alternate,
		if alternate then GOLD else colors.surface, if alternate then colors.ink else colors.muted)
	for i, button in {minimumBid, listBid, pass} do
		button.Position, button.Size = UDim2.new((i - 1) / 3, 2, 0, 0), UDim2.new(1 / 3, -5, 0, 52)
	end
end

local function matchdayPanel()
	title("Take the shot?")
	local odds = UI.box(body, "ShotOdds", colors.surface, 9)
	odds.AutomaticSize, odds.Size = Enum.AutomaticSize.Y, UDim2.new(1, 0, 0, 0)
	UI.pad(odds, 10, 4)
	UI.stack(odds, 0)
	local weight = 0
	for _, outcome in Edition.shots do weight += outcome.weight end
	local titles = {goal = "Goal and cup", save = "Save", offside = "Offside"}
	for _, outcome in Edition.shots do
		UI.label(odds, t("%s · %d of %d · %+d CR", t(titles[outcome.result]), outcome.weight, weight, outcome.cash),
			13, {font = BOLD, color = if outcome.cash < 0 then colors.pink else colors.mint})
	end
	UI.label(odds, t("Each cup adds %d CR to the final total.", Edition.trophy_value), 12, {color = GOLD})
	footer(52)
	primary, alternate = function() send("shoot") end, function() send("safe") end
	local shoot = UI.button(actions, "Shoot", t("Shoot · %d%% goal", math.floor(Game.goalChance * 100 + 0.5)), 52, primary, GOLD, colors.ink)
	local safe = UI.button(actions, "SafePlay", t("Play safe · +%d CR", Edition.safe_cash), 52, alternate)
	shoot.Size = UDim2.new(0.5, -4, 0, 52)
	safe.Size, safe.Position = UDim2.new(0.5, -4, 0, 52), UDim2.new(0.5, 4, 0, 0)
end

local function finishPanel(s: any)
	local sharedTitle = s.standings[1].score == s.standings[2].score
	title(if sharedTitle then "League champions" else "Season champion", if sharedTitle then "Same team value: shared title" else "Season value")
	for index, record in s.standings do
		local seat = nil
		local clubs, assets = 0, 0
		for _, candidate in s.seats do if candidate.id == record.id then seat = candidate break end end
		for i, club in s.clubs do
			if club.owner == record.id then
				if Board.tiles[i].league > 0 then clubs += 1 else assets += 1 end
			end
		end
		local winner = record.score == s.standings[1].score
		local row = UI.box(body, "Rank" .. index, colors.surface, 9)
		row.AutomaticSize, row.Size = Enum.AutomaticSize.Y, UDim2.new(1, 0, 0, 0)
		UI.pad(row, 11, 8)
		UI.stack(row, 2)
		if winner then UI.stroke(row, GOLD) end
		local rank = if winner then "01" else string.format("%02d", index)
		UI.label(row, rank .. "  /  " .. (if seat then sessionName(record.id) else "—"), 17, {font = BLACK, color = if winner then GOLD else colors.text})
		local summary = t("%d CR value", record.score) .. "  ·  " .. t(if clubs == 0 then "No clubs" else "%d clubs", clubs)
		if assets > 0 then summary ..= "  ·  " .. t("%d assets", assets) end
		if seat and seat.trophies > 0 then summary ..= "  ·  " .. t("%d cups", seat.trophies) end
		UI.label(row, summary, 12, {color = colors.muted})
	end
	footer(48)
	primary = function() send("lobby") end
	UI.button(actions, "BackToLobby", t("Back to lobby"), 48, primary, colors.mint, colors.ink)
end

render = function()
	primary, alternate = nil, nil
	tagline.Text = if russian then Edition.ru else string.upper(Edition.name)
	local wide = root.AbsoluteSize.X >= 420
	rulesButton.Text, clubsButton.Text = if wide then t("Rules") else "?", t(if wide then "View holdings" else "Holdings")
	closeButton.Text = t("Close")
	body:ClearAllChildren()
	body.CanvasPosition = Vector2.zero
	UI.stack(body, 4)
	UI.pad(body, 4, 1, 5)
	local data = snapshot
	local s = data and data.match
	scorecards(s)
	if not data then
		phase.Text = "WORLD DRAFT"
		title("Connect to table…")
		footer(0)
	elseif not s then
		phase.Text = t("TABLE BRIEFING")
		lobbyPanel(data)
	elseif data.auction then
		phase.Text = t("TRANSFER AUCTION")
		auctionPanel(s, data.auction)
	elseif s.phase == "final" then
		phase.Text = string.upper(t("Final whistle"))
		finishPanel(s)
	else
		phase.Text = t("ROUND %d / %d", s.round, Board.rounds)
		local seat = s.seats[s.active]
		if seat.id == Player.UserId and not seat.bot then
			if s.phase == "move" then
				routePanel(s, seat)
			elseif s.phase == "bench" then
				benchPanel(s, seat)
			elseif s.phase == "matchday" then
				matchdayPanel()
			else
				contractPanel(s, seat)
			end
		else
			local watching = true
			for _, entry in s.seats do if entry.id == Player.UserId and not entry.bot then watching = false end end
			if data.trade and data.trade.terms.buyer == Player.UserId then
				UI.button(body, "IncomingTrade", t("Review club offer"), 44, function() show("tradeReply") end, colors.mint, colors.ink)
			end
			title(t("%s's turn", seat.name), if watching then "Watch this season and join the next one." else nil)
			storyCard(s)
			footer(0)
		end
	end
	drawDialog()
end

root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	arrange()
	render()
end)
arrange()
render()
Input.InputBegan:Connect(function(input, captured)
	if captured or Input:GetFocusedTextBox() then return end
	if opened ~= "" then
		if input.KeyCode == Enum.KeyCode.Escape then show(opened) end
		return
	end
	if input.KeyCode == Enum.KeyCode.One or input.KeyCode == Enum.KeyCode.Return then
		if primary then primary() end
	elseif input.KeyCode == Enum.KeyCode.Two then
		if alternate then alternate() end
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then

		local index = tableView.pickTile(input.Position)
		if index then
			inspected = index
			show("cell")
		end
	end
end)

task.spawn(function()
	while gui.Parent do
		local remaining = if snapshot and snapshot.deadline > 0 then math.max(0, math.ceil(snapshot.deadline - workspace:GetServerTimeNow())) else nil
		countdown.Text = if remaining then string.format(":%02d", remaining) else ""
		if tradeHelp and snapshot.deadline - workspace:GetServerTimeNow() < Board.tradeMinimumReply then
			tradeHelp.Text = t("Trade window closed for this turn.")
			tradeHelp.TextColor3 = GOLD
		end
		if replyActions.Visible and snapshot.trade then
			local seconds = math.max(0, math.ceil(snapshot.trade.expires - workspace:GetServerTimeNow()))
			dialogTitle.Text = t("CLUB DEAL") .. string.format("  :%02d", seconds)
		end
		task.wait(0.12)
	end
end)

local net = ReplicatedStorage:WaitForChild("WorldDraft")
local intent = net:WaitForChild("Intent") :: RemoteEvent
local snapshots = net:WaitForChild("Snapshot") :: RemoteEvent
remote = intent
local outcomes = {
	goal = "GOAL!", offside = "Offside", save = "Save",
	buy = "Club signed", upgrade = "Stadium upgraded", league = "League complete",
	tradeSale = "Club sold", tradeSwap = "Clubs swapped", var = "VAR review",
	auctionWon = "Club won at auction", auctionLeague = "League complete", auctionEmpty = "Still available", sold = "Sold to the bank",
}
snapshots.OnClientEvent:Connect(function(data)
	local old = snapshot
	if old and data.version <= old.version then return end
	snapshot = data
	audio.scene(data.match ~= nil and data.match.phase ~= "final")
	if data.trade and data.trade.terms.buyer == Player.UserId and (not old or not old.trade or old.trade.token ~= data.trade.token) then
		opened = "tradeReply"
		dialogBody.CanvasPosition = Vector2.zero
	end
	if data.auction and (not old or not old.auction or old.auction.token ~= data.auction.token) then
		audio.play("card")
		for _, seat in data.match.seats do
			if seat.id == Player.UserId and not seat.bot and seat.cash >= Game.auctionMinimum(data.auction.tile) then
				opened = ""
				break
			end
		end
	end
	tableView.sync(data)
	render()
	local match, previous = data.match, old and old.match
	if not match or not previous or old.serial ~= data.serial then
		resultBanner.hide()
		return
	end
	local last, before = match.last, previous.last
	local moved = match.motion.serial ~= previous.motion.serial
	local final = match.phase == "final" and previous.phase ~= "final"
	if final then
		audio.play("whistle")
		audio.play("final")
	end
	if not (moved or final or last.kind ~= before.kind or last.tile ~= before.tile or last.who ~= before.who) then return end
	local animatedMove = moved and not reduced()
	local delay = if animatedMove then Arena.landingAfter(match.motion.steps) else 0
	task.delay(delay, function()
		if snapshot.serial ~= data.serial or not snapshot.match then return end
		local name = sessionName(last.who)
		local headline, caption, tint = outcomes[last.kind], name .. "  /  " .. t(Board.tiles[last.tile].name), colors.mint
		local shot: string? = nil
		if Board.tiles[last.tile].league == 0 and last.kind == "buy" then headline = "Asset acquired" end
		if Board.tiles[last.tile].league == 0 and last.kind == "auctionWon" then headline = "Asset won at auction" end
		if final then
			local tied = {}
			for _, record in match.standings do
				if record.score == match.standings[1].score then table.insert(tied, sessionName(record.id)) end
			end
			headline, caption, tint = "Final whistle", table.concat(tied, "  /  "), GOLD
		elseif last.kind == "var" then
			caption, tint = t("%s canceled an Offside card", name), colors.mint
		elseif last.kind == "tradeSale" or last.kind == "tradeSwap" then
			caption = t(Board.tiles[last.tile].name) .. "  /  " ..
				(if last.kind == "tradeSwap" then t(Board.tiles[last.otherTile].name) else string.format("%d CR", last.amount))
		elseif last.kind == "sold" then
			caption = name .. "  /  " .. t(Board.tiles[last.tile].name) .. string.format("  /  +%d CR", last.amount)
		elseif last.card > 0 then
			local card = Edition.cards[last.card]
			headline = if russian then card.ru else card.title
			caption = name .. (if card.kind == "bench" then "  /  " .. t("Next turn") else string.format("  /  %+d CR", last.amount))
			tint = if card.kind == "bench" then GOLD else colors.blue
		elseif last.kind == "goal" or last.kind == "save" or last.kind == "offside" then
			shot = last.kind
			caption = name .. string.format("  /  %+d CR", last.amount)
			tint = if last.kind == "goal" then GOLD else colors.pink
		elseif last.kind == "auctionWon" or last.kind == "auctionLeague" then
			caption = name .. "  /  " .. t(Board.tiles[last.tile].name) .. string.format("  /  %d CR", -last.amount)
			tint = GOLD
		elseif last.kind == "auctionEmpty" then
			caption, tint = t(Board.tiles[last.tile].name), colors.blue
		elseif last.kind == "league" then
			local league = Board.leagues[Board.tiles[last.tile].league]
			caption, tint = name .. "  /  " .. (if russian then league.ru else league.name), GOLD
		end
		if moved and not animatedMove and snapshot.match.motion.serial == match.motion.serial then audio.play("land") end
		if not headline then return end
		if snapshot.version ~= data.version and (snapshot.match.last.who ~= last.who or snapshot.match.last.kind ~= last.kind or snapshot.match.last.tile ~= last.tile) then return end
		local title = t(headline)
		local exciting = final or last.kind == "goal" or last.kind == "league" or last.kind == "auctionLeague"
		local function reveal()
			if snapshot.serial ~= data.serial or not snapshot.match then return end
			if shot then audio.play(shot) end
			if not final and snapshot.match.phase == "final" then return end
			if not final and not shot then
				audio.play(if last.card > 0 or last.kind == "auctionEmpty" then "card" else "sign")
			end
			resultBanner.reveal(title, caption, tint, reduced(), mode,
				math.max(.28, 1 - (View.railWidth(root.AbsoluteSize) + 24) / math.max(1, root.AbsoluteSize.X)))
			if exciting then tableView.celebrate(last.tile, true) elseif last.kind == "upgrade" then tableView.celebrate(last.tile, false) end
		end
		if shot then
			local figure = 1
			for _, seat in match.seats do
				if seat.id == last.who then figure = seat.figure; break end
			end
			tableView.playShot(shot, last.who, figure, reveal)
		else
			reveal()
		end
	end)
end)

repeat
	intent:FireServer("sync")
	task.wait(1)
until snapshot ~= nil
