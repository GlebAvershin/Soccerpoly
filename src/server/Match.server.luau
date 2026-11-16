--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage:WaitForChild("League")
local Board = require(Shared.Board)
local Edition = require(Shared.EventCards)
local Experiment = require(Shared.Experiment)
local Rules = require(Shared.Rules)
local Game = Rules.withBoard(Board, Edition)
local Telemetry = require(script.Parent.Telemetry)
local buildWorld = require(script.Parent.World)
Players.CharacterAutoLoads = false
local rng = Random.new()
local function nextInteger(a: number, b: number): number return rng:NextInteger(a, b) end
local bots = table.freeze({"Atlas", "Vega", "Nova"})
local MAX_SEATS = #Board.figures
local ALLOWED = table.freeze({
	sync = true, start = true, lobby = true, figure = true, short = true, long = true,
	buy = true, upgrade = true, skip = true, shoot = true, safe = true,
})
local LOOP_SECONDS, OFFER_SECONDS = 20, 13
local BOT_MOVE_SECONDS, BOT_OFFER_SECONDS = 1.7, 1.5
local MIN_ACTION_SECONDS = 0.18
local studioArgs
if RunService:IsStudio() then
	local ok, args = pcall(function() return game:GetService("StudioTestService"):GetTestArgs() end)
	if ok then studioArgs = args end
end
local fast = studioArgs == "WorldDraftSmoke" or studioArgs == "WorldDraftDuo" or studioArgs == "WorldDraftSix"
local network = Instance.new("Folder")
network.Name = "WorldDraft"
local intent = Instance.new("RemoteEvent")
intent.Name, intent.Parent = "Intent", network
local pushed = Instance.new("RemoteEvent")
pushed.Name, pushed.Parent = "Snapshot", network

type LobbySeat = {id: number, order: number, name: string, figure: number}
type Quota = {tokens: number, time: number}
type Funnel = {id: string, step: number, joinedAt: number, completed: number, assigned: boolean, moved: boolean}
local lobby: {[Player]: LobbySeat} = {}
local quotas: {[Player]: Quota} = {}
local funnels: {[Player]: Funnel} = {}
local match: Rules.Match? = nil
local startedAt, deadline, availableAt = 0, 0, 0
local entryNumber, version, serial = 0, 0, 0
local mode, variant = "solo", "none"

local function seatList(): {LobbySeat}
	local result = {}
	for _, seat in lobby do table.insert(result, seat) end
	table.sort(result, function(a: LobbySeat, b: LobbySeat) return a.order < b.order end)
	while #result > MAX_SEATS do table.remove(result) end
	return result
end

local function output()
	local listed = seatList()
	local s = match
	local scores = {}
	local gates = {}
	if s then
		for _, seat in s.seats do table.insert(scores, Game.score(s, seat.id)) end
		for i in Board.tiles do gates[i] = Game.gate(s, i) end
	end
	return {
		version = version, serial = serial, lobby = listed, host = if listed[1] then listed[1].id else 0,
		match = if s then {
			seats = s.seats, clubs = s.clubs, active = s.active, round = s.round, phase = s.phase,
			short = s.short, long = s.long, last = s.last, motion = s.motion, standings = s.standings,
		} else nil,
		deadline = deadline, availableAt = availableAt, scores = scores, gates = gates,
		variant = variant,
	}
end

local function publish()
	version += 1
	pushed:FireAllClients(output())
end

local function step(player: Player, target: number, label: string)
	local funnel = funnels[player]
	if funnel and funnel.step == target - 1 then
		funnel.step = target
		Telemetry.step(player, funnel.id, target, label)
	end
end

-- When a watcher takes an open seat, preserve existing selections.
local function refreshFigures()
	local listed, used, undecided = seatList(), {}, {}
	for _, seat in listed do
		if seat.figure > 0 and not used[seat.figure] then
			used[seat.figure] = true
		else
			table.insert(undecided, seat)
		end
	end
	for _, seat in undecided do
		for figure = 1, MAX_SEATS do
			if not used[figure] then
				seat.figure, used[figure] = figure, true
				break
			end
		end
	end
