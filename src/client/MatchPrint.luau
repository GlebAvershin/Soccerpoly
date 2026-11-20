--!strict
-- Single-colour pictograms on the same 28-point grid as the match programme.
local UI = require(script.Parent.Components)
local Print = {}
Print.display = Font.new("rbxasset://fonts/families/RobotoCondensed.json", Enum.FontWeight.Bold)
local V = Vector2.new

local outlines = {
	book = {
		{V(14,8),V(10,6),V(4,6),V(4,21),V(10,21),V(14,23),V(18,21),V(24,21),V(24,6),V(18,6),V(14,8),V(14,23)},
		{V(7,11),V(10,11)},
		{V(18,11),V(21,11)},
	},
	clubs = {
		{V(7,6),V(14,4),V(21,6),V(21,14),V(19,19),V(14,23),V(9,19),V(7,14),V(7,6)},
		{V(10,11),V(18,11)},
		{V(12,15),V(16,15)},
	},
	camera = {
		{V(4,11),V(4,8),V(10,8),V(12,5),V(17,5),V(19,8),V(24,8),V(24,21),V(4,21),V(4,11)},
		{V(14,10),V(17,11),V(18,14),V(17,17),V(14,18),V(11,17),V(10,14),V(11,11),V(14,10)},
	},
	chat = {
		{V(4,7),V(24,7),V(24,19),V(13,19),V(8,23),V(8,19),V(4,19),V(4,7)},
		{V(8,13),V(12,13)},
		{V(16,13),V(20,13)},
	},
	cup = {
		{V(7,4),V(21,4),V(20,11),V(18,15),V(14,17),V(10,15),V(8,11),V(7,4)},
		{V(7,6),V(3,6),V(4,10),V(8,12)}, {V(21,6),V(25,6),V(24,10),V(20,12)},
		{V(14,17),V(14,22)}, {V(9,24),V(11,22),V(17,22),V(19,24),V(9,24)},
	},
	pennant = {
		{V(7,24),V(7,4),V(23,8),V(7,14)}, {V(10,9),V(14,9)}, {V(4,24),V(10,24)},
	},
	transfer = {
		{V(3,9),V(23,9),V(18,4)}, {V(25,19),V(5,19),V(10,24)},
	},
	whistle = {
		{V(4,12),V(19,12),V(24,8),V(25,13),V(19,18),V(17,23),V(9,24),V(4,20),V(4,12)},
		{V(9,16),V(13,16),V(14,19),V(10,20),V(9,16)}, {V(12,8),V(12,4)}, {V(16,8),V(18,5)},
	},
}

function Print.mark(parent: Instance, shape: string, color: Color3, size: number): Frame
	local art = UI.box(parent, "Match insignia")
	art.Size = UDim2.fromOffset(size, size)
	for _, path in outlines[shape] or outlines.pennant do
		for i = 2, #path do
			local a, b = path[i-1], path[i]
			local delta, mid = b - a, (a + b) * .5
			local line = UI.box(art, "Ink", color, 1)
			line.AnchorPoint = V(.5,.5)
			line.Position = UDim2.fromScale(mid.X / 28, mid.Y / 28)
			line.Size = UDim2.fromOffset(delta.Magnitude * size / 28 + 1, math.max(1.5, size / 17))
			line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
		end
	end
	return art
end

function Print.duotone(parent: GuiObject, light: Color3, dark: Color3)
	parent.BackgroundColor3 = Color3.new(1,1,1)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(light, dark)
	gradient.Rotation, gradient.Parent = 24, parent
end

return Print
