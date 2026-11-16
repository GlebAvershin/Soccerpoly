--!strict
-- Repeat each seed with all six rotations so every figure plays every seat.
local Board = require("../src/shared/Board")
local Edition = require("../src/shared/EventCards")
local Rules = require("../src/shared/Rules")
local Game = Rules.withBoard(Board, Edition)

type Stats = {score: number, wins: number, spent: number}
type Totals = {phases: number, sales: number, swaps: number}
local samples = 4320
local figureCount = #Board.figures

local function wins(s: Rules.Match, id: number): number
	local first, tied, won = s.standings[1].score, 0, false
	for _, standing in s.standings do
		if standing.score ~= first then break end
		tied += 1
		won = won or standing.id == id
	end
	return if won then 1 / tied else 0
end

local function routeValue(s: Rules.Match, seat: Rules.Seat, steps: number): number
	local index = Game.target(seat.position, steps)
	local tile, club = Board.tiles[index], s.clubs[index]
	local power = if seat.ability == "armed" then Board.figureAbilities[seat.figure] else ""
	local value = 0
	if seat.position + steps > #Board.tiles then
		value = Board.kickoffCash + (if power == "kickoff" then Board.abilityAmounts.kickoff else 0)
	end
	if tile.kind == "goalDeck" then return value + 100 + (if power == "var" then Board.abilityAmounts.var else 0) end
	if tile.kind == "offsideDeck" then return value + (if power == "var" then 0 else -55) end
	if tile.kind == "matchday" then
		return value + 91 + (if power == "goal" then (5 / 6) * Board.abilityAmounts.goal else 0)
	end
	if tile.price == 0 then return value + tile.award end
	if club.owner == seat.id then
		return value + (if power == "upgrade" and club.level == 0 and tile.league > 0 then 55 else 10)
	end
	if club.owner ~= 0 then
		local rebate = if power == "gate" then Board.abilityAmounts.gate else 0
		return value - math.max(0, math.min(seat.cash + value, Game.gate(s, index)) - rebate)
	end
	if seat.cash + value < tile.price then return value end
	local partners = 0
	if tile.league > 0 then
		for _, member in Board.members[tile.league] do
			if s.clubs[member].owner == seat.id then partners += 1 end
		end
	end
	return value + 73 + tile.gate * .22 + partners * 55
end

local function play(seed: number, rotation: number, powers: boolean, market: boolean, totals: Totals): Rules.Match
	local x = seed
	local function rng(a: number, b: number): number
		x = (x * 16807) % 2147483647
		return a + x % (b - a + 1)
	end
	local seats: {Rules.Entry} = {}
	for i = 1, figureCount do
		seats[i] = {id = i, name = tostring(i), figure = (i + rotation - 1) % figureCount + 1, bot = true}
	end
	local s = Game.new(seats, rng)
	while s.phase ~= "final" do
		totals.phases += 1
		if s.phase == "auction" then
			Game.botBids(s)
			assert(Game.closeAuction(s, rng))
			continue
		end
		local seat = s.seats[s.active]
		if s.phase == "move" then
			if powers and seat.ability == "ready" then
				local best = math.max(routeValue(s, seat, s.short), routeValue(s, seat, s.long))
				if Board.figureAbilities[seat.figure] ~= "route" or (seat.cash >= Board.abilityAmounts.route
					and routeValue(s, seat, Game.shortAfterPower(s.short)) > best + 12 + Board.abilityAmounts.route) then
					assert(Game.apply(s, seat.id, "ability", rng))
				end
			end
			if market then
				local buyer = s.seats[(s.active + (seed + s.round) % (figureCount - 1)) % figureCount + 1]
				local offered, requested = 0, 0
				for i in Board.tiles do
					if Game.canTransfer(s, seat.id, i) then offered = i end
					if Game.canTransfer(s, buyer.id, i) then requested = i end
				end
				if (seed + s.round) % 2 == 0 then requested = 0 end
				local option = if requested == 0 then (seed + s.round) % #Board.tradeRates + 1 else 0
				if Game.proposeTrade(s, seat.id, buyer.id, offered, requested, option) then
					local deal = assert(s.trade)
					local accept = Game.botAcceptsTrade(s, deal)
					assert(Game.replyTrade(s, buyer.id, accept))
					if accept then
						if requested == 0 then totals.sales += 1 else totals.swaps += 1 end
					end
					assert(s.phase == "move" and s.trade == nil)
				end
			end
		end
		local verb = if s.phase == "move" then (if routeValue(s, seat, s.long) >= routeValue(s, seat, s.short) then "long" else "short")
			else Game.botAction(s)
		assert(Game.apply(s, seat.id, verb, rng))
	end
	assert(s.round == Board.rounds and s.motion.serial == Board.rounds * figureCount and #s.standings == figureCount)
	for _, seat in s.seats do assert(seat.cash >= 0) end
	return s
end

local function report(label: string, powers: boolean, market: boolean): ({Stats}, number)
	local totals = {phases = 0, sales = 0, swaps = 0}
	local byFigure: {Stats} = {}
	for i = 1, figureCount do byFigure[i] = {score = 0, wins = 0, spent = 0} end
	for trial = 1, samples do
		local rotation = (trial - 1) % figureCount
		local seed = math.ceil(trial / figureCount) * 9973
		local s = play(seed, rotation, powers, market, totals)
		for _, seat in s.seats do
			local stats = byFigure[seat.figure]
			stats.score += Game.score(s, seat.id)
			stats.wins += wins(s, seat.id)
			stats.spent += if seat.ability == "spent" then 1 else 0
		end
	end
	print(string.format("%s: %d seasons, %.2f phases, %d sales, %d swaps", label, samples, totals.phases / samples, totals.sales, totals.swaps))
	return byFigure, totals.phases / samples
end

local baseline = report("Market only", false, true)
local full, fullPhases = report("Market with powers", true, true)
local noDeals, noDealsPhases = report("Powers only", true, false)
assert(fullPhases <= noDealsPhases * 1.05, "The market increased required phase resolutions by over 5%")
for _, scenario in {full, noDeals} do
	local minimum, maximum = 1, 0
	for _, stats in scenario do
		minimum = math.min(minimum, stats.wins / samples)
		maximum = math.max(maximum, stats.wins / samples)
	end
	assert(maximum - minimum <= .04, "Figure win-rate spread exceeded four points under the simulated policy")
end
for i, figure in Board.figures do
	print(string.format("%-12s | points %6.1f -> %6.1f (%+5.1f) | wins %5.2f%% -> %5.2f%% | spent %5.1f%%, no deals %5.2f%% win",
		figure.name, baseline[i].score / samples, full[i].score / samples, (full[i].score - baseline[i].score) / samples,
		baseline[i].wins * 100 / samples, full[i].wins * 100 / samples, full[i].spent * 100 / samples, noDeals[i].wins * 100 / samples))
end
