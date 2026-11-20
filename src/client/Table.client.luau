--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local GuiService = game:GetService("GuiService")
local Input = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local Player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("League")
local Board = require(shared.TourBoard)
local Geometry = require(shared.Geometry)
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
local Print = require(script.Parent.MatchPrint)
local TweenService = game:GetService("TweenService")
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

local brand = UI.box(root, "Soccerpoly wordmark", colors.paper, 4)
brand.Position, brand.Size = UDim2.fromOffset(13, 8), UDim2.fromOffset(151, 28)
local crest = UI.box(brand, "Cup field", colors.panel, 3)
crest.Size = UDim2.fromOffset(30,28)
local crestMark = Print.mark(crest, "cup", colors.gold, 23)
crestMark.Position = UDim2.fromOffset(3,2)
local brandText = UI.label(brand, "SOCCERPOLY", 18, {color = colors.ink, ellipsis = true})
brandText.FontFace = Print.display
brandText.Position, brandText.Size = UDim2.fromOffset(37, 0), UDim2.new(1, -39, 1, 0)
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
local panel = UI.box(root, "MatchPanel", colors.panel, 6)
panel.Active = true
UI.stroke(panel, colors.outline)
local topLine = UI.box(panel, "KickoffLine", colors.gold, 1)
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

local function sponsorCard(parent: Instance)
	local vip = Player:GetAttribute("CareerIsVip") == true
	if not vip and ((Player:GetAttribute("CareerMatches") or 0) < 1 or Player:GetAttribute("CareerVipVerified") ~= true) then return end
	local card = UI.box(parent, "VipCard", colors.surface, 10)
	card.Size, card.AutomaticSize = UDim2.new(1, 0, 0, 0), Enum.AutomaticSize.Y
	UI.pad(card, 12, 10)
	UI.stroke(card, if vip then colors.mint else GOLD)
	UI.stack(card, 4)
	UI.label(card, t(if vip then "VIP Active · +25% XP Bonus" else "VIP Sponsor Pass"), 15, {font = BLACK, color = GOLD})
	UI.label(card, t("Unlock Obsidian Gold dice, Champion's Halo aura and +25% XP bonus!"), 13, {color = colors.text})
	if not vip then
		local buy = UI.button(card, "BuyVipBtn", t("View price in Robux"), 36, function()
			game:GetService("MarketplaceService"):PromptGamePassPurchase(Player, require(shared.SponsorPass))
		end, GOLD, colors.ink)
		buy.Size = UDim2.new(1, 0, 0, 36)
	end
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
		elseif inTrade or opened == "tradeReply" then "CLUB DEAL" elseif opened == "career" then "CAREER & LOCKER" else "PROPERTY LEDGER")
	constraint.MaxSize = if opened == "cell" then Vector2.new(390, 320) elseif opened == "career" then Vector2.new(480, 560) else Vector2.new(530, 590)
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
			elseif s and club.owner == Player.UserId and club.level < Board.maxLevel then
				UI.label(card, t("Land on your club to upgrade up to level %d.", Board.maxLevel), 13, {color = colors.ink})
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
			local text = if tile.kind == "tax" then t("Pay league tax (%d CR).", math.abs(tile.award))
				elseif tile.kind == "tour" then t("On your next turn, travel to any destination on the board.")
				elseif tile.kind == "bench" then t("Rest on the bench. Roll doubles to return, or pay %d CR.", Board.benchFee)
				elseif tile.kind == "championship" then t("A goal wins a cup and a cash bonus. A safe play keeps your budget steady.")
				elseif tile.kind == "chance" then t("Draw a card, earn a sponsor bonus, protect a club or shoot on goal.")
				elseif tile.kind == "goalDeck" then t("Draw a reward from the Goal deck.")
				elseif tile.kind == "offsideDeck" then t("Draw a penalty or bench card.")
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
	elseif opened == "career" then
		local level = Player:GetAttribute("CareerLevel") or 1
		local curXp = Player:GetAttribute("CareerLevelCurXp") or 0
		local neededXp = math.max(1, Player:GetAttribute("CareerLevelNeededXp") or 120)
		local matches = Player:GetAttribute("CareerMatches") or 0
		local wins = Player:GetAttribute("CareerWins") or 0
		local trophies = Player:GetAttribute("CareerTrophies") or 0
		local streak = Player:GetAttribute("CareerLoginStreak") or 1
		local equippedDice = (Player:GetAttribute("CareerEquippedDice") :: string?) or "ivory_classic"
		local equippedAura = (Player:GetAttribute("CareerEquippedAura") :: string?) or "mint_classic"
		local unlockedJson = Player:GetAttribute("CareerUnlocked")
		local unlocked = {}
		if type(unlockedJson) == "string" then
			pcall(function() unlocked = HttpService:JSONDecode(unlockedJson) end)
		end
		unlocked["ivory_classic"] = true
		unlocked["mint_classic"] = true

		local header = UI.box(dialogBody, "ProfileHeader", colors.surface, 10)
		header.Size, header.AutomaticSize = UDim2.new(1, 0, 0, 0), Enum.AutomaticSize.Y
		UI.pad(header, 14, 12)
		UI.stack(header, 4)
		UI.label(header, t("Manager Level %d", level), 20, {font = BLACK, color = GOLD})
		UI.label(header, t("Matches: %d  ·  Wins: %d  ·  Cups: %d", matches, wins, trophies), 14, {font = BOLD, color = colors.text})
		UI.label(header, t("Login Streak: %d days", streak), 13, {color = colors.mint})

		local barBg = UI.box(header, "XpBarBg", colors.panel, 4)
		barBg.Size = UDim2.new(1, 0, 0, 8)
		local barFill = UI.box(barBg, "XpFill", colors.mint, 4)
		barFill.Size = UDim2.fromScale(math.clamp(curXp / neededXp, 0.05, 1), 1)

		local canSpin = Player:GetAttribute("CareerCanSpin") ~= false
		local spinBanner = UI.button(dialogBody, "WheelBtn", t("Daily Lucky Spin") .. (if canSpin then " ✦ (" .. t("Spin Available!") .. ")" else " (" .. t("Next spin tomorrow") .. ")"), 38, function()
			show("wheel")
		end, if canSpin then GOLD else colors.surface, if canSpin then colors.ink else colors.muted)
		spinBanner.Size = UDim2.new(1, 0, 0, 38)

		sponsorCard(dialogBody)

		UI.label(dialogBody, t("DICE SKINS"), 15, {font = BOLD, color = colors.mint})
		local diceItems = {
			{"ivory_classic", "Classic Ivory", 1},
			{"carbon_stealth", "Carbon Stealth", 2},
			{"neon_cyber", "Neon Cyber", 4},
			{"gold_championship", "Championship Gold", 6},
			{"obsidian_gold", "Obsidian Gold", 99},
		}
		for _, item in diceItems do
			local id, name, reqLevel = item[1], item[2], item[3]
			local isUnlocked = (reqLevel < 99 and level >= reqLevel) or unlocked[id] == true
			local isEquipped = equippedDice == id
			local row = UI.box(dialogBody, "Dice_" .. id, colors.surface, 8)
			row.Size = UDim2.new(1, 0, 0, 44)
			UI.pad(row, 10, 0)
			local nameLabel = UI.label(row, t(name), 14, {font = BOLD, color = if isEquipped then GOLD else (if isUnlocked then colors.text else colors.muted)})
			nameLabel.Position = UDim2.fromScale(0, 0.15)
			nameLabel.Size = UDim2.new(0.60, 0, 0.70, 0)
			local btnText = if isEquipped then t("Equipped") elseif isUnlocked then t("Equip") elseif reqLevel == 99 then t("VIP Exclusive") else t("Unlocks at Level %d", reqLevel)
			local btn = UI.button(row, "EquipBtn", btnText, 32, if isUnlocked and not isEquipped then function()
				local channel = ReplicatedStorage:WaitForChild("WorldDraft"):FindFirstChild("CareerAction")
				if channel and channel:IsA("RemoteEvent") then
					channel:FireServer("equip", "dice", id)
					audio.play("select")
				end
				drawDialog()
			end else nil, if isEquipped then colors.panel else (if isUnlocked then colors.mint else colors.panel),
				if isEquipped then colors.muted else (if isUnlocked then colors.ink else colors.outline))
			btn.AnchorPoint = Vector2.new(1, 0.5)
			btn.Position = UDim2.new(1, 0, 0.5, 0)
			btn.Size = UDim2.new(0.38, 0, 0, 32)
		end

		UI.label(dialogBody, t("AURA SKINS"), 15, {font = BOLD, color = colors.mint})
		local auraItems = {
			{"mint_classic", "Team Mint", 1},
			{"flame_trail", "Flame Trail", 3},
			{"golden_radiance", "Golden Radiance", 5},
			{"champions_halo", "Champion's Halo", 99},
		}
		for _, item in auraItems do
			local id, name, reqLevel = item[1], item[2], item[3]
			local isUnlocked = (reqLevel < 99 and level >= reqLevel) or unlocked[id] == true
			local isEquipped = equippedAura == id
			local row = UI.box(dialogBody, "Aura_" .. id, colors.surface, 8)
			row.Size = UDim2.new(1, 0, 0, 44)
			UI.pad(row, 10, 0)
			local nameLabel = UI.label(row, t(name), 14, {font = BOLD, color = if isEquipped then GOLD else (if isUnlocked then colors.text else colors.muted)})
			nameLabel.Position = UDim2.fromScale(0, 0.15)
			nameLabel.Size = UDim2.new(0.60, 0, 0.70, 0)
			local btnText = if isEquipped then t("Equipped") elseif isUnlocked then t("Equip") elseif reqLevel == 99 then t("VIP Exclusive") else t("Unlocks at Level %d", reqLevel)
			local btn = UI.button(row, "EquipAuraBtn", btnText, 32, if isUnlocked and not isEquipped then function()
				local channel = ReplicatedStorage:WaitForChild("WorldDraft"):FindFirstChild("CareerAction")
				if channel and channel:IsA("RemoteEvent") then
					channel:FireServer("equip", "aura", id)
					audio.play("select")
				end
				drawDialog()
			end else nil, if isEquipped then colors.panel else (if isUnlocked then colors.mint else colors.panel),
				if isEquipped then colors.muted else (if isUnlocked then colors.ink else colors.outline))
			btn.AnchorPoint = Vector2.new(1, 0.5)
			btn.Position = UDim2.new(1, 0, 0.5, 0)
			btn.Size = UDim2.new(0.38, 0, 0, 32)
		end

		UI.label(dialogBody, t("ACHIEVEMENTS"), 15, {font = BOLD, color = GOLD})
		local achievements = {
			{name = "First Victory", done = wins >= 1, desc = "1 win"},
			{name = "Continental Champion", done = trophies >= 1, desc = "1 trophy"},
			{name = "Grand Stadium", done = level >= 3, desc = "Level 3"},
			{name = "Club Tycoon", done = level >= 5, desc = "Level 5"},
		}
		local achGrid = UI.box(dialogBody, "AchGrid", colors.panel, 8)
		achGrid.Size, achGrid.AutomaticSize = UDim2.new(1, 0, 0, 0), Enum.AutomaticSize.Y
		UI.pad(achGrid, 10, 8)
		UI.stack(achGrid, 4)
		for _, ach in achievements do
			local achRow = UI.box(achGrid, ach.name, colors.surface, 6)
			achRow.Size = UDim2.new(1, 0, 0, 36)
			UI.pad(achRow, 8, 0)
			local status = if ach.done then "✓ " else "○ "
			local achTitle = UI.label(achRow, status .. t(ach.name), 13,
				{font = BOLD, color = if ach.done then colors.mint else colors.muted})
			achTitle.Position = UDim2.fromScale(0, 0.15)
			achTitle.Size = UDim2.new(0.65, 0, 0.70, 0)
			local achDesc = UI.label(achRow, ach.desc, 11,
				{font = BOLD, color = if ach.done then colors.text else colors.outline, align = RIGHT})
			achDesc.Position = UDim2.new(0.65, 0, 0.15, 0)
			achDesc.Size = UDim2.new(0.35, -4, 0.70, 0)
		end

		UI.label(dialogBody, t("DAILY CONTRACTS"), 15, {font = BOLD, color = colors.mint})
		local questsJson = Player:GetAttribute("CareerQuests")
		local quests = {}
		if type(questsJson) == "string" then
			pcall(function() quests = HttpService:JSONDecode(questsJson) end)
		end
		local questDisplay = {
			{id = "match", title = "Play 1 Match", reward = 150},
			{id = "sign", title = "Sign 2 Clubs", reward = 200},
			{id = "upgrade", title = "Upgrade 1 Stadium", reward = 250},
		}
		local questGrid = UI.box(dialogBody, "QuestGrid", colors.panel, 8)
		questGrid.Size, questGrid.AutomaticSize = UDim2.new(1, 0, 0, 0), Enum.AutomaticSize.Y
		UI.pad(questGrid, 10, 8)
		UI.stack(questGrid, 4)
		for _, qd in questDisplay do
			local q = quests[qd.id] or {progress = 0, goal = 1, claimed = false}
			local qRow = UI.box(questGrid, "Quest_" .. qd.id, colors.surface, 6)
			qRow.Size = UDim2.new(1, 0, 0, 42)
			UI.pad(qRow, 8, 0)
			local canClaim = q.progress >= q.goal and not q.claimed
			local qTitle = UI.label(qRow, t(qd.title) .. string.format(" (%d/%d)", q.progress, q.goal), 13,
				{font = BOLD, color = if q.claimed then colors.muted elseif q.progress >= q.goal then colors.mint else colors.text})
			qTitle.Position = UDim2.fromScale(0, 0.15)
			qTitle.Size = UDim2.new(0.60, 0, 0.70, 0)

			local btnText = if q.claimed then t("Claimed") elseif canClaim then t("Claim +%d XP", qd.reward) else string.format("+%d XP", qd.reward)
			local qBtn = UI.button(qRow, "ClaimQuestBtn", btnText, 30, if canClaim then function()
				local channel = ReplicatedStorage:WaitForChild("WorldDraft"):FindFirstChild("CareerAction")
				if channel and channel:IsA("RemoteEvent") then
					channel:FireServer("claim_quest", qd.id)
					audio.play("upgrade")
				end
				drawDialog()
			end else nil, if canClaim then colors.mint else colors.panel,
				if canClaim then colors.ink else (if q.claimed then colors.outline else colors.muted))
			qBtn.AnchorPoint = Vector2.new(1, 0.5)
			qBtn.Position = UDim2.new(1, 0, 0.5, 0)
			qBtn.Size = UDim2.new(0.38, 0, 0, 30)
		end
	elseif opened == "wheel" then
		titleLabel.Text = t("DAILY LUCKY WHEEL")
		local canSpin = Player:GetAttribute("CareerCanSpin") ~= false
		local wheelCenter = UI.box(dialogBody, "WheelWrapper", colors.surface, 12)
		wheelCenter.Size = UDim2.new(1, 0, 0, 260)
		UI.pad(wheelCenter, 10, 10)

		local wheelDisc = Instance.new("Frame")
		wheelDisc.Name = "WheelDisc"
		wheelDisc.Size = UDim2.fromOffset(170, 170)
		wheelDisc.AnchorPoint = Vector2.new(0.5, 0.5)
		wheelDisc.Position = UDim2.fromScale(0.5, 0.40)
		wheelDisc.BackgroundColor3 = Color3.fromHex("141822")
		wheelDisc.BorderSizePixel = 0
		wheelDisc.Parent = wheelCenter
		local discCorner = Instance.new("UICorner")
		discCorner.CornerRadius = UDim.new(1, 0)
		discCorner.Parent = wheelDisc
		local discStroke = Instance.new("UIStroke")
		discStroke.Color = GOLD
		discStroke.Thickness = 3
		discStroke.Parent = wheelDisc

		local pointer = Instance.new("TextLabel")
		pointer.Name = "Pointer"
		pointer.Size = UDim2.fromOffset(26, 26)
		pointer.AnchorPoint = Vector2.new(0.5, 0)
		pointer.Position = UDim2.new(0.5, 0, 0, 2)
		pointer.BackgroundTransparency = 1
		pointer.Text = "▼"
		pointer.TextColor3 = GOLD
		pointer.Font = Enum.Font.BuilderSansExtraBold
		pointer.TextSize = 22
		pointer.ZIndex = 5
		pointer.Parent = wheelCenter

		local sectorLabels = {"+100 CR", "+150 XP", "+200 CR", "+1 Cup", "+250 XP", "+300 CR"}
		local sectorColors = {Art.mint, GOLD, Color3.fromHex("00B4D8"), Color3.fromHex("FF9E00"), Color3.fromHex("7209B7"), Color3.fromHex("F72585")}
		for i = 1, 6 do
			local angle = (i - 1) * 60
			local spoke = Instance.new("Frame")
			spoke.Name = "Spoke" .. i
			spoke.Size = UDim2.fromScale(1, 1)
			spoke.BackgroundTransparency = 1
			spoke.Rotation = angle
			spoke.Parent = wheelDisc

			local tag = UI.label(spoke, sectorLabels[i], 12, {font = BLACK, color = sectorColors[i], align = Enum.TextXAlignment.Center})
			tag.AnchorPoint = Vector2.new(0.5, 0)
			tag.Position = UDim2.fromScale(0.5, 0.08)
			tag.Size = UDim2.fromOffset(70, 20)
		end

		local statusLabel = UI.label(wheelCenter, if canSpin then t("Spin Available!") else t("Next spin tomorrow"), 13,
			{font = BOLD, color = if canSpin then colors.mint else colors.muted, align = Enum.TextXAlignment.Center})
		statusLabel.AnchorPoint = Vector2.new(0.5, 1)
		statusLabel.Position = UDim2.new(0.5, 0, 1, -44)
		statusLabel.Size = UDim2.new(1, 0, 0, 20)

		local isSpinning = false
		local spinBtn = UI.button(wheelCenter, "SpinBtn", t("SPIN"), 38, if canSpin then function()
			if isSpinning then return end
			isSpinning = true
			local wd = ReplicatedStorage:WaitForChild("WorldDraft", 5)
			local wheelAction = if wd then wd:FindFirstChild("WheelAction") :: RemoteEvent? else nil
			if wheelAction then
				wheelAction:FireServer()
				audio.play("select")
				local conn
				conn = wheelAction.OnClientEvent:Connect(function(ok, sectorIdx, kind, amount)
					conn:Disconnect()
					if ok then
						local targetRot = 360 * 5 + (6 - sectorIdx) * 60 + 30
						local tween = TweenService:Create(wheelDisc, TweenInfo.new(3.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Rotation = targetRot})
						tween:Play()
						task.spawn(function()
							for _ = 1, 16 do
								task.wait(0.16)
								audio.play("select")
							end
							task.wait(0.6)
							audio.play("upgrade")
							statusLabel.Text = t("Congratulations! You won %s", sectorLabels[sectorIdx])
							statusLabel.TextColor3 = GOLD
							task.wait(2.2)
							drawDialog()
						end)
					else
						isSpinning = false
					end
				end)
			end
		end else nil, if canSpin then GOLD else colors.panel, if canSpin then colors.ink else colors.outline)
		spinBtn.AnchorPoint = Vector2.new(0.5, 1)
		spinBtn.Position = UDim2.new(0.5, 0, 1, 0)
		spinBtn.Size = UDim2.new(0.70, 0, 0, 38)
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
local function touchlineButton(name: string, label: string, symbol: string, press: () -> ()): TextButton
	local button = PropertyCard.button(root, name, label, press)
	button.TextTransparency = 1
	local mark = Print.mark(button, symbol, colors.paper, 27)
	mark.AnchorPoint, mark.Position = Vector2.new(.5,.5), UDim2.fromScale(.5,.5)
	return button
