--!strict
local UI = require(script.Parent.Components)
return function(root: Frame, selectLanguage: (string)->())
	local shade = UI.box(root, "LanguagePicker", UI.color.ink)
	shade.Size, shade.Active, shade.ZIndex = UDim2.fromScale(1,1), true, 100
	local card = UI.box(shade, "Choice", UI.color.panel, 16)
	card.AnchorPoint, card.Position, card.Size = Vector2.new(.5,.5), UDim2.fromScale(.5,.5), UDim2.new(.90,0,0,246)
	local limit=Instance.new("UISizeConstraint")
	limit.MaxSize,limit.Parent=Vector2.new(414,246), card
	UI.stroke(card, UI.color.outline)
	local word=UI.label(card,"FOOTBOLAPOLIA",14,{color=UI.color.mint,font=Enum.Font.BuilderSansBold})
	word.Position,word.Size=UDim2.fromOffset(22,15),UDim2.new(1,-44,0,26)
	local title=UI.label(card,"Язык игры / Game language",22,{font=Enum.Font.BuilderSansExtraBold})
	title.Position,title.Size=UDim2.fromOffset(22,44),UDim2.new(1,-44,0,48)
	for i, lang in {"ru","en"} do
		local button=UI.button(card,lang,if lang=="ru" then "Русский" else "English",52,function() selectLanguage(lang) end,UI.color.surface)
		button.Size,button.Position=UDim2.new(1,-44,0,52),UDim2.fromOffset(22,99+(i-1)*62)
	end
	return shade
end
