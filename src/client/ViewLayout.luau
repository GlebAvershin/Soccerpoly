--!strict
local View = {}

function View.mode(size: Vector2): string
	if size.X < size.Y * 1.16 then return "portrait" end
	return if size.Y < 510 then "rail" else "dock"
end

function View.dockHeight(size: Vector2, mode: string): number
	if mode == "portrait" then return math.clamp(math.round(size.Y * .32), 222, 286) end
	return 145
end

function View.railWidth(size: Vector2): number
	return math.clamp(math.round(size.X * .39), 246, 316)
end

return View
