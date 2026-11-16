--!strict
local Board = {}
export type Tile = {kind: string, name: string, code: string, city: string, league: number, price: number, gate: number, award: number}
local function club(name: string, code: string, city: string, league: number, price: number, gate: number): Tile
	return {kind = "club", name = name, code = code, city = city, league = league, price = price, gate = gate, award = 0}
end
local function asset(kind: string, name: string, code: string, city: string, price: number, gate: number): Tile
	return {kind = kind, name = name, code = code, city = city, league = 0, price = price, gate = gate, award = 0}
end

local function stop(kind: string, name: string, code: string, award: number?): Tile
	return {kind = kind, name = name, code = code, city = "", league = 0, price = 0, gate = 0, award = award or 0}
end

Board.leagues = table.freeze({
	table.freeze({name = "La Liga", code = "LAL", color = 0xF19D4D, ru = "Ла Лига"}),
	table.freeze({name = "Premier League", code = "EPL", color = 0x62BAED, ru = "АПЛ"}),
	table.freeze({name = "Bundesliga", code = "BUN", color = 0xAA8DE3, ru = "Бундеслига"}),
	table.freeze({name = "Serie A", code = "SEA", color = 0x64BC8A, ru = "Серия А"}),
	table.freeze({name = "Ligue 1", code = "L1", color = 0xE8889D, ru = "Лига 1"}),
})
Board.tiles = table.freeze({
	stop("kickoff", "Kickoff", "KO"),
	club("Atlético Madrid", "ATM", "Madrid", 1, 160, 55),
	club("Olympique de Marseille", "OM", "Marseille", 5, 160, 55),
	stop("goalDeck", "Goal deck", "GOL"),
	club("Liverpool FC", "LIV", "Liverpool", 2, 160, 55),
	club("Bayer Leverkusen", "B04", "Leverkusen", 3, 160, 55),
	club("AC Milan", "ACM", "Milan", 4, 160, 55),
	asset("venue", "Old Trafford", "OT", "Manchester", 180, 45),
	club("FC Barcelona", "FCB", "Barcelona", 1, 215, 75),
	club("Manchester City", "MCI", "Manchester", 2, 215, 75),
	club("Borussia Dortmund", "BVB", "Dortmund", 3, 215, 75),
	stop("matchday", "Matchday", "MD"),
	club("Inter Milan", "INT", "Milan", 4, 215, 75),
	stop("offsideDeck", "Offside deck", "VAR"),
	club("AS Monaco", "ASM", "Monaco", 5, 215, 75),
	club("Manchester United", "MUN", "Manchester", 2, 270, 98),
	club("Juventus", "JUV", "Turin", 4, 270, 98),
	asset("commercial", "TV Rights", "TV", "", 145, 35),
	club("Bayern Munich", "BAY", "Munich", 3, 270, 98),
	asset("commercial", "Kit Deal", "KIT", "", 145, 35),
	club("Paris Saint-Germain", "PSG", "Paris", 5, 270, 98),
	stop("matchday", "Matchday", "MD"),
	club("Real Madrid", "RMA", "Madrid", 1, 270, 98),
	asset("venue", "Santiago Bernabéu", "SB", "Madrid", 180, 45),
})
for _, tile in Board.tiles do table.freeze(tile) end
local members: {{number}} = {}
local assetGroups: {[string]: {number}} = {venue = {}, commercial = {}}
for league in Board.leagues do members[league] = {} end
for i, tile in Board.tiles do
	if tile.league > 0 then
		table.insert(members[tile.league], i)
	elseif assetGroups[tile.kind] then
		table.insert(assetGroups[tile.kind], i)
	end
end
for _, league in members do table.freeze(league) end
Board.members = table.freeze(members)
for _, group in assetGroups do table.freeze(group) end
Board.assetGroups = table.freeze(assetGroups)
Board.benchFee = 50

Board.figures = table.freeze({
	table.freeze({name = "Mika Vale", role = "Playmaker", ru = "Плеймейкер", number = "08", color = 0x7BFAAA, dark = 0x193F37, skin = 0xC88D62, hair = 0x251820}),
	table.freeze({name = "Inez Sol", role = "Striker", ru = "Нападающая", number = "09", color = 0xFF9F69, dark = 0x57263B, skin = 0xAC6244, hair = 0x30182C}),
	table.freeze({name = "Kai Ito", role = "Winger", ru = "Вингер", number = "17", color = 0x6CBFFF, dark = 0x29315A, skin = 0xF4BD93, hair = 0x233653}),
	table.freeze({name = "Amara Diop", role = "Keeper", ru = "Вратарь", number = "01", color = 0xEBACFF, dark = 0x492A67, skin = 0x885341, hair = 0x221C2C}),
	table.freeze({name = "Rafa Marin", role = "Coach", ru = "Тренер", number = "CT", color = 0xF4D46B, dark = 0x39453F, skin = 0xCF9269, hair = 0x3B2A27}),
	table.freeze({name = "Samira Noor", role = "Referee", ru = "Арбитр", number = "RF", color = 0xF588A5, dark = 0x402A49, skin = 0xBD785B, hair = 0x262132}),
})

Board.figureAbilities = table.freeze({"route", "goal", "kickoff", "gate", "upgrade", "var"})
Board.abilityAmounts = table.freeze({route = 20, goal = 45, kickoff = 50, gate = 50, upgrade = 50, signing = 30, var = 50})
Board.tradeSeconds = 6
Board.tradeMinimumReply = 3
Board.tradeRates = table.freeze({90, 100, 110})
Board.maxSeats = #Board.figures
Board.rounds = 8
Board.startCash = 700
Board.kickoffCash = 140
Board.upgradeCost = 100
Board.upgradeGate = 45
Board.maxLevel = 2
Board.leagueValue = 160
return table.freeze(Board)
