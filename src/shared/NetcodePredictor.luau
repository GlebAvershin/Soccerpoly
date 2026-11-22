--!strict
--[[
    NetcodePredictor.luau
    Deterministic Client-Side Prediction and Server Reconciliation for
    Soccerpoly Penalty Shootout Mechanics and Ball Trajectory.
]]

export type Vector3Record = {
    X: number,
    Y: number,
    Z: number,
}

export type KickCommand = {
    CommandId: number,
    ClientTimestamp: number,
    AimVector: Vector3Record,
    Power: number,
    CurveSpin: number,
}

export type BallSimulationState = {
    Position: Vector3Record,
    Velocity: Vector3Record,
    Tick: number,
    Timestamp: number,
    IsGoal: boolean,
}

local NetcodePredictor = {}
NetcodePredictor.__index = NetcodePredictor

local GRAVITY = -9.81 * 2 -- Scaled physics for responsive arcade feel
local AIR_DRAG = 0.985
local GOAL_PLANE_Z = 28.0 -- Target goal line coordinate

function NetcodePredictor.new(isServer: boolean)
    local self = setmetatable({}, NetcodePredictor)
    self.IsServer = isServer
    self.HistoryBuffer = {} -- Ring buffer for server rollback
    self.PendingCommands = {} -- Unacknowledged client commands
    self.CurrentTick = 0
    return self
end

-- Simulates 1 physics step forward
function NetcodePredictor.IntegrateStep(
    pos: Vector3Record,
    vel: Vector3Record,
    spin: number,
    dt: number
): (Vector3Record, Vector3Record)
    -- Magnus effect lateral displacement from curve spin
    local lateralCurve = spin * vel.Z * 0.12 * dt
    local newVx = (vel.X + lateralCurve) * AIR_DRAG
    local newVy = (vel.Y + GRAVITY * dt) * AIR_DRAG
    local newVz = vel.Z * AIR_DRAG

    local newPos = {
        X = pos.X + newVx * dt,
        Y = math.max(0, pos.Y + newVy * dt),
        Z = pos.Z + newVz * dt,
    }
    local newVel = {
        X = newVx,
        Y = (newPos.Y <= 0) and math.abs(newVy) * 0.4 or newVy,
        Z = newVz,
    }
    return newPos, newVel
end

-- Client initiates local prediction immediately (0ms visual delay)
function NetcodePredictor:PredictKick(cmd: KickCommand): BallSimulationState
    local initialPos = { X = 0, Y = 0.5, Z = 0 }
    local initialVel = {
        X = cmd.AimVector.X * cmd.Power,
        Y = math.max(2.0, cmd.AimVector.Y * cmd.Power * 0.6),
        Z = cmd.AimVector.Z * cmd.Power,
    }

    table.insert(self.PendingCommands, cmd)

    -- Integrate forward until goal line reached or ball stops
    local pos = initialPos
    local vel = initialVel
    local dt = 1 / 60
    local stepCount = 0

    while pos.Z < GOAL_PLANE_Z and stepCount < 180 do
        pos, vel = NetcodePredictor.IntegrateStep(pos, vel, cmd.CurveSpin, dt)
        stepCount += 1
    end

    -- Goal detection: between posts (-3.6m to 3.6m) and below crossbar (2.4m)
    local isGoal = math.abs(pos.X) <= 3.6 and pos.Y <= 2.4 and pos.Y >= 0

    return {
        Position = pos,
        Velocity = vel,
        Tick = self.CurrentTick + stepCount,
        Timestamp = cmd.ClientTimestamp + (stepCount * dt),
        IsGoal = isGoal,
    }
end

-- Server authoritatively simulates with rewind and bounds verification
function NetcodePredictor:ServerProcessCommand(
    cmd: KickCommand,
    serverTick: number
): (BallSimulationState, boolean)
    -- Anti-cheat validation: check that power and aim vector are physically valid
    local aimMagnitude = math.sqrt(cmd.AimVector.X^2 + cmd.AimVector.Y^2 + cmd.AimVector.Z^2)
    local isValidInput = (cmd.Power >= 5 and cmd.Power <= 35) and
                         (math.abs(aimMagnitude - 1.0) < 0.05) and
                         (math.abs(cmd.CurveSpin) <= 1.5)

    if not isValidInput then
        -- Reject hacked/invalid packet
        local fallbackPos = { X = 0, Y = 0, Z = 0 }
        return {
            Position = fallbackPos,
            Velocity = fallbackPos,
            Tick = serverTick,
            Timestamp = cmd.ClientTimestamp,
            IsGoal = false,
        }, false
    end

    -- Run deterministic authoritative trajectory
    local initialPos = { X = 0, Y = 0.5, Z = 0 }
    local initialVel = {
        X = cmd.AimVector.X * cmd.Power,
        Y = math.max(2.0, cmd.AimVector.Y * cmd.Power * 0.6),
        Z = cmd.AimVector.Z * cmd.Power,
    }

    local pos = initialPos
    local vel = initialVel
    local dt = 1 / 60
    local stepCount = 0

    while pos.Z < GOAL_PLANE_Z and stepCount < 180 do
        pos, vel = NetcodePredictor.IntegrateStep(pos, vel, cmd.CurveSpin, dt)
        stepCount += 1
    end

    local isGoal = math.abs(pos.X) <= 3.6 and pos.Y <= 2.4 and pos.Y >= 0
    local authState = {
        Position = pos,
        Velocity = vel,
        Tick = serverTick + stepCount,
        Timestamp = cmd.ClientTimestamp + (stepCount * dt),
        IsGoal = isGoal,
    }

    return authState, true
end

return NetcodePredictor
