--!strict
-- Ink under the panorama is repeated in its lower wash so the art runs into the caption.
local C = Color3.fromHex
local leagues = {
	C("6E1C2D"), -- 1: Spain (Royal Crimson)
	C("152F4F"), -- 2: England (Premier Sapphire)
	C("242B33"), -- 3: Germany (Charcoal Titanium)
	C("0F3D38"), -- 4: Italy (Calcio Emerald)
	C("1E2A5E"), -- 5: France (Monarch Navy)
}
return {
	clubFace = Font.new("rbxasset://fonts/families/RobotoCondensed.json", Enum.FontWeight.Bold),
	amountFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Heavy),
	title = C("FFFFFF"),
	price = C("FFD700"),
	ink = function(tile): Color3
		return leagues[tile.league] or (if tile.kind == "venue" then C("3D3934") else C("1E2E36"))
	end,
}
