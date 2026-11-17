--!strict
local Board = require("../src/shared/TourBoard")
local Edition = require("../src/shared/EventCards")
local Game = require("../src/shared/Rules").withBoard(Board, Edition)

local function first(low: number, _high: number): number return low end

local function roll(a: number, b: number)
	local pending = {a, b}
	return function(low: number, high: number): number
		local value = table.remove(pending, 1) or low
		assert(value >= low and value <= high)
		return value
	end
end

local function start()
	return Game.new({{id = 1, name = "One", figure = 1}, {id = 2, name = "Two", figure = 2}}, first)
end

assert(#Board.tiles == 32)
for _, group in Board.members do assert(#group == 4) end
assert(#Board.assetGroups.venue == 4)

local s = start()
assert(not Game.apply(s, 2, "roll", roll(1, 2)))
assert(not Game.apply(s, 1, "long", roll(1, 2)))
assert(Game.apply(s, 1, "roll", roll(1, 2)))
assert(s.phase == "offer" and s.motion.steps == 3 and s.diceA == 1 and s.diceB == 2)
assert(not Game.apply(s, 1, "buy", first, 1.3))
assert(Game.apply(s, 1, "buy", first, 2))
assert(s.clubs[4].owner == 1 and s.clubs[4].level == 2)
assert(s.seats[1].cash == Board.startCash - Board.tiles[4].price - 2 * Board.upgradeCost)
assert(Game.apply(s, 2, "roll", roll(1, 2)))
assert(s.phase == "rebuy")
local price, rent = Game.rebuyPrice(s, 4), Game.gate(s, 4)
assert(s.seats[2].cash == Board.startCash - rent)
assert(Game.apply(s, 2, "rebuy", first))
assert(s.clubs[4].owner == 2 and s.clubs[4].level == 2)
assert(s.seats[1].cash == Board.startCash - Board.tiles[4].price - 2 * Board.upgradeCost + rent + price)

s = start()
s.clubs[4].owner = 2
s.active, s.phase = 2, "shield"
assert(not Game.apply(s, 2, "shield", first, 2))
assert(Game.apply(s, 2, "shield", first, 4))
assert(s.clubs[4].shield and s.active == 1)
assert(Game.apply(s, 1, "roll", roll(1, 2)))
assert(s.phase == "move" and s.clubs[4].owner == 2 and s.seats[1].cash == Board.startCash - Game.gate(s, 4))

s = start()
assert(Game.apply(s, 1, "roll", roll(1, 2)) and Game.apply(s, 1, "skip", first))
assert(s.phase == "move" and s.auction == nil and s.clubs[4].owner == 0)

s = start()
assert(Game.apply(s, 1, "roll", roll(1, 1)) and s.active == 1)
assert(s.seats[1].cash == Board.startCash + Board.tiles[3].award)
assert(Game.apply(s, 1, "roll", roll(1, 1)) and s.active == 1)
assert(Game.apply(s, 1, "roll", roll(1, 1)) and s.active == 2)
assert(s.seats[1].position == Board.benchTile and s.seats[1].benched and s.motion.warp)
s.active, s.phase = 1, "bench"
assert(Game.apply(s, 1, "roll", roll(1, 2)) and s.seats[1].benched)
s.active, s.phase = 1, "bench"
assert(Game.apply(s, 1, "roll", roll(1, 1)) and not s.seats[1].benched)

s = start()
s.seats[1].position, s.phase, s.seats[1].touring = 9, "tour", true
assert(not Game.apply(s, 1, "travel", first, 9))
assert(Game.apply(s, 1, "travel", first, 2))
assert(s.seats[1].cash == Board.startCash + Board.kickoffCash and s.motion.warp)
assert(s.phase == "offer" and s.seats[1].position == 2)

s = start()
s.clubs[4].owner, s.clubs[4].level = 2, 3
s.clubs[2].owner = 1
s.seats[1].cash = 1
assert(Game.apply(s, 1, "roll", roll(1, 2)))
assert(s.phase == "debt")
assert(not Game.apply(s, 1, "sell", first, 4))
assert(Game.apply(s, 1, "sell", first, 2))
assert(s.phase == "debt" and s.clubs[2].owner == 0)
assert(Game.apply(s, 1, "bankrupt", first))
assert(s.phase == "final" and s.winner == 2 and s.finishReason == "bankruptcy")

for _, reason in {"line", "venues", "triple"} do
	s = start()
	if reason == "line" then
		for i = 2, 8 do if Board.tiles[i].price > 0 then s.clubs[i].owner = 1 end end
	elseif reason == "venues" then
		for _, i in Board.assetGroups.venue do s.clubs[i].owner = 1 end
	else
		for _, league in {2, 4, 5} do
			for _, i in Board.members[league] do s.clubs[i].owner = 1 end
		end
	end
	assert(Game.apply(s, 1, "roll", roll(1, 1)))
	assert(s.phase == "final" and s.winner == 1 and s.finishReason == reason, reason)
end

print("Tour verified: 32 cells, indexed builds, doubles, bench, away tour, repurchase, debt and property victories")
