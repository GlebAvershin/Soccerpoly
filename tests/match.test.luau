--!strict
local Board = require("../src/shared/Board")
local Edition = require("../src/shared/EventCards")
local Rules = require("../src/shared/Rules")
local Game = Rules.withBoard(Board, Edition)
local function low(a: number, _b: number): number return a end
local function start(rng: (number, number) -> number)
	return Game.new({{id = 10, name = "A", figure = 1}, {id = 20, name = "B", figure = 2}}, rng)
end

assert(#Board.tiles == 24)
assert(#Board.leagues == 5)
local clubCount = 0
local clubCodes: {[string]: boolean} = {}
for _, tile in Board.tiles do
	if tile.kind == "club" then
		assert(Board.leagues[tile.league] and not clubCodes[tile.code])
		clubCodes[tile.code] = true
		clubCount += 1
	end
end
assert(clubCount == 15)
for league in Board.leagues do
	local group = Board.members[league]
	assert(#group == 3)
	for rank, index in group do
		local baseline = Board.tiles[Board.members[1][rank]]
		assert(Board.tiles[index].price == baseline.price and Board.tiles[index].gate == baseline.gate)
	end
end
local s = start(low)
assert(not Game.apply(s, 20, "short", low))
assert(not Game.apply(s, 10, "buy", low))
assert(Game.apply(s, 10, "short", low) and s.phase == "offer")
assert(Game.apply(s, 10, "buy", low))
assert(s.clubs[2].owner == 10 and s.seats[1].cash == 700 - Board.tiles[2].price)
assert(s.active == 2)
assert(Game.apply(s, 20, "short", low))
assert(s.seats[1].cash == 700 - Board.tiles[2].price + Board.tiles[2].gate)
assert(s.seats[2].cash == 700 - Board.tiles[2].gate)

s = start(low)
s.seats[1].position = 24
assert(Game.apply(s, 10, "short", low))
assert(s.seats[1].cash == 840 and s.seats[1].position == 1)
s = start(low)
s.seats[1].cash = 0
assert(Game.apply(s, 10, "short", low) and s.phase == "auction")
assert(not Game.bid(s, 10, 1) and not Game.bid(s, 777, 1))
local minimum = Game.auctionMinimum(2)
s.seats[2].cash = minimum
assert(not Game.bid(s, 20, 2) and not Game.bid(s, 20, -1))
assert(Game.bid(s, 20, 1) and not Game.bid(s, 20, 0) and Game.auctionReady(s))
assert(s.seats[2].cash == minimum and s.clubs[2].owner == 0)
assert(Game.closeAuction(s, low) and not Game.closeAuction(s, low))
assert(s.active == 2 and s.seats[2].cash == 0 and s.clubs[2].owner == 20)
assert(s.last.kind == "auctionWon" and s.last.amount == -minimum)

s = start(low)
assert(Game.apply(s, 10, "short", low) and Game.apply(s, 10, "skip", low))
assert(Game.bid(s, 10, 2) and not Game.auctionReady(s))
assert(Game.bid(s, 20, 2) and Game.closeAuction(s, low))
assert(s.clubs[2].owner == 20 and s.last.who == 20 and s.motion.serial == 1)

s = start(low)
s.round, s.active = Board.rounds, 2
assert(Game.apply(s, 20, "short", low) and Game.apply(s, 20, "skip", low))
assert(Game.bid(s, 10, 0))
assert(Game.closeAuction(s, low) and s.phase == "final" and #s.standings == 2)
assert(s.last.kind == "auctionEmpty" and s.clubs[2].owner == 0)

s = start(low)
for _, index in Board.members[1] do
	if index ~= 2 then s.clubs[index].owner = 20 end
end
assert(Game.apply(s, 10, "short", low) and Game.apply(s, 10, "skip", low))
assert(Game.bid(s, 20, 1) and Game.closeAuction(s, low))
assert(s.last.kind == "auctionLeague" and Game.gate(s, 2) == 2 * Board.tiles[2].gate)

s = start(low)
s.clubs[2].owner = 10
assert(Game.apply(s, 10, "short", low) and Game.apply(s, 10, "upgrade", low))
assert(s.clubs[2].level == 1 and Game.apply(s, 20, "short", low))
s.seats[1].position = 1
assert(Game.apply(s, 10, "short", low) and s.phase == "move" and s.active == 2)
assert(s.clubs[2].level == 1)
s = start(low)
s.seats[1].position = 3
assert(Game.apply(s, 10, "short", low))
assert(s.last.title == "Scouting report" and s.seats[1].cash == 780)
s = start(low)
s.seats[2].cash = 7
for _, i in Board.members[1] do s.clubs[i].owner = 10 end
s.clubs[2].level = 1
assert(Game.gate(s, 2) == 2 * Board.tiles[2].gate + 2 * Board.upgradeGate)
local leagueCost = 0
for _, index in Board.members[1] do leagueCost += Board.tiles[index].price end
assert(Game.score(s, 10) == 700 + leagueCost + Board.upgradeCost + Board.leagueValue)
assert(Game.apply(s, 10, "short", low) and Game.apply(s, 10, "upgrade", low))
assert(s.clubs[2].level == 2)
assert(Game.apply(s, 20, "short", low) and s.seats[2].cash == 0 and s.last.amount == -7)
s.seats[1].cash = 0
assert(Game.apply(s, 10, "short", low) and s.phase == "move") -- Neither seat can afford the auction minimum.

-- Matchday action is role- and turn-neutral, and the trophy is worth portfolio value.
s = start(low)
s.seats[1].position = 11
assert(Game.apply(s, 10, "short", low) and s.phase == "matchday")
assert(not Game.apply(s, 20, "shoot", low))
assert(not Game.apply(s, 10, "buy", low))
assert(Game.apply(s, 10, "shoot", low))
assert(s.last.kind == "goal" and s.seats[1].cash == 840 and s.seats[1].trophies == 1)
assert(Game.score(s, 10) == 840 + Edition.trophy_value)
s = start(low)
s.seats[1].position, s.seats[1].cash = 11, 5
assert(Game.apply(s, 10, "short", low))
assert(Game.apply(s, 10, "shoot", function(_a, b) return b end))
assert(s.last.kind == "offside" and s.last.amount == -5 and s.seats[1].trophies == 0)
s = start(low)
s.seats[1].position = 11
assert(Game.apply(s, 10, "short", low) and Game.apply(s, 10, "safe", low))
assert(s.last.kind == "safe" and s.seats[1].cash == 700 + Edition.safe_cash)
for _, family in {{index = 4, reward = true}, {index = 14, reward = false}} do
	local deckSize = 0
	for _, card in Edition.cards do if (card.amount > 0) == family.reward then deckSize += 1 end end
	s = start(low)
	local seenCards: {[number]: boolean} = {}
	for draw = 1, deckSize + 1 do
		local seat = s.seats[s.active]
		seat.position = family.index - 1
		assert(Game.apply(s, seat.id, "short", low))
		local card = Edition.cards[s.last.card]
		assert(card and (card.amount > 0) == family.reward)
		if draw <= deckSize then assert(not seenCards[s.last.card], "Duplicate card before reshuffle") end
		seenCards[s.last.card] = true
	end
end

s = start(low)
s.seats[1].position, s.seats[2].position = 13, 3
assert(Game.apply(s, 10, "short", low) and s.seats[1].benched and s.active == 2)
assert(Game.apply(s, 20, "short", low) and s.phase == "bench")
assert(not Game.apply(s, 10, "long", low))
local oldMotion = s.motion.serial
assert(Game.apply(s, 10, "release", low) and s.phase == "move")
assert(s.seats[1].cash == 700 - Board.benchFee and s.motion.serial == oldMotion)
assert(not Game.apply(s, 10, "release", low))
assert(Game.apply(s, 10, "long", low) and s.phase == "offer" and s.seats[1].position == 18)

s = start(low)
s.seats[1].position, s.seats[1].benched, s.phase = 14, true, "bench"
s.seats[1].cash = 0
assert(not Game.apply(s, 10, "release", low))
assert(Game.apply(s, 10, "short", low) and not s.seats[1].benched and s.motion.steps == 1)

s = start(low)
local stadium, otherStadium = table.unpack(Board.assetGroups.venue)
local commercial = Board.assetGroups.commercial[1]
s.seats[1].position = stadium - 1
assert(Game.apply(s, 10, "short", low) and Game.apply(s, 10, "buy", low))
assert(s.clubs[stadium].owner == 10 and Game.gate(s, stadium) == 45)
s.clubs[otherStadium].owner, s.clubs[commercial].owner = 10, 10
assert(Game.gate(s, stadium) == 90 and Game.gate(s, commercial) == 35)
assert(not Game.apply(s, 20, "sell", low, stadium))
s.seats[2].position = stadium - 1
assert(Game.apply(s, 20, "short", low) and s.last.amount == -90)
assert(not Game.apply(s, 10, "sell", low, 10000) and not Game.apply(s, 10, "sell", low, stadium + 0.5))
local beforeSale = s.seats[1].cash
assert(Game.apply(s, 10, "sell", low, stadium))
assert(s.seats[1].cash == beforeSale + 108 and s.clubs[stadium].owner == 0 and Game.gate(s, otherStadium) == 45)
assert(not Game.apply(s, 10, "sell", low, commercial))
s.seats[1].position = stadium - 1
assert(Game.apply(s, 10, "short", low) and s.phase == "offer")
assert(Game.apply(s, 10, "skip", low) and Game.bid(s, 20, 1) and Game.closeAuction(s, low))
assert(s.clubs[stadium].owner == 20 and not s.soldThisTurn and s.last.kind == "auctionWon")

-- Sales and swaps settle in place with bilateral approval and no replay.
s = start(low)
s.clubs[2].owner, s.clubs[5].owner = 10, 20
assert(not Game.proposeTrade(s, 20, 10, 5, 0, 2))
assert(not Game.proposeTrade(s, 10, 10, 2, 0, 2))
assert(not Game.proposeTrade(s, 10, 20, 8, 0, 2))
assert(not Game.proposeTrade(s, 10, 20, 2, 0, 4))
assert(not Game.proposeTrade(s, 10, 20, 2.5, 0, 2))
assert(not Game.proposeTrade(s, 10, 20, 2, 5, 2))
assert(Game.proposeTrade(s, 10, 20, 2, 0, 3))
assert(not Game.replyTrade(s, 10, true))
assert(not Game.apply(s, 10, "sell", low, 2))
assert(Game.replyTrade(s, 20, true) and not Game.replyTrade(s, 20, true))
assert(s.trade == nil and s.clubs[2].owner == 20 and s.phase == "move" and s.motion.serial == 0)
assert(s.seats[1].cash == 876 and s.seats[2].cash == 524 and s.last.kind == "tradeSale")
assert(not Game.proposeTrade(s, 10, 20, 2, 0, 1))
assert(Game.apply(s, 10, "short", low) and not s.tradeUsed and s.active == 2)

s = start(low)
s.clubs[2].owner, s.clubs[5].owner, s.clubs[9].owner = 10, 20, 10
s.clubs[9].level = 1
assert(not Game.proposeTrade(s, 10, 20, 2, 5, 0))
assert(Game.apply(s, 10, "sellUpgrades", low, 9))
assert(s.clubs[9].owner == 10 and s.clubs[9].level == 0 and s.seats[1].cash == 750)
assert(Game.proposeTrade(s, 10, 20, 2, 5, 0) and Game.replyTrade(s, 20, true))
assert(s.clubs[2].owner == 20 and s.clubs[5].owner == 10 and s.last.kind == "tradeSwap")
assert(s.seats[1].cash == 750 and s.seats[2].cash == 700)

-- Cross-tier swaps settle the list difference in either direction and conserve both portfolios.
for _, pair in {{2, 23}, {23, 2}} do
	s = start(low)
	local offered, requested = pair[1], pair[2]
	s.clubs[offered].owner, s.clubs[requested].owner = 10, 20
	local difference = Game.swapDifference(offered, requested)
	assert(math.abs(difference) == 110)
	local payer = if difference > 0 then s.seats[2] else s.seats[1]
	payer.cash = 109
	assert(not Game.proposeTrade(s, 10, 20, offered, requested, 0))
	payer.cash = 110
	assert(Game.proposeTrade(s, 10, 20, offered, requested, 0))
	payer.cash = 109
	assert(Game.replyTrade(s, 20, true))
	assert(s.clubs[offered].owner == 10 and s.clubs[requested].owner == 20 and s.last.kind == "start")

	s = start(low)
	s.clubs[offered].owner, s.clubs[requested].owner = 10, 20
	local sellerValue, buyerValue = Game.score(s, 10), Game.score(s, 20)
	assert(Game.proposeTrade(s, 10, 20, offered, requested, 0) and Game.replyTrade(s, 20, true))
	assert(s.last.amount == difference and s.seats[1].cash == 700 + difference and s.seats[2].cash == 700 - difference)
	assert(Game.score(s, 10) == sellerValue and Game.score(s, 20) == buyerValue)
end
for i, tile in Board.tiles do
	if tile.league > 0 then
		for option in Board.tradeRates do
			local price = assert(Game.tradePrice(i, option))
			assert(math.abs(price - tile.price) <= math.ceil(tile.price / 10))
		end
	end
end

for _, decline in {false, true} do
	s = start(low)
	s.clubs[2].owner, s.clubs[5].owner = 10, 20
	assert(Game.proposeTrade(s, 10, 20, 2, 0, 2))
	if decline then
		assert(Game.replyTrade(s, 20, false))
		assert(not Game.proposeTrade(s, 10, 20, 2, 5, 0))
	else
		assert(Game.apply(s, 10, "long", low))
	end
	assert(s.trade == nil and s.clubs[2].owner == 10 and not Game.replyTrade(s, 20, true))
end
s = start(low)
s.clubs[2].owner, s.seats[2].cash = 10, 10
assert(not Game.proposeTrade(s, 10, 20, 2, 0, 2))
s.seats[2].cash = 700
assert(Game.proposeTrade(s, 10, 20, 2, 0, 2))
s.seats[2].cash = 10
assert(Game.replyTrade(s, 20, true))
assert(s.clubs[2].owner == 10 and s.seats[1].cash == 700 and s.last.kind == "start")

for figure, power in Board.figureAbilities do
	s = start(low)
	local seat = s.seats[1]
	seat.figure = figure
	assert(not Game.apply(s, 20, "ability", low))
	assert(Game.apply(s, 10, "ability", low) and not Game.apply(s, 10, "ability", low))
	assert(s.phase == "move" and s.round == 1 and s.motion.serial == 0)
	if power == "route" then
		assert(s.short == 2 and s.long == 4 and seat.cash == 680)
		assert(Game.apply(s, 10, "short", low) and s.motion.steps == 2)
	elseif power == "goal" then
		seat.position = 11
		assert(Game.apply(s, 10, "short", low) and Game.apply(s, 10, "shoot", low))
		assert(seat.cash == 885 and seat.trophies == 1)
	elseif power == "kickoff" then
		seat.position = 24
		assert(Game.apply(s, 10, "short", low) and seat.cash == 890)
	elseif power == "gate" then
		s.clubs[2].owner, s.clubs[2].level = 20, 1
		assert(Game.apply(s, 10, "short", low) and seat.cash == 650 and s.seats[2].cash == 750)
	elseif power == "upgrade" then
		s.clubs[2].owner, seat.cash = 10, 50
		assert(Game.apply(s, 10, "short", low) and s.phase == "upgrade")
		assert(Game.apply(s, 10, "upgrade", low) and seat.cash == 0 and s.clubs[2].level == 1)
	elseif power == "var" then
		seat.position = 13
		assert(Game.apply(s, 10, "short", low) and s.last.kind == "var" and s.last.card > 0)
		assert(not seat.benched and seat.cash == 700)
	end
	assert(seat.ability == "spent")
	if power ~= "route" then assert(s.last.power == power) end
end

s = start(low)
s.seats[1].cash = 19
assert(not Game.apply(s, 10, "ability", low) and s.short == 1 and s.seats[1].ability == "ready")

s = start(low)
s.seats[1].figure, s.seats[1].position = 2, 11
assert(Game.apply(s, 10, "ability", low) and Game.apply(s, 10, "short", low))
assert(Game.apply(s, 10, "shoot", function(a, b) return math.floor((a + b) / 2) + 1 end))
assert(s.last.kind == "save" and s.last.power == "goal" and s.seats[1].ability == "spent" and s.seats[1].trophies == 0)

for _, auction in {false, true} do
	s = start(low)
	s.seats[1].figure = 5
	assert(Game.apply(s, 10, "ability", low) and Game.apply(s, 10, "short", low))
	if auction then
		assert(Game.apply(s, 10, "skip", low) and Game.bid(s, 10, 2) and Game.closeAuction(s, low))
	else
		assert(Game.apply(s, 10, "buy", low))
	end
	assert(s.seats[1].ability == "spent" and s.seats[1].cash == 570 and s.last.power == "upgrade")
end

s = start(low)
s.seats[1].figure, s.seats[1].position = 6, 3
assert(Game.apply(s, 10, "ability", low) and Game.apply(s, 10, "short", low))
assert(s.last.kind == "goalDeck" and s.last.power == "var" and s.seats[1].cash == 780 + Board.abilityAmounts.var)

s = start(low)
s.seats[1].figure, s.seats[1].cash, s.clubs[2].owner = 4, 15, 20
assert(Game.apply(s, 10, "ability", low) and Game.apply(s, 10, "short", low))
assert(s.last.kind == "gate" and s.last.amount == 0 and s.seats[1].cash == 15 and s.seats[2].cash == 700)

print("Rule scenarios passed")
local wins = {0, 0, 0, 0, 0, 0}
local leagueCount, longest = 0, 0
local baselineActions, transfersActions, completedSales, completedSwaps = 0, 0, 0, 0
local function season(seed: number, entries: {Rules.Entry}, optional: boolean): (Rules.Match, number)
	local x = seed
	local function rng(a: number, b: number): number
		x = (x * 16807) % 2147483647
		return a + x % (b - a + 1)
	end
	local count = #entries
	local match = Game.new(entries, rng)
	local actions = 0
	while match.phase ~= "final" do
		if match.phase == "auction" then
			Game.botBids(match)
			assert(Game.auctionReady(match))
			assert(Game.closeAuction(match, rng))
		else
			local seat = match.seats[match.active]
			if optional and match.phase == "move" then
				if Game.botUsesAbility(match) then assert(Game.apply(match, seat.id, "ability", rng)) end
				local buyer = match.seats[match.active % count + 1].id
				local offered, requested = 0, 0
				for index in Board.tiles do
					if Game.canTransfer(match, seat.id, index) then offered = index end
					if Game.canTransfer(match, buyer, index) then requested = index end
				end
				if (seed + match.round) % 2 == 0 then requested = 0 end
				if Game.proposeTrade(match, seat.id, buyer, offered, requested, if requested == 0 then 2 else 0) then
					local trade = assert(match.trade)
					local accept = Game.botAcceptsTrade(match, trade)
					assert(Game.replyTrade(match, buyer, accept))
					if accept then
						if requested == 0 then completedSales += 1 else completedSwaps += 1 end
					end
				end
				assert(match.phase == "move", "Optional action added a mandatory phase")
			end
			assert(Game.apply(match, seat.id, Game.botAction(match), rng))
		end
		actions += 1
		assert(actions <= count * Board.rounds * 3, "Match did not terminate")
		for _, seat in match.seats do
			assert(seat.cash >= 0 and seat.position >= 1 and seat.position <= #Board.tiles)
		end
	end
	assert(match.round == Board.rounds and #match.standings == count)
	assert(match.motion.serial == Board.rounds * count)
	return match, actions
end

for seed = 1, 800 do
	local count = 2 + seed % (Board.maxSeats - 1)
	local entries: {Rules.Entry} = {}
	for i = 1, count do table.insert(entries, {id = i, name = tostring(i), figure = i, bot = true}) end
	local _, baseline = season(seed, entries, false)
	local match, actions = season(seed, entries, true)
	baselineActions += baseline
	transfersActions += actions
	longest = math.max(actions, longest)
	for i, record in match.standings do
		assert(record.score == Game.score(match, record.id))
		if i > 1 then assert(record.score <= match.standings[i - 1].score) end
	end
	wins[match.standings[1].id] += 1
	for i = 1, count do
		for league in Board.members do if Game.setComplete(match, i, league) then leagueCount += 1 end end
	end
	assert(not Game.apply(match, match.seats[match.active].id, "short", low))
end
assert(completedSales > 0 and completedSwaps > 0)
assert(transfersActions <= baselineActions * 1.05, "Required phase count grew by over 5%")
print(string.format("800 paired seeds: %.2f vs %.2f required phase resolutions per season; %d sales, %d swaps; max phases: %d",
	baselineActions / 800, transfersActions / 800, completedSales, completedSwaps, longest))
print(string.format("Complete sets: %d; first place by seat: %s", leagueCount, table.concat(wins, "/")))

local Experiment = require("../src/shared/Experiment")
local coach = 0
for id = 1, 4000 do
	local arm = Experiment.arm(id)
	assert(arm == Experiment.arm(id))
	if arm == "coach" then coach += 1 end
end
assert(coach >= 1960 and coach <= 2040, "Experiment bucket skew on sequential IDs")
print("Stable experiment assignment checked on 4000 IDs")
