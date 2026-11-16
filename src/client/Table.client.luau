--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Localize = game:GetService("LocalizationService")
local Input = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

local Player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("League")
local Board = require(shared.Board)
local Rules = require(shared.Rules)
local Game = Rules.withBoard(Board)
local Pawn = require(script.Parent.Pawn)
local Arena = require(script.Parent.Arena)
local UI = require(script.Parent.Components)
local copy = require(script.Parent.Copy)
local colors = UI.color
local GOLD, BOLD, BLACK = colors.gold, Enum.Font.GothamBold, Enum.Font.GothamBlack
local LEFT, CENTER, RIGHT = Enum.TextXAlignment.Left, Enum.TextXAlignment.Center, Enum.TextXAlignment.Right
local function hex(v: number): Color3 return Color3.fromHex(string.format("%06x", v)) end
local russian = string.sub(string.lower(Localize.RobloxLocaleId), 1, 2) == "ru"
local soundOn, reduced = true, false
local function t(key: string, ...: any): string return copy(key, russian, ...) end
local snapshot: any = nil
local remote: RemoteEvent? = nil
local tableView = Arena.new(Player.UserId)

local gui = Instance.new("ScreenGui")
gui.Name = "WorldDraftHUD"
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = Player:WaitForChild("PlayerGui")
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false) end)
local root = UI.box(gui, "Viewport")
root.Size = UDim2.fromScale(1, 1)

local mark = UI.box(root, "Masthead", colors.background, 12)
UI.stroke(mark, colors.outline)
local shield = UI.box(mark, "Shield", colors.mint, 7)
shield.Size, shield.Position = UDim2.fromOffset(38, 36), UDim2.fromOffset(8, 7)
local wd = UI.label(shield, "WD", 16, {font = BLACK, align = CENTER, color = colors.ink, ellipsis = true})
wd.Size = UDim2.fromScale(1, 1)
local mast = UI.label(mark, "FOOTBOLAPOLIA", 16, {font = BLACK, ellipsis = true})
mast.Size, mast.Position = UDim2.new(1, -60, 0, 21), UDim2.fromOffset(54, 5)
local tagline = UI.label(mark, "", 9, {font = BOLD, color = colors.mint, ellipsis = true})
tagline.Size, tagline.Position = UDim2.new(1, -60, 0, 15), UDim2.fromOffset(54, 27)

local scores = UI.box(root, "Scoreboard")
local scoreLayout = UI.stack(scores, 6, true)
local panel = UI.box(root, "MatchPanel", colors.panel, 15)
UI.stroke(panel, colors.outline)
local topLine = UI.box(panel, "KickoffLine", colors.mint, 1)
topLine.Size, topLine.Position = UDim2.new(1, -26, 0, 2), UDim2.fromOffset(13, 0)
local phase = UI.label(panel, "", 11, {font = BOLD, color = colors.mint, ellipsis = true, name = "Phase"})
phase.Position, phase.Size = UDim2.fromOffset(14, 12), UDim2.new(0.75, -15, 0, 20)
local countdown = UI.label(panel, "", 13, {font = BOLD, color = GOLD, align = RIGHT, ellipsis = true, name = "Countdown"})
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
UI.stroke(dialog, colors.outline)
local constraint = Instance.new("UISizeConstraint")
constraint.MaxSize = Vector2.new(530, 590)
constraint.Parent = dialog
local dialogTitle = UI.label(dialog, "", 17, {font = BLACK, color = colors.mint, ellipsis = true})
dialogTitle.Size, dialogTitle.Position = UDim2.new(1, -135, 0, 32), UDim2.fromOffset(18, 8)
local dialogBody = UI.scroll(dialog, "Content")
dialogBody.Position, dialogBody.Size = UDim2.fromOffset(13, 50), UDim2.new(1, -26, 1, -62)
local opened = ""
local primary: (() -> ())? = nil
local alternate: (() -> ())? = nil
local portrait = false
local function playSound(mode: string)
	if not soundOn then return end
	local sound = Instance.new("Sound")
	sound.Name = "TableFeedback"
	sound.SoundId = if mode == "land" then "rbxasset://sounds/action_jump_land.mp3" else "rbxasset://sounds/volume_slider.ogg"
	sound.PlaybackSpeed = if mode == "win" then 1.38 elseif mode == "land" then 1.38 else 1.05
	sound.Volume = if mode == "land" then 0.20 else 0.15
	sound.Parent = SoundService
	sound:Play()
	game:GetService("Debris"):AddItem(sound, 2)
