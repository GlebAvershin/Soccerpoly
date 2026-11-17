--!strict
local shared = game:GetService("ReplicatedStorage"):WaitForChild("League")
local Board = require(shared.TourBoard)
local Art = require(shared.Presentation)
local illustrate = require(script.Parent.Programme)
local UI = require(script.Parent.Components)
local C = Color3.fromHex
local colors = UI.color
local INK = Art.ink
local CENTER = Enum.TextXAlignment.Center
local BOLD = Enum.Font.BuilderSansBold
local style = require(script.Parent.ProgrammeStyle)
local function text(parent: Instance, content: string, height: number, y: number, size: number, color: Color3): TextLabel
	local label = UI.label(parent, content, size, {font = Enum.Font.BuilderSans, color = color, align = CENTER, ellipsis = true})
	label.Position, label.Size = UDim2.new(0, 10, 0, y), UDim2.new(1, -20, 0, height)
	return label
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

local function illustration(parent: Instance, index: number, height: number)
	local tile = Board.tiles[index]
	local backing = UI.box(parent, "Illustration", style.ink(tile))
	backing.Position, backing.Size = UDim2.fromOffset(0, 37), UDim2.new(1, 0, 0, height + 2)
	illustrate(backing, tile, true)
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
	shade.Size = UDim2.fromScale(1,1)
	-- Keep controls within the safe area while dimming the district behind the top bar.
	shade.BackgroundTransparency = 1
	local scrim = UI.box(shade, "District scrim", colors.background)
	scrim.BackgroundTransparency, scrim.ZIndex = .28, 0
	scrim.Position, scrim.Size = UDim2.fromScale(-1,-1), UDim2.fromScale(3,3)
	for _, child in shade:GetChildren() do if child:IsA("UICorner") then child:Destroy() end end
	local wrapper = UI.box(shade, "PropertyCard")
	wrapper.Position, wrapper.AnchorPoint = UDim2.fromScale(.5, .51), Vector2.new(.5, .5)
	wrapper.Size = UDim2.new(.90, 0, 0, 284)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize, limit.Parent = Vector2.new(452, 284), wrapper
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
			local extraArt = if shade.AbsoluteSize.Y >= 550 then 28 else 0
			local height = 284 + optionsHeight + extraArt
			wrapper.Size = UDim2.new(.90, 0, 0, height)
			limit.MaxSize = Vector2.new(452, height)
			local tile = Board.tiles[info.index]
			local bodyInk = style.ink(tile)
			local ruled = bodyInk:Lerp(style.title, .09)
			local paper = UI.box(wrapper, "Club dossier", bodyInk, 7)
			paper.Size = UDim2.fromScale(1, 1)
			UI.stroke(paper, bodyInk:Lerp(style.price,.47))
			local league = Art.accent(tile.kind, tile.league)
			local header = UI.box(paper, "Club header", colors.ink, 6)
			header.Position, header.Size = UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 37)
			local tab = UI.box(header, "League accent", league)
			tab.Position, tab.Size = UDim2.fromOffset(11, 10), UDim2.fromOffset(4, 17)
			local title = text(header, info.title, 36, 0, 23, colors.text)
			title.FontFace = style.clubFace
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.Position, title.Size = UDim2.fromOffset(23, 0), UDim2.new(1, -67, 1, 0)
			local exit = UI.button(header, "CloseCard", "×", 33, info.close, colors.ink, colors.text)
			exit.BackgroundTransparency, exit.TextSize = 1, 25
			exit.Position, exit.Size = UDim2.new(1, -39, 0, 0), UDim2.fromOffset(39, 33)
			for _, child in exit:GetChildren() do if child:IsA("UIStroke") then child:Destroy() end end
			illustration(paper, info.index, 127 + extraArt)
			local summary = text(paper, info.summary, 30, 169 + extraArt, 16, style.title)
			summary.FontFace = style.amountFace
			if options then
				local function row(y: number, cells: {string}, fill: Color3, heading: boolean, selected: boolean?)
					local columns = UI.box(paper, "Prices", fill)
					columns.Position, columns.Size = UDim2.fromOffset(13, y), UDim2.new(1, -26, 0, 26)
					for i, cell in cells do
						local label = text(columns, cell, 25, 0, 14, if selected then colors.ink elseif heading then style.price else style.title)
						label.Position, label.Size = UDim2.new((i - 1) / #cells, 7, 0, 0), UDim2.new(1 / #cells, -14, 1, 0)
						label.TextXAlignment = if i == 1 then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right
						if i > 1 and not heading then label.FontFace = style.amountFace else label.Font = BOLD end
					end
					return columns
				end
				row(200 + extraArt, info.columns or {}, colors.ink, true)
				for i, item in options do
					local fill = if item.highlighted then C("CBE7D5") elseif i % 2 == 0 then ruled else bodyInk
					local columns = row(226 + extraArt + (i - 1) * 28, item.cells, fill, false, item.highlighted)
					if item.press then
						local button = UI.button(columns, "ChooseLevel" .. i, "", 26, item.press, fill)
						button.BackgroundTransparency, button.Size = 1, UDim2.fromScale(1, 1)
						for _, child in button:GetChildren() do if child:IsA("UIStroke") then child:Destroy() end end
					end
				end
			end
			local close = Card.button(paper, "Skip", info.closeLabel, info.close)
			close.Position, close.Size = UDim2.new(if info.action then 0 else .23, 15, 0, 207 + extraArt + optionsHeight),
				UDim2.new(if info.action then .40 else .48, -23, 0, 39)
			if info.action and info.actionName and info.actionLabel then
				local accept = Card.button(paper, info.actionName, info.actionLabel, info.action, true)
				accept.Position, accept.Size = UDim2.new(.40, 8, 0, 207 + extraArt + optionsHeight), UDim2.new(.60, -23, 0, 39)
			end
			text(paper, info.footer, 26, 251 + extraArt + optionsHeight, 14, C("D4DEDA"))
			limit.Parent, scale.Parent = wrapper, wrapper
			shade.Visible = true
			fit()
		end,
	}
end

return Card
