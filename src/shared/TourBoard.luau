--!strict
local Base = require(if script then script.Parent.Board else "./Board")
local Board = table.clone(Base)

local function property(kind: string, name: string, code: string, league: number, price: number, gate: number): Base.Tile
	return table.freeze({kind = kind, name = name, code = code, city = "", league = league, price = price, gate = gate, award = 0})
end

local function club(name: string, code: string, league: number, price: number, gate: number): Base.Tile
	return property("club", name, code, league, price, gate)
end

local function venue(name: string, code: string): Base.Tile
	return property("venue", name, code, 0, 200, 25)
end

local function stop(kind: string, name: string, code: string, award: number?): Base.Tile
	return table.freeze({kind = kind, name = name, code = code, city = "", league = 0, price = 0, gate = 0, award = award or 0})
end

Board.tiles = table.freeze({
	stop("kickoff", "Kickoff", "KO"),
	club("Sevilla FC", "SEV", 1, 80, 20),
	stop("tax", "League tax", "TAX", -100),
	club("Atlético Madrid", "ATM", 1, 120, 30),
	stop("chance", "Chance", "CH"),
	club("FC Barcelona", "FCB", 1, 160, 45),
	club("Real Madrid", "RMA", 1, 200, 60),
	venue("Santiago Bernabéu", "SB"),
	stop("tour", "Away tour", "TOUR"),
	club("Arsenal", "ARS", 2, 160, 40),
	club("Liverpool FC", "LIV", 2, 180, 45),
	club("Manchester City", "MCI", 2, 200, 55),
	stop("chance", "Chance", "CH"),
	club("Manchester United", "MUN", 2, 220, 60),
	venue("Old Trafford", "OT"),
	club("AC Milan", "ACM", 4, 180, 45),
	stop("championship", "Championship", "CUP"),
	club("Inter Milan", "INT", 4, 180, 45),
	venue("San Siro", "SS"),
	club("Juventus", "JUV", 4, 200, 55),
	stop("chance", "Chance", "CH"),
	club("Napoli", "NAP", 4, 160, 40),
	club("Bayer Leverkusen", "B04", 3, 140, 35),
	club("RB Leipzig", "RBL", 3, 120, 30),
	stop("bench", "The bench", "BENCH"),
	club("Borussia Dortmund", "BVB", 3, 160, 40),
	club("Bayern Munich", "BAY", 3, 200, 60),
	club("Olympique Lyonnais", "OL", 5, 100, 25),
	venue("Allianz Arena", "AA"),
	club("Olympique de Marseille", "OM", 5, 140, 35),
	club("AS Monaco", "ASM", 5, 160, 45),
	club("Paris Saint-Germain", "PSG", 5, 200, 60),
})

local members: {{number}} = {}
for index in Board.leagues do members[index] = {} end
local venues: {number} = {}
for index, tile in Board.tiles do
	if tile.league > 0 then table.insert(members[tile.league], index)
	elseif tile.kind == "venue" then table.insert(venues, index) end
end
for _, league in members do table.freeze(league) end
Board.members = table.freeze(members)
Board.assetGroups = table.freeze({venue = table.freeze(venues)})
Board.startCash, Board.kickoffCash = 2000, 200
Board.upgradeCost, Board.upgradeGate, Board.maxLevel = 100, 70, 3
Board.maxSeats = 4
Board.tour, Board.id = true, "continental_tour_v1"
Board.benchTile = 25
Board.matchSeconds, Board.turnSeconds = 20 * 60, 15
return table.freeze(Board)
