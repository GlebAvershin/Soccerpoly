--!strict
local UI = require(script.Parent.Components)
local Print = require(script.Parent.MatchPrint)
local cupPrint = require(script.Parent.CupPrint)
local colors = UI.color

return function(root: Frame, selectLanguage: (string)->())
	local shade = UI.box(root, "LanguagePicker", colors.ink)
	shade.Visible = false
	shade.Size, shade.Active, shade.ZIndex = UDim2.fromScale(1,1), true, 100
	shade.BackgroundTransparency = .13
	local card = UI.box(shade, "Choice", colors.paper, 6)
	card.AnchorPoint = Vector2.new(.5,.5)
	card.Position, card.Size = UDim2.fromScale(.5,.5), UDim2.new(.92,0,0,246)
	card.ClipsDescendants = true
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize, limit.Parent = Vector2.new(492,246), card
	UI.stroke(card, colors.gold, 1)
	local header = UI.box(card, "Cup programme", Color3.fromHex("18463D"))
	header.Size = UDim2.new(1,0,0,98)
	local art = UI.box(header, "Cup illustration", colors.panel)
	art.Position, art.Size = UDim2.new(.65,0,0,0), UDim2.fromScale(.35,1)
	art.ClipsDescendants = true
	local emblem = Print.mark(art, "cup", colors.gold, 52)
	emblem.AnchorPoint, emblem.Position = Vector2.new(.5,.5), UDim2.fromScale(.5,.5)
	task.defer(function()
		local image = cupPrint(art)
		if image then
			image.ScaleType = Enum.ScaleType.Crop
			emblem.Visible = false
		end
	end)
	local word = UI.label(header,"SOCCERPOLY",22,{color=colors.text, ellipsis=true})
	word.FontFace = Print.display
	word.Position, word.Size = UDim2.fromOffset(18,9), UDim2.new(.63,-18,0,30)
	local rule = UI.box(header,"Cover rule",colors.gold)
	rule.Position, rule.Size = UDim2.fromOffset(18,47), UDim2.new(.60,-18,0,1)
	local cup = UI.label(header,"CONTINENTAL CUP",14,{font=Enum.Font.RobotoMono,color=colors.gold,ellipsis=true})
	cup.Position, cup.Size = UDim2.fromOffset(18,54), UDim2.new(.63,-18,0,25)
	local title = UI.label(card,"Game language / Язык игры",20,{font=Enum.Font.BuilderSansBold,color=colors.ink,ellipsis=true})
	title.Position, title.Size = UDim2.fromOffset(18,110), UDim2.new(1,-36,0,33)
	for i, lang in {"en","ru"} do
		local button = UI.button(card,lang,if lang=="ru" then "Русский" else "English",57,function() selectLanguage(lang) end,colors.panel)
		button.Size, button.Position = UDim2.new(.5,-23,0,57), UDim2.new((i-1)*.5,if i==1 then 18 else 5,0,159)
	end
	return shade
end
