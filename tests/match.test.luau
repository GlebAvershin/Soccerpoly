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
for league = 1, 4 do assert(#Board.members[league] == 3) end
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
assert(Game.apply(s, 10, "short", low) and s.phase == "move" and s.active == 2)
s = start(low)
s.seats[1].position = 3
assert(Game.apply(s, 10, "short", low))
assert(s.last.title == "Scouting report" and s.seats[1].cash == 780)
s = start(low)
s.seats[2].cash = 7
for _, i in Board.members[1] do s.clubs[i].owner = 10 end
s.clubs[2].level = 1
assert(Game.gate(s, 2) == 2 * Board.tiles[2].gate + 2 * Board.upgradeGate)
assert(Game.score(s, 10) == 700 + Board.tiles[2].price + Board.tiles[3].price + Board.tiles[7].price + Board.upgradeCost + Board.leagueValue)
assert(Game.apply(s, 10, "short", low) and Game.apply(s, 10, "upgrade", low))
assert(s.clubs[2].level == 2)
assert(Game.apply(s, 20, "short", low) and s.seats[2].cash == 0 and s.last.amount == -7)
s.seats[1].cash = 0
assert(Game.apply(s, 10, "short", low) and s.phase == "move") -- next owned club offers upgrade only if affordable

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
s = start(low)
local seenCards: {[number]: boolean} = {}
for i = 1, #Edition.cards + 1 do
	local seat = s.seats[s.active]
	seat.position = 3
	assert(Game.apply(s, seat.id, "short", low))
	assert(s.last.card > 0)
	if i <= #Edition.cards then assert(not seenCards[s.last.card], "Duplicate card before reshuffle") end
	seenCards[s.last.card] = true
end

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
		assert(Game.apply(match, match.seats[match.active].id, Game.botAction(match), rng))
		actions += 1
		assert(actions <= count * Board.rounds * 2, "Match did not terminate")
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
