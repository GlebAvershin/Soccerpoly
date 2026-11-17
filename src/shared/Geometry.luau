--!strict
local Geometry = {}
local cells: {Vector3} = {}
local halfSide, corner = 63, 18
local normal = (2 * halfSide - 2 * corner) / 7
local line = halfSide - corner / 2
for edge = 0, 3 do
	local yaw = (edge + 1) * math.pi / 2
	local x, z = math.sin(yaw), math.cos(yaw)
	for slot = 0, 7 do
		local step = if slot == 0 then -line else -halfSide + corner + (slot - .5) * normal
		table.insert(cells, Vector3.new(x * line + z * step, 1, z * line - x * step))
	end
end
Geometry.cells = table.freeze(cells)
Geometry.width, Geometry.depth = halfSide * 2, halfSide * 2

function Geometry.tileYaw(index: number): number
	return (math.floor((index - 1) / 8) + 1) * math.pi / 2
end

function Geometry.tileSize(index: number): Vector2
	return Vector2.new(if (index - 1) % 8 == 0 then corner else normal, corner)
end

return table.freeze(Geometry)
