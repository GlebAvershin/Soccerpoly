--!strict
local TweenService = game:GetService("TweenService")
local UI = require(script.Parent.Components)
local colors = UI.color

local Banner = {}

function Banner.new(parent: Frame)
	local view = Instance.new("Frame")
	view.Name, view.BackgroundColor3, view.Visible = "PlayResult", colors.paper, false
	view.AnchorPoint, view.ZIndex = Vector2.new(.5, 0), 5
	view.Size, view.Position = UDim2.new(.86, 0, 0, 90), UDim2.fromScale(.5, .42)
	view.Parent = parent
	UI.round(view, 16)
	UI.stroke(view, colors.ink, 2)
	local bound = Instance.new("UISizeConstraint")
	bound.MaxSize, bound.Parent = Vector2.new(332, 65), view
	local stripe = UI.box(view, "Result color", colors.gold, 5)
	stripe.Size, stripe.Position = UDim2.new(0, 7, 1, -26), UDim2.fromOffset(12, 13)
	local heading = UI.label(view, "", 21, {font = Enum.Font.BuilderSansExtraBold, color = colors.ink, ellipsis = true})
	heading.Size, heading.Position = UDim2.new(1, -45, 0, 33), UDim2.fromOffset(31, 6)
	local detail = UI.label(view, "", 14, {font = Enum.Font.BuilderSansBold, color = colors.panel, ellipsis = true})
	detail.Size, detail.Position = UDim2.new(1, -45, 0, 24), UDim2.fromOffset(32, 34)
	local seq = 0
	local tweens: {Tween} = {}

	local function stop()
		seq += 1
		for _, tween in tweens do tween:Cancel() end
		table.clear(tweens)
	end

	local function play(instance: Instance, time: number, easing: Enum.EasingStyle, goal: {[string]: any})
		local tween = TweenService:Create(instance, TweenInfo.new(time, easing, Enum.EasingDirection.Out), goal)
		table.insert(tweens, tween)
		tween:Play()
	end

	return {
		hide = function()
			stop()
			view.Visible = false
		end,
		reveal = function(title: string, caption: string, tint: Color3, reduced: boolean, mode: string, railFraction: number)
			stop()
			local revision = seq
			heading.Text, detail.Text, stripe.BackgroundColor3 = title, caption, tint
			view.Size = UDim2.new(if mode == "rail" then railFraction - .06 else .88, 0, 0, 65)
			local place = if mode == "rail" then UDim2.new(railFraction * .5, 0, 0, 108)
				elseif mode == "portrait" then UDim2.new(.5, 0, .46, 0)
				else UDim2.new(.5, 0, 0, if parent.AbsoluteSize.X >= 920 then 76 else 108)
			view.Position = place
			view.Visible = true
			if not reduced then
				view.Position = place + UDim2.fromOffset(0, -9)
				play(view, .20, Enum.EasingStyle.Quart, {Position = place})
			end
			task.delay(1.40, function()
				if revision ~= seq then return end
				if reduced then
					view.Visible = false
				else
					play(view, .22, Enum.EasingStyle.Quad, {Position = place + UDim2.fromOffset(0, -15)})
					task.delay(.23, function() if revision == seq then view.Visible = false end end)
				end
			end)
		end,
	}
end

return Banner
