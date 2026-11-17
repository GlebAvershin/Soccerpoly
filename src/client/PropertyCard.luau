--!strict
local GuiService = game:GetService("GuiService")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("League")
local Board = require(shared.TourBoard)
local Art = require(shared.Presentation)
local Meshes = require(script.Parent.MeshLibrary)
local UI = require(script.Parent.Components)
local C = Color3.fromHex
local colors = UI.color
local INK = Art.ink
local CENTER = Enum.TextXAlignment.Center
local BOLD = Enum.Font.BuilderSansExtraBold

local function text(parent: Instance, content: string, height: number, y: number, size: number, color: Color3): TextLabel
	local label = UI.label(parent, content, size, {font = Enum.Font.BuilderSans, color = color, align = CENTER, ellipsis = true})
	label.Position, label.Size = UDim2.new(0, 10, 0, y), UDim2.new(1, -20, 0, height)
	return label
end

local function gradient(obj: GuiObject, top: Color3, bottom: Color3)
	local effect = Instance.new("UIGradient")
	effect.Rotation, effect.Color = 90, ColorSequence.new(top, bottom)
	effect.Parent = obj
end

local Card = {}

function Card.button(parent: Instance, name: string, label: string, press: () -> (), primary: boolean?): TextButton
	local button = UI.button(parent, name, label, 44, press,
		if primary then colors.mint else colors.surface, if primary then INK else colors.text)
	-- Side controls and ticket actions share the same stadium-signage geometry.
	local corner = button:FindFirstChildOfClass("UICorner")
	if corner then corner.CornerRadius = UDim.new(0, 5) end
	button.TextSize = 15
	return button
end

local function illustration(parent: Instance, index: number, level: number)
	local tile = Board.tiles[index]
	local backing = UI.box(parent, "Illustration", Color3.new(1, 1, 1))
	backing.Position, backing.Size = UDim2.fromOffset(12, 39), UDim2.new(1, -24, 0, 127)
	gradient(backing, C("46466D"), C("211F37"))
	UI.stroke(backing, colors.outline)
	local view = Instance.new("ViewportFrame")
	view.Name, view.BackgroundTransparency, view.Size = "ClubMiniature", 1, UDim2.fromScale(1, 1)
	view.Ambient, view.LightColor, view.LightDirection = C("BBC8B5"), C("FFF3DC"), Vector3.new(-3, -5, -2)
	view.Parent = backing
	local world = Instance.new("WorldModel")
	world.Parent = view
	local function block(name: string, size: Vector3, position: Vector3, color: Color3): Part
		local part = Instance.new("Part")
		part.Name, part.Anchored, part.CanCollide = name, true, false
		part.Material, part.Size, part.Position, part.Color = Enum.Material.SmoothPlastic, size, position, color
		part.Parent = world
		return part
	end
	block("Plinth", Vector3.new(11.5, .45, 11.5), Vector3.new(0, -.22, 0), C("8A8A80"))
	block("Turf", Vector3.new(9.6, .23, 9.6), Vector3.new(0, .10, 0), C("A2BC54"))
	local color = Art.accent(tile.kind, tile.league)
	block("Club foundation", Vector3.new(5.2, .36, 3.80), Vector3.new(0, .41, .3), color:Lerp(INK, .14))
	local height = 1.35 + level * .40
	block("Club pavilion", Vector3.new(4.88, height, 3.44), Vector3.new(0, .55 + height * .5, .3), C("FFF1D9"))
	local roof = block("Rounded roof", Vector3.new(5.35, .38, 3.89), Vector3.new(0, .74 + height, .3), color)
	Meshes.apply("die", roof)
	block("Club entry", Vector3.new(1.16, 1.05, .045), Vector3.new(.9, 1.07, 2.043), color:Lerp(INK, .55))
	for _, side in {-1, 1} do
		block("Box window", Vector3.new(.94, .54, .045), Vector3.new(side * 1.52, .70 + height * .64, 2.052), C("425B72"))
	end
	for _, x in {-4, 4} do
		local stem = block("Tree trunk", Vector3.new(.22, 1.34, .22), Vector3.new(x, .87, -2.4), C("866336"))
		stem.CastShadow = false
		local leaf = block("Tree crown", Vector3.new(1.32, 1.42, 1.32), Vector3.new(x, 1.67, -2.4), C("87A52C"))
		leaf.Shape = Enum.PartType.Ball
	end
	local camera = Instance.new("Camera")
	camera.FieldOfView = 28
	camera.CFrame = CFrame.lookAt(Vector3.new(15, 14, 15), Vector3.new(0, .64, 0))
	camera.Parent, view.CurrentCamera = view, camera
end

export type Details = {
	index: number, level: number, title: string, summary: string, footer: string,
	actionName: string?, actionLabel: string?, action: (() -> ())?,
	closeLabel: string, close: () -> (),
	columns: {string}?, levels: {{cells: {string}, press: (() -> ())?, highlighted: boolean?}}?,
}

