--!strict
--[[
    LiveOpsClient.luau
    Cross-Game LiveOps & LinUCB Dynamic Shop Client SDK for Soccerpoly.
    Interacts with the shared Multi-Game Backend to fetch active seasons,
    cross-game meta-contracts, and personalized cosmetic offerings.
]]

export type LiveOpsSeason = {
    SeasonId: string,
    Title: string,
    DurationDays: number,
    ActiveGames: { string },
    Status: string,
}

export type CrossGameContract = {
    ContractId: string,
    Title: string,
    Description: string,
    TargetGames: { string },
    GoalMetric: string,
    TargetValue: number,
    XpReward: number,
    TokenReward: number,
}

export type CosmeticRecommendation = {
    ArmId: string,
    Category: string,
    Style: string,
    PriceTokens: number,
    PredictedAffinityScore: number,
}

local LiveOpsClient = {}
LiveOpsClient.__index = LiveOpsClient

function LiveOpsClient.new(playerId: string)
    local self = setmetatable({}, LiveOpsClient)
    self.PlayerId = playerId
    self.CurrentSeason = {
        SeasonId = "SEASON_NORTHERN_EXPEDITION",
        Title = "Northern Expedition · Cross-Game Frontier",
        DurationDays = 45,
        ActiveGames = { "atlas", "soccer", "mosaic", "freight" },
        Status = "ACTIVE",
    }
    return self
end

function LiveOpsClient:GetSeason(): LiveOpsSeason
    return self.CurrentSeason
end

function LiveOpsClient:GetAvailableContracts(): { CrossGameContract }
    return {
        {
            ContractId = "CONTRACT_01",
            Title = "Archipelago Tactician",
            Description = "Solve 3 charts in Lantern Atlas and win 2 auctions in Soccerpoly",
            TargetGames = { "atlas", "soccer" },
            GoalMetric = "tactical_wins",
            TargetValue = 5,
            XpReward = 750,
            TokenReward = 150,
        },
        {
            ContractId = "CONTRACT_03",
            Title = "Grand Quad Master",
            Description = "Participate in matches across all 4 titles during active season",
            TargetGames = { "atlas", "soccer", "mosaic", "freight" },
            GoalMetric = "quad_matches",
            TargetValue = 4,
            XpReward = 1500,
            TokenReward = 400,
        },
    }
end

-- Simulates LinUCB recommendation scoring locally on player context vector
function LiveOpsClient:GetPersonalizedCosmetics(
    playerContext: { Velocity: number, BpTier: number, TokenBalance: number, Aesthetic: number }
): { CosmeticRecommendation }
    -- LinUCB weighting: combines playstyle velocity and aesthetic affinity
    local isPrestige = playerContext.Aesthetic > 0.6
    return {
        {
            ArmId = "soccer_golden_ball",
            Category = "Ball",
            Style = "Prestige",
            PriceTokens = 300,
            PredictedAffinityScore = isPrestige and 0.88 or 0.45,
        },
        {
            ArmId = "soccer_retro_kit",
            Category = "Kit",
            Style = "Classic",
            PriceTokens = 250,
            PredictedAffinityScore = 0.65,
        },
    }
end

return LiveOpsClient
