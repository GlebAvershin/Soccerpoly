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

assert(Board.formats[1].matchSeconds == 1200 and Board.formats[1].turnSeconds == 15)
assert(Board.formats[2].matchSeconds == 3600 and Board.formats[2].turnSeconds == 30)

s = start()
s.seats[1].position = 10
assert(Game.apply(s, 1, "roll", roll(3, 4)) and s.phase == "matchday")
assert(not Game.apply(s, 1, "host", first))
assert(Game.apply(s, 1, "shoot", first))
assert(s.last.kind == "goal" and s.seats[1].cash == Board.startCash + 140 and s.seats[1].trophies == 1)
assert(s.active == 2)

s = start()
s.clubs[4].owner, s.seats[1].position = 1, 10
assert(Game.apply(s, 1, "roll", roll(3, 4)) and Game.apply(s, 1, "host", first))
assert(s.phase == "championship" and not Game.apply(s, 1, "festival", first, 2))
assert(Game.apply(s, 1, "festival", first, 4) and s.festival == 4)

for _, event in {4, 5, 6} do
	s = start()
	s.clubs[4].owner, s.seats[1].position = 1, 2
	local rngValues = {1, 2, event}
	local function draw(low: number, high: number): number
		local value = table.remove(rngValues, 1) or low
		assert(value >= low and value <= high)
		return value
	end
	assert(Game.apply(s, 1, "roll", draw))
	if event == 4 then
		assert(s.phase == "matchday" and not Game.apply(s, 1, "host", first))
		assert(Game.tourDecision(s) == "safe")
		assert(Game.apply(s, 1, "safe", first) and s.seats[1].cash == Board.startCash + Edition.safe_cash)
	elseif event == 5 then
		assert(s.last.kind == "sponsor" and s.seats[1].cash == Board.startCash + Board.sponsorBonus)
	else
		assert(s.phase == "shield" and Game.apply(s, 1, "shield", first, 4) and s.clubs[4].shield)
	end
end

for rollValue = 1, 6 do
	s = start()
	s.phase = "matchday"
	local function shot(low: number, high: number): number
		return if high == 6 then rollValue else low
	end
	assert(Game.apply(s, 1, "shoot", shot))
	assert(s.last.kind == (if rollValue <= 3 then "goal" elseif rollValue <= 5 then "save" else "offside"))
end

print("Tour verified: 32 cells, indexed builds, doubles, bench, away tour, repurchase, debt, property victories, formats and Matchday outcomes")