end

local function joined(player: Player)
	if lobby[player] then return end
	entryNumber += 1
	lobby[player] = {id = player.UserId, order = entryNumber, name = player.DisplayName, figure = 0}
	refreshFigures()
	funnels[player] = {id = HttpService:GenerateGUID(false), step = 0, joinedAt = os.clock(), completed = 0, assigned = false, moved = false}
	step(player, 1, "Joined")
	publish()
end

local function consume(player: Player): boolean
	local now = os.clock()
	local quota = quotas[player] or {tokens = 12, time = now}
	local tokens = math.min(12, quota.tokens + (now - quota.time) * 6)
	quota.tokens, quota.time = math.max(0, tokens - 1), now
	quotas[player] = quota
	return tokens >= 1
end

local function setClock(duration: number, delay: number?)
	local now = workspace:GetServerTimeNow()
	deadline, availableAt = now + duration, now + (delay or MIN_ACTION_SECONDS)
end

local function clockTurn(s: Rules.Match, moved: boolean)
	if s.phase == "final" then
		deadline = 0
		return
	end
	local bot = s.seats[s.active].bot
	local move = s.phase == "move"
	if fast and bot then
		setClock(0.10, 0)
	else
		local seconds = if bot then (if move then BOT_MOVE_SECONDS else BOT_OFFER_SECONDS)
			else (if move then LOOP_SECONDS else OFFER_SECONDS)
		setClock(seconds, if moved then 0.84 else MIN_ACTION_SECONDS)
	end
end

