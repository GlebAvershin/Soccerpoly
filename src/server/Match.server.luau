--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage:WaitForChild("League")
local Board = require(Shared.TourBoard)
local Edition = require(Shared.EventCards)
local Rules = require(Shared.Rules)
local Game = Rules.withBoard(Board, Edition)
local Telemetry = require(script.Parent.Telemetry)
local buildWorld = require(script.Parent.World)
Players.CharacterAutoLoads = false
local rng = Random.new()
local function nextInteger(a: number, b: number): number return rng:NextInteger(a, b) end
local bots = table.freeze({"Atlas", "Vega", "Nova"})
local MAX_SEATS = Board.maxSeats
local ALLOWED = table.freeze({
	sync = true, start = true, lobby = true, figure = true, roll = true, rebuy = true,
	buy = true, upgrade = true, skip = true, shoot = true, safe = true, bid = true, release = true, sell = true,
	sellUpgrades = true, trade = true, tradeAccept = true, tradeDecline = true, travel = true, festival = true, shield = true, bankrupt = true,
})
local AUCTION_SECONDS = 8
local BOT_MOVE_SECONDS, BOT_OFFER_SECONDS = 1.7, 1.5
local MIN_ACTION_SECONDS = 0.18
local studioArgs
if RunService:IsStudio() then
	local ok, args = pcall(function() return game:GetService("StudioTestService"):GetTestArgs() end)
	if ok then studioArgs = args end
end
local fast = studioArgs == "WorldDraftSmoke" or studioArgs == "WorldDraftDuo" or studioArgs == "WorldDraftFour"
local network = Instance.new("Folder")
network.Name = "WorldDraft"
local intent = Instance.new("RemoteEvent")
intent.Name, intent.Parent = "Intent", network
local pushed = Instance.new("RemoteEvent")
pushed.Name, pushed.Parent = "Snapshot", network

type LobbySeat = {id: number, order: number, name: string, figure: number}
type Quota = {tokens: number, time: number}
type Funnel = {id: string, step: number, completed: number, moved: boolean}
local lobby: {[Player]: LobbySeat} = {}
local quotas: {[Player]: Quota} = {}
local funnels: {[Player]: Funnel} = {}
local match: Rules.Match? = nil
local startedAt, deadline, availableAt, matchEndsAt = 0, 0, 0, 0
local fastRng = Random.new(74214)
local entryNumber, version, serial, auctionToken = 0, 0, 0, 0
local tradeToken, tradeExpires, tradeBotAt = 0, 0, 0
local mode, variant = "solo", "none"

local function seatList(): {LobbySeat}
	local result = {}
	for _, seat in lobby do table.insert(result, seat) end
	table.sort(result, function(a: LobbySeat, b: LobbySeat) return a.order < b.order end)
	while #result > MAX_SEATS do table.remove(result) end
	return result
end

local function output(viewer: Player?)
	local listed = seatList()
	local s = match
	local scores = {}
	local gates = {}
	local auction = nil
	local trade = s and s.trade
	local privateTrade = if trade and viewer and (viewer.UserId == trade.buyer or viewer.UserId == trade.seller)
		then {terms = trade, token = tradeToken, expires = tradeExpires} else nil
	if s and s.auction then
		local responded = {}
		for i, seat in s.seats do responded[i] = s.auction.replies[seat.id] ~= nil end
		auction = {token = auctionToken, tile = s.auction.tile, responded = responded}
	end
	if s then
		for _, seat in s.seats do table.insert(scores, Game.score(s, seat.id)) end
		for i in Board.tiles do gates[i] = Game.gate(s, i) end
	end
	return {
		version = version, serial = serial, lobby = listed, host = if listed[1] then listed[1].id else 0,
		match = if s then {
			seats = s.seats, clubs = s.clubs, active = s.active, round = s.round, phase = s.phase,
			short = s.short, long = s.long, last = s.last, motion = s.motion, standings = s.standings, soldThisTurn = s.soldThisTurn, tradeUsed = s.tradeUsed,
			diceA = s.diceA, diceB = s.diceB, rollSerial = s.rollSerial, debt = s.debt,
			festival = s.festival, winner = s.winner, finishReason = s.finishReason,
		} else nil,
		deadline = deadline, availableAt = availableAt, matchEndsAt = matchEndsAt, scores = scores, gates = gates,
		variant = variant, auction = auction, trade = privateTrade,
	}
end

