--!strict
local Board = require(script.Parent.Board)
local Style = {}

function Style.hex(value: number): Color3
	return Color3.fromRGB(math.floor(value / 65536), math.floor(value / 256) % 256, value % 256)
end

Style.ink = Color3.fromHex("233348")
Style.paper = Color3.fromHex("FFF3D8")
Style.field = Color3.fromHex("75A934")
Style.slate = Color3.fromHex("283E64")
Style.gold = Color3.fromHex("FFC558")
Style.mint = Color3.fromHex("B9E39B")
Style.route = table.freeze({0x8DE876, 0x71DDF9})
Style.tileWidth = 15.9
Style.tileDepth = 15.9
Style.figureScale = 1.82
Style.pitchDepthScale = 1.35
Style.boardYaw = math.rad(38)
Style.boardNear = Vector3.new(math.sin(Style.boardYaw), 0, math.cos(Style.boardYaw))
Style.boardRight = Vector3.new(Style.boardNear.Z, 0, -Style.boardNear.X)
Style.clubColors = table.freeze({
	[2] = 0xDB3747, [3] = 0x0794C6, [5] = 0xBC253B, [6] = 0xCF273C,
	[7] = 0xC72F3B, [9] = 0xA22958, [10] = 0x3194C6, [11] = 0xA87B0E,
	[13] = 0x1756AA, [15] = 0xD9374E, [16] = 0xCE342F, [17] = 0x49536A,
	[19] = 0xC8324A, [21] = 0x215EA4, [23] = 0x735AB0,
})
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