local function start()
	local entries: {Rules.Entry} = {}
	local used = {}
	for _, seat in seatList() do
		if #entries == MAX_SEATS then break end
		table.insert(entries, {id = seat.id, name = seat.name, figure = seat.figure})
		used[seat.figure] = true
	end
	mode = if #entries == 1 then "solo" else "social"
	local enableExperiment = RunService:IsStudio() or workspace:GetAttribute("CoachExperimentEnabled") == true
	variant = if enableExperiment and mode == "solo" then Experiment.arm(entries[1].id) else "none"
	for figure = 1, MAX_SEATS do
		if #entries >= 3 then break end
		if not used[figure] then
			table.insert(entries, {id = -100 - figure, name = bots[#entries] or "Atlas", figure = figure, bot = true})
		end
	end
	-- Randomise seating so the host has no systematic first-move advantage.
	if not fast then
		for i = #entries, 2, -1 do
			local j = nextInteger(1, i)
			entries[i], entries[j] = entries[j], entries[i]
		end
	end
	local s = Game.new(entries, if fast then function(a, _b) return a end else nextInteger)
	match = s
	serial += 1
	startedAt = os.clock()
	clockTurn(s, false)
	for _, seat in s.seats do
		if not seat.bot then
			local player = Players:GetPlayerByUserId(seat.id)
			if player then
				step(player, 2, "Season started")
				local funnel = funnels[player]
				if funnel then
					funnel.moved = false
					if variant ~= "none" and not funnel.assigned then
						funnel.assigned = true
						Telemetry.event(player, "OnboardingAssigned_v1", 1, mode, variant, Experiment.id)
					end
					if funnel.completed > 0 then Telemetry.event(player, "SeasonReplayed_v1", 1, mode, variant) end
				end
				Telemetry.event(player, "SeasonStarted_v1", 1, mode, variant, Edition.id)
			end
		end
	end
	publish()
end

local function action(s: Rules.Match, verb: string, player: Player?)
	local previousMotion, previousPhase = s.motion.serial, s.phase
	local seat = s.seats[s.active]
	if not Game.apply(s, seat.id, verb, if fast then function(a, _b) return a end else nextInteger) then return false end
	local moved = s.motion.serial ~= previousMotion
	clockTurn(s, moved)
	publish()
	if player then
		local funnel = funnels[player]
		if moved and funnel and not funnel.moved then
			funnel.moved = true
			Telemetry.event(player, "FirstRouteSeconds_v2", os.clock() - startedAt, mode, variant)
			if funnel.step == 2 then Telemetry.event(player, "FirstRouteSeconds_v1", os.clock() - funnel.joinedAt, mode, variant) end
			step(player, 3, "First route chosen")
		end
		if moved then Telemetry.event(player, "RouteChosen_v1", 1, mode, variant, verb) end
		if previousPhase == "offer" and verb == "buy" then
			Telemetry.event(player, "ClubSigned_v1", Board.tiles[seat.position].price, mode, variant)
		end
		if previousPhase == "matchday" then
			Telemetry.event(player, "MatchdayResolved_v1", 1, mode, variant, s.last.kind)
		end
		if moved and s.last.card > 0 then
			Telemetry.event(player, "TacticsDrawn_v1", 1, mode, variant, Edition.cards[s.last.card].id)
		end
		if s.last.kind == "league" then Telemetry.event(player, "LeagueCompleted_v1", 1, mode, variant) end
	end
	if s.phase == "final" then
		for _, attendee in s.seats do
			local p = if attendee.bot then nil else Players:GetPlayerByUserId(attendee.id)
			if p then
				local funnel = funnels[p]
				if funnel then funnel.completed += 1 end
				step(p, 4, "Season finished")
				Telemetry.event(p, "SeasonFinished_v1", math.floor(os.clock() - startedAt), mode, variant, Edition.id)
			end
		end
	end
	return true
end

intent.OnServerEvent:Connect(function(player, verb, revision, value)
	if not lobby[player] or not consume(player) or type(verb) ~= "string" or not ALLOWED[verb] then return end
	if verb == "sync" then
		pushed:FireClient(player, output())
		return
	end
	if revision ~= version then
		pushed:FireClient(player, output())
		return
	end
	local s = match
	local seat = lobby[player]
	if verb == "start" then
		local listed = seatList()
		if s == nil and listed[1] and listed[1].id == seat.id then start() end
	elseif verb == "lobby" then
		if s and s.phase == "final" then
			match, deadline = nil, 0
			publish()
		end
	elseif verb == "figure" then
		if s or type(value) ~= "number" or value % 1 ~= 0 or value < 1 or value > MAX_SEATS or value == seat.figure then return end
		local eligible = false
		for _, slot in seatList() do
			if slot.id == seat.id then
				eligible = true
			elseif slot.figure == value then
				return
			end
		end
		if eligible then
			seat.figure = value
			publish()
		end
	elseif s and s.phase ~= "final" and not s.seats[s.active].bot and s.seats[s.active].id == player.UserId then
		local now = workspace:GetServerTimeNow()
		if now >= availableAt and now < deadline then action(s, verb, player) end
	end
end)

buildWorld()
network.Parent = ReplicatedStorage
Players.PlayerAdded:Connect(joined)
Players.PlayerRemoving:Connect(function(player)
	lobby[player], quotas[player], funnels[player] = nil, nil, nil
	refreshFigures()
	local s = match
	if next(lobby) == nil then
		match, deadline = nil, 0
	elseif s then
		for i, seat in s.seats do
			if seat.id == player.UserId and not seat.bot then
				seat.bot = true
				if i == s.active then clockTurn(s, false) end
				break
			end
		end
	end
	publish()
end)
for _, player in Players:GetPlayers() do joined(player) end

while task.wait(if fast then 0.05 else 0.16) do
	local s = match
	if s and s.phase ~= "final" and workspace:GetServerTimeNow() >= deadline then
		local seat = s.seats[s.active]
		local verb = if seat.bot then Game.botAction(s) elseif s.phase == "move" then "short" elseif s.phase == "matchday" then "safe" else "skip"
		local p = if seat.bot then nil else Players:GetPlayerByUserId(seat.id)
		if p then Telemetry.event(p, "TurnTimedOut_v1", 1, mode, variant, s.phase) end
		action(s, verb, nil)
	end
end
