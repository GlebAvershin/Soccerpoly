--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local GuiService = game:GetService("GuiService")
local Input = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("League")
local Board = require(shared.TourBoard)
local Edition = require(shared.EventCards)
local Rules = require(shared.Rules)
local Game = Rules.withBoard(Board, Edition)
local shotCash: {[string]: number} = {}
for _, shot in Edition.shots do shotCash[shot.result] = shot.cash end
local Art = require(shared.Presentation)
local ResultBanner = require(script.Parent.ResultBanner)
local Pawn = require(script.Parent.Pawn)
local Arena = require(script.Parent.Arena)
local PropertyCard = require(script.Parent.PropertyCard)
local TableAudio = require(script.Parent.TableAudio)
local UI = require(script.Parent.Components)
local copy = require(script.Parent.Copy)
local colors = UI.color
local GOLD, BOLD, BLACK = colors.gold, Enum.Font.BuilderSansBold, Enum.Font.BuilderSansExtraBold
local CENTER, RIGHT = Enum.TextXAlignment.Center, Enum.TextXAlignment.Right
local function hex(v: number): Color3 return Color3.fromHex(string.format("%06x", v)) end
local russian = Player:GetAttribute("TableLanguage") == "ru"
local languageRevision = 0
local soundOn, musicOn, reducePreference = true, true, false
local function reduced(): boolean return reducePreference or GuiService.ReducedMotionEnabled end
local function t(key: string, ...: any): string return copy(key, russian, ...) end
local snapshot: any = nil
local remote: RemoteEvent? = nil

local gui = Instance.new("ScreenGui")
gui.Name = "WorldDraftHUD"
gui.ResetOnSpawn, gui.AutoLocalize = false, false
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
local propertyCard = PropertyCard.new(root)
GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function()
	tableView.reduceMotion(reduced())
end)

local brand = UI.box(root, "Soccerpoly wordmark", colors.ink, 5)
brand.BackgroundTransparency = .14
brand.Position, brand.Size = UDim2.fromOffset(13, 8), UDim2.fromOffset(151, 28)
for i = 1, 2 do
	local slash = UI.box(brand, "Stencil stroke", colors.mint)
	slash.Position, slash.Size = UDim2.fromOffset(9 + (i - 1) * 7, 5), UDim2.fromOffset(4, 16)
	slash.Rotation = 21
end
local brandText = UI.label(brand, "SOCCERPOLY", 16, {font = BLACK, color = colors.text, ellipsis = true})
brandText.Position, brandText.Size = UDim2.fromOffset(25, 0), UDim2.new(1, -27, 1, 0)
local scores = UI.box(root, "Scoreboard", colors.ink, 6)
scores.AnchorPoint, scores.Position = Vector2.new(.5, 0), UDim2.new(.5, 0, 0, 10)
UI.stroke(scores, colors.outline)
local matchClock = UI.box(root, "MatchClock", colors.ink, 5)
matchClock.AnchorPoint, matchClock.Position = Vector2.new(1, 0), UDim2.new(1, -13, 0, 6)
matchClock.Size, matchClock.Visible = UDim2.fromOffset(80, 29), false
UI.stroke(matchClock, colors.outline)
local clockText = UI.label(matchClock, "", 18, {font = Enum.Font.RobotoMono, color = colors.mint, align = CENTER, ellipsis = true})
clockText.Size = UDim2.fromScale(1, 1)
local turnPrompt = UI.box(root, "TurnPrompt")
turnPrompt.AnchorPoint, turnPrompt.Position = Vector2.new(.5, 1), UDim2.new(.5, 0, 1, -12)
turnPrompt.Size = UDim2.fromOffset(264, 48)
local dealButton: TextButton? = nil
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
		for _, seat in snapshot.match.seats do if seat.id == id then return if seat.bot then t(seat.name) else seat.name end end
	end
	return "—"
end

local function preferencesLine(parent: Instance, name: string, label: string, press: () -> ())
	UI.button(parent, name, label, 42, press)
end
local render: () -> ()
local picker: Frame
local function chooseLanguage(lang: string, manual: boolean)
	russian = lang == "ru"
	languageRevision += 1
	picker.Visible = false
	resultBanner.hide()
	tableView.relocalize()
	if opened == "inspect" then opened = ""; propertyCard.hide() end
	if manual then
		task.spawn(function()
			ReplicatedStorage:WaitForChild("WorldDraft"):WaitForChild("Language"):FireServer(lang)
		end)
	end
	render()
