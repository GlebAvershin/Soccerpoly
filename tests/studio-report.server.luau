local studio = game:GetService("StudioTestService")
local mode = studio:GetTestArgs()
local expected = ({WorldDraftSmoke = 1, WorldDraftDuo = 2, WorldDraftFour = 4})[mode]
assert(expected)
local net = game:GetService("ReplicatedStorage"):WaitForChild("WorldDraft")
local players = game:GetService("Players")
local report = Instance.new("RemoteEvent")
report.Name = "StudioReport"
report:SetAttribute("ReadyCount", 0)
report.Parent = net
task.delay(if expected == 4 then 180 else 75, function() studio:EndTest("TIMEOUT") end)
local checks, ready = {}, {}
local metrics = ""
report.OnServerEvent:Connect(function(player, status)
	if status == "READY" then
		if not ready[player] then
			ready[player] = true
			report:SetAttribute("ReadyCount", report:GetAttribute("ReadyCount") + 1)
		end
		return
	end
	if string.sub(status, 1, 7) == "METRIC " then metrics = " | " .. string.sub(status, 8); return end
	if status ~= "PASS" then studio:EndTest(tostring(status)); return end
	checks[player] = true
	local total = 0
	for _ in checks do total += 1 end
	if total < expected then return end
	assert(#players:GetPlayers() == total)
	local arena = workspace:FindFirstChild("WorldDraftArena")
	assert(arena and #arena:GetDescendants() > 300)
	studio:EndTest("PASS " .. mode .. metrics)
end)
