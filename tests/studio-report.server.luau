local studio = game:GetService("StudioTestService")
local mode = studio:GetTestArgs()
assert(mode == "WorldDraftSmoke" or mode == "WorldDraftDuo")
local net = game:GetService("ReplicatedStorage"):WaitForChild("WorldDraft")
local players = game:GetService("Players")
local report = Instance.new("RemoteEvent")
report.Name = "StudioReport"
report.Parent = net
task.delay(75, function() studio:EndTest("TIMEOUT") end)
local checks = {}
report.OnServerEvent:Connect(function(player, status)
	if status ~= "PASS" then studio:EndTest(tostring(status)); return end
	checks[player] = true
	local total = 0
	for _ in checks do total += 1 end
	if total < (if mode == "WorldDraftDuo" then 2 else 1) then return end
	assert(#players:GetPlayers() == total)
	local arena = workspace:FindFirstChild("WorldDraftArena")
	assert(arena and #arena:GetDescendants() > 300)
	studio:EndTest("PASS " .. mode)
end)
