-- Render the production pawns at six representative moments in their animation.
-- Run this in Studio edit mode against the built Soccerpoly place. The output
-- file feeds render-player-lineup.py, which lights the posed shapes in Blender.
local source = game:GetService("StarterPlayer").StarterPlayerScripts.Soccerpoly
local pawn = require(source.Pawn)
local poses = {
	{"idle", .68, 1}, {"kick", .58, .65}, {"idle", .20, 1},
	{"stride", .78, .65}, {"idle", .37, 1}, {"cheer", .30, 1},
}

local pieces = Instance.new("Folder")
pieces.Name = "Lineup export"
pieces.Parent = workspace
local function export(figure, pose)
	local model = pawn.make(figure, pieces)
	local deadline = os.clock() + 24
	local function mesh(label)
		local part = model:FindFirstChild(label, true)
		return part and part:IsA("MeshPart") and part
	end
	while os.clock() < deadline and not (mesh("Face") and mesh("Jersey") and mesh("Fluted medal base")) do
		task.wait(.1)
	end
	for _, label in {"Face","Jersey","Fluted medal base","Woven collar","Bent forearm","Palm","Quadriceps","Molded outsole"} do
		assert(mesh(label), string.format("Figure %d is missing %s", figure, label))
	end
	if pose[1] == "stride" then
		pawn.run(model, pose[2], pose[3])
	else
		pawn.animate(model, pose[1], pose[2], pose[3])
	end
	for _, part in model:GetDescendants() do
		if not part:IsA("BasePart") or part.Transparency >= 1 then continue end
		local tint, size = part.Color, part.Size
		local row = {figure, part.Name, part:GetAttribute("BlenderSource") or "-",
			if part:IsA("Part") then part.Shape.Name else "Block",
			tint.R, tint.G, tint.B, size.X, size.Y, size.Z, part.CFrame:GetComponents()}
		print("FIGURE_EXPORT\t" .. table.concat(row, "\t"))
	end
	model:Destroy()
end
local ok, issue = xpcall(function()
	for figure, pose in poses do export(figure, pose) end
end, debug.traceback)
pieces:Destroy()
assert(ok, issue)
