--!strict
local Geometry = {}
local cells: {Vector3} = {}
for col = 0, 6 do table.insert(cells, Vector3.new(-51 + col * 17, 1, 51)) end
for row = 1, 6 do table.insert(cells, Vector3.new(51, 1, 51 - row * 17)) end
for col = 1, 6 do table.insert(cells, Vector3.new(51 - col * 17, 1, -51)) end
for row = 1, 5 do table.insert(cells, Vector3.new(-51, 1, -51 + row * 17)) end
Geometry.cells = table.freeze(cells)
Geometry.width = 119
Geometry.depth = 119
Geometry.colors = table.freeze({
	kickoff = 0xBDFF87, tactics = 0xEB9DF7, broadcast = 0x5CB5FF,
	sponsor = 0xFFCF71, matchday = 0x65E5C4, whistle = 0xF78C81,
})
return table.freeze(Geometry)
