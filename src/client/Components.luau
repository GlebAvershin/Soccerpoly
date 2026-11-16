--!strict
local UI = {}
local function c(hex: string): Color3 return Color3.fromHex(hex) end
UI.color = table.freeze({
	background = c("0B1422"), panel = c("101D2D"), surface = c("192B3E"), outline = c("2C495D"),
	text = c("F0F5FC"), muted = c("ADBED1"), mint = c("C4FF87"), blue = c("8DD2FF"),
	ink = c("111D28"), gold = c("FFD680"), pink = c("FCA39B"),
})
local colors = UI.color

function UI.round(node: GuiObject, radius: number)
	local modifier = Instance.new("UICorner")
	modifier.CornerRadius = UDim.new(0, radius)
	modifier.Parent = node
end

function UI.stroke(node: GuiObject, color: Color3, thickness: number?)
	local modifier = Instance.new("UIStroke")
	modifier.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	modifier.Color, modifier.Thickness = color, thickness or 1
	modifier.Parent = node
	return modifier
end

function UI.box(parent: Instance, name: string, color: Color3?, radius: number?): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = color or colors.background
	frame.BackgroundTransparency = if color then 0 else 1
	if radius then UI.round(frame, radius) end
	frame.Parent = parent
	return frame
end

function UI.pad(parent: Instance, x: number, top: number?, bottom: number?)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, x), UDim.new(0, x)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, top or x), UDim.new(0, bottom or top or x)
	pad.Parent = parent
end

function UI.stack(parent: Instance, gap: number, horizontal: boolean?): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, gap)
	if horizontal then layout.FillDirection = Enum.FillDirection.Horizontal end
	layout.Parent = parent
	return layout
end

function UI.label(parent: Instance, message: string, size: number, opts: {font: Enum.Font?, color: Color3?, align: Enum.TextXAlignment?, name: string?, ellipsis: boolean?}?): TextLabel
	local o = opts or {}
	local l = Instance.new("TextLabel")
	l.Name = o.name or "Text"
	l.Size = UDim2.new(1, 0, 0, size + 4)
	l.BackgroundTransparency = 1
	l.Text, l.TextSize = message, size
	l.TextColor3, l.Font = o.color or colors.text, o.font or Enum.Font.Gotham
	l.TextXAlignment, l.TextYAlignment = o.align or Enum.TextXAlignment.Left, Enum.TextYAlignment.Center
	l.TextWrapped = not o.ellipsis
	if o.ellipsis then
		l.TextTruncate = Enum.TextTruncate.AtEnd
	else
		l.AutomaticSize = Enum.AutomaticSize.Y
	end
	l.Parent = parent
	return l
end

function UI.button(parent: Instance, name: string, text: string, height: number, callback: (() -> ())?, fill: Color3?, color: Color3?): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = UDim2.new(1, 0, 0, height)
	b.BackgroundColor3 = fill or colors.surface
	b.BorderSizePixel = 0
	b.TextColor3 = color or colors.text
	b.Text, b.TextSize, b.Font = text, 14, Enum.Font.GothamBold
	b.TextWrapped = true
	b.AutoButtonColor = callback ~= nil
	b.Active = callback ~= nil
	b.Selectable = callback ~= nil
	UI.round(b, 9)
	if callback then b.Activated:Connect(callback) end
	b.Parent = parent
	return b
end

function UI.scroll(parent: Instance, name: string): ScrollingFrame
	local s = Instance.new("ScrollingFrame")
	s.Name = name
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.CanvasSize = UDim2.new()
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.ScrollingDirection = Enum.ScrollingDirection.Y
	s.ScrollBarThickness = 3
	s.ScrollBarImageColor3 = colors.outline
	s.Parent = parent
	return s
end

return UI
