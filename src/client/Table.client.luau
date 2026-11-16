--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Localize = game:GetService("LocalizationService")
local GuiService = game:GetService("GuiService")
local Input = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

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
local UI = require(script.Parent.Components)
local copy = require(script.Parent.Copy)
local colors = UI.color
local GOLD, BOLD, BLACK = colors.gold, Enum.Font.GothamBold, Enum.Font.GothamBlack
local CENTER, RIGHT = Enum.TextXAlignment.Center, Enum.TextXAlignment.Right
local function hex(v: number): Color3 return Color3.fromHex(string.format("%06x", v)) end
local russian = string.sub(string.lower(Localize.RobloxLocaleId), 1, 2) == "ru"
local soundOn, reducePreference = true, false
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
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false) end)
local root = UI.box(gui, "Viewport")
root.Size = UDim2.fromScale(1, 1)
local tableView = Arena.new(Player.UserId, root)
local resultBanner = ResultBanner.new(root)
GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function()
	tableView.reduceMotion(reduced())
end)

local mark = UI.box(root, "Masthead", colors.paper, 11)
UI.stroke(mark, colors.ink, 2)
local shield = UI.box(mark, "Shield", colors.gold, 7)
shield.Size, shield.Position = UDim2.fromOffset(38, 36), UDim2.fromOffset(8, 7)
local wd = UI.label(shield, "WD", 16, {font = BLACK, align = CENTER, color = colors.ink, ellipsis = true})
wd.Size = UDim2.fromScale(1, 1)
local mast = UI.label(mark, "FOOTBOLAPOLIA", 17, {font = BLACK, color = colors.ink, ellipsis = true})
mast.Size, mast.Position = UDim2.new(1, -60, 0, 21), UDim2.fromOffset(54, 5)
local tagline = UI.label(mark, "", 10, {font = BOLD, color = colors.panel, ellipsis = true})
tagline.Size, tagline.Position = UDim2.new(1, -60, 0, 15), UDim2.fromOffset(54, 27)

