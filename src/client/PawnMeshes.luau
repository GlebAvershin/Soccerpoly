--!strict
local AssetService = game:GetService("AssetService")
local Data = require(script.Parent.PawnMeshData)

type Shape = {points: {number}, normals: {number}, triangles: {number}}
type Pending = {source: BasePart, legacy: {BasePart}?}
local requests: {[string]: {Pending}} = {}
local templates: {[string]: MeshPart} = {}
local Meshes = {}

local function replace(request: Pending, template: MeshPart)
	local source = request.source
	local owner = source.Parent
	if not owner then return end
	local part = template:Clone()
	part.Name, part.CFrame, part.Size, part.Color = source.Name, source.CFrame, source.Size, source.Color
	part.Transparency, part.Material, part.CastShadow = source.Transparency, source.Material, source.CastShadow
	part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
	part.Parent = owner
	source:Destroy()
	if request.legacy then
		for _, piece in request.legacy do piece:Destroy() end
	end
end

local function loadTemplate(data: Shape): MeshPart?
	local mesh = AssetService:CreateEditableMesh()
	if not mesh then return nil end
	local verts, normals = {}, {}
	for i = 1, #data.points, 3 do
		local ordinal = (i + 2) / 3
		verts[ordinal] = mesh:AddVertex(Vector3.new(data.points[i], data.points[i + 1], data.points[i + 2]) / 10000)
		normals[ordinal] = mesh:AddNormal(Vector3.new(data.normals[i], data.normals[i + 1], data.normals[i + 2]).Unit)
	end
	for i = 1, #data.triangles, 3 do
		local a, b, c = data.triangles[i], data.triangles[i + 1], data.triangles[i + 2]
		local face = mesh:AddTriangle(verts[a], verts[b], verts[c])
		mesh:SetFaceNormals(face, {normals[a], normals[b], normals[c]})
	end
	-- A template retains the mesh content for all clones on this client.
	return AssetService:CreateMeshPartAsync(Content.fromObject(mesh), {CollisionFidelity = Enum.CollisionFidelity.Box})
end

for name, shape in Data do
	requests[name] = {}
	task.defer(function()
		local success, template = pcall(loadTemplate, shape)
		local pending = requests[name]
		requests[name] = nil
		if success and template then
			templates[name] = template
			for _, request in pending do replace(request, template) end
		end
	end)
end

function Meshes.apply(name: string, source: BasePart, legacy: {BasePart}?)
	local template = templates[name]
	local pending = requests[name]
	if template then
		replace({source = source, legacy = legacy}, template)
	elseif pending then
		table.insert(pending, {source = source, legacy = legacy})
	end
end

return table.freeze(Meshes)
