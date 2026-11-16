--!strict
-- Emits labeled synthetic onboarding traffic and real rule-engine simulation results.
local Board = require("../src/shared/Board")
local Edition = require("../src/shared/EventCards")
local Rules = require("../src/shared/Rules")
local Experiment = require("../src/shared/Experiment")
local Game = Rules.withBoard(Board, Edition)

local seed = 613513
local function random(a: number, b: number): number
	seed = (seed * 48271) % 2147483647
	return a + seed % (b - a + 1)
end
local epoch = 1794528000
local sequence = 0
local function emit(dataset: string, id: number, session: number, offset: number, variant: string,
	device: string, channel: string, mode: string, name: string, value: number)
	sequence += 1
	print(string.format(
		'{"event_id":"e%d","dataset":"%s","player_id":"p%d","session_id":"s%d","ts":%d,"variant":"%s","device":"%s","channel":"%s","mode":"%s","name":"%s","value":%.3f}',
		sequence, dataset, id, session, epoch + offset, variant, device, channel, mode, name, value))
end

-- Marketing and behavioral effects here are explicit fixture parameters, for verifying the analyst workflow.
for id = 1, 3600 do
	local assigned = math.floor(id / 800) * 86400 + random(1, 7200)
	local arm = Experiment.arm(id)
	local device = if random(1, 10) <= 7 then "mobile" else "desktop"
	local channel = ({"direct", "friend", "campaign"})[random(1, 3)]
	local function participation(name: string, delay: number, value: number, session: number?)
		emit("synthetic_ab", id, session or id, assigned + delay, arm, device, channel, "solo", name, value)
	end
	participation("OnboardingAssigned_v1", 0, 1)
	local firstChance = 62 + (if arm == "coach" then 8 else 0) + (if device == "desktop" then 7 else 0)
	if random(1, 100) <= firstChance then
		local seconds = random(5, 88)
		participation("FirstRouteSeconds_v2", seconds, seconds)
		if random(1, 10) <= 7 then participation("ClubSigned_v1", seconds + 15, random(160, 245)) end
	elseif random(1, 10) == 1 then
		participation("FirstRouteSeconds_v2", 110, 110) -- boundary case: excluded from primary outcome
	end
	if random(1, 100) <= 64 then
		local duration = random(210, 510)
		participation("SeasonFinished_v1", duration, duration)
		if random(1, 100) <= 23 then participation("SeasonReplayed_v1", duration + 10, 1, id + 100000) end
	end
	if random(1, 100) <= 18 then participation("SessionJoined", 86401 + random(1, 2200), 1, id + 200000) end
end

for number = 1, 1200 do
	seed = number * 9973
	local seats = 2 + number % (Board.maxSeats - 1)
	local actors: {Rules.Entry} = {}
	for slot = 1, seats do table.insert(actors, {id = number * 10 + slot, name = "Bot", figure = slot, bot = true}) end
	local match = Game.new(actors, random)
	local decisions = 0
	local seconds, visits, goals = 0, 0, 0
	local auctions, soldAtAuction = 0, 0
	local fees, kickoffAwards = 0, 0
	while match.phase ~= "final" do
		local seat = match.seats[match.active]
		local when = match.phase
		if when == "auction" then
			Game.botBids(match)
			assert(Game.closeAuction(match, random))
			auctions += 1
			if match.last.amount < 0 then soldAtAuction += 1 end
		else
			assert(Game.apply(match, seat.id, Game.botAction(match), random))
		end
		decisions += 1
		seconds += if when == "move" then 6 else 4
		if when == "matchday" then
			visits += 1
			if match.last.kind == "goal" then goals += 1 end
		elseif when == "move" then
			if match.last.kind == "gate" then fees -= match.last.amount end
			if match.last.crossed then kickoffAwards += Board.kickoffCash end
		end
	end
	local function result(name: string, value: number, id: number?)
		emit("rules_simulation", id or number, number, seconds, "none", "none", "none", tostring(seats), name, value)
	end
	result("TableDecisions", decisions)
	result("TableFees", fees)
	result("TableKickoffAwards", kickoffAwards)
	result("TableCupVisits", visits)
	result("TableGoals", goals)
	result("TableAuctions", auctions)
	result("TableAuctionSales", soldAtAuction)
	for _, seat in match.seats do
		local clubs, upgrades = 0, 0
		for index, owned in match.clubs do
			if owned.owner == seat.id and Board.tiles[index].league > 0 then
				clubs += 1
				upgrades += owned.level
			end
		end
		result("EndingCash", seat.cash, seat.id)
		result("EndingValue", Game.score(match, seat.id), seat.id)
		result("OwnedClubs", clubs, seat.id)
		result("StadiumUpgrades", upgrades, seat.id)
		result("CupsWon", seat.trophies, seat.id)
	end
end