local scores = UI.box(root, "Scoreboard")
local panel = UI.box(root, "MatchPanel", colors.panel, 15)
panel.Active = true
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
dialog.Active = true
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
local mode = "dock"
local inspected = 0
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
	dialogTitle.Text = t(if opened == "rules" then "HOW TO PLAY" elseif opened == "cell" then "BOARD CELL" else "CLUB LEDGER")
	constraint.MaxSize = if opened == "cell" then Vector2.new(390, 290) else Vector2.new(530, 590)
	local offset = dialogBody.CanvasPosition
	dialogBody:ClearAllChildren()
	UI.stack(dialogBody, 10)
	UI.pad(dialogBody, 5, 2, 9)
	if opened == "cell" then
		local tile = Board.tiles[inspected]
		local s = snapshot and snapshot.match
		local club = if s then s.clubs[inspected] else {owner = 0, level = 0}
		local accent = Art.accent(tile.kind, tile.league)
		local card = UI.box(dialogBody, "CellDetails", colors.paper, 12)
		card.AutomaticSize, card.Size = Enum.AutomaticSize.Y, UDim2.new(1, 0, 0, 0)
		UI.pad(card, 14, 13)
		UI.stack(card, 4)
		UI.stroke(card, accent, 3)
		if tile.kind == "club" then
			local league = Board.leagues[tile.league]
			UI.label(card, (if russian then league.ru else league.name) .. "  /  " .. tile.city, 13, {font = BOLD, color = colors.panel})
		end
		UI.label(card, t(tile.name), 23, {font = BLACK, color = colors.ink})
		if tile.kind == "club" then
			local gate = if club.owner == 0 then tile.gate else snapshot.gates[inspected]
			UI.label(card, t("Price %d  /  Gate %d  /  Stadium %d", tile.price, gate, club.level), 14, {color = colors.ink})
			UI.label(card, if club.owner == 0 then t("Free") else t("Owner: %s", sessionName(club.owner)), 14, {font = BOLD, color = colors.panel})
		else
			local text = if tile.kind == "tactics" then t("Draw a card from the tactics deck.")
				elseif tile.kind == "matchday" then t("A goal wins a cup and a cash bonus. A safe play keeps your budget steady.")
				elseif tile.kind == "kickoff" then t("Each move shows two destinations. Crossing Kickoff pays 140 CR.")
				else string.format("+%d CR", tile.award)
			UI.label(card, text, 14, {color = colors.ink})
		end
	elseif opened == "rules" then
		local topics = {
			{"1. Pick either route", "Each move shows two destinations. Crossing Kickoff pays 140 CR."},
			{"2. Collect a league", "Sign free clubs. Rivals pay you at their gates. Own all three in one league to double those fees."},
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
			render()
		end)
		preferencesLine(dialogBody, "Audio", t(if soundOn then "Sound: on" else "Sound: off"), function()
			soundOn = not soundOn
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
		panel.Size = UDim2.fromOffset(math.max(1, math.min(1116, size.X - 20)), View.dockHeight(size, mode))
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
	if tile.kind == "club" then
		if club.owner == 0 then return t("Sign · %d CR", tile.price) end
		if club.owner == seat.id then return t("Your club") end
		return t("Gate · −%d CR", snapshot.gates[index])
	elseif tile.kind == "tactics" then
		return t("Draw a card")
	elseif tile.kind == "matchday" then
		return t("Play for a cup")
	elseif tile.kind == "kickoff" then
		return t("%+d CR · KICKOFF", Board.kickoffCash)
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
	})[last.kind] or "%s landed on %s"
	if last.kind == "start" then
		UI.label(card, t("The transfer window is open."), 14)
	elseif last.card > 0 then
		local info = Edition.cards[last.card]
		UI.label(card, (if russian then info.ru else info.title) .. string.format("  /  %+d CR", last.amount), 14, {font = BOLD, color = if last.amount < 0 then colors.pink else GOLD})
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
		UI.label(card, t(template, name, title) .. delta, 14)
	end
	if last.crossed then UI.label(card, t("%+d CR · KICKOFF", Board.kickoffCash), 12, {font = BOLD, color = colors.mint}) end
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
	local cardHeight = if compact then 34 else 41
	local gap = if width < 500 then 4 else 6
	local columns = if #s.seats > 4 and width < 620 and root.AbsoluteSize.X < 920 then 3 else #s.seats
	for i, seat in s.seats do
		local color = hex(Board.figures[seat.figure].color)
		local frame = UI.box(scores, "Seat" .. i, colors.background, 8)
		frame.Size = UDim2.new(1 / columns, -gap, 0, cardHeight)
		frame.Position = UDim2.new(((i - 1) % columns) / columns, 0, 0, math.floor((i - 1) / columns) * (cardHeight + 4))
		UI.stroke(frame, if s.active == i and s.phase ~= "final" then color else colors.outline)
		UI.pad(frame, 7, if compact then 1 else 4)
		UI.stack(frame, 1)
		UI.label(frame, sessionName(seat.id) .. (if seat.bot then " · " .. t("BOT") else ""), 11, {color = color, font = BOLD, ellipsis = true})
		local cash = tostring(seat.cash)
		if seat.trophies > 0 then cash ..= " · " .. t("%d cups", seat.trophies) else cash ..= " CR" end
		UI.label(frame, cash, 13, {font = BOLD, ellipsis = true})
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
	feature.Size = UDim2.new(1, 0, 0, if mode == "dock" then 103 else 72)
	UI.stroke(feature, figureColor:Lerp(colors.outline, 0.54))
	local textArea = UI.box(feature, "FootballerDetails")
	textArea.Position, textArea.Size = UDim2.new(0, 11, 0, if mode == "dock" then 16 else 5), UDim2.new(0.60, -11, 1, -16)
	UI.stack(textArea, 3)
	UI.label(textArea, "#" .. figure.number .. "  /  " .. t("Choose your figure"), 10, {font = BOLD, color = figureColor})
	UI.label(textArea, figure.name, 20, {font = BLACK})
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
		local b = UI.button(actions, if i == 1 then "RouteShort" else "RouteLong", "", 78, choose, color, colors.ink)
		b.Position, b.Size = UDim2.new(.5 * (i - 1), if i == 1 then 0 else 4, 0, 0), UDim2.new(.5, -4, 0, 78)
		UI.pad(b, 8, 6)
		UI.stack(b, 2)
		UI.label(b, i .. "  /  " .. (if steps == 1 then t("1 step") else t("%d steps", steps)), 11, {font = BOLD, color = colors.panel, ellipsis = true, name = "Steps"})
		UI.label(b, t(target.name), if mode == "dock" then 17 else 14, {font = BLACK, color = colors.ink, ellipsis = true, name = "Destination"})
		UI.label(b, cost, 11, {font = BOLD, color = colors.ink, name = "Stake"})
	end
	storyCard(s)
end