end

local function send(verb: string, value: number?)
	local channel, data = remote, snapshot
	if not channel or not data then return end
	local revision = data.version
	local function dispatch()
		if snapshot and snapshot.version == revision then channel:FireServer(verb, revision, value) end
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
local function drawDialog()
	dialogShade.Visible = opened ~= ""
	if opened == "" then return end
	dialogTitle.Text = t(if opened == "rules" then "HOW TO PLAY" else "CLUB LEDGER")
	local offset = dialogBody.CanvasPosition
	dialogBody:ClearAllChildren()
	UI.stack(dialogBody, 10)
	UI.pad(dialogBody, 5, 2, 9)
	if opened == "rules" then
		local topics = {
			{"1. Pick either route", "Each move shows two destinations. Crossing Kickoff pays 140 CR."},
			{"2. Collect a league", "Sign free clubs. Rivals pay you at their gates. Own all three in one league to double those fees."},
			{"3. Beat the final whistle", "After 8 rounds, cash + club and stadium value + league bonuses decide the winner. Everyone plays to the end."},
		}
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
			render()
		end)
		preferencesLine(dialogBody, "Audio", t(if soundOn then "Sound: on" else "Sound: off"), function()
			soundOn = not soundOn
			drawDialog()
		end)
		preferencesLine(dialogBody, "Motion", t(if reduced then "Motion: reduced" else "Motion: full"), function()
			reduced = not reduced
			tableView.reduceMotion(reduced)
			drawDialog()
		end)
	else
		UI.label(dialogBody, t("Complete three clubs for a 160 CR portfolio bonus."), 13, {color = colors.muted})
		local match = snapshot and snapshot.match
		for n, league in Board.leagues do
			UI.label(dialogBody, string.upper(if russian then league.ru else league.name), 14, {font = BOLD, color = hex(league.color)})
			for _, i in Board.members[n] do
				local tile = Board.tiles[i]
				local club = if match then match.clubs[i] else {owner = 0, level = 0}
				local card = UI.box(dialogBody, tile.code, colors.surface, 8)
				card.Size, card.AutomaticSize = UDim2.new(1, 0, 0, 0), Enum.AutomaticSize.Y
				UI.pad(card, 10, 8)
				UI.stack(card, 3)
				UI.label(card, tile.name .. "  /  " .. tile.city, 14, {font = BOLD})
				local gate = if club.owner ~= 0 then snapshot.gates[i] else tile.gate
				UI.label(card, t("Price %d  /  Gate %d  /  Stadium %d", tile.price, gate, club.level), 12, {color = colors.muted})
				UI.label(card, if club.owner == 0 then t("Free") else t("Owner: %s", sessionName(club.owner)), 12,
					{color = if club.owner == Player.UserId then colors.mint else colors.muted})
			end
		end
	end
	dialogBody.CanvasPosition = offset
end

local function show(name: string)
	opened = if opened == name then "" else name
	dialogBody.CanvasPosition = Vector2.zero
	drawDialog()
end
local rulesButton = UI.button(root, "Rules", "?", 40, function() show("rules") end)
local clubsButton = UI.button(root, "Clubs", "", 40, function() show("clubs") end)
local closeButton = UI.button(dialog, "Close", "", 32, function() show(opened) end)
closeButton.AnchorPoint, closeButton.Position, closeButton.Size = Vector2.new(1, 0), UDim2.new(1, -12, 0, 9), UDim2.fromOffset(103, 32)

