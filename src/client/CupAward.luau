--!strict
local TweenService = game:GetService("TweenService")
local UI = require(script.Parent.Components)
local Print = require(script.Parent.MatchPrint)
local colors = UI.color

-- Reuse the cast already loaded for the north stand, including its enamel and gilt.
return function(parent: Instance, title: string, caption: string, animate: boolean)
	local card = UI.box(parent, "Championship award", colors.paper, 4)
	card.Size = UDim2.new(1,0,0,92)
	local mount = UI.box(card, "Cup mount", colors.panel, 3)
	mount.Size = UDim2.fromOffset(75,92)
	local stage = workspace:FindFirstChild("WorldDraftArena")
	local trophy = stage and stage:FindFirstChild("Continental Cup",true)
	if trophy and trophy:IsA("MeshPart") then
		local view = Instance.new("ViewportFrame")
		view.Name = "Silverware portrait"
		view.Size, view.BackgroundTransparency = UDim2.fromScale(1,1), 1
		view.LightDirection = Vector3.new(-1,-1,-1)
		view.Ambient, view.LightColor = Color3.fromRGB(163,154,134), Color3.fromRGB(255,235,171)
		view.Parent = mount
		local cup = trophy:Clone()
		cup.CFrame = CFrame.identity
		cup.Parent = view
		local camera = Instance.new("Camera")
		camera.FieldOfView = 30
		camera.CFrame = CFrame.lookAt(Vector3.new(3,3.3,23),Vector3.zero)
		camera.Parent, view.CurrentCamera = view,camera
		if animate then
			cup.CFrame = CFrame.Angles(0,math.rad(-62),0)
			TweenService:Create(cup,TweenInfo.new(.78,Enum.EasingStyle.Cubic,Enum.EasingDirection.Out),{CFrame=CFrame.identity}):Play()
		end
	else
		local mark = Print.mark(mount,"cup",colors.gold,45)
		mark.AnchorPoint, mark.Position = Vector2.new(.5,.5), UDim2.fromScale(.5,.5)
	end
	local heading = UI.label(card,title,22,{color=colors.ink})
	heading.FontFace = Print.display
	heading.AutomaticSize = Enum.AutomaticSize.None
	heading.Position, heading.Size = UDim2.fromOffset(87,4), UDim2.new(1,-94,0,52)
	heading.TextScaled = true
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize, cap.MinTextSize, cap.Parent = 22,12,heading
	local sub = UI.label(card,caption,12,{color=colors.surface})
	sub.AutomaticSize = Enum.AutomaticSize.None
	sub.Position, sub.Size = UDim2.fromOffset(87,55), UDim2.new(1,-94,0,34)
end
