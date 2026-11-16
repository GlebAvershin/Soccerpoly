--!strict
-- The board is injected so the same rules run in Studio and the standalone Luau CLI.
type RNG = (number, number) -> number
type Tile = {code: string, city: string, kind: string, name: string, league: number, price: number, gate: number, award: number}
type Board = {
	read tiles: {Tile}, read members: {{number}}, read assetGroups: {[string]: {number}},
	read rounds: number, read maxSeats: number, read figureAbilities: {string},
	read abilityAmounts: {read route: number, read goal: number, read kickoff: number, read gate: number, read upgrade: number, read signing: number, read var: number},
	read tradeRates: {number},
	read startCash: number, read kickoffCash: number, read upgradeCost: number, read upgradeGate: number,
	read maxLevel: number, read leagueValue: number, read benchFee: number,
}
type Card = {read id: string, read kind: string, read title: string, read amount: number, read body: string, read ru: string, read ruBody: string}
type Shot = {read result: string, read cash: number, read weight: number}
type Edition = {read cards: {Card}, read shots: {Shot}, read safe_cash: number, read trophy_value: number}
export type Entry = {id: number, name: string, figure: number, bot: boolean?}
export type Seat = {id: number, name: string, figure: number, bot: boolean, cash: number, position: number, trophies: number, benched: boolean, ability: "ready" | "armed" | "spent"}
export type Club = {owner: number, level: number}
export type Story = {kind: string, title: string, who: number, tile: number, amount: number, card: number, crossed: boolean, other: number?, otherTile: number?, power: string?}
export type Motion = {serial: number, who: number, from: number, steps: number}
export type Standing = {id: number, score: number}
export type Auction = {tile: number, replies: {[number]: number}}
export type Trade = {seller: number, buyer: number, offered: number, requested: number, price: number}
export type Match = {
	seats: {Seat}, clubs: {Club}, active: number, round: number, phase: string, short: number, long: number,
	last: Story, motion: Motion, standings: {Standing}, decks: {[string]: {number}}, auction: Auction?, soldThisTurn: boolean, trade: Trade?, tradeUsed: boolean,
}