local function arrange()
	local size = root.AbsoluteSize
	portrait = size.X / math.max(1, size.Y) < 1.16
	mark.Position = UDim2.fromOffset(12, 9)
	mark.Size = UDim2.fromOffset(if portrait then math.clamp(size.X - 112, 190, 270) else 271, 50)
	local panelWidth = if size.X < 800 then 300 else 349
	if portrait then
		panel.AnchorPoint, panel.Position = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -10)
		panel.Size = UDim2.new(1, -20, 0, math.min(size.Y - 112, math.clamp(math.floor(size.Y * 0.47), 255, 450)))
	else
		panel.AnchorPoint, panel.Position = Vector2.new(1, 0), UDim2.new(1, -14, 0, 67)
		panel.Size = UDim2.new(0, panelWidth, 1, -81)
	end
	local desktop = not portrait and size.X >= 1000
	rulesButton.Size = UDim2.fromOffset(if desktop then 86 else 44, 42)
	clubsButton.Size = UDim2.fromOffset(if desktop then 95 else (if portrait then 44 else 64), 42)
	rulesButton.AnchorPoint, clubsButton.AnchorPoint = Vector2.new(1, 0), Vector2.new(1, 0)
	rulesButton.Position = UDim2.new(1, -12, 0, 11)
	clubsButton.Position = UDim2.new(1, if desktop then -104 else -62, 0, 11)
	scores.Position = UDim2.fromOffset(12, 67)
	scores.Size = UDim2.new(1, if portrait then -24 else -panelWidth - 33, 0, 58)
	scoreLayout.Padding = UDim.new(0, if size.X < 500 then 4 else 6)
end

local function spendText(s: any, seat: any, index: number): (string, Color3)
	local tile, club = Board.tiles[index], s.clubs[index]
	if tile.kind == "club" then
		if club.owner == 0 then return t("FREE CLUB · %d CR", tile.price), hex(Board.leagues[tile.league].color) end
		if club.owner == seat.id then return t("YOUR CLUB"), colors.mint end
		return t("RIVAL GATE · −%d CR", snapshot.gates[index]), colors.pink
	elseif tile.kind == "tactics" then
		return t("TACTICS CARD"), hex(0xEB9DF7)
	elseif tile.kind == "kickoff" then
		return t("%+d CR · KICKOFF", Board.kickoffCash), colors.mint
	end
	return string.format("+%d CR", tile.award), GOLD
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
	})[last.kind] or "%s landed on %s"
	if last.kind == "start" then
		UI.label(card, t("The transfer window is open."), 14)
	elseif last.card > 0 then
		local info = Board.cards[last.card]
		UI.label(card, (if russian then info.ru else info.title) .. string.format("  /  %+d CR", last.amount), 14, {font = BOLD, color = if last.amount < 0 then colors.pink else GOLD})
		UI.label(card, t("%s drew a card", name) .. " · " .. (if russian then info.ruBody else info.body), 12, {color = colors.muted})
	else
		local title = t(tile.name)
		if last.kind == "league" then title = if russian then Board.leagues[tile.league].ru else Board.leagues[tile.league].name end
		local delta = if last.amount == 0 then "" else string.format("  /  %+d CR", last.amount)
		if last.kind == "offer" or last.kind == "invest" then delta = "" end
		UI.label(card, t(template, name, title) .. delta, 14)
	end
	if last.crossed then UI.label(card, t("%+d CR · KICKOFF", Board.kickoffCash), 12, {font = BOLD, color = colors.mint}) end
end

local function footer(height: number)
	actions:ClearAllChildren()
	actions.Size = UDim2.new(1, -24, 0, height)
	body.Size = UDim2.new(1, -18, 1, -43 - (if height == 0 then 8 else height + 12))
end

local function title(titleText: string, description: string?)
	UI.label(body, t(titleText), 23, {font = BLACK, name = "Headline"})
	if description then UI.label(body, t(description), 13, {color = colors.muted}) end
end

