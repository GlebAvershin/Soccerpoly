--!strict
local TweenService = game:GetService("TweenService")
local UI = require(script.Parent.Components)
local Print = require(script.Parent.MatchPrint)
local colors = UI.color

local Banner = {}

function Banner.new(parent: Frame)
	local view = Instance.new("CanvasGroup")
	view.Name, view.BackgroundColor3, view.Visible = "PlayResult", colors.paper, false
	view.AnchorPoint, view.ZIndex = Vector2.new(.5, 0), 5
	view.Size = UDim2.new(.92, 0, 0, 66)
	view.Parent = parent
	UI.round(view, 4)
	UI.stroke(view, colors.ink)
	local bound = Instance.new("UISizeConstraint")
	bound.MaxSize, bound.Parent = Vector2.new(394, 66), view
	local stub = UI.box(view, "Match seal", colors.gold)
	stub.Size = UDim2.new(0,53,1,0)
	local emblems = {}
	for _, symbol in {"pennant", "cup", "whistle", "transfer"} do
		local mark = Print.mark(stub, symbol, colors.ink, 34)
		mark.AnchorPoint, mark.Position = Vector2.new(.5,.5), UDim2.fromScale(.5,.5)
		emblems[symbol] = mark
	end
	for i = 1, 7 do
		local cut = UI.box(view,"Ticket seam",colors.outline)
		cut.Position, cut.Size = UDim2.fromOffset(55,3+(i-1)*9), UDim2.fromOffset(1,4)
	end
	local heading = UI.label(view, "", 22, {color = colors.ink, ellipsis = true})
	heading.FontFace = Print.display
	heading.Size = UDim2.new(1, -78, 0, 29)
	local detail = UI.label(view, "", 14, {font = Enum.Font.BuilderSans, color = colors.surface, ellipsis = true})
	detail.Size = UDim2.new(1, -78, 0, 23)
	local rule = UI.box(view, "Event underline", colors.surface)
	rule.Position = UDim2.new(0,56,1,-3)
	local seq = 0
	local tweens: {Tween} = {}

	local function stop()
		seq += 1
		for _, tween in tweens do tween:Cancel() end
		table.clear(tweens)
	end

	local function play(instance: Instance, time: number, goal: {[string]: any})
		local tween = TweenService:Create(instance, TweenInfo.new(time, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), goal)
		table.insert(tweens, tween)
		tween:Play()
	end

	return {
		hide = function()
			stop()
			view.Visible = false
		end,
		reveal = function(title: string, caption: string, tint: Color3, reduced: boolean, event: string)
			stop()
			local revision = seq
			local symbol = if event == "final" or event == "league" or event == "goal" then "cup"
				elseif event == "offside" or event == "save" or event == "bench" then "whistle"
				elseif string.find(event,"trade") or string.find(event,"auction") or event == "buy" then "transfer"
				else "pennant"
			for key, mark in emblems do mark.Visible = key == symbol end
			heading.Text, detail.Text, stub.BackgroundColor3 = title, caption, tint
			local place = UDim2.new(.5, 0, 0, if parent.AbsoluteSize.Y < 430 then 8 elseif parent.AbsoluteSize.X >= 1040 then 77 else 109)
			local titleRest, detailRest = UDim2.fromOffset(68,5), UDim2.fromOffset(69,33)
			view.Position, view.GroupTransparency = place, 0
			heading.Position, detail.Position = titleRest, detailRest
			local ruleSize = UDim2.new(1,-56,0,3)
			rule.Size, rule.BackgroundColor3 = ruleSize, colors.panel
			view.Visible = true
			if not reduced then
				view.GroupTransparency, view.Position = 1, place + UDim2.fromOffset(0, -6)
				heading.Position, detail.Position = titleRest + UDim2.fromOffset(8,0), detailRest + UDim2.fromOffset(12,0)
				rule.Size = UDim2.fromOffset(0,3)
				play(view, .16, {Position=place, GroupTransparency=0})
				play(heading, .22, {Position=titleRest})
				play(detail, .28, {Position=detailRest})
				play(rule, .38, {Size=ruleSize})
			end
			task.delay(1.65, function()
				if revision ~= seq then return end
				if reduced then
					view.Visible = false
				else
					play(view, .18, {GroupTransparency=1})
					task.delay(.19,function()
						if revision == seq then view.Visible = false end
					end)
				end
			end)
		end,
	}
end

return Banner
