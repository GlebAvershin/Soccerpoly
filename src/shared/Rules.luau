--!strict
-- The board is injected so the same rules run in Studio and the standalone Luau CLI.
type RNG = (number, number) -> number
type Tile = {code: string, city: string, kind: string, name: string, league: number, price: number, gate: number, award: number}
type Board = {
	read tiles: {Tile}, read members: {{number}},
	read cards: {{read title: string, read amount: number, read body: string, read ru: string, read ruBody: string}}, read rounds: number,
	read startCash: number, read kickoffCash: number, read upgradeCost: number, read upgradeGate: number,
	read maxLevel: number, read leagueValue: number,
}
export type Entry = {id: number, name: string, figure: number, bot: boolean?}
export type Seat = {id: number, name: string, figure: number, bot: boolean, cash: number, position: number}
export type Club = {owner: number, level: number}
export type Story = {kind: string, title: string, who: number, tile: number, amount: number, card: number, crossed: boolean}
export type Motion = {serial: number, who: number, from: number, steps: number}
export type Standing = {id: number, score: number}
export type Match = {
	seats: {Seat}, clubs: {Club}, active: number, round: number, phase: string, short: number, long: number,
	last: Story, motion: Motion, standings: {Standing},
}

local function withBoard(board: Board)
	local Rules = {}
	local function setComplete(s: Match, id: number, league: number): boolean
		if id == 0 then return false end
		for _, index in board.members[league] do
			if s.clubs[index].owner ~= id then return false end
		end
		return true
	end
	Rules.setComplete = setComplete

	function Rules.gate(s: Match, index: number): number
		local tile, club = board.tiles[index], s.clubs[index]
		if tile.kind ~= "club" or club.owner == 0 then return 0 end
		return (tile.gate + club.level * board.upgradeGate) * (if setComplete(s, club.owner, tile.league) then 2 else 1)
	end

	function Rules.score(s: Match, id: number): number
		local total = 0
		for _, seat in s.seats do
			if seat.id == id then
				total = seat.cash
				break
			end
		end
		for i, club in s.clubs do
			if club.owner == id then total += board.tiles[i].price + club.level * board.upgradeCost end
		end
		for league in board.members do
			if setComplete(s, id, league) then total += board.leagueValue end
		end
		return total
	end

	function Rules.target(position: number, steps: number): number
		return (position - 1 + steps) % #board.tiles + 1
	end

	local function story(kind: string, title: string, who: number, tile: number, amount: number?, card: number?, crossed: boolean?): Story
		return {kind = kind, title = title, who = who, tile = tile, amount = amount or 0, card = card or 0, crossed = crossed == true}
	end

	local function makeRoutes(s: Match, rng: RNG)
		s.short, s.long = rng(1, 3), rng(4, 6)
	end

	function Rules.new(entries: {Entry}, rng: RNG): Match
		assert(#entries >= 2 and #entries <= 4, "Expected 2–4 seats")
		local seats: {Seat} = {}
		local clubs: {Club} = {}
		local seen: {[number]: boolean} = {}
		for i, entry in entries do
			assert(entry.id ~= 0 and not seen[entry.id], "Expected a unique seat")
			seen[entry.id] = true
			seats[i] = {id = entry.id, name = entry.name, figure = entry.figure, bot = entry.bot == true, cash = board.startCash, position = 1}
		end
		for i in board.tiles do clubs[i] = {owner = 0, level = 0} end
		local s: Match = {
			seats = seats, clubs = clubs, active = 1, round = 1, phase = "move", short = 0, long = 0,
			last = story("start", "Kickoff", seats[1].id, 1), motion = {serial = 0, who = 0, from = 1, steps = 0},
			standings = {},
		}
		makeRoutes(s, rng)
		return s
	end

	local function advance(s: Match, rng: RNG)
		if s.active == #s.seats then
			if s.round == board.rounds then
				s.phase = "final"
				for _, seat in s.seats do table.insert(s.standings, {id = seat.id, score = Rules.score(s, seat.id)}) end
				table.sort(s.standings, function(a: Standing, b: Standing)
					if a.score == b.score then return a.id < b.id end
					return a.score > b.score
				end)
				return
			end
			s.round += 1
			s.active = 1
		else
			s.active += 1
		end
		s.phase = "move"
		makeRoutes(s, rng)
	end

	function Rules.apply(s: Match, id: number, action: string, rng: RNG): boolean
		local seat = s.seats[s.active]
		if seat.id ~= id or s.phase == "final" then return false end
		local current = seat.position
		if s.phase == "offer" or s.phase == "upgrade" then
			local tile, club = board.tiles[current], s.clubs[current]
			if action == "skip" then
				s.last = story("skip", tile.name, id, current)
			elseif action == "buy" and s.phase == "offer" and club.owner == 0 and seat.cash >= tile.price then
				seat.cash -= tile.price
				club.owner = id
				s.last = story(if setComplete(s, id, tile.league) then "league" else "buy", tile.name, id, current, -tile.price)
			elseif action == "upgrade" and s.phase == "upgrade" and club.owner == id and club.level < board.maxLevel and seat.cash >= board.upgradeCost then
				seat.cash -= board.upgradeCost
				club.level += 1
				s.last = story("upgrade", tile.name, id, current, -board.upgradeCost)
			else
				return false
			end
			advance(s, rng)
			return true
		end
		if s.phase ~= "move" or (action ~= "short" and action ~= "long") then return false end
		local steps = if action == "short" then s.short else s.long
		local crossed = current + steps > #board.tiles
		if crossed then seat.cash += board.kickoffCash end
		local nextTile = Rules.target(current, steps)
		seat.position = nextTile
		s.motion = {serial = s.motion.serial + 1, who = id, from = current, steps = steps}
		local tile, club = board.tiles[nextTile], s.clubs[nextTile]
		local kind, title, amount, card = tile.kind, tile.name, tile.award, 0

		if kind == "club" then
			if club.owner == 0 and seat.cash >= tile.price then
				s.phase = "offer"
				s.last = story("offer", title, id, nextTile, tile.price, 0, crossed)
				return true
			elseif club.owner == id and club.level < board.maxLevel and seat.cash >= board.upgradeCost then
				s.phase = "upgrade"
				s.last = story("invest", title, id, nextTile, board.upgradeCost, 0, crossed)
				return true
			elseif club.owner ~= 0 and club.owner ~= id then
				kind, amount = "gate", -math.min(seat.cash, Rules.gate(s, nextTile))
				for _, owner in s.seats do
					if owner.id == club.owner then
						owner.cash -= amount
						break
					end
				end
			else
				kind = "visit"
			end
		elseif kind == "tactics" then
			card = rng(1, #board.cards)
			title, amount = board.cards[card].title, board.cards[card].amount
		end
		amount = math.max(-seat.cash, amount)
		seat.cash += amount
		s.last = story(kind, title, id, nextTile, amount, card, crossed)
		advance(s, rng)
		return true
	end

	function Rules.botAction(s: Match): string
		local seat = s.seats[s.active]
		if s.phase == "offer" then return "buy" end
		if s.phase == "upgrade" then
			return if seat.cash >= board.upgradeCost + 100 and s.round < board.rounds then "upgrade" else "skip"
		end
		local function value(steps: number): number
			local index = Rules.target(seat.position, steps)
			local tile, club = board.tiles[index], s.clubs[index]
			local projected = if seat.position + steps > #board.tiles then board.kickoffCash else 0
			if tile.kind ~= "club" then return projected + (if tile.kind == "tactics" then 58 else tile.award) end
			if club.owner == seat.id then return projected + 12 end
			if club.owner ~= 0 then return projected - Rules.gate(s, index) end
			if seat.cash + projected < tile.price then return projected end
			local owned = 0
			for _, partner in board.members[tile.league] do if s.clubs[partner].owner == seat.id then owned += 1 end end
			return projected + 79 + tile.gate * 0.22 + owned * 55
		end
		return if value(s.long) >= value(s.short) then "long" else "short"
	end

	return table.freeze(Rules)
end

return table.freeze({withBoard = withBoard})