local function scorecards(s: any)
	for _, child in scores:GetChildren() do if child:IsA("Frame") then child:Destroy() end end
	if not s then return end
	local gap = if root.AbsoluteSize.X < 500 then 4 else 6
	for i, seat in s.seats do
		local color = hex(Board.figures[seat.figure].color)
		local frame = UI.box(scores, "Seat" .. i, colors.background, 8)
		frame.Size = UDim2.new(1 / #s.seats, -gap, 1, -5)
		frame.LayoutOrder = i
		UI.stroke(frame, if s.active == i and s.phase ~= "final" then color else colors.outline)
		UI.pad(frame, 7, 5)
		UI.stack(frame, 1)
		UI.label(frame, sessionName(seat.id) .. (if seat.bot then " · " .. t("BOT") else ""), 11, {color = color, font = BOLD, ellipsis = true})
		UI.label(frame, tostring(seat.cash) .. " CR", 15, {font = BOLD, ellipsis = true})
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
	title("Choose your footballer", "All figures play by the same rules.")
	local figure = Board.figures[selected]
	local figureColor = hex(figure.color)
	local feature = UI.box(body, "FootballerCard", colors.surface, 12)
	feature.Size = UDim2.new(1, 0, 0, if portrait then 88 else 157)
	UI.stroke(feature, figureColor:Lerp(colors.outline, 0.54))
	local textArea = UI.box(feature, "FootballerDetails")
	textArea.Position, textArea.Size = UDim2.new(0, 11, 0, if portrait then 11 else 22), UDim2.new(0.60, -11, 1, -16)
	UI.stack(textArea, 3)
	UI.label(textArea, "No. " .. figure.number .. "  /  " .. t("Your selection"), 10, {font = BOLD, color = figureColor})
	UI.label(textArea, figure.name, 21, {font = BLACK})
	UI.label(textArea, if russian then figure.ru else figure.role, 13, {color = colors.muted})
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "FootballerPreview"
	viewport.BackgroundTransparency = 1
	viewport.Position, viewport.Size = UDim2.new(0.56, 0, 0, 2), UDim2.new(0.44, -4, 1, -4)
	viewport.LightColor, viewport.Ambient, viewport.LightDirection = hex(0xFFFFFF), hex(0xC5DCFA), Vector3.new(-2, -5, -6)
	viewport.Parent = feature
	local camera = Instance.new("Camera")
	camera.FieldOfView = 35
	camera.CFrame = CFrame.lookAt(Vector3.new(6, 4.65, 10), Vector3.new(0, 2.71, 0))
	camera.Parent, viewport.CurrentCamera = viewport, camera
	Pawn.make(selected, viewport)

	local row = UI.box(body, "FigurePicker")
	row.Size = UDim2.new(1, 0, 0, 43)
	for i, candidate in Board.figures do
		local available = i ~= selected and not taken[i]
		local b = UI.button(row, "Figure" .. i, candidate.number, 43, if available then function() send("figure", i) end else nil,
			if i == selected then hex(candidate.color) else colors.surface,
			if i == selected then colors.ink elseif available then hex(candidate.color) else colors.muted)
		b.Position, b.Size = UDim2.new((i - 1) / 4, if i == 1 then 0 else 3, 0, 0), UDim2.new(0.25, -4, 0, 43)
	end
	UI.label(body, t("%d online · bots fill empty seats", #data.lobby), 12, {color = colors.muted})
	footer(48)
	local isHost = data.host == Player.UserId
	if isHost then primary = function() send("start") end end
	UI.button(actions, "StartSeason", t(if isHost then "Start season" else "Waiting for the host"), 48, primary,
		if isHost then colors.mint else colors.surface, if isHost then colors.ink else colors.muted)
end

local function portfolio(s: any, seat: any)
	local score = 0
	for i, entry in s.seats do if entry.id == seat.id then score = snapshot.scores[i] end end
	local card = UI.box(body, "LeagueProgress", colors.background, 9)
	card.Size, card.AutomaticSize = UDim2.new(1, 0, 0, 0), Enum.AutomaticSize.Y
	UI.pad(card, 10, 8)
	UI.stack(card, 5)
	UI.label(card, t("Season value") .. "  /  " .. score .. " CR", 13, {font = BOLD})
	for i, league in Board.leagues do
		local count = 0
		for _, index in Board.members[i] do if s.clubs[index].owner == seat.id then count += 1 end end
		UI.label(card, (if russian then league.ru else league.name) .. "  " .. count .. " / 3", 11,
			{color = hex(league.color), font = BOLD})
	end
end

local function routePanel(s: any, seat: any)
	title("Choose a route", "Preview the destination. Then pick your move.")
	footer(58)
	for i, route in {{s.short, "short", colors.mint}, {s.long, "long", colors.blue}} do
		local steps, verb, color = route[1] :: number, route[2] :: string, route[3] :: Color3
		local index = Game.target(seat.position, steps)
		local target = Board.tiles[index]
		local cost, accent = spendText(s, seat, index)
		local lane = UI.box(body, if i == 1 then "ShortRoutePreview" else "LongRoutePreview", colors.surface, 9)
		lane.Size, lane.AutomaticSize = UDim2.new(1, 0, 0, 0), Enum.AutomaticSize.Y
		UI.pad(lane, 10, 7)
		UI.stack(lane, 3)
		UI.label(lane, i .. "  /  " .. t(target.name), 15, {font = BOLD, color = color})
		local extra = if seat.position + steps > #Board.tiles and index ~= 1 then "  ·  +" .. Board.kickoffCash else ""
		UI.label(lane, cost .. extra, 11, {color = accent, font = BOLD})
		local function choose() send(verb) end
		if i == 1 then primary = choose else alternate = choose end
		local b = UI.button(actions, if i == 1 then "RouteShort" else "RouteLong", i .. "  /  " .. t("%d steps", steps) .. "\n" .. t(target.name), 58, choose, color, colors.ink)
		b.Position, b.Size = UDim2.new(0.5 * (i - 1), if i == 1 then 0 else 4, 0, 0), UDim2.new(0.5, -4, 0, 58)
	end
	storyCard(s)
	if not portrait then portfolio(s, seat) end
end

local function contractPanel(s: any, seat: any)
	local offer = s.phase == "offer"
	local tile, club = Board.tiles[seat.position], s.clubs[seat.position]
	local league = Board.leagues[tile.league]
	title(if offer then "Sign this club?" else "Upgrade your stadium?")
	local card = UI.box(body, "Contract", colors.surface, 9)
	card.Size, card.AutomaticSize = UDim2.new(1, 0, 0, 0), Enum.AutomaticSize.Y
	UI.pad(card, 12, 11)
	UI.stack(card, 5)
	UI.label(card, (if russian then league.ru else league.name) .. "  /  " .. tile.city, 11, {font = BOLD, color = hex(league.color)})
	UI.label(card, tile.name, 21, {font = BLACK})
	UI.label(card, t("%d CR cash", seat.cash), 12, {color = colors.muted})
	UI.label(card, if offer then t("Gate +%d CR each visit from a rival.", tile.gate) else t("Level %d → %d · gate +%d CR", club.level,
		club.level + 1, Board.upgradeGate * (if Game.setComplete(s, seat.id, tile.league) then 2 else 1)), 13, {color = colors.mint})
	if offer then UI.label(body, t("Sign all 3 clubs in a league to double their gate."), 13, {color = colors.muted}) end
	storyCard(s)
	footer(50)
	primary, alternate = function() send(if offer then "buy" else "upgrade") end, function() send("skip") end
	local b = UI.button(actions, if offer then "SignClub" else "Upgrade", t(if offer then "Sign · %d CR" else "Upgrade · %d CR",
		if offer then tile.price else Board.upgradeCost), 50, primary, colors.mint, colors.ink)
	b.Size = UDim2.new(0.67, -4, 0, 50)
	local skip = UI.button(actions, "Skip", t("Pass"), 50, alternate)
	skip.Size, skip.Position = UDim2.new(0.33, -4, 0, 50), UDim2.new(0.67, 4, 0, 0)
end

local function finishPanel(s: any)
	local sharedTitle = s.standings[1].score == s.standings[2].score
	title(if sharedTitle then "League champions" else "Season champion", if sharedTitle then "Same team value: shared title" else "Season value")
	for index, record in s.standings do
		local seat = nil
		local clubs = 0
		for _, candidate in s.seats do if candidate.id == record.id then seat = candidate break end end
		for _, club in s.clubs do if club.owner == record.id then clubs += 1 end end
		local winner = record.score == s.standings[1].score
		local row = UI.box(body, "Rank" .. index, colors.surface, 9)
		row.AutomaticSize, row.Size = Enum.AutomaticSize.Y, UDim2.new(1, 0, 0, 0)
		UI.pad(row, 11, 8)
		UI.stack(row, 2)
		if winner then UI.stroke(row, GOLD) end
		local rank = if winner then "01" else string.format("%02d", index)
		UI.label(row, rank .. "  /  " .. (if seat then sessionName(record.id) else "—"), 17, {font = BLACK, color = if winner then GOLD else colors.text})
		UI.label(row, t("%d CR value", record.score) .. "  ·  " .. t(if clubs == 0 then "No clubs" else "%d clubs", clubs), 12, {color = colors.muted})
	end
	footer(48)
	primary = function() send("lobby") end
	UI.button(actions, "BackToLobby", t("Back to lobby"), 48, primary, colors.mint, colors.ink)
end

render = function()
	primary, alternate = nil, nil
	tagline.Text = t("THE WORLD DRAFT  /  SEASON 01")
	local wide = not portrait and root.AbsoluteSize.X >= 1000
	rulesButton.Text, clubsButton.Text = if wide then t("Rules") else "?", if portrait then "≡" else t("View clubs")
	closeButton.Text = t("Close")
	body:ClearAllChildren()
	body.CanvasPosition = Vector2.zero
	UI.stack(body, 8)
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
	elseif s.phase == "final" then
		phase.Text = string.upper(t("Final whistle"))
		finishPanel(s)
	else
		phase.Text = t("ROUND %d / %d", s.round, Board.rounds)
		local seat = s.seats[s.active]
		if seat.id == Player.UserId and not seat.bot then
			if s.phase == "move" then routePanel(s, seat) else contractPanel(s, seat) end
		else
			local watching = true
			for _, entry in s.seats do if entry.id == Player.UserId and not entry.bot then watching = false end end
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
	end
end)

task.spawn(function()
	while gui.Parent do
		local remaining = if snapshot and snapshot.deadline > 0 then math.max(0, math.ceil(snapshot.deadline - workspace:GetServerTimeNow())) else nil
		countdown.Text = if remaining then string.format(":%02d", remaining) else ""
		task.wait(0.12)
	end
end)

local net = ReplicatedStorage:WaitForChild("WorldDraft")
local intent = net:WaitForChild("Intent") :: RemoteEvent
local snapshots = net:WaitForChild("Snapshot") :: RemoteEvent
remote = intent
snapshots.OnClientEvent:Connect(function(data)
	local old = snapshot
	if old and data.version <= old.version then return end
	snapshot = data
	if data.match and old and old.match then
		if data.match.phase == "final" and old.match.phase ~= "final" then
			playSound("win")
		elseif data.match.motion.serial ~= old.match.motion.serial then
			task.delay(if reduced then 0 else math.min(0.70, data.match.motion.steps * 0.12), function() playSound("land") end)
		elseif data.match.last.kind == "buy" or data.match.last.kind == "league" or data.match.last.kind == "upgrade" then
			playSound("confirm")
		end
	end
	tableView.sync(data)
	render()
end)
repeat
	intent:FireServer("sync")
	task.wait(1)
until snapshot ~= nil