end
picker = require(script.Parent.LanguagePicker)(root,function(lang) chooseLanguage(lang,true) end)
local languageButton = UI.button(root,"ChangeLanguage","",40,function() picker.Visible=true end,colors.panel)
languageButton.AnchorPoint,languageButton.Position,languageButton.Size = Vector2.new(1,0),UDim2.new(1,-12,0,6),UDim2.fromOffset(106,40)

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
	if (inTrade and (not myMove or s.tradeUsed)) or (opened == "tradeReply" and not (snapshot and snapshot.trade)) then
		opened = ""
	end
	tradeHelp = nil
	replyActions.Visible = opened == "tradeReply"
	replyActions:ClearAllChildren()
	dialogShade.Visible = opened ~= ""
	if opened == "" then return end
	dialogTitle.Text = t(if opened == "rules" then "HOW TO PLAY" elseif opened == "cell" then "BOARD CELL"
		elseif inTrade or opened == "tradeReply" then "CLUB DEAL" else "PROPERTY LEDGER")
	constraint.MaxSize = if opened == "cell"  then Vector2.new(390, 320) else Vector2.new(530, 590)
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
				UI.label(card, t("Each additional venue doubles the visiting fee."), 13, {color = colors.ink})
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
				elseif tile.kind == "championship" then t("A goal wins a cup and a cash bonus. A safe play keeps your budget steady.")
				elseif tile.kind == "chance" then t("Draw a card, earn a sponsor bonus, protect a club or shoot on goal.")
				else t("Crossing Kickoff pays %d CR.", Board.kickoffCash)
			UI.label(card, text, 14, {color = colors.ink})
		end
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
					UI.button(dialogBody, "TradePlayer" .. seat.id, sessionName(seat.id) .. (if seat.bot then " · " .. t("Bot") else ""), 44, function()
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
					local button = UI.button(row, "TradePrice" .. option, t("%d CR", price), 44,
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
					if difference ~= 0 then label ..= t("  /  %+d CR", difference) end
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
		local give = if terms.requested == 0 then t("%d CR", terms.price) else t(Board.tiles[terms.requested].name)
		if terms.requested ~= 0 then
			if terms.price < 0 then receive ..= t(" + %d CR", -terms.price) end
			if terms.price > 0 then give ..= t(" + %d CR", terms.price) end
		end
		UI.label(dialogBody, t("You receive %s", receive), 19, {font = BLACK})
		UI.label(dialogBody, t("You give %s", give), 16, {color = colors.text})
		local accept = UI.button(replyActions, "TradeAccept", t("Accept"), 44, function() send("tradeAccept") end, colors.mint, colors.ink)
		accept.Size = UDim2.new(.5, -4, 1, 0)
		local decline = UI.button(replyActions, "TradeDecline", t("Decline"), 44, function() send("tradeDecline") end)
		decline.Position, decline.Size = UDim2.new(.5, 4, 0, 0), UDim2.new(.5, -4, 1, 0)

	elseif opened == "rules" then
		local topics = {
			{"Roll two dice", "The sum moves your figure clockwise. Rolling doubles gives another roll. Three doubles send you to the bench."},
			{"Clubs and rent", "Buy a free club, build when you land on yours, or pay rent on a rival's club. Some clubs can be repurchased after paying rent."},
			{"Club deals", "Before rolling, you can propose one trade or sale. The other player must accept."},
			{"Away tour and championship", "On your next turn, Away tour lets you select any destination. Choose a club to host the championship and double its rent."},
			{"Matchday", "On Championship and some Chance cells, shoot for a trophy or take a guaranteed bonus."},
			{"Win the table", "Win with three leagues, an entire side or all four venues. You also win as the last solvent player or by leading in value at full time."},
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
		preferencesLine(dialogBody, "Language", t("Game language · English"), function() picker.Visible=true end)
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
		UI.label(dialogBody, t("Complete leagues or collect all four venues."), 13, {color = colors.muted})
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
			end
	dialogBody.CanvasPosition = offset
end

local function show(name: string)
	opened = if opened == name then "" else name
	dialogBody.CanvasPosition = Vector2.zero
	drawDialog()
end
dialogShade.Activated:Connect(function() show(opened) end)
local rulesButton = PropertyCard.button(root, "Rules", "?", function() show("rules") end)
local clubsButton = PropertyCard.button(root, "Clubs", "≡", function() show("clubs") end)
dealButton = PropertyCard.button(root, "ClubDeals", "⇄", function() show("tradeClubs") end)
dealButton.AnchorPoint, dealButton.Position, dealButton.Size = Vector2.new(1, .5), UDim2.new(1, -11, .62, 0), UDim2.fromOffset(41, 41)
local followTurn = false
local cameraView: TextButton
local function toggleCamera()
	followTurn = not followTurn
	tableView.setFollow(followTurn)
	cameraView.Text = t(if followTurn then "Full board" else "Follow turn")
end
cameraView = UI.button(root, "BoardCamera", t("Follow turn"), 43, toggleCamera, colors.ink, colors.text)
cameraView.AnchorPoint, cameraView.Position = Vector2.new(0, 1), UDim2.new(0, 12, 1, -83)
cameraView.Size, cameraView.Visible = UDim2.fromOffset(110, 43), false
UI.stroke(cameraView, colors.outline)
local closeButton = UI.button(dialog, "Close", "", 40, function() show(opened) end)
closeButton.AnchorPoint, closeButton.Position, closeButton.Size = Vector2.new(1, 0), UDim2.new(1, -12, 0, 9), UDim2.fromOffset(104, 40)

local function arrange()
	local size = root.AbsoluteSize
	mode = if size.X >= 630 then "dock" else "portrait"
	local shortLandscape = size.X > size.Y and size.Y < 430
	if dealButton then
		dealButton.Position = if size.X < size.Y * .86 then UDim2.new(1, -111, 1, -104) else UDim2.new(1, -11, .62, 0)
	end
	scores.AnchorPoint = if shortLandscape then Vector2.new(0,.5) else Vector2.new(.5,0)
	scores.Position = if shortLandscape then UDim2.new(0,6,.49,0) else UDim2.new(.5,0,0,if size.X>=1040 then 8 else 41)
	turnPrompt.AnchorPoint = if shortLandscape then Vector2.new(1,1) else Vector2.new(.5,1)
	turnPrompt.Size = UDim2.fromOffset(if shortLandscape then 94 else 264,48)
	turnPrompt.Position = if shortLandscape then UDim2.new(1,-4,1,-6) else UDim2.new(.5,0,1,-12)
	if shortLandscape and dealButton then dealButton.Position = UDim2.new(1,-7,.19,0) end
	brand.Visible = not shortLandscape
	matchClock.AnchorPoint = if shortLandscape then Vector2.new(0, 1) else Vector2.new(1, 0)
	matchClock.Position = if shortLandscape then UDim2.new(0, 13, 1, -12) else UDim2.new(1, -13, 0, 6)
	for i, control in {rulesButton, clubsButton} do
		control.AnchorPoint = Vector2.new(1, .5)
		control.Position = if size.X < size.Y * .86 then UDim2.new(1,-11-(i-1)*50,1,-104)
			elseif shortLandscape then UDim2.new(1,-7,.19,49*i) else UDim2.new(1, -11, .70 + (i - 1) * .08, 0)
		control.Size = UDim2.fromOffset(41, 41)
	end
	panel.AnchorPoint, panel.Position = Vector2.new(.5, .5), UDim2.fromScale(.5, .53)
	panel.Size = UDim2.fromOffset(math.max(230, math.min(560, size.X - 58)), math.max(172, math.min(302, size.Y - 106)))
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

local portraits: {[number]: ViewportFrame} = {}
local function scorecards(s: any)
	for _, portrait in portraits do portrait.Parent = nil end
	-- Keep the scoreboard outline while updating player records.
	for _, child in scores:GetChildren() do
		if child:IsA("Frame") then child:Destroy() end
	end
	scores.Visible = s ~= nil
	if not s then
		for _, portrait in portraits do portrait:Destroy() end
		table.clear(portraits)
		return
	end
	local compact = root.AbsoluteSize.X < 630 or root.AbsoluteSize.Y < 430
	local outerWidth = math.clamp(root.AbsoluteSize.X - 24, 0, 696)
	local height = if compact then 47 else 58
	local stacked = root.AbsoluteSize.X > root.AbsoluteSize.Y and root.AbsoluteSize.Y < 430
	local width = if stacked then 92 else outerWidth / #s.seats
	scores.Size = if stacked then UDim2.fromOffset(width,height*#s.seats) else UDim2.fromOffset(outerWidth,height)
	local portraitSize = if compact then 0 else 44
	for i, seat in s.seats do
		local active = s.active == i and s.phase ~= "final"
		local tint = Art.seatColors[i]
		local card = UI.box(scores, "Seat" .. i, if active then tint:Lerp(colors.panel, .82) else colors.panel, 4)
		card.Position = if stacked then UDim2.fromOffset(3,(i-1)*height+3) else UDim2.fromOffset((i-1)*width+3,3)
		card.Size = UDim2.fromOffset(width-6,height-6)
		local band = UI.box(card, "Team accent", tint)
		band.Position, band.Size = UDim2.new(0, 3, 1, -3), UDim2.new(1, -6, 0, if active then 3 else 1)
		local textInset = if compact then 5 else portraitSize + 10
		local textWidth = UDim2.new(1, -textInset - 3, 0, 18)
		local name = UI.label(card, sessionName(seat.id), 12,
			{font = BOLD, color = if active then tint else colors.muted, ellipsis = true, name = "PlayerName"})
		name.Position, name.Size = UDim2.fromOffset(textInset, if compact then 2 else 6), textWidth
		local money = UI.label(card, if seat.bankrupt then t("Bankrupt") else t("%d CR",seat.cash), 15,
			{font = BLACK, color = colors.text, ellipsis = true, name = "Balance"})
		money.Position, money.Size = UDim2.fromOffset(textInset, if compact then 18 else 26), textWidth
		if compact then continue end
		local avatar = UI.box(card, "Figure", tint:Lerp(colors.ink, .73), 4)
		avatar.Position, avatar.Size = UDim2.fromOffset(4, 3), UDim2.fromOffset(portraitSize, portraitSize)
		local miniature = portraits[seat.figure]
		if not miniature then
			miniature = Instance.new("ViewportFrame")
			miniature.Name, miniature.BackgroundTransparency, miniature.Size = "PlayerPortrait", 1, UDim2.fromScale(1, 1)
			miniature.Ambient, miniature.LightColor = hex(0xB6BBCB), hex(0xFFF3D7)
			miniature.LightDirection = Vector3.new(-1, -2, -4)
			local camera = Instance.new("Camera")
			camera.FieldOfView = 27
			local eyeLine = 0.45 + 5.62 * Board.figures[seat.figure].height
			local target = Vector3.new(0, eyeLine - .43, 0)
			camera.CFrame = CFrame.lookAt(target + Vector3.new(.78, .26, 5.05), target)
			camera.Parent, miniature.CurrentCamera = miniature, camera
			Pawn.make(seat.figure, miniature, true)
			portraits[seat.figure] = miniature
		end
		miniature.Parent = avatar
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
	footer(132)
	local figure = Board.figures[selected]
	local figureColor = hex(figure.color)
	local feature = UI.box(body, "FootballerCard", colors.surface, 12)
	feature.Size = UDim2.new(1, 0, 0, if mode == "dock" then 170 else 104)
	UI.stroke(feature, figureColor:Lerp(colors.outline, 0.54))
	local textArea = UI.box(feature, "FootballerDetails")
	textArea.Position, textArea.Size = UDim2.new(0, 11, 0, if mode == "dock" then 16 else 5), UDim2.new(0.60, -11, 1, -16)
	UI.stack(textArea, 3)
	UI.label(textArea, "#" .. figure.number .. "  /  " .. t("Choose your figure"), 10, {font = BOLD, color = figureColor})
	UI.label(textArea, if russian then figure.localName else figure.name, if #figure.name > 15 then 17 else 20, {font = BLACK})
	UI.label(textArea, if russian then figure.ru else figure.role, 13, {font = BOLD, color = figureColor})

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "FootballerPreview"
	viewport.BackgroundTransparency = 1
	viewport.Position, viewport.Size = UDim2.new(0.56, 0, 0, 2), UDim2.new(0.44, -4, 1, -4)
	viewport.LightColor, viewport.Ambient, viewport.LightDirection = hex(0xFFFFFF), hex(0xC5DCFA), Vector3.new(-2, -5, -6)
	viewport.Parent = feature
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	local bust = Vector3.new(0, .45 + figure.height * 4.95, 0)
	camera.CFrame = CFrame.lookAt(bust + Vector3.new(.98, .34, 6.65), bust)
	camera.Parent, viewport.CurrentCamera = viewport, camera
	tableView.preview(Pawn.make(selected, viewport))

	local row = UI.box(actions, "FigurePicker")
	row.Size = UDim2.new(1, 0, 0, 43)
	for i, candidate in Board.figures do
		local available = i ~= selected and not taken[i]
		local b = UI.button(row, "Figure" .. i, candidate.countryCode, 43, if available then function() send("figure", i) end else nil,
			if i == selected then hex(candidate.color) else colors.surface,
			if i == selected then colors.ink elseif available then hex(candidate.color) else colors.muted)
		local count = #Board.figures
		b.Position, b.Size = UDim2.new((i - 1) / count, 0, 0, 0), UDim2.new(1 / count, -4, 0, 43)
	end
	local isHost = data.host == Player.UserId
	if isHost then primary = function() send("start") end end
	local format = UI.button(actions, "MatchFormat", t(Board.formats[data.format].label), 34,
		if isHost then function() send("format", 3 - data.format) end else nil, colors.surface, colors.text)
	format.Position = UDim2.fromOffset(0, 47)
	local start = UI.button(actions, "StartSeason", t(if isHost then "Start season" else "Waiting for the host"), 48, primary,
		if isHost then colors.mint else colors.surface, if isHost then colors.ink else colors.muted)
	start.Position = UDim2.fromOffset(0, 84)
end

local function showContract(data: any, seat: any, choice: number?)
	local s = data.match
	local phaseKey = s.phase
	local index = seat.position
	local tile, holding = Board.tiles[index], s.clubs[index]
	local offer, upgrade, rebuy = phaseKey == "offer", phaseKey == "upgrade", phaseKey == "rebuy"
	local minimum = if upgrade then holding.level + 1 else 0
	local level = choice or minimum
	local price = if rebuy then Game.rebuyPrice(s, index) else Game.buildPrice(s, index, level)
	local verb = if offer then "buy" elseif upgrade then "upgrade" else "rebuy"
	local accept = function() send(verb, if rebuy then nil else level) end
	local dismiss = function() send("skip") end
	primary, alternate = accept, dismiss
	local rows = nil
	if not rebuy and tile.league > 0 then
		rows = {}
		for desired = minimum, Board.maxLevel do
			local cost = Game.buildPrice(s, index, desired)
			local rent = Game.tourRentAt(s, index, desired)
			local pick = if seat.cash >= cost then function() showContract(data, seat, desired) end else nil
			table.insert(rows, {cells = {t("Level %d", desired), tostring(cost), tostring(rent)}, highlighted = desired == level, press = pick})
		end
	end
	propertyCard.show({
		index = index, level = if rebuy then holding.level else level, title = t(tile.name),
		summary = t(if offer then "Buy club for %d CR" elseif upgrade then "Build for %d CR" else "Repurchase club for %d CR", price),
		footer = t("Remaining balance: %d CR", seat.cash - price),
		actionName = if offer then "SignClub" elseif upgrade then "Upgrade" else "RebuyClub",
		actionLabel = t(if upgrade then "Build · %d CR" elseif offer then "Buy · %d CR" else "Repurchase · %d CR", price),
		action = accept, closeLabel = t("Cancel"), close = dismiss,
		columns = {t("Level"), t("Cost"), t("Rent")}, levels = rows,
	})
end

local function showInspection(data: any, index: number)
	local tile = Board.tiles[index]
	local holding = data and data.match and data.match.clubs[index]
	local owned = holding and holding.owner ~= 0
	opened = "inspect"
	local rates = nil
	if tile.league > 0 then
		rates = {}
		for level = 0, Board.maxLevel do
			local fee = if data and data.match then Game.tourRentAt(data.match, index, level) else tile.gate + level * Board.upgradeGate
			local buyout = 2 * (tile.price + level * Board.upgradeCost)
			table.insert(rates, {
				cells = {t("Level %d", level), tostring(tile.price + level * Board.upgradeCost), tostring(fee), tostring(buyout)},
				highlighted = owned and holding.level == level,
			})
		end
	end

	propertyCard.show({
		index = index, level = if holding then holding.level else 0, title = t(tile.name),
		summary = if tile.price > 0 then t("Price %d CR · Rent %d CR", tile.price, if owned then data.gates[index] else tile.gate)
			else t("Special cell"),
		footer = if owned then t("Owner: %s", sessionName(holding.owner)) else if tile.price > 0 then propertyGroup(tile) else "",
		closeLabel = t("Close"), close = function() opened = ""; propertyCard.hide() end,
		actionName = "ManageClub", actionLabel = t("Manage club"),
		columns = {t("Level"), t("Cost"), t("Rent"), t("Buyout")}, levels = rates,
		action = if owned and holding.owner == Player.UserId then function() propertyCard.hide(); show("cell") end else nil,
	})
end

local function rollPanel(s: any, mine: boolean)
	local player = s.seats[s.active]
	if mine then
		primary = function() send("roll") end
		local canRelease = s.phase == "bench" and player.cash >= Board.benchFee
		local button = UI.button(turnPrompt, "RollDice", t("Roll dice"), 46, primary, colors.mint, colors.ink)
		button.Size = UDim2.new(if canRelease then .58 else 1, 0, 1, 0)
		if canRelease then
			alternate = function() send("release") end
			local release = UI.button(turnPrompt, "BenchRelease", t("Pay %d CR", Board.benchFee), 46, alternate)
			if turnPrompt.AbsoluteSize.X < 120 then
				button.Size = UDim2.fromScale(1,1)
				release.Position, release.Size = UDim2.fromScale(0,-1.04), UDim2.fromScale(1,1)
			else
				release.Position, release.Size = UDim2.fromScale(.60,0), UDim2.fromScale(.40,1)
			end
		end
	else
		local rail = UI.box(turnPrompt, "Turn status", colors.ink, 5)
		rail.Size = UDim2.fromScale(1, 1)
		UI.stroke(rail, colors.outline)
		local message = UI.label(rail, t("%s's turn", sessionName(player.id)), 15,
			{font = BOLD, color = colors.text, align = CENTER, ellipsis = true})
		message.Size = UDim2.fromScale(1, 1)
	end
end

local function matchdayPanel(s: any, seat: any)
	title("Matchday", t("A goal earns %d CR and a trophy. A save earns %d CR. Offside costs %d CR.",
		shotCash.goal, shotCash.save, -shotCash.offside))
	local canHost = false
	if s.last.kind == "championship" then
		for index, asset in s.clubs do
			if asset.owner == seat.id and Board.tiles[index].league > 0 then
				canHost = true
				break
			end
		end
	end
	footer(if canHost then 89 else 43)
	primary = function() send("shoot") end
	alternate = function() send("safe") end
	local shoot = UI.button(actions, "MatchdayShoot", t("Shoot · %d%% goal", math.round(Game.goalChance * 100)),
		43, primary, colors.mint, colors.ink)
	local safe = UI.button(actions, "MatchdaySafe", t("Play safe · +%d CR", Edition.safe_cash), 43, alternate)
	shoot.Size, safe.Size = UDim2.new(.5, -3, 0, 43), UDim2.new(.5, -3, 0, 43)
	safe.Position = UDim2.new(.5, 3, 0, 0)
	if canHost then
		local host = UI.button(actions, "MatchdayHost", t("Host championship"), 41, function() send("host") end)
		host.Position = UDim2.fromOffset(0, 48)
	end
end

local function selectionPanel(s: any, seat: any)
	local debt = s.phase == "debt"
	local travel, shielding = s.phase == "tour", s.phase == "shield"
	title(if debt then t("Pay %d CR", s.debt.amount) elseif travel then "Choose a destination"
		elseif shielding then "Choose a club to protect" else "Choose a host club")
	UI.label(body, t(if debt then "Sell assets to pay your bill." else "Select a cell on the board or a name below."), 14, {color = colors.text})
	for index, tile in Board.tiles do
		local selectable = if travel then index ~= seat.position else s.clubs[index].owner == seat.id and (debt or tile.league > 0) and (not shielding or not s.clubs[index].shield)
		if selectable then
			UI.button(body, "SelectCell" .. index, t(tile.name), 43,
				function() send(if debt then "sell" elseif travel then "travel" elseif shielding then "shield" else "festival", index) end)
		end
	end
	footer(if travel then 0 else 43)
	if not travel then
		UI.button(actions, if debt then "Bankrupt" else "Skip", t(if debt then "Declare bankruptcy" else "Pass"), 43,
			function() send(if debt then "bankrupt" else "skip") end)
	end
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

local function finishPanel(s: any)
	local sharedTitle = not s.winner and s.standings[1].score == s.standings[2].score
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
		local winner = if s.winner then record.id == s.winner else record.score == s.standings[1].score
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
	closeButton.Text = t("Close")
	body:ClearAllChildren()
	body.CanvasPosition = Vector2.zero
	UI.stack(body, 4)
	UI.pad(body, 4, 1, 5)
	turnPrompt:ClearAllChildren()
	footer(0)
	local data = snapshot
	local s = data and data.match
	scorecards(s)
	languageButton.Visible,languageButton.Text = s == nil, if russian then "Язык · RU" else "Language · EN"
	matchClock.Visible = s ~= nil and s.phase ~= "final"
	local shot = root:GetAttribute("ShotPlaying") == true
	rulesButton.Visible, clubsButton.Visible, turnPrompt.Visible = not shot, not shot, not shot
	local now = workspace:GetServerTimeNow()
	local waiting = s and now < data.availableAt
	local seat = s and s.seats[s.active]
	local mine = seat and seat.id == Player.UserId and not seat.bot
	if dealButton then dealButton.Visible = not shot and mine and s.phase == "move" and not s.tradeUsed end
	panel.Visible = s == nil or (not waiting and (data.auction ~= nil or s.phase == "final"
		or (mine and (s.phase == "matchday" or s.phase == "championship" or s.phase == "debt" or s.phase == "tour" or s.phase == "shield"))))
	if opened ~= "inspect" then propertyCard.hide() end
	if not data then
		phase.Text = "SOCCERPOLY"
		title("Connect to table…")
	elseif not s then
		phase.Text = t("SELECT A FIGURE")
		lobbyPanel(data)
	elseif s.phase == "final" then
		phase.Text = string.upper(t("Final whistle"))
		finishPanel(s)
	elseif not waiting then
		if data.auction then
			phase.Text = t("TRANSFER AUCTION")
			auctionPanel(s, data.auction)
		elseif mine and (s.phase == "offer" or s.phase == "upgrade" or s.phase == "rebuy") then
			opened = ""
			showContract(data, seat)
		elseif mine and s.phase == "matchday" then
			phase.Text = t(Board.tiles[seat.position].name)
			matchdayPanel(s, seat)
		elseif mine and (s.phase == "championship" or s.phase == "debt" or s.phase == "tour" or s.phase == "shield") then
			phase.Text = if s.phase == "debt" then t("Settlement") else t(Board.tiles[seat.position].name)
			selectionPanel(s, seat)
		elseif s.phase == "move" or s.phase == "bench" then
			rollPanel(s, mine)
		end
	end
	local screen = root.AbsoluteSize
	cameraView.Visible = not shot and s ~= nil and s.phase ~= "final" and screen.X < screen.Y * .86 and not panel.Visible
	cameraView.Text = t(if followTurn then "Full board" else "Follow turn")
	if opened ~= "inspect" then drawDialog() else dialogShade.Visible = false end
end

root:GetAttributeChangedSignal("ShotPlaying"):Connect(function() render() end)
root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	arrange()
	render()
end)
arrange()
render()
Input.InputBegan:Connect(function(input, captured)
	if Input:GetFocusedTextBox() then return end
	if picker.Visible then
		if input.KeyCode == Enum.KeyCode.R then chooseLanguage("ru",true)
		elseif input.KeyCode == Enum.KeyCode.E then chooseLanguage("en",true) end
		return
	end
	if captured then return end
	if input.KeyCode == Enum.KeyCode.L then picker.Visible=true return end
	if opened ~= "" then
		if input.KeyCode == Enum.KeyCode.Escape then
			if opened == "inspect" then opened = ""; propertyCard.hide() else show(opened) end
		end
		return
	end
	if input.KeyCode == Enum.KeyCode.V and cameraView.Visible then
		toggleCamera()
	elseif input.KeyCode == Enum.KeyCode.One or input.KeyCode == Enum.KeyCode.Return then
		if primary then primary() end
	elseif input.KeyCode == Enum.KeyCode.Two then
		if alternate then alternate() end
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then

		local index = tableView.pickTile(input.Position)
		if index then
			local s = snapshot and snapshot.match
			local mine = s and s.seats[s.active].id == Player.UserId
			if mine and s.phase == "tour" then send("travel", index)
			elseif mine and (s.phase == "championship" or s.phase == "shield") and s.clubs[index].owner == Player.UserId and Board.tiles[index].league > 0 then
				send(if s.phase == "shield" then "shield" else "festival", index)
			else
				inspected = index
				showInspection(snapshot, index)
			end
		end
	end
end)

task.spawn(function()
	while gui.Parent do
		local remaining = if snapshot and snapshot.deadline > 0 then math.max(0, math.ceil(snapshot.deadline - workspace:GetServerTimeNow())) else nil
		countdown.Text = if remaining then string.format(":%02d", remaining) else ""
		if snapshot and snapshot.match and snapshot.matchEndsAt then
			local balance = math.max(0, math.ceil(snapshot.matchEndsAt - workspace:GetServerTimeNow()))
			clockText.Text = string.format("%02d:%02d", math.floor(balance / 60), balance % 60)
		end
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
	goal = "GOAL!", offside = "Offside", save = "Save", safe = "Guaranteed bonus",
	sponsor = "Sponsor bonus", festival = "Championship awarded",
	buy = "Club signed", upgrade = "Stadium upgraded", league = "League complete",
	tradeSale = "Club sold", tradeSwap = "Clubs swapped", var = "VAR review",
	shield = "Club protected", shieldDrawn = "Club shield", sentOff = "Sent to the bench", rebuy = "Club repurchased",
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
	if data.match and data.availableAt > workspace:GetServerTimeNow() then
		task.delay(data.availableAt - workspace:GetServerTimeNow() + .04, function()
			if snapshot == data then render() end
		end)
	end
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
				(if last.kind == "tradeSwap" then t(Board.tiles[last.otherTile].name) else t("%d CR", last.amount))
		elseif last.kind == "goal" or last.kind == "save" or last.kind == "offside"
			or last.kind == "safe" or last.kind == "sponsor" then
			caption = name .. t("  /  %+d CR", last.amount)
			if last.kind == "goal" then
				caption ..= "  /  " .. t("+1 trophy")
				tint = GOLD
			elseif last.kind == "offside" then
				tint = colors.pink
			end
		elseif last.kind == "sold" then
			caption = name .. "  /  " .. t(Board.tiles[last.tile].name) .. t("  /  +%d CR", last.amount)
		elseif last.card > 0 then
			local card = Edition.cards[last.card]
			headline = if russian then card.ru else card.title
			caption = name .. (if card.kind == "bench" then "  /  " .. t("Next turn") else t("  /  %+d CR", last.amount))
			tint = if card.kind == "bench" then GOLD else colors.blue
		elseif last.kind == "auctionWon" or last.kind == "auctionLeague" then
			caption = name .. "  /  " .. t(Board.tiles[last.tile].name) .. t("  /  %d CR", -last.amount)
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
		local revision = languageRevision
		local title = t(headline)
		local exciting = final or last.kind == "goal" or last.kind == "league" or last.kind == "auctionLeague"
		local shot = not final and last.card == 0 and (last.kind == "goal" or last.kind == "save" or last.kind == "offside")
		local function reveal()
			if revision ~= languageRevision then return end
			if snapshot.serial ~= data.serial or not snapshot.match then return end
			if not final and snapshot.match.phase == "final" then return end
			if not final and not shot then
				audio.play(if last.card > 0 or last.kind == "auctionEmpty" then "card" else "sign")
			end
			resultBanner.reveal(title, caption, tint, reduced())
			if exciting then
				tableView.stadiumMessage(title, tint)
				tableView.celebrate(last.tile, true)
			elseif last.kind == "upgrade" then
				tableView.celebrate(last.tile, false)
			end
		end
		if shot then
			for _, actor in match.seats do
				if actor.id == last.who then
					tableView.playShot(last.kind, actor.figure, reveal)
					return
				end
			end
		end
		reveal()
	end)
end)

local function restoreLanguage()
	local saved = Player:GetAttribute("TableLanguage")
	if languageRevision == 0 and (saved == "ru" or saved == "en") and russian ~= (saved == "ru") then
		chooseLanguage(saved,false)
	end
end
Player:GetAttributeChangedSignal("TableLanguage"):Connect(restoreLanguage)
restoreLanguage()

repeat
	intent:FireServer("sync")
	task.wait(1)
until snapshot ~= nil