local function publish()
	version += 1
	if match and match.trade then
		for _, player in Players:GetPlayers() do pushed:FireClient(player, output(player)) end
	else
		pushed:FireAllClients(output())
	end
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
	funnels[player] = {id = HttpService:GenerateGUID(false), step = 0, completed = 0, moved = false}
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
	local intro = if moved then .75 + s.motion.steps * .09 else MIN_ACTION_SECONDS
	if s.phase == "auction" then
		auctionToken = version + 1
		setClock(AUCTION_SECONDS + intro, intro)
		return
	end
	local bot = s.seats[s.active].bot
	local move = s.phase == "move" or s.phase == "tour" or s.phase == "bench"
	if fast and bot then
		setClock(intro + .16, intro)
	else
		local seconds = if bot then (if move then BOT_MOVE_SECONDS else BOT_OFFER_SECONDS)
			else Board.turnSeconds
		setClock(seconds + intro, intro)
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
	for figure = 1, #Board.figures do
		if #entries >= 4 then break end
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
	matchEndsAt = workspace:GetServerTimeNow() + (if fast then 25 else Board.matchSeconds)
	clockTurn(s, false)
	for _, seat in s.seats do
		if not seat.bot then
			local player = Players:GetPlayerByUserId(seat.id)
			if player then
				step(player, 2, "Season started")
				local funnel = funnels[player]
				if funnel then
					funnel.moved = false
					if funnel.completed > 0 then Telemetry.event(player, "SeasonReplayed_v1", 1, mode, variant) end
				end
				Telemetry.event(player, "SeasonStarted_v1", 1, mode, variant, Board.id)
			end
		end
	end
	publish()
end

local function action(s: Rules.Match, verb: string, player: Player?, index: number?)
	local previousMotion, previousPhase, previousActive = s.motion.serial, s.phase, s.active
	local seat = s.seats[s.active]
	local function studioRoll(low: number, high: number): number
		return fastRng:NextInteger(low, high)
	end
	local roll = if fast then studioRoll else nextInteger
	if fast and verb == "roll" and not s.rollSerial then
		local nextDie = 0
		roll = function(low: number, high: number): number
			nextDie += 1
			return if nextDie <= 2 then nextDie else studioRoll(low, high)
		end
	end
	local accepted: boolean
	if verb == "closeAuction" then
		accepted = Game.closeAuction(s, roll)
	elseif verb == "fullTime" then
		while s.phase == "debt" do
			local resolution, asset = Game.tourDecision(s)
			if not Game.apply(s, seat.id, resolution, roll, asset) then break end
		end
		Game.finish(s, nil, "time")
		accepted = true
	else
		accepted = Game.apply(s, seat.id, verb, roll, index)
	end
	if not accepted then return false end
	local moved = s.motion.serial ~= previousMotion
	if s.phase ~= previousPhase or previousActive ~= s.active or (verb ~= "sell" and verb ~= "sellUpgrades") then clockTurn(s, moved) end
	publish()
	if player then
		local funnel = funnels[player]
		if moved and funnel and not funnel.moved then
			funnel.moved = true
			Telemetry.event(player, "FirstRollSeconds_v1", os.clock() - startedAt, mode, variant)
			step(player, 3, "First roll resolved")
		end
		if moved then Telemetry.event(player, "TourMove_v1", 1, mode, variant, verb) end
		if previousPhase == "offer" and verb == "buy" then
			local tile = Board.tiles[seat.position]
			Telemetry.event(player, if tile.league > 0 then "ClubSigned_v1" else "AssetSigned_v1", -s.last.amount, mode, variant)
		end
		if previousPhase == "matchday" then
			Telemetry.event(player, "MatchdayResolved_v1", 1, mode, variant, s.last.kind)
		end
		if moved and s.last.card > 0 then
			Telemetry.event(player, "TacticsDrawn_v1", 1, mode, variant, Edition.cards[s.last.card].id)
		end
		if s.last.kind == "league" then Telemetry.event(player, "LeagueCompleted_v1", 1, mode, variant) end
	end
	if previousPhase == "auction" and s.last.amount < 0 then
		local winner = Players:GetPlayerByUserId(s.last.who)
		if winner then
			local tile = Board.tiles[s.last.tile]
			Telemetry.event(winner, if tile.league > 0 then "ClubSigned_v1" else "AssetSigned_v1", -s.last.amount, mode, variant)
			Telemetry.event(winner, "AuctionWon_v1", -s.last.amount, mode, variant)
			if s.last.kind == "auctionLeague" then Telemetry.event(winner, "LeagueCompleted_v1", 1, mode, variant) end
		end
	end
	if s.phase == "final" then
		for _, attendee in s.seats do
			local p = if attendee.bot then nil else Players:GetPlayerByUserId(attendee.id)
			if p then
				local funnel = funnels[p]
				if funnel then funnel.completed += 1 end
				step(p, 4, "Season finished")
				Telemetry.event(p, "SeasonFinished_v1", math.floor(os.clock() - startedAt), mode, variant, Board.id)
			end
		end
	end
	return true
