--!strict
local Meshes = require(script.Parent.MeshLibrary)
local frameData = require(script.Parent.ReplayMeshData).replay_goal_frame

local FRONT = Vector3.new(37.5, .34, 0)
local HALF, BACK, BOTTOM, TOP = 13.5, 6, .14, 8.9
local HIT_Z, HIT_Y = 9.35, 6.35
local Goal = {target = FRONT + Vector3.new(BACK, HIT_Y, HIT_Z)}
type Knot = {pin: Attachment, rest: Vector3, weight: number}

local function blank(name: string, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
	p.Parent = parent
	return p
end

local function rail(parent: Instance, a: Vector3, b: Vector3, diameter: number)
	local p = blank("Goal tube", parent)
	p.Shape, p.Material = Enum.PartType.Cylinder, Enum.Material.SmoothPlastic
	p.Color, p.Size = Color3.fromHex("FCFAEB"), Vector3.new((a-b).Magnitude, diameter, diameter)
	p.CFrame = CFrame.lookAt(FRONT + (a+b)*.5, FRONT+b) * CFrame.Angles(0, math.pi*.5, 0)
end

local function smooth(t: number): number
	return t*t*(3-2*t)
end

-- Paired cubic spans meet at the struck row and column. Matching their tangent
-- lengths to one third of each span keeps both families of cords interwoven.
function Goal.make(parent: Folder): (number) -> ()
	local fallback = Instance.new("Folder")
	fallback.Name, fallback.Parent = "Goal frame fallback", parent
	for _, z in {-HALF, HALF} do
		rail(fallback, Vector3.new(0, 0, z), Vector3.new(0, 10.4, z), .38)
		rail(fallback, Vector3.new(0, 10.4, z), Vector3.new(BACK, TOP, z), .24)
		rail(fallback, Vector3.new(BACK, TOP, z), Vector3.new(BACK, BOTTOM, z), .18)
		rail(fallback, Vector3.new(0, BOTTOM, z), Vector3.new(BACK, BOTTOM, z), .18)
	end
	rail(fallback, Vector3.new(0, 10.4, -HALF), Vector3.new(0, 10.4, HALF), .38)
	rail(fallback, Vector3.new(BACK, TOP, -HALF), Vector3.new(BACK, TOP, HALF), .14)
	local frame = blank("Matchday goal", parent)
	frame.Position = FRONT + Vector3.new(table.unpack(frameData.center))
	frame.Size, frame.Transparency = Vector3.new(table.unpack(frameData.size)), 1
	frame.Color = Color3.new(1, 1, 1)
	frame:SetAttribute("MeshPlaceholder", true)
	Meshes.apply("replay_goal_frame", frame, {fallback})

	local hub = blank("Woven back net", parent)
	hub.Size, hub.Position, hub.Transparency = Vector3.one * .05, FRONT, 1
	local knots: {Knot} = {}
	local function pin(pos: Vector3, axis: Vector3): Attachment
		local a = Instance.new("Attachment")
		a.Position, a.Axis, a.Parent = pos, axis, hub
		return a
	end
	local function cord(start: Attachment, finish: Attachment)
		local beam = Instance.new("Beam")
		beam.Name, beam.Attachment0, beam.Attachment1 = "Braided cord", start, finish
		local third = (start.Position - finish.Position).Magnitude / 3
		beam.CurveSize0, beam.CurveSize1 = third, third
		beam.Width0, beam.Width1, beam.Segments = .089, .089, 6
		beam.FaceCamera, beam.LightInfluence = true, .64
		beam.Color, beam.Transparency = ColorSequence.new(Color3.fromHex("E6F0E6")), NumberSequence.new(.035)
		beam.Parent = hub
	end
	local function strand(a: Vector3, mid: Vector3, b: Vector3, weight: number)
		local axis = (b-a).Unit
		local knot = pin(mid, axis)
		cord(pin(a, axis), knot)
		cord(knot, pin(b, axis))
		table.insert(knots, {pin = knot, rest = mid, weight = smooth(weight)})
	end
	for i = 1, 15 do
		local z = -HALF + 2*HALF*i/16
		local weight = if z < HIT_Z then (z+HALF)/(HIT_Z+HALF) else (HALF-z)/(HALF-HIT_Z)
		strand(Vector3.new(BACK,BOTTOM,z), Vector3.new(BACK,HIT_Y,z), Vector3.new(BACK,TOP,z), weight)
	end
	for i = 1, 6 do
		local y = BOTTOM + (TOP-BOTTOM)*i/7
		local weight = if y < HIT_Y then (y-BOTTOM)/(HIT_Y-BOTTOM) else (TOP-y)/(TOP-HIT_Y)
		strand(Vector3.new(BACK,y,-HALF), Vector3.new(BACK,y,HIT_Z), Vector3.new(BACK,y,HALF), weight)
	end
	return function(seconds: number)
		local bulge = 4.75 * math.exp(-seconds*5.8) * math.sin(seconds*17)
		for _, knot in knots do
			knot.pin.Position = knot.rest + Vector3.xAxis * (bulge*knot.weight)
		end
	end
end

return table.freeze(Goal)
