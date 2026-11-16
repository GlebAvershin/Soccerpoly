local studio = game:GetService("StudioTestService")
local mode = studio:GetTestArgs()
local expected = ({WorldDraftSmoke = 1, WorldDraftDuo = 2, WorldDraftSix = 6})[mode]
assert(expected)
local net = game:GetService("ReplicatedStorage"):WaitForChild("WorldDraft")
local players = game:GetService("Players")
local report = Instance.new("RemoteEvent")
report.Name = "StudioReport"
report.Parent = net
task.delay(if expected == 6 then 145 else 75, function() studio:EndTest("TIMEOUT") end)
local checks = {}
report.OnServerEvent:Connect(function(player, status)
	if status ~= "PASS" then studio:EndTest(tostring(status)); return end
	checks[player] = true
	local total = 0
	for _ in checks do total += 1 end
	if total < expected then return end
	assert(#players:GetPlayers() == total)
	local arena = workspace:FindFirstChild("WorldDraftArena")
	assert(arena and #arena:GetDescendants() > 300)
	studio:EndTest("PASS " .. mode)
end)
