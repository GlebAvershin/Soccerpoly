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

print("Rule scenarios passed")
local wins = {0, 0, 0, 0, 0, 0}
local leagueCount, longest = 0, 0
for seed = 1, 800 do
	local x = seed
	local function rng(a: number, b: number): number
		x = (x * 16807) % 2147483647
		return a + x % (b - a + 1)
	end
	local count = 2 + seed % (Board.maxSeats - 1)
	local entries: {Rules.Entry} = {}
	for i = 1, count do table.insert(entries, {id = i, name = tostring(i), figure = i, bot = true}) end
	local match = Game.new(entries, rng)
	local actions = 0
	while match.phase ~= "final" do
		if match.phase == "auction" then
			Game.botBids(match)
			assert(Game.auctionReady(match))
			assert(Game.closeAuction(match, rng))
		else
			assert(Game.apply(match, match.seats[match.active].id, Game.botAction(match), rng))
		end
		actions += 1
		assert(actions <= count * Board.rounds * 3, "Match did not terminate")
		for _, seat in match.seats do
			assert(seat.cash >= 0 and seat.position >= 1 and seat.position <= #Board.tiles)
		end
	end
	longest = math.max(actions, longest)
	assert(match.round == Board.rounds and #match.standings == count)
	assert(match.motion.serial == Board.rounds * count)
	for i, record in match.standings do
		assert(record.score == Game.score(match, record.id))
		if i > 1 then assert(record.score <= match.standings[i - 1].score) end
	end
	wins[match.standings[1].id] += 1
	for i = 1, count do
		for league in Board.members do if Game.setComplete(match, i, league) then leagueCount += 1 end end
	end
	assert(not Game.apply(match, match.seats[match.active].id, "short", rng))
end
print(string.format("800 seeded seasons passed; max actions: %d, complete sets: %d, first place by seat: %s", longest, leagueCount, table.concat(wins, "/")))

local Experiment = require("../src/shared/Experiment")
local coach = 0
for id = 1, 4000 do
	local arm = Experiment.arm(id)
	assert(arm == Experiment.arm(id))
	if arm == "coach" then coach += 1 end
end
assert(coach >= 1960 and coach <= 2040, "Experiment bucket skew on sequential IDs")
print("Stable experiment assignment checked on 4000 IDs")
