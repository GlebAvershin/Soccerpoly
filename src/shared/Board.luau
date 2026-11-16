--!strict
local Board = {}
export type Tile = {kind: string, name: string, code: string, city: string, league: number, price: number, gate: number, award: number}
local function club(name: string, code: string, city: string, league: number, price: number, gate: number): Tile
	return {kind = "club", name = name, code = code, city = city, league = league, price = price, gate = gate, award = 0}
end
local function stop(kind: string, name: string, code: string, award: number?): Tile
	return {kind = kind, name = name, code = code, city = "", league = 0, price = 0, gate = 0, award = award or 0}
end

Board.leagues = table.freeze({
	table.freeze({name = "Iberia", code = "IBE", color = 0xFF9754, ru = "Иберия"}),
	table.freeze({name = "Atlantic", code = "ATL", color = 0x56C7FA, ru = "Атлантика"}),
	table.freeze({name = "Pacific", code = "PAC", color = 0xBC9AFF, ru = "Тихий океан"}),
	table.freeze({name = "Southern", code = "SUR", color = 0x71DFAD, ru = "Южная лига"}),
})
Board.tiles = table.freeze({
	stop("kickoff", "Kickoff", "KO"),
	club("Castilla Crown", "CAS", "Madrid", 1, 160, 55),
	club("Porto Tide", "POR", "Porto", 1, 180, 62),
	stop("tactics", "Tactics deck", "TAC"),
	club("London Forge", "LON", "London", 2, 190, 66),
	stop("broadcast", "TV rights", "TV", 105),
	club("Sevilla Sol", "SEV", "Seville", 1, 200, 70),
	stop("sponsor", "Sponsor", "SP", 75),
	club("Rotterdam Dock", "ROT", "Rotterdam", 2, 215, 74),
	stop("tactics", "Tactics deck", "TAC"),
	club("Osaka Kites", "OSA", "Osaka", 3, 225, 78),
	stop("matchday", "Matchday", "MD", 85),
	club("Dakar Comets", "DAK", "Dakar", 2, 240, 84),
	stop("tactics", "Tactics deck", "TAC"),
	club("Han River FC", "HAN", "Seoul", 3, 245, 86),
	stop("sponsor", "Sponsor", "SP", 75),
	club("Lima Condors", "LIM", "Lima", 4, 255, 92),
	stop("broadcast", "TV rights", "TV", 105),
	club("Sydney Suns", "SYD", "Sydney", 3, 270, 98),
	stop("tactics", "Tactics deck", "TAC"),
	club("Rio Aurora", "RIO", "Rio de Janeiro", 4, 280, 104),
	stop("matchday", "Matchday", "MD", 85),
	club("Cape Strikers", "CPT", "Cape Town", 4, 290, 110),
	stop("whistle", "Added time", "+", 120),
})
for _, tile in Board.tiles do table.freeze(tile) end
local members: {{number}} = {{}, {}, {}, {}}
for i, tile in Board.tiles do
	if tile.league > 0 then table.insert(members[tile.league], i) end
end
for _, league in members do table.freeze(league) end
Board.members = table.freeze(members)

Board.figures = table.freeze({
	table.freeze({name = "Mika Vale", role = "Playmaker", ru = "Плеймейкер", number = "08", color = 0x7BFAAA, dark = 0x193F37, skin = 0xC88D62, hair = 0x251820}),
	table.freeze({name = "Inez Sol", role = "Striker", ru = "Нападающая", number = "09", color = 0xFF9F69, dark = 0x57263B, skin = 0xAC6244, hair = 0x30182C}),
	table.freeze({name = "Kai Ito", role = "Winger", ru = "Вингер", number = "17", color = 0x6CBFFF, dark = 0x29315A, skin = 0xF4BD93, hair = 0x233653}),
	table.freeze({name = "Amara Diop", role = "Keeper", ru = "Вратарь", number = "01", color = 0xEBACFF, dark = 0x492A67, skin = 0x885341, hair = 0x221C2C}),
})

Board.cards = table.freeze({
	table.freeze({title = "Scouting report", ru = "Отчёт скаута", body = "A new partner backs the academy.", ruBody = "Новый партнёр поддержал академию.", amount = 80}),
	table.freeze({title = "Clean sheet", ru = "Сухой матч", body = "The defence earns a team bonus.", ruBody = "Защита заработала командную премию.", amount = 115}),
	table.freeze({title = "Derby night", ru = "Вечер дерби", body = "A sold-out derby fills the stands.", ruBody = "На дерби проданы все билеты.", amount = 145}),
	table.freeze({title = "Pitch repairs", ru = "Ремонт газона", body = "The grounds crew needs new turf.", ruBody = "Стадиону нужно новое покрытие.", amount = -45}),
	table.freeze({title = "Away support", ru = "Выездная поддержка", body = "Fans turn out on the road.", ruBody = "Болельщики поддержали команду на выезде.", amount = 100}),
	table.freeze({title = "Travel delay", ru = "Задержка рейса", body = "The squad books another flight.", ruBody = "Команда забронировала другой рейс.", amount = -35}),
})

Board.rounds = 8
Board.startCash = 700
Board.kickoffCash = 140
Board.upgradeCost = 100
Board.upgradeGate = 45
Board.maxLevel = 2
Board.leagueValue = 160
return table.freeze(Board)
