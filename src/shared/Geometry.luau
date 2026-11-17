--!strict
local Geometry = {}
local cells: {Vector3} = {}
local halfSide, corner = 63, 18
local normal = (2 * halfSide - 2 * corner) / 7
local line = halfSide - corner / 2
-- The two horizontal runs each span 90 studs between fixed corner squares.
local touchlineWidths: {[number]: {number}} = {
	[1] = {13, 16, 13.5, 8.5, 13, 15.5, 10.5},
	[3] = {16, 12, 10, 13, 16, 12, 11},
}
local widths: {number} = {}
for edge = 0, 3 do
	local yaw = (edge + 1) * math.pi / 2
	local x, z = math.sin(yaw), math.cos(yaw)
	local along = -halfSide + corner
	local strip = touchlineWidths[edge]
	for slot = 0, 7 do
		local width = if slot == 0 then corner elseif strip then strip[slot] else normal
		local step = if slot == 0 then -line else along + width / 2
		if slot ~= 0 then along += width end
		table.insert(widths, width)
		table.insert(cells, Vector3.new(x * line + z * step, 1, z * line - x * step))
	end
end
Geometry.cells = table.freeze(cells)
Geometry.width, Geometry.depth = halfSide * 2, halfSide * 2

function Geometry.tileYaw(index: number): number
	return (math.floor((index - 1) / 8) + 1) * math.pi / 2
end

function Geometry.tileSize(index: number): Vector2
	return Vector2.new(widths[index], corner)
end

return table.freeze(Geometry)
