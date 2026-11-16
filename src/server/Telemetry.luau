--!strict
local Analytics = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")
local Telemetry = {}
local enabled = not RunService:IsStudio() and game.PlaceId ~= 0
local funnel = "WorldDraftOnboarding_v1"

function Telemetry.step(player: Player, session: string, number: number, label: string)
	if not enabled then return end
	task.defer(function()
		local ok, err = pcall(Analytics.LogFunnelStepEvent, Analytics, player, funnel, session, number, label)
		if not ok then warn("[WorldDraft/Analytics]", err) end
	end)
end

function Telemetry.event(player: Player, name: string, value: number, mode: string, variant: string, detail: string?)
	if not enabled then return end
	task.defer(function()
		local ok, err = pcall(Analytics.LogCustomEvent, Analytics, player, name, value, {CustomField01 = mode, CustomField02 = variant, CustomField03 = detail or "general"})
		if not ok then warn("[WorldDraft/Analytics]", err) end
	end)
end

return Telemetry
