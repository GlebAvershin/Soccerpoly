--!strict
-- Ink under the panorama is repeated in its lower wash so the art runs into the caption.
local C = Color3.fromHex
local leagues = {C("533546"), C("233F51"), C("3B4049"), C("204440"), C("373852")}
return {
	clubFace = Font.new("rbxasset://fonts/families/RobotoCondensed.json", Enum.FontWeight.Regular),
	amountFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold),
	title = C("F7F8F4"),
	price = C("F9DCA0"),
	ink = function(tile): Color3
		return leagues[tile.league] or (if tile.kind == "venue" then C("45413C") else C("243740"))
	end,
}
