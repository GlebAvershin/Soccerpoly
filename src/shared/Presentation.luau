--!strict
local Style = {}

function Style.hex(value: number): Color3
	return Color3.fromRGB(math.floor(value / 65536), math.floor(value / 256) % 256, value % 256)
end

Style.ink = Color3.fromHex("19364D")
Style.paper = Color3.fromHex("FFF8E6")
Style.sea = Color3.fromHex("83C7DB")
Style.field = Color3.fromHex("328677")
Style.slate = Color3.fromHex("24465C")
Style.gold = Color3.fromHex("FFBF50")
Style.mint = Color3.fromHex("84E4AA")
Style.route = table.freeze({0x67E3A2, 0x78C5FF})
Style.tileWidth = 15.9
Style.tileDepth = 9.95
Style.tileTop = 0.69

Style.leagues = table.freeze({0xF19D4D, 0x62BAED, 0xAA8DE3, 0x64BC8A})
Style.stops = table.freeze({
	kickoff = 0x6FCD91, tactics = 0xAC91E6, broadcast = 0x75BBEA,
	sponsor = 0xF5C46F, matchday = 0x5FC7AE, whistle = 0xEE8B74,
})
Style.shortCity = table.freeze({["Rio de Janeiro"] = "Rio"})
Style.shortStop = table.freeze({
	kickoff = "Kickoff", tactics = "Tactics", broadcast = "TV Rights",
	sponsor = "Sponsor", matchday = "Matchday", whistle = "Added Time",
})
Style.sign = table.freeze({kickoff = "»", tactics = "?", broadcast = "TV", sponsor = "+", matchday = "★", whistle = "+T"})

function Style.accent(kind: string, league: number): Color3
	return Style.hex(if league > 0 then Style.leagues[league] else Style.stops[kind])
end

return table.freeze(Style)