local function contractPanel(s: any, seat: any)
	local offer = s.phase == "offer"
	local tile, club = Board.tiles[seat.position], s.clubs[seat.position]
	local league = Board.leagues[tile.league]
	title(if offer then "Sign this club?" else "Upgrade your stadium?")
	local card = UI.box(body, "Contract", colors.surface, 9)
	card.Size, card.AutomaticSize = UDim2.new(1, 0, 0, 0), Enum.AutomaticSize.Y
	UI.pad(card, 10, 6)
	UI.stack(card, 2)
	UI.label(card, (if russian then league.ru else league.name) .. "  /  " .. tile.city, 11, {font = BOLD, color = hex(league.color)})
	UI.label(card, tile.name, 21, {font = BLACK})
	UI.label(card, if offer then t("Gate +%d CR each visit from a rival.", tile.gate) else t("Level %d → %d · gate +%d CR", club.level,
		club.level + 1, Board.upgradeGate * (if Game.setComplete(s, seat.id, tile.league) then 2 else 1)), 13, {color = colors.mint})
	footer(50)
	primary, alternate = function() send(if offer then "buy" else "upgrade") end, function() send("skip") end
	local b = UI.button(actions, if offer then "SignClub" else "Upgrade", t(if offer then "Sign · %d CR" else "Upgrade · %d CR",
		if offer then tile.price else Board.upgradeCost), 50, primary, colors.mint, colors.ink)
	b.Size = UDim2.new(0.67, -4, 0, 50)
	local skip = UI.button(actions, "Skip", t("Pass"), 50, alternate)
	skip.Size, skip.Position = UDim2.new(0.33, -4, 0, 50), UDim2.new(0.67, 4, 0, 0)
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
		local summary = t("%d CR value", record.score) .. "  ·  " .. t(if clubs == 0 then "No clubs" else "%d clubs", clubs)
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
	rulesButton.Text, clubsButton.Text = if wide then t("Rules") else "?", t(if wide then "View clubs" else "Clubs")
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
	elseif s.phase == "final" then
		phase.Text = string.upper(t("Final whistle"))
		finishPanel(s)
	else
		phase.Text = t("ROUND %d / %d", s.round, Board.rounds)
		local seat = s.seats[s.active]
		if seat.id == Player.UserId and not seat.bot then
			if s.phase == "move" then
				routePanel(s, seat)
			elseif s.phase == "matchday" then
				matchdayPanel()
			else
				contractPanel(s, seat)
			end
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
}
snapshots.OnClientEvent:Connect(function(data)
	local old = snapshot
	if old and data.version <= old.version then return end
	snapshot = data
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
	if not (moved or final or last.kind ~= before.kind or last.tile ~= before.tile or last.who ~= before.who) then return end
	local delay = if moved and not reduced() then .10 + match.motion.steps * .105 else 0
	task.delay(delay, function()
		if snapshot.serial ~= data.serial or not snapshot.match then return end
		local name = sessionName(last.who)
		local headline, caption, tint = outcomes[last.kind], name .. "  /  " .. t(Board.tiles[last.tile].name), colors.mint
		local shot: string? = nil
		if final then
			local tied = {}
			for _, record in match.standings do
				if record.score == match.standings[1].score then table.insert(tied, sessionName(record.id)) end
			end
			headline, caption, tint = "Final whistle", table.concat(tied, "  /  "), GOLD
		elseif last.card > 0 then
			local card = Edition.cards[last.card]
			headline, caption, tint = if russian then card.ru else card.title, name .. string.format("  /  %+d CR", last.amount), colors.blue
		elseif last.kind == "goal" or last.kind == "save" or last.kind == "offside" then
			shot = last.kind
			caption = name .. string.format("  /  %+d CR", last.amount)
			tint = if last.kind == "goal" then GOLD else colors.pink
		elseif last.kind == "league" then
			local league = Board.leagues[Board.tiles[last.tile].league]
			caption, tint = name .. "  /  " .. (if russian then league.ru else league.name), GOLD
		end
		if moved and snapshot.match.motion.serial == match.motion.serial then playSound("land") end
		if not headline then return end
		if snapshot.version ~= data.version and (snapshot.match.last.who ~= last.who or snapshot.match.last.kind ~= last.kind or snapshot.match.last.tile ~= last.tile) then return end
		local exciting = final or last.kind == "goal" or last.kind == "league"
		if exciting then playSound("win") elseif not moved then playSound("confirm") end
		resultBanner.reveal(t(headline), caption, tint, reduced(), mode,
			math.max(.28, 1 - (View.railWidth(root.AbsoluteSize) + 24) / math.max(1, root.AbsoluteSize.X)), shot)
		if exciting then tableView.celebrate(last.tile, true) elseif last.kind == "upgrade" then tableView.celebrate(last.tile, false) end
	end)
end)

repeat
	intent:FireServer("sync")
	task.wait(1)
until snapshot ~= nil