function Card.new(root: Frame)
	local shade = UI.button(root, "PropertyBackdrop", "", 1, nil, colors.background)
	shade.BorderSizePixel, shade.BackgroundTransparency, shade.AutoButtonColor = 0, .28, false
	shade.Active, shade.Modal, shade.Visible, shade.ZIndex = true, true, false, 12
	local top = GuiService:GetGuiInset().Y
	shade.Position, shade.Size = UDim2.fromOffset(0, -top), UDim2.new(1, 0, 1, top)
	for _, child in shade:GetChildren() do if child:IsA("UICorner") then child:Destroy() end end
	local wrapper = UI.box(shade, "PropertyCard")
	wrapper.Position, wrapper.AnchorPoint = UDim2.fromScale(.5, .51), Vector2.new(.5, .5)
	wrapper.Size = UDim2.new(.90, 0, 0, 284)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize, limit.Parent = Vector2.new(405, 284), wrapper
	local scale = Instance.new("UIScale")
	scale.Parent = wrapper
	local function fit()
		scale.Scale = math.min(1, math.max(0, shade.AbsoluteSize.Y - 22) / limit.MaxSize.Y)
	end
	shade:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	return {
		hide = function() shade.Visible = false end,
		show = function(info: Details)
			limit.Parent, scale.Parent = nil, nil
			wrapper:ClearAllChildren()
			local options = info.levels
			local optionsHeight = if options then 26 + #options * 28 else 0
			local height = 284 + optionsHeight
			wrapper.Size = UDim2.new(.90, 0, 0, height)
			limit.MaxSize = Vector2.new(405, height)
			local paper = UI.box(wrapper, "Club dossier", colors.panel, 7)
			paper.Size = UDim2.fromScale(1, 1)
			UI.stroke(paper, colors.outline)
			local tile = Board.tiles[info.index]
			local league = Art.accent(tile.kind, tile.league)
			local header = UI.box(paper, "Club header", colors.ink, 6)
			header.Position, header.Size = UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 37)
			local tab = UI.box(header, "League accent", league)
			tab.Position, tab.Size = UDim2.fromOffset(11, 10), UDim2.fromOffset(4, 17)
			local title = text(header, info.title, 36, 0, 20, colors.text)
			title.Font, title.TextXAlignment = BOLD, Enum.TextXAlignment.Left
			title.Position, title.Size = UDim2.fromOffset(23, 0), UDim2.new(1, -67, 1, 0)
			local exit = UI.button(header, "CloseCard", "×", 33, info.close, colors.ink, colors.text)
			exit.BackgroundTransparency, exit.TextSize = 1, 25
			exit.Position, exit.Size = UDim2.new(1, -39, 0, 0), UDim2.fromOffset(39, 33)
			for _, child in exit:GetChildren() do if child:IsA("UIStroke") then child:Destroy() end end
			illustration(paper, info.index, info.level)
			local summary = text(paper, info.summary, 30, 169, 14, colors.text)
			summary.Font = Enum.Font.BuilderSansBold
			if options then
				local function row(y: number, cells: {string}, fill: Color3, heading: boolean, selected: boolean?)
					local columns = UI.box(paper, "Prices", fill)
					columns.Position, columns.Size = UDim2.fromOffset(13, y), UDim2.new(1, -26, 0, 26)
					for i, cell in cells do
						local label = text(columns, cell, 25, 0, 12, if selected then colors.ink else colors.text)
						label.Position, label.Size = UDim2.fromScale((i - 1) / #cells, 0), UDim2.fromScale(1 / #cells, 1)
						if heading or selected then label.Font = BOLD end
					end
					return columns
				end
				row(200, info.columns or {}, colors.ink, true)
				for i, item in options do
					local fill = if item.highlighted then colors.mint elseif i % 2 == 0 then colors.surface else colors.ink
					local columns = row(226 + (i - 1) * 28, item.cells, fill, false, item.highlighted)
					if item.press then
						local button = UI.button(columns, "ChooseLevel" .. i, "", 26, item.press, fill)
						button.BackgroundTransparency, button.Size = 1, UDim2.fromScale(1, 1)
						for _, child in button:GetChildren() do if child:IsA("UIStroke") then child.Color = colors.outline end end
					end
				end
			end
			local close = Card.button(paper, "Skip", info.closeLabel, info.close)
			close.Position, close.Size = UDim2.new(if info.action then 0 else .23, 15, 0, 207 + optionsHeight),
				UDim2.new(if info.action then .40 else .48, -23, 0, 39)
			if info.action and info.actionName and info.actionLabel then
				local accept = Card.button(paper, info.actionName, info.actionLabel, info.action, true)
				accept.Position, accept.Size = UDim2.new(.40, 8, 0, 207 + optionsHeight), UDim2.new(.60, -23, 0, 39)
			end
			text(paper, info.footer, 26, 251 + optionsHeight, 13, colors.muted)
			limit.Parent, scale.Parent = wrapper, wrapper
			shade.Visible = true
			fit()
		end,
	}
end

return Card
