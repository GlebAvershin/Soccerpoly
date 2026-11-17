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
	table.freeze({name = "Lionel Messi", localName = "Лионель Месси", model = "messi", countryCode = "ARG", role = "Playmaker", ru = "Плеймейкер", number = "10", color = 0x9ADBF3, kit = 0xEDF3EC, dark = 0x1B3044, skin = 0xCE926F, height = .96, width = .94, leftFoot = true}),
	table.freeze({name = "Cristiano Ronaldo", localName = "Криштиану Роналду", model = "ronaldo", countryCode = "POR", role = "Striker", ru = "Нападающий", number = "07", color = 0xFA7992, kit = 0xB92547, dark = 0x143D38, skin = 0xBF815E, height = 1.06, width = 1.04, leftFoot = false}),
	table.freeze({name = "Kylian Mbappé", localName = "Килиан Мбаппе", model = "mbappe", countryCode = "FRA", role = "Forward", ru = "Форвард", number = "10", color = 0x929EFF, kit = 0x444C9D, dark = 0x202746, skin = 0x92573C, height = 1.01, width = 1.06, leftFoot = false}),
	table.freeze({name = "Lamine Yamal", localName = "Ламин Ямаль", model = "yamal", countryCode = "ESP", role = "Winger", ru = "Вингер", number = "19", color = 0xF8A763, kit = 0xDA422F, dark = 0x35233D, skin = 0xAF7152, height = 1.00, width = .88, leftFoot = true}),
	table.freeze({name = "Erling Haaland", localName = "Эрлинг Холанд", model = "haaland", countryCode = "NOR", role = "Striker", ru = "Нападающий", number = "09", color = 0xE1DED0, kit = 0xD9DEE0, dark = 0x233B55, skin = 0xE7A78B, height = 1.11, width = 1.10, leftFoot = true}),
	table.freeze({name = "Vinícius Júnior", localName = "Винисиус Жуниор", model = "vinicius", countryCode = "BRA", role = "Winger", ru = "Вингер", number = "07", color = 0xBCF389, kit = 0xECD44B, dark = 0x244E43, skin = 0x884D37, height = .99, width = .97, leftFoot = false}),
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
Board.tour, Board.benchTile, Board.matchSeconds = false, 0, 0
return table.freeze(Board)
