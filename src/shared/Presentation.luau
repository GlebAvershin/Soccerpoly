--!strict
local Board = require(script.Parent.TourBoard)
local Style = {}

function Style.hex(value: number): Color3
	return Color3.fromRGB(math.floor(value / 65536), math.floor(value / 256) % 256, value % 256)
end

Style.ink = Color3.fromHex("141522")
Style.paper = Color3.fromHex("F6F6E9")
Style.field = Color3.fromHex("68AB79")
Style.slate = Color3.fromHex("827E81")
Style.gold = Color3.fromHex("FFC558")
Style.mint = Color3.fromHex("C4F568")
Style.tile = Color3.fromHex("F4EDDD")
Style.printInk = Color3.fromHex("152B2E")
Style.boardFov = 7.6
Style.seatColors = table.freeze({Color3.fromHex("F68AB8"), Color3.fromHex("C4F568"), Color3.fromHex("FFC66D"), Color3.fromHex("79D7FA")})
Style.figureScale = 2.58
Style.diceLead = .45
Style.runAnticipation = .105
Style.runPerCell = .138
Style.runBrake = .215

function Style.arrivalAfter(steps: number): number
	return Style.diceLead + Style.runAnticipation + steps * Style.runPerCell
end
Style.pitchDepthScale = 1
Style.boardYaw = math.rad(45)
Style.boardNear = Vector3.new(math.sin(Style.boardYaw), 0, math.cos(Style.boardYaw))
Style.boardRight = Vector3.new(Style.boardNear.Z, 0, -Style.boardNear.X)
Style.tileTop = 0.69
Style.stops = table.freeze({
	kickoff = 0xC4F568, chance = 0xC1A1FA, tax = 0xF9AB83,
	tour = 0x78D8F2, championship = 0xFFD281, bench = 0xA6C7BB, venue = 0xD7BC7A,
})

function Style.accent(kind: string, league: number): Color3
	return Style.hex(if league > 0 then Board.leagues[league].color else Style.stops[kind])
end

return table.freeze(Style)