end
local rulesButton = touchlineButton("Rules", "Rules", "book", function() show("rules") end)
local clubsButton = touchlineButton("Clubs", "Clubs", "clubs", function() show("clubs") end)
local careerButton = touchlineButton("CareerButton", "Career", "cup", function() show("career") end)
local emoteButton: TextButton
local resetCamButton = touchlineButton("ResetCamButton", "Reset camera", "camera", function() tableView.resetCamera() end)

local emoteBar = UI.box(root, "EmoteBar", colors.ink, 8)
emoteBar.Visible = false
emoteBar.ZIndex = 6
emoteBar.Size = UDim2.fromOffset(256, 46)
UI.pad(emoteBar, 4, 3)
UI.stroke(emoteBar, Art.gold)

local emoteList = {
	{"goal", "⚽"},
	{"fire", "🔥"},
	{"trophy", "🏆"},
	{"gg", "👏"},
	{"shock", "😱"},
	{"laugh", "😂"},
}

local function toggleEmotes()
	emoteBar.Visible = not emoteBar.Visible
	if emoteBar.Visible then audio.play("select") end
end

emoteButton = touchlineButton("EmoteButton", "Emotes", "chat", toggleEmotes)

for i, em in emoteList do
	local b = UI.button(emoteBar, "Emote_" .. em[1], em[2], 38, function()
		emoteBar.Visible = false
		local channel = ReplicatedStorage:WaitForChild("WorldDraft"):FindFirstChild("EmoteAction")
		if channel and channel:IsA("RemoteEvent") then
			channel:FireServer(em[1])
		end
	end, colors.surface, colors.text)
	b.Position = UDim2.new((i - 1) / #emoteList, 2, 0, 1)
	b.Size = UDim2.new(1 / #emoteList, -4, 1, -2)
end
dealButton = touchlineButton("ClubDeals", "Club deals", "transfer", function() show("tradeClubs") end)
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
	local portrait = size.X < size.Y * .86
	scores.AnchorPoint = if shortLandscape then Vector2.new(0,.5) else Vector2.new(.5,0)
	scores.Position = if shortLandscape then UDim2.new(0,6,.49,0) else UDim2.new(.5,0,0,if size.X>=1040 then 8 else 41)
	turnPrompt.AnchorPoint = if shortLandscape or portrait then Vector2.new(1,1) else Vector2.new(.5,1)
	turnPrompt.Size = UDim2.fromOffset(if shortLandscape then 94 elseif portrait then math.clamp(size.X-144,100,264) else 264,48)
	turnPrompt.Position = if shortLandscape then UDim2.new(1,-4,1,-6)
		elseif portrait then UDim2.new(1,-12,1,-12) else UDim2.new(.5,0,1,-12)
	cameraView.Position = UDim2.new(0,12,1,-14)
	brand.Visible = not shortLandscape
	matchClock.AnchorPoint = if shortLandscape then Vector2.new(0, 1) else Vector2.new(1, 0)
	matchClock.Position = if shortLandscape then UDim2.new(0, 13, 1, -12) else UDim2.new(1, -13, 0, 6)
	local controls = {rulesButton, clubsButton, careerButton, emoteButton, resetCamButton}
	if dealButton then table.insert(controls, dealButton) end
	for i, control in controls do
		control.AnchorPoint = Vector2.new(.5, .5)
		control.Position = if portrait then UDim2.new(.5, (i-3.5)*46, 1, -89)
			elseif shortLandscape then UDim2.new(1,-28-((i-1)%2)*46,.47,(math.floor((i-1)/2)-1)*46)
			else UDim2.new(1,-33,.54,(i-3.5)*46)
		control.Size = UDim2.fromOffset(42,42)
	end
	emoteBar.AnchorPoint = if portrait then Vector2.new(.5,1) else Vector2.new(1,.5)
	emoteBar.Position = if portrait then UDim2.new(.5,0,1,-116)
		else emoteButton.Position + UDim2.fromOffset(-27,0)
	panel.AnchorPoint, panel.Position = Vector2.new(.5, .5), UDim2.fromScale(.5, .53)
end

local function footer(height: number, fullWidth: boolean?)
	actions:ClearAllChildren()
	if mode == "dock" and height > 0 and not fullWidth then
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
local lastActiveSeat: number? = nil
local function scorecards(s: any)
	for _, portrait in portraits do portrait.Parent = nil end
	-- Keep the scoreboard outline while updating player records.
	for _, child in scores:GetChildren() do
		if child:IsA("Frame") then child:Destroy() end
	end
	scores.Visible = s ~= nil
	if not s then
		lastActiveSeat = nil
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
	local changedTurn = lastActiveSeat ~= nil and lastActiveSeat ~= s.active
	lastActiveSeat = s.active
	for i, seat in s.seats do
		local active = s.active == i and s.phase ~= "final"
		local tint = Art.seatColors[i]
		local card = UI.box(scores, "Seat" .. i, if active then colors.paper else colors.panel, 3)
		card.Position = if stacked then UDim2.fromOffset(3,(i-1)*height+3) else UDim2.fromOffset((i-1)*width+3,3)
		card.Size = UDim2.fromOffset(width-6,height-6)
		local band = UI.box(card, "Team accent", if active then colors.ink else tint)
		band.Position, band.Size = UDim2.new(0, 0, 1, -3), UDim2.new(1, 0, 0, 3)
		if active then
			local rule = UI.box(band, "Possession", tint)
			rule.Size = UDim2.fromScale(1,1)
			if changedTurn and not reduced() then
				rule.Size = UDim2.fromScale(0,1)
				TweenService:Create(rule, TweenInfo.new(.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
					{Size=UDim2.fromScale(1,1)}):Play()
			end
		end
		local textInset = if compact then 6 else portraitSize + 12
		local textWidth = UDim2.new(1, -textInset - 3, 0, 18)
		local name = UI.label(card, sessionName(seat.id), 12,
			{font = BOLD, color = if active then colors.panel else colors.muted, ellipsis = true, name = "PlayerName"})
		name.Position, name.Size = UDim2.fromOffset(textInset, if compact then 1 else 4), textWidth
		local money = UI.label(card, if seat.bankrupt then t("Bankrupt") else t("%d CR",seat.cash), if compact then 16 else 19,
			{color = if active then colors.ink else colors.text, ellipsis = true, name = "Balance"})
		money.FontFace = Print.display
		money.Position, money.Size = UDim2.fromOffset(textInset, if compact then 16 else 21), UDim2.new(1,-textInset-3,0,if compact then 20 else 24)
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

local lobbyPreview: ViewportFrame? = nil
local lobbyPreviewFigure = 0
local lobbyPreviewModel: Model? = nil

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
	local wide = mode == "dock"
	local feature = UI.box(body, "FootballerCard", colors.paper, 4)
	feature.ClipsDescendants = true
	feature.Size = UDim2.new(1, 0, 0, if wide then 178 else 104)
	local portraitField = UI.box(feature, "Kit colours", figureColor)
	portraitField.Position, portraitField.Size = UDim2.fromScale(.57,0), UDim2.fromScale(.43,1)
	Print.duotone(portraitField, figureColor, hex(figure.dark))
	for i = 0, 2 do
		local sash = UI.box(portraitField, "Kit sash", hex(figure.kit))
		sash.AnchorPoint, sash.Position = Vector2.new(.5,.5), UDim2.fromScale(.25+i*.32,.5)
		sash.Size, sash.Rotation, sash.BackgroundTransparency = UDim2.fromScale(.09,1.65), 22, .73
	end
	portraitField.ClipsDescendants = true
	local folio = UI.label(feature, figure.countryCode .. "  /  " .. figure.number, 13,
		{font = Enum.Font.RobotoMono, color = colors.surface, ellipsis = true})
	folio.Position, folio.Size = UDim2.fromOffset(11,if wide then 13 else 6), UDim2.new(.54,-11,0,18)
	local hairline = UI.box(feature, "Squad rule", colors.outline)
	hairline.Position, hairline.Size = UDim2.fromOffset(11,if wide then 37 else 29), UDim2.new(.53,-11,0,1)
	local name = UI.label(feature, if russian then figure.localName else figure.name, if wide then 25 else 21,
		{color = colors.ink})
	name.FontFace = Print.display
	name.AutomaticSize, name.TextYAlignment = Enum.AutomaticSize.None, Enum.TextYAlignment.Center
	name.Position, name.Size = UDim2.fromOffset(11,if wide then 40 else 32), UDim2.new(.55,-12,0,if wide then 78 else 45)
	local role = UI.label(feature, if russian then figure.ru else figure.role, 13, {font=BOLD,color=colors.surface,ellipsis=true})
	role.Position, role.Size = UDim2.fromOffset(11,if wide then 123 else 78), UDim2.new(.54,-12,0,20)

	if not lobbyPreview or lobbyPreviewFigure ~= selected then
		local switchFigure = lobbyPreview ~= nil
		if lobbyPreview then lobbyPreview:Destroy() end
		local viewport = Instance.new("ViewportFrame")
		viewport.Name = "FootballerPreview"
		viewport.BackgroundTransparency = 1
		viewport.Position, viewport.Size = UDim2.fromOffset(0,0), UDim2.fromScale(1,1)
		viewport.LightColor, viewport.Ambient, viewport.LightDirection = hex(0xFFF6E8), hex(0xB8CFEA), Vector3.new(-2, -5, -6)
		local camera = Instance.new("Camera")
		camera.FieldOfView = 30
		local bust = Vector3.new(0, .45 + figure.height * 4.95, 0)
		camera.CFrame = CFrame.lookAt(bust + Vector3.new(.98, .34, 6.65), bust)
		camera.Parent, viewport.CurrentCamera = viewport, camera
		lobbyPreviewModel = Pawn.make(selected, viewport)
		lobbyPreview, lobbyPreviewFigure = viewport, selected
		if switchFigure and not reduced() then
			viewport.Position, viewport.ImageTransparency = UDim2.fromOffset(8,0), .5
			TweenService:Create(viewport,TweenInfo.new(.22,Enum.EasingStyle.Cubic,Enum.EasingDirection.Out),
				{Position=UDim2.fromOffset(0,0),ImageTransparency=0}):Play()
		end
	end
	if lobbyPreview then lobbyPreview.Parent = portraitField end
	if lobbyPreviewModel then tableView.preview(lobbyPreviewModel) end

	local row = UI.box(actions, "FigurePicker")
	row.Size = UDim2.new(1, 0, 0, 43)
	for i, candidate in Board.figures do
		local available = i ~= selected and not taken[i]
		local b = UI.button(row, "Figure" .. i, candidate.countryCode, 43, if available then function() send("figure", i) end else nil,
			if i == selected then hex(candidate.color) else colors.surface,
			if i == selected then colors.ink elseif available then hex(candidate.color) else colors.muted)
		local count = #Board.figures
		b.Position, b.Size = UDim2.new((i - 1) / count, 0, 0, 0), UDim2.new(1 / count, -4, 0, 43)
		if i == selected then
			local selectedRule = UI.box(b, "Selected nation", colors.ink)
			selectedRule.Size, selectedRule.Position = UDim2.new(1,-14,0,2), UDim2.new(0,7,1,-7)
		end
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
			elseif tile.kind == "kickoff" then t("Crossing Kickoff pays %d CR.", Board.kickoffCash)
			elseif tile.kind == "tax" then t("Pay league tax (%d CR).", math.abs(tile.award))
			elseif tile.kind == "tour" then t("Away tour · travel anywhere next turn")
			elseif tile.kind == "bench" then t("The bench · roll doubles or pay %d CR", Board.benchFee)
			elseif tile.kind == "championship" then t("Championship arena · shoot or host")
			elseif tile.kind == "chance" then t("Chance · card, shield, bonus or shot")
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

local cupAward = require(script.Parent.CupAward)
local lastAwardSerial: number? = nil
local function finishPanel(s: any)
	local sharedTitle = not s.winner and s.standings[1].score == s.standings[2].score
	cupAward(body, t(if sharedTitle then "League champions" else "Season champion"),
		t(if sharedTitle then "Same team value: shared title" else "Season value"), panel.Visible and lastAwardSerial ~= snapshot.serial and not reduced())
	if panel.Visible then lastAwardSerial = snapshot.serial end
	if Player:GetAttribute("FirstCompletedMatch") == snapshot.serial and Player:GetAttribute("CareerIsVip") ~= true then
		sponsorCard(body)
	end
	local pair: Frame? = nil
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
		if mode == "dock" and index % 2 == 1 then
			pair = UI.box(body,"Standings row")
			pair.Size, pair.AutomaticSize = UDim2.new(1,0,0,0), Enum.AutomaticSize.Y
		end
		local row = UI.box(pair or body, "Rank" .. index, colors.surface, 5)
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.Size = if pair then UDim2.new(.5, -3, 0, 0) else UDim2.new(1,0,0,0)
		if pair and index % 2 == 0 then row.Position = UDim2.new(.5,3,0,0) end
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
	footer(48,true)
	primary = function() send("lobby") end
	UI.button(actions, "BackToLobby", t("Back to lobby"), 48, primary, colors.mint, colors.ink)
end

render = function()
	primary, alternate = nil, nil
	closeButton.Text = t("Close")
	if lobbyPreview then lobbyPreview.Parent = nil end
	body:ClearAllChildren()
	body.CanvasPosition = Vector2.zero
	UI.stack(body, 4)
	UI.pad(body, 4, 1, 5)
	turnPrompt:ClearAllChildren()
	footer(0)
	local data = snapshot
	local s = data and data.match
	local room = root.AbsoluteSize
	local panelHeight = if s and s.phase == "final" and mode == "dock" then 368
		elseif data and not s and mode == "dock" then 230 else 302
	panel.Size = UDim2.fromOffset(math.clamp(room.X - 58, 230, 560), math.clamp(room.Y - 106, 172, panelHeight))
	scorecards(s)
	languageButton.Visible,languageButton.Text = s == nil, if russian then "Язык · RU" else "Language · EN"
	matchClock.Visible = s ~= nil and s.phase ~= "final"
	local shot = root:GetAttribute("ShotPlaying") == true
	rulesButton.Visible, clubsButton.Visible, careerButton.Visible, resetCamButton.Visible, turnPrompt.Visible = not shot, not shot, not shot, not shot, not shot
	emoteButton.Visible = not shot
	if shot then emoteBar.Visible = false end
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

for _, attribute in {"CareerMatches", "FirstCompletedMatch", "CareerIsVip", "CareerVipVerified", "CareerUnlocked"} do
	Player:GetAttributeChangedSignal(attribute):Connect(function()
		if opened == "career" or (snapshot and snapshot.match and snapshot.match.phase == "final") then render() end
	end)
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
				if match.winner == record.id or (not match.winner and record.score == match.standings[1].score) then
					table.insert(tied, sessionName(record.id))
				end
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
				if last.kind == "bankrupt" then
					audio.play("bankrupt")
				elseif last.kind == "upgrade" then
					audio.play("upgrade")
				elseif last.card > 0 or last.kind == "auctionEmpty" then
					audio.play("card")
				else
					audio.play("sign")
				end
			end
			if last.amount ~= 0 and last.tile and Geometry.cells[last.tile] then
				local text = string.format("%+d CR", last.amount)
				local popTint = if last.amount > 0 then colors.mint else colors.pink
				tableView.popup(Geometry.cells[last.tile], text, popTint)
			end
			if last.crossed then
				tableView.popup(Geometry.cells[1], string.format("+%d CR", Board.kickoffCash), GOLD)
			end
			resultBanner.reveal(title, caption, tint, reduced(), if final then "final" else last.kind)
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
