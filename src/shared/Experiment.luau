--!strict
local Experiment = {}
Experiment.id = "coach_hint_v1"

function Experiment.arm(userId: number): string
	-- Hash the experiment id with the player id; assignment is stable across servers.
	local key = Experiment.id .. ":" .. tostring(userId)
	local bucket = 5381
	for i = 1, #key do
		bucket = bit32.bxor((bucket * 33) % 4294967296, string.byte(key, i) :: number)
	end
	-- Mix high bits into the bucket; sequential IDs should split independently of their last digit.
	bucket = bit32.bxor(bucket, bit32.rshift(bucket, 16), bit32.rshift(bucket, 7))
	return if bucket % 2 == 0 then "control" else "coach"
end

return table.freeze(Experiment)
