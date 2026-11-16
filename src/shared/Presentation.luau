--!strict
local Board = require(script.Parent.Board)
local Style = {}

function Style.hex(value: number): Color3
	return Color3.fromRGB(math.floor(value / 65536), math.floor(value / 256) % 256, value % 256)
end

Style.ink = Color3.fromHex("122626")
Style.paper = Color3.fromHex("F6F5E9")
Style.field = Color3.fromHex("1F895B")
Style.slate = Color3.fromHex("284349")
Style.gold = Color3.fromHex("FFCB69")
Style.mint = Color3.fromHex("A7ED8C")
Style.route = table.freeze({0xB3FA87, 0x92DBF7})
Style.tileWidth = 15.9
Style.tileDepth = 9.95
Style.tileTop = 0.69

Style.stops = table.freeze({
	kickoff = 0x6FCD91, goalDeck = 0x7FD2AF, offsideDeck = 0xEE8B74,
	venue = 0x69BAC5, commercial = 0xE8C862, matchday = 0x5FC7AE,
})
Style.shortStop = table.freeze({
	kickoff = "Kickoff", goalDeck = "Goal", offsideDeck = "Offside", matchday = "Matchday",
})

function Style.accent(kind: string, league: number): Color3
	return Style.hex(if league > 0 then Board.leagues[league].color else Style.stops[kind])
end

return table.freeze(Style)
