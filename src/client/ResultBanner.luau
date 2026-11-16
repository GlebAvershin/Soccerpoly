--!strict
local TweenService = game:GetService("TweenService")
local UI = require(script.Parent.Components)
local colors = UI.color

local Banner = {}

function Banner.new(parent: Frame)
	local view = Instance.new("CanvasGroup")
	view.Name, view.BackgroundColor3, view.Visible = "PlayResult", colors.paper, false
	view.AnchorPoint, view.ZIndex = Vector2.new(.5, .5), 5
	view.Size, view.Position = UDim2.new(.86, 0, 0, 90), UDim2.fromScale(.5, .42)
	view.Parent = parent
	UI.round(view, 16)
	UI.stroke(view, colors.ink, 2)
	local bound = Instance.new("UISizeConstraint")
	bound.MaxSize, bound.Parent = Vector2.new(420, 95), view
	local grow = Instance.new("UIScale")
	grow.Parent = view
	local stripe = UI.box(view, "Result color", colors.gold, 5)
	stripe.Size, stripe.Position = UDim2.new(0, 7, 1, -26), UDim2.fromOffset(12, 13)
	local heading = UI.label(view, "", 25, {font = Enum.Font.GothamBlack, color = colors.ink, ellipsis = true})
	heading.Size, heading.Position = UDim2.new(1, -45, 0, 33), UDim2.fromOffset(31, 12)
	local detail = UI.label(view, "", 14, {font = Enum.Font.GothamBold, color = colors.panel, ellipsis = true})
	detail.Size, detail.Position = UDim2.new(1, -45, 0, 24), UDim2.fromOffset(32, 51)
	local pitch = UI.box(view, "Shot replay", Color3.fromHex("65BB96"), 9)
	pitch.AnchorPoint, pitch.Position, pitch.Size = Vector2.new(1, .5), UDim2.new(1, -10, .5, 0), UDim2.fromOffset(92, 66)
	pitch.ClipsDescendants = true
	local goal = UI.box(pitch, "Goal", Color3.fromHex("489E81"), 3)
	goal.Position, goal.Size = UDim2.fromOffset(60, 13), UDim2.fromOffset(26, 40)
	UI.stroke(goal, colors.paper, 2)
	for x = 6, 20, 7 do
		local mesh = UI.box(goal, "Net", colors.paper)
		mesh.BackgroundTransparency = .46
		mesh.Position, mesh.Size = UDim2.fromOffset(x, 0), UDim2.new(0, 1, 1, 0)
	end
	for y = 8, 32, 8 do
		local mesh = UI.box(goal, "Net", colors.paper)
		mesh.BackgroundTransparency = .46
		mesh.Position, mesh.Size = UDim2.fromOffset(0, y), UDim2.new(1, 0, 0, 1)
	end
	local ball = UI.box(pitch, "Ball", colors.paper, 12)
	ball.AnchorPoint, ball.Size = Vector2.new(.5, .5), UDim2.fromOffset(18, 18)
	UI.stroke(ball, colors.ink, 1.4)
	local spot = UI.box(ball, "Panel", colors.ink, 1)
	spot.Size, spot.Position, spot.Rotation = UDim2.fromOffset(7, 7), UDim2.fromOffset(5.5, 5.5), 31
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
		reveal = function(title: string, caption: string, tint: Color3, reduced: boolean, mode: string, railFraction: number, shot: string?)
			stop()
			local revision = seq
			heading.Text, detail.Text, stripe.BackgroundColor3 = title, caption, tint
			view.Size = UDim2.new(if mode == "rail" then railFraction - .06 else .88, 0, 0, 90)
			view.Position = UDim2.fromScale(if mode == "rail" then railFraction * .5 else .5, if mode == "portrait" then .47 else .43)
			local illustrateShot = shot ~= nil
			pitch.Visible = illustrateShot
			local textWidth = if illustrateShot then -142 else -45
			heading.Size = UDim2.new(1, textWidth, 0, 33)
			detail.Size = UDim2.new(1, textWidth, 0, 24)
			view.Visible = true
			if illustrateShot then
				local target = if shot == "goal" then UDim2.fromOffset(73, 30)
					elseif shot == "save" then UDim2.fromOffset(54, 39) else UDim2.fromOffset(76, 6)
				ball.Position, ball.Rotation = target, 0
				if not reduced then
					ball.Position = UDim2.fromOffset(12, 50)
					play(ball, .43, Enum.EasingStyle.Quart, {Position = target, Rotation = 238})
				end
			end
			grow.Scale, view.GroupTransparency = if reduced then 1 else .86, if reduced then 0 else 1
			if not reduced then
				play(grow, .29, Enum.EasingStyle.Back, {Scale = 1})
				play(view, .16, Enum.EasingStyle.Quad, {GroupTransparency = 0})
			end
			task.delay(1.40, function()
				if revision ~= seq then return end
				if reduced then
					view.Visible = false
				else
					play(view, .22, Enum.EasingStyle.Quad, {GroupTransparency = 1})
					task.delay(.23, function() if revision == seq then view.Visible = false end end)
				end
			end)
		end,
	}
end

return Banner