local function withBoard(board: Board, edition: Edition)
	local Rules = {}
	local shotWeight, goalWeight = 0, 0
	for _, outcome in edition.shots do
		shotWeight += outcome.weight
		if outcome.result == "goal" then goalWeight += outcome.weight end
	end
	Rules.goalChance = goalWeight / shotWeight

	local families: {[string]: {number}} = {goalDeck = {}, offsideDeck = {}}
	for i, card in edition.cards do
		local family = if card.amount > 0 then families.goalDeck else families.offsideDeck
		table.insert(family, i)
	end

	local function draw(deck: {number}, allowed: {number}, rng: RNG): number
		if #deck == 0 then
			for _, index in allowed do table.insert(deck, index) end
		end
		local index = rng(1, #deck)
		local result = deck[index]
		deck[index] = deck[#deck]
		table.remove(deck)
		return result
	end
	local function setComplete(s: Match, id: number, league: number): boolean
		if id == 0 or league == 0 then return false end
		for _, index in board.members[league] do
			if s.clubs[index].owner ~= id then return false end
		end
		return true
	end
	Rules.setComplete = setComplete

	local function group(tile: Tile): {number}
		return if tile.league > 0 then board.members[tile.league] else board.assetGroups[tile.kind]
	end

	local function ownedCount(s: Match, id: number, tile: Tile): number
		local count = 0
		for _, index in group(tile) do
			if s.clubs[index].owner == id then count += 1 end
		end
		return count
	end

	function Rules.sellValue(s: Match, index: number): number
		return math.floor(board.tiles[index].price * 3 / 5) + math.floor(s.clubs[index].level * board.upgradeCost / 2)
	end

	function Rules.gate(s: Match, index: number): number
		local tile, club = board.tiles[index], s.clubs[index]
		if tile.price == 0 or club.owner == 0 then return 0 end
		if tile.league == 0 then return tile.gate * ownedCount(s, club.owner, tile) end
		return (tile.gate + club.level * board.upgradeGate) * (if setComplete(s, club.owner, tile.league) then 2 else 1)
	end

	function Rules.score(s: Match, id: number): number
		local total = 0
		for _, seat in s.seats do
			if seat.id == id then
				total = seat.cash + seat.trophies * edition.trophy_value
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
		assert(#entries >= 2 and #entries <= board.maxSeats, "Seat count out of range")
		local seats: {Seat} = {}
		local clubs: {Club} = {}
		local seen: {[number]: boolean} = {}
		for i, entry in entries do
			assert(entry.id ~= 0 and not seen[entry.id], "Expected a unique seat")
			seen[entry.id] = true
			seats[i] = {id = entry.id, name = entry.name, figure = entry.figure, bot = entry.bot == true, cash = board.startCash, position = 1, trophies = 0, benched = false, ability = "ready"}
		end
		for i in board.tiles do clubs[i] = {owner = 0, level = 0} end
		local s: Match = {
			seats = seats, clubs = clubs, active = 1, round = 1, phase = "move", short = 0, long = 0,
			last = story("start", "Kickoff", seats[1].id, 1), motion = {serial = 0, who = 0, from = 1, steps = 0},
			standings = {}, decks = {goalDeck = {}, offsideDeck = {}}, auction = nil, soldThisTurn = false, trade = nil, tradeUsed = false,
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
		s.phase = if s.seats[s.active].benched then "bench" else "move"
		s.soldThisTurn, s.tradeUsed = false, false
		makeRoutes(s, rng)
	end

	function Rules.auctionMinimum(index: number): number
		return math.ceil(board.tiles[index].price * 3 / 20) * 5
	end

	local function openAuction(s: Match, index: number, crossed: boolean): boolean
		local minimum = Rules.auctionMinimum(index)
		for _, seat in s.seats do
			if seat.cash >= minimum then
				s.auction = {tile = index, replies = {}}
				s.phase = "auction"
				s.last = story("auction", board.tiles[index].name, s.seats[s.active].id, index, 0, 0, crossed)
				return true
			end
		end
		return false
	end

	function Rules.bid(s: Match, id: number, choice: number): boolean
		local auction = s.auction
		if s.phase ~= "auction" or not auction or auction.replies[id] ~= nil then return false end
		if choice ~= 0 and choice ~= 1 and choice ~= 2 then return false end
		local minimum = Rules.auctionMinimum(auction.tile)
		for _, seat in s.seats do
			if seat.id == id and seat.cash >= minimum then
				local amount = if choice == 0 then 0 elseif choice == 1 then minimum else board.tiles[auction.tile].price
				if amount > seat.cash then return false end
				auction.replies[id] = amount
				return true
			end
		end
		return false
	end

	function Rules.auctionReady(s: Match): boolean
		local auction = s.auction
		if not auction then return false end
		local minimum = Rules.auctionMinimum(auction.tile)
		for _, seat in s.seats do
			if seat.cash >= minimum and auction.replies[seat.id] == nil then return false end
		end
		return true
	end

	function Rules.botBids(s: Match): boolean
		local auction = s.auction
		if not auction then return false end
		local changed = false
		local tile = board.tiles[auction.tile]
		local minimum = Rules.auctionMinimum(auction.tile)
		for _, seat in s.seats do
			if seat.bot and seat.cash >= minimum and auction.replies[seat.id] == nil then
				local partners = ownedCount(s, seat.id, tile)
				local choice = if partners == #group(tile) - 1 and seat.cash >= tile.price then 2
					elseif partners >= 1 or (s.round <= board.rounds - 2 and seat.cash >= minimum + 130) then 1 else 0
				if Rules.bid(s, seat.id, choice) then changed = true end
			end
		end
		return changed
	end

	local function armed(seat: Seat, ability: string): boolean
		return seat.ability == "armed" and board.figureAbilities[seat.figure] == ability
	end

	local function awardSigning(s: Match, seat: Seat, tile: Tile)
		if tile.league > 0 and armed(seat, "upgrade") then
			seat.cash += board.abilityAmounts.signing
			seat.ability, s.last.power = "spent", "upgrade"
		end
	end

	function Rules.closeAuction(s: Match, rng: RNG): boolean
		local auction = s.auction
		if s.phase ~= "auction" or not auction then return false end
		local tile, club = board.tiles[auction.tile], s.clubs[auction.tile]
		local winner: Seat? = nil
		local price = 0
		-- Walk in turn order after the player who triggered the auction. The initiator breaks ties last.
		for offset = 1, #s.seats do
			local seat = s.seats[(s.active - 1 + offset) % #s.seats + 1]
			local bid = auction.replies[seat.id] or 0
			if bid > price and bid <= seat.cash then
				winner, price = seat, bid
			end
		end
		if winner then
			winner.cash -= price
			club.owner = winner.id
			local kind = if setComplete(s, winner.id, tile.league) then "auctionLeague" else "auctionWon"
			s.last = story(kind, tile.name, winner.id, auction.tile, -price, 0, s.last.crossed)
			awardSigning(s, winner, tile)
		else
			s.last = story("auctionEmpty", tile.name, s.seats[s.active].id, auction.tile, 0, 0, s.last.crossed)
		end
		s.auction = nil
		advance(s, rng)
		return true
	end

	local function participant(s: Match, id: number): Seat?
		for _, seat in s.seats do
			if seat.id == id then return seat end
		end
		return nil
	end

	function Rules.canTransfer(s: Match, id: number, index: number): boolean
		local tile = board.tiles[index]
		if not tile or tile.league == 0 or s.clubs[index].owner ~= id then return false end
		for _, member in board.members[tile.league] do
			if s.clubs[member].level > 0 then return false end
		end
		return true
	end

	function Rules.tradePrice(index: number, option: number): number?
		local rate, tile = board.tradeRates[option], board.tiles[index]
		return if rate and tile and tile.league > 0 then math.floor(tile.price * rate / 100) else nil
	end

	-- A positive difference is paid by the buyer. A negative difference is paid by the seller.
	function Rules.swapDifference(offered: number, requested: number): number
		return board.tiles[offered].price - board.tiles[requested].price
	end

	function Rules.proposeTrade(s: Match, id: number, buyerId: number, offered: number, requested: number, option: number): boolean
		local buyer = participant(s, buyerId)
		if s.phase ~= "move" or s.seats[s.active].id ~= id or s.tradeUsed or not buyer or buyerId == id
			or not Rules.canTransfer(s, id, offered) then return false end
		local price = 0
		if requested == 0 then
			local quote = Rules.tradePrice(offered, option)
			if not quote then return false end
			price = quote
		else
			if option ~= 0 or not Rules.canTransfer(s, buyerId, requested) then return false end
			price = Rules.swapDifference(offered, requested)
		end
		if buyer.cash < price or s.seats[s.active].cash < -price then return false end
		s.trade = {seller = id, buyer = buyerId, offered = offered, requested = requested, price = price}
		s.tradeUsed = true
		return true
	end

	function Rules.replyTrade(s: Match, id: number, accept: boolean): boolean
		local trade = s.trade
		if not trade or trade.buyer ~= id or s.phase ~= "move" then return false end
		s.trade = nil
		if not accept then return true end
		local seller, buyer = s.seats[s.active], participant(s, id)
		if seller.id ~= trade.seller or not buyer or buyer.cash < trade.price or seller.cash < -trade.price
			or not Rules.canTransfer(s, seller.id, trade.offered)
			or (trade.requested ~= 0 and not Rules.canTransfer(s, id, trade.requested)) then
			return true
		end
		s.clubs[trade.offered].owner = id
		if trade.requested ~= 0 then
			s.clubs[trade.requested].owner = seller.id
		end
		seller.cash += trade.price
		buyer.cash -= trade.price
		s.last = story(if trade.requested == 0 then "tradeSale" else "tradeSwap", board.tiles[trade.offered].name, seller.id, trade.offered, trade.price)
		s.last.other, s.last.otherTile = id, trade.requested
		return true
	end

	function Rules.botAcceptsTrade(s: Match, trade: Trade): boolean
		local buyer = participant(s, trade.buyer)
		if not buyer then return false end
		local function value(index: number, id: number, held: boolean): number
			local tile = board.tiles[index]
			local partners = ownedCount(s, id, tile) - (if held then 1 else 0)
			return tile.price + (if partners == #group(tile) - 1 then board.leagueValue else partners * 25)
		end
		local gain = value(trade.offered, buyer.id, false)
		if trade.requested == 0 then return buyer.cash >= trade.price + 50 and gain >= trade.price end
		local outgoing, incoming = board.tiles[trade.requested], board.tiles[trade.offered]
		if trade.price > 0 and buyer.cash < trade.price + 50 then return false end
		if outgoing.league == incoming.league then return true end
		return gain - trade.price >= value(trade.requested, buyer.id, true) and not setComplete(s, buyer.id, outgoing.league)
	end

	function Rules.upgradePrice(seat: Seat): number
		return board.upgradeCost - (if armed(seat, "upgrade") then board.abilityAmounts.upgrade else 0)
	end

	function Rules.shortAfterPower(steps: number): number
		return if steps == 3 then 2 else steps + 1
	end

	local function canUpgrade(s: Match, seat: Seat, index: number): boolean
		local club = s.clubs[index]
		return board.tiles[index].league > 0 and club.owner == seat.id and club.level < board.maxLevel and seat.cash >= Rules.upgradePrice(seat)
			and (club.level == 0 or setComplete(s, seat.id, board.tiles[index].league))
	end

	function Rules.apply(s: Match, id: number, action: string, rng: RNG, index: number?): boolean
		local seat = s.seats[s.active]
		if seat.id ~= id or s.phase == "final" then return false end
		local current = seat.position
		if action == "ability" then
			if s.phase ~= "move" or seat.ability ~= "ready" then return false end
			local ability = board.figureAbilities[seat.figure]
			if ability == "route" then
				if seat.cash < board.abilityAmounts.route then return false end
				seat.cash -= board.abilityAmounts.route
				s.short = Rules.shortAfterPower(s.short)
			end
			seat.ability = if ability == "route" then "spent" else "armed"
			return true
		end
		if action == "sell" or action == "sellUpgrades" then
			if s.phase ~= "move" or s.soldThisTurn or s.trade or not index or index % 1 ~= 0 or index < 1 or index > #board.tiles then return false end
			local tile, holding = board.tiles[index], s.clubs[index]
			if tile.price == 0 or holding.owner ~= id then return false end
			local upgradesOnly = action == "sellUpgrades"
			if upgradesOnly and holding.level == 0 then return false end
			local proceeds = if upgradesOnly then math.floor(holding.level * board.upgradeCost / 2) else Rules.sellValue(s, index)
			seat.cash += proceeds
			holding.level = 0
			if not upgradesOnly then holding.owner = 0 end
			s.soldThisTurn = true
			s.last = story(if upgradesOnly then "soldUpgrades" else "sold", tile.name, id, index, proceeds)
			return true
		end
		if s.phase == "bench" then
			if action == "release" and seat.cash >= board.benchFee then
				seat.cash -= board.benchFee
				seat.benched, s.phase = false, "move"
				s.last = story("release", board.tiles[current].name, id, current, -board.benchFee)
				return true
			end
			if action ~= "short" then return false end
			seat.benched, s.phase = false, "move"
		end
		if s.phase == "matchday" then
			if action ~= "shoot" and action ~= "safe" then return false end
			local amount, result = edition.safe_cash, "safe"
			if action == "shoot" then
				local roll = rng(1, shotWeight)
				for _, outcome in edition.shots do
					roll -= outcome.weight
					if roll <= 0 then
						amount, result = outcome.cash, outcome.result
						break
					end
				end
			end
			local power: string? = nil
			if result == "goal" then seat.trophies += 1 end
			if (result == "goal" or result == "save") and armed(seat, "goal") then
				seat.ability, power = "spent", "goal"
				amount += board.abilityAmounts.goal
			end
			amount = math.max(-seat.cash, amount)
			seat.cash += amount
			s.last = story(result, board.tiles[current].name, id, current, amount, 0, s.last.crossed)
			s.last.power = power
			advance(s, rng)
			return true
		end
		if s.phase == "offer" or s.phase == "upgrade" then
			local tile, club = board.tiles[current], s.clubs[current]
			if action == "skip" then
				if s.phase == "offer" and openAuction(s, current, s.last.crossed) then return true end
				s.last = story("skip", tile.name, id, current)
			elseif action == "buy" and s.phase == "offer" and club.owner == 0 and seat.cash >= tile.price then
				seat.cash -= tile.price
				club.owner = id
				s.last = story(if setComplete(s, id, tile.league) then "league" else "buy", tile.name, id, current, -tile.price)
				awardSigning(s, seat, tile)
			elseif action == "upgrade" and s.phase == "upgrade" and canUpgrade(s, seat, current) then
				local cost = Rules.upgradePrice(seat)
				seat.cash -= cost
				club.level += 1
				s.last = story("upgrade", tile.name, id, current, -cost)
				if cost < board.upgradeCost then
					seat.ability, s.last.power = "spent", "upgrade"
				end
			else
				return false
			end
			advance(s, rng)
			return true
		end
		if s.phase ~= "move" or (action ~= "short" and action ~= "long") then return false end
		s.trade = nil
		local power: string? = nil
		local steps = if action == "short" then s.short else s.long
		local crossed = current + steps > #board.tiles
		if crossed then
			seat.cash += board.kickoffCash
			if armed(seat, "kickoff") then
				seat.ability, power = "spent", "kickoff"
				seat.cash += board.abilityAmounts.kickoff
			end
		end
		local nextTile = Rules.target(current, steps)
		seat.position = nextTile
		s.motion = {serial = s.motion.serial + 1, who = id, from = current, steps = steps}
		local tile, club = board.tiles[nextTile], s.clubs[nextTile]
		local kind, title, amount, card = tile.kind, tile.name, tile.award, 0

		if tile.price > 0 then
			if club.owner == 0 and seat.cash >= tile.price then
				s.phase = "offer"
				s.last = story("offer", title, id, nextTile, tile.price, 0, crossed)
				s.last.power = power
				return true
			elseif club.owner == 0 and openAuction(s, nextTile, crossed) then
				s.last.power = power
				return true
			elseif canUpgrade(s, seat, nextTile) then
				s.phase = "upgrade"
				s.last = story("invest", title, id, nextTile, Rules.upgradePrice(seat), 0, crossed)
				s.last.power = power
				return true
			elseif club.owner ~= 0 and club.owner ~= id then
				local gate = math.min(seat.cash, Rules.gate(s, nextTile))
				if gate > 0 and armed(seat, "gate") then
					seat.ability, power = "spent", "gate"
					gate = math.max(0, gate - board.abilityAmounts.gate)
				end
				kind, amount = "gate", -gate
				for _, owner in s.seats do
					if owner.id == club.owner then
						owner.cash -= amount
						break
					end
				end
			else
				kind = "visit"
			end
		elseif kind == "goalDeck" or kind == "offsideDeck" then
			card = draw(s.decks[kind], families[kind], rng)
			local entry = edition.cards[card]
			if kind == "offsideDeck" and armed(seat, "var") then
				seat.ability, power, kind, amount = "spent", "var", "var", 0
			else
				if entry.kind == "bench" then seat.benched = true end
				title, amount = entry.title, entry.amount
				if kind == "goalDeck" and armed(seat, "var") then
					seat.ability, power = "spent", "var"
					amount += board.abilityAmounts.var
				end
			end
		elseif kind == "matchday" then
			s.phase = "matchday"
			s.last = story("matchday", title, id, nextTile, 0, 0, crossed)
			s.last.power = power
			return true
		end
		amount = math.max(-seat.cash, amount)
		seat.cash += amount
		s.last = story(kind, title, id, nextTile, amount, card, crossed)
		s.last.power = power
		advance(s, rng)
		return true
	end

	local function routeValue(s: Match, seat: Seat, steps: number): number
		local index = Rules.target(seat.position, steps)
		local tile, club = board.tiles[index], s.clubs[index]
		local projected = if seat.position + steps > #board.tiles
			then board.kickoffCash + (if armed(seat, "kickoff") then board.abilityAmounts.kickoff else 0) else 0
		if tile.kind == "goalDeck" then return projected + 95 + (if armed(seat, "var") then board.abilityAmounts.var else 0) end
		if tile.kind == "offsideDeck" then return projected - (if armed(seat, "var") then 0 else 40) end
		if tile.kind == "matchday" then return projected + 88 + (if armed(seat, "goal") then board.abilityAmounts.goal * .8 else 0) end
		if tile.price == 0 then return projected + tile.award end
		if club.owner == seat.id then return projected + (if armed(seat, "upgrade") and canUpgrade(s, seat, index) then 50 else 12) end
		if club.owner ~= 0 then
			local due = math.min(seat.cash + projected, Rules.gate(s, index))
			return projected - math.max(0, due - (if armed(seat, "gate") then board.abilityAmounts.gate else 0))
		end
		if seat.cash + projected < tile.price then return projected end
		local owned = ownedCount(s, seat.id, tile)
		return projected + 79 + tile.gate * 0.22 + owned * 55
	end

	function Rules.botUsesAbility(s: Match): boolean
		local seat = s.seats[s.active]
		if s.phase ~= "move" or seat.ability ~= "ready" then return false end
		if board.figureAbilities[seat.figure] ~= "route" then return true end
		local price = board.abilityAmounts.route
		local current = math.max(routeValue(s, seat, s.short), routeValue(s, seat, s.long))
		return seat.cash >= price and routeValue(s, seat, Rules.shortAfterPower(s.short)) > current + price
	end

	function Rules.botAction(s: Match): string
		local seat = s.seats[s.active]
		if s.phase == "offer" then return "buy" end
		if s.phase == "bench" then return "short" end
		if s.phase == "matchday" then
			return if seat.cash >= 200 or s.round >= board.rounds - 1 or armed(seat, "goal") then "shoot" else "safe"
		end
		if s.phase == "upgrade" then
			return if seat.cash >= Rules.upgradePrice(seat) + 100 and s.round < board.rounds then "upgrade" else "skip"
		end

		return if routeValue(s, seat, s.long) >= routeValue(s, seat, s.short) then "long" else "short"
	end

	return table.freeze(Rules)
end

return table.freeze({withBoard = withBoard})
