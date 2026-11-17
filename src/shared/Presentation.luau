--!strict
local Board = require(script.Parent.TourBoard)
local Style = {}

function Style.hex(value: number): Color3
	return Color3.fromRGB(math.floor(value / 65536), math.floor(value / 256) % 256, value % 256)
end

Style.ink = Color3.fromHex("302B34")
Style.paper = Color3.fromHex("F5EEE8")
Style.field = Color3.fromHex("AFC556")
Style.slate = Color3.fromHex("827E81")
Style.gold = Color3.fromHex("FFC558")
Style.mint = Color3.fromHex("DCF282")
Style.seatColors = table.freeze({Color3.fromHex("DD1464"), Color3.fromHex("8DA117"), Color3.fromHex("E3A900"), Color3.fromHex("1595C2")})
Style.figureScale = 1.80
Style.pitchDepthScale = 1
Style.boardYaw = math.pi / 4
Style.boardNear = Vector3.new(math.sin(Style.boardYaw), 0, math.cos(Style.boardYaw))
Style.boardRight = Vector3.new(Style.boardNear.Z, 0, -Style.boardNear.X)
Style.tileTop = 0.69
Style.stops = table.freeze({
	kickoff = 0xC5A5C1, chance = 0xC9B8CF, tax = 0xEAC1B5,
	tour = 0xACC4E1, championship = 0xADC565, bench = 0x90CED0, venue = 0xEECB99,
})

function Style.accent(kind: string, league: number): Color3
	return Style.hex(if league > 0 then Board.leagues[league].color else Style.stops[kind])
end

return table.freeze(Style)
