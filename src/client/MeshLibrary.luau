--!strict
local AssetService = game:GetService("AssetService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local Portraits = require(script.Parent.PlayerSculptData)
local HeadPaint = require(script.Parent.HeadPaint)
local texture = require(script.Parent.IndexedImage)
type Paint = {width: number, height: number, palette: string, pixels: string}
local PawnData = require(script.Parent.PawnMeshData)
local StadiumData = require(script.Parent.StadiumMeshData)
local CupData = require(script.Parent.CupMeshData)
local ReplayData = require(script.Parent.ReplayMeshData)

type Shape = {
	points: {number}, normals: {number}, triangles: {number},
	uvs: {number}?, uvIndices: {number}?, normalIndices: {number}?, colors: {number}?, faceColors: {number}?, vertexColors: {number}?,
}
type Pending = {source: BasePart, legacy: {Instance}?}
local requests: {[string]: {Pending}} = {}
local failed: {[string]: boolean} = {}
local templates: {[string]: MeshPart} = {}
local Meshes = {}
local waiting: {string} = {}
local loading = false

local function replace(request: Pending, template: MeshPart)
	local source = request.source
	local owner = source.Parent
	if not owner then return end
	local part = template:Clone()
	part.Name, part.CFrame, part.Size, part.Color = source.Name, source.CFrame, source.Size, source.Color
	part.Transparency = if source:GetAttribute("MeshPlaceholder") then 0 else source.Transparency
	part.Material, part.CastShadow = source.Material, source.CastShadow
	part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
	local popIn = source:GetAttribute("PopIn") == true
	for key, value in source:GetAttributes() do part:SetAttribute(key, value) end
	part:SetAttribute("MeshShape", nil)
	part:SetAttribute("MeshPlaceholder", nil)
	part:SetAttribute("PopIn", nil)
	part:SetAttribute("BlenderMesh", true)
	part.Parent = owner
	if popIn and not GuiService.ReducedMotionEnabled then
		local fullSize = part.Size
		local fullPose = part.CFrame
		part.Size = fullSize * Vector3.new(1.18, .12, 1.18)
		part.CFrame = fullPose * CFrame.new(0, -fullSize.Y * .44, 0)
		TweenService:Create(part, TweenInfo.new(.34, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{Size = fullSize, CFrame = fullPose}):Play()
	end
	source:Destroy()
	if request.legacy then
		for _, piece in request.legacy do piece:Destroy() end
	end
end

local function loadTemplate(data: Shape, paint: Paint?): MeshPart?
	local mesh = AssetService:CreateEditableMesh()
	if not mesh then return nil end
	local image: EditableImage? = nil
	if paint then
		local ok, result = pcall(texture, paint)
		if ok then image = result end
	end
	local verts, normals, colors = {}, {}, {}
	for i = 1, #data.points, 3 do
		verts[(i + 2) / 3] = mesh:AddVertex(Vector3.new(data.points[i], data.points[i + 1], data.points[i + 2]) / 10000)
	end
	for i = 1, #data.normals, 3 do
		normals[(i + 2) / 3] = mesh:AddNormal(Vector3.new(data.normals[i], data.normals[i + 1], data.normals[i + 2]).Unit)
	end
	if data.colors and not image then
		for i, hex in data.colors do
			colors[i] = mesh:AddColor(Color3.fromRGB(bit32.rshift(hex, 16), bit32.extract(hex, 8, 8), bit32.extract(hex, 0, 8)), 1)
		end
	end
	local uvs = {}
	if data.uvs then
		for i = 1, #data.uvs, 2 do
			uvs[(i + 1) / 2] = mesh:AddUV(Vector2.new(data.uvs[i], data.uvs[i + 1]) / 10000)
		end
	end
	local corners = data.normalIndices or data.triangles
	for i = 1, #data.triangles, 3 do
		local a, b, c = data.triangles[i], data.triangles[i + 1], data.triangles[i + 2]
		local face = mesh:AddTriangle(verts[a], verts[b], verts[c])
		if data.uvIndices then
			local uv = data.uvIndices
			mesh:SetFaceUVs(face, {uvs[uv[i]], uvs[uv[i+1]], uvs[uv[i+2]]})
		end
		mesh:SetFaceNormals(face, {normals[corners[i]], normals[corners[i + 1]], normals[corners[i + 2]]})
		if data.vertexColors and not image then
			local tint = data.vertexColors
			mesh:SetFaceColors(face, {colors[tint[a]], colors[tint[b]], colors[tint[c]]})
		elseif data.faceColors then
			local color = colors[data.faceColors[(i + 2) / 3]]
			mesh:SetFaceColors(face, {color, color, color})
		end
	end
	-- Bake each template before starting the next shape to release the editable memory budget.
	local content = Content.fromObject(mesh)
	local ok, result, baked = pcall(function()
		return AssetService:CreateDataModelContentAsync(content)
	end)
	if ok and result == Enum.CreateContentResult.Success then
		content = baked
		mesh:Destroy()
	end
	local part = AssetService:CreateMeshPartAsync(content, {CollisionFidelity = Enum.CollisionFidelity.Box})
	if image then
		part.TextureContent = Content.fromObject(image)
		part:SetAttribute("PaintedAtlas", true)
	end
	return part
end

local function loadPending()
	while #waiting > 0 do
		local name = table.remove(waiting, 1) :: string
		local shape = (PawnData :: {[string]: Shape})[name] or (StadiumData :: {[string]: Shape})[name]
			or (CupData :: {[string]: Shape})[name] or (ReplayData :: {[string]: Shape})[name] or (Portraits :: {[string]: Shape})[name]
		local success, template = pcall(loadTemplate, shape, (HeadPaint :: {[string]: Paint})[name])
		local pending = requests[name]
		requests[name] = nil
		if success and template then
			template:SetAttribute("BlenderSource", name)
			templates[name] = template
			for _, request in pending do replace(request, template) end
		else
			failed[name] = true
		end
	end
	loading = false
end

function Meshes.apply(name: string, source: BasePart, legacy: {Instance}?)
	if failed[name] then return end
	local template = templates[name]
	local pending = requests[name]
	local request = {source = source, legacy = legacy}
	if template then
		replace(request, template)
	elseif pending then
		table.insert(pending, request)
	else
		requests[name] = {request}
		table.insert(waiting, name)
		if not loading then
			loading = true
			task.defer(loadPending)
		end
	end
end

function Meshes.decorate(stage: Instance)
	for _, placeholder in stage:GetDescendants() do
		if not placeholder:IsA("BasePart") then continue end
		local shape = placeholder:GetAttribute("MeshShape")
		if type(shape) ~= "string" then continue end
		local group = placeholder.Parent
		local legacy = if group then group:FindFirstChild("Fallback") else nil
		Meshes.apply(shape, placeholder, if legacy then {legacy} else nil)
	end
end

return table.freeze(Meshes)