end

local function integer(value: any): boolean
	return type(value) == "number" and value % 1 == 0
end

local function replyTrade(s: Rules.Match, id: number, accept: boolean)
	if Game.replyTrade(s, id, accept) then publish() end
end

intent.OnServerEvent:Connect(function(player, verb, revision, value)
	if not lobby[player] or not consume(player) or type(verb) ~= "string" or not ALLOWED[verb] then return end
	if verb == "sync" then
		pushed:FireClient(player, output(player))
		return
	end
	local s = match
	if verb == "tradeAccept" or verb == "tradeDecline" then
		if s and s.trade and revision == tradeToken and workspace:GetServerTimeNow() < tradeExpires then
			replyTrade(s, player.UserId, verb == "tradeAccept")
		end
		return
	end
	if verb == "bid" then
		if not s or not s.auction or revision ~= auctionToken or type(value) ~= "number" then return end
		local now = workspace:GetServerTimeNow()
		if now < availableAt or now >= deadline then return end
		for _, bidder in s.seats do
			if bidder.id == player.UserId and not bidder.bot and Game.bid(s, bidder.id, value) then
				if Game.auctionReady(s) then action(s, "closeAuction", nil) else publish() end
				break
			end
		end
		return
	end
	if revision ~= version then
		pushed:FireClient(player, output(player))
		return
	end
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
		if s or type(value) ~= "number" or value % 1 ~= 0 or value < 1 or value > #Board.figures or value == seat.figure then return end
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
		if now < availableAt or now >= deadline then return end
		if verb == "trade" then
			if deadline - now < Board.tradeMinimumReply then return end
			if type(value) ~= "table" or not integer(value.buyer) or not integer(value.offered)
				or not integer(value.requested) or not integer(value.option) then return end
			if Game.proposeTrade(s, player.UserId, value.buyer, value.offered, value.requested, value.option) then
				tradeToken, tradeExpires = version + 1, math.min(now + Board.tradeSeconds, deadline)
				tradeBotAt = now + (if fast then 0.15 else 0.65)
				publish()
			end
		else
			action(s, verb, player, if type(value) == "number" then value else nil)
		end
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
		local trade = s.trade
		if trade and (trade.seller == player.UserId or trade.buyer == player.UserId) then s.trade = nil end
		for i, seat in s.seats do
			if seat.id == player.UserId and not seat.bot then
				seat.bot = true
				if i == s.active and s.phase ~= "auction" then clockTurn(s, false) end
				break
			end
		end
	end
	publish()
end)
for _, player in Players:GetPlayers() do joined(player) end

while task.wait(if fast then 0.05 else 0.16) do
	local s = match
	local now = workspace:GetServerTimeNow()
	local trade = s and s.trade
	if s and trade and now < deadline then
		if now >= tradeExpires then
			replyTrade(s, trade.buyer, false)
		elseif now >= tradeBotAt then
			for _, seat in s.seats do
				if seat.id == trade.buyer and seat.bot then
					replyTrade(s, seat.id, Game.botAcceptsTrade(s, trade))
					break
				end
			end
		end
	end
	if s and s.phase ~= "final" and now >= matchEndsAt then
		action(s, "fullTime", nil)
	elseif s and s.auction then
		if now >= availableAt then
			local changed = Game.botBids(s)
			if now >= deadline or Game.auctionReady(s) then
				action(s, "closeAuction", nil)
			elseif changed then
				publish()
			end
		end
	elseif s and s.phase ~= "final" and now >= deadline then
		local seat = s.seats[s.active]
		local verb, index = Game.tourDecision(s)
		local p = if seat.bot then nil else Players:GetPlayerByUserId(seat.id)
		if p then Telemetry.event(p, "TurnTimedOut_v1", 1, mode, variant, s.phase) end
		action(s, verb, nil, index)
	end
end
