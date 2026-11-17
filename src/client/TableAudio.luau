--!strict
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")

type Cue = {asset: string, volume: number, speed: number?, cap: number?}
local cues: {[string]: Cue} = {
	select = {asset = "rbxasset://sounds/volume_slider.ogg", volume = .23, speed = 1.22},
	step = {asset = "rbxassetid://9119983236", volume = .19, speed = 1.06, cap = .17},
	land = {asset = "rbxassetid://9119322058", volume = .36, speed = 1.1, cap = .46},
	card = {asset = "rbxassetid://9118104432", volume = .26, cap = .78},
	dice = {asset = "rbxassetid://9114072654", volume = .32, speed = 1.12, cap = .92},
	goalMotif = {asset = "rbxassetid://9038650772", volume = .24, cap = 2.55},
	sign = {asset = "rbxassetid://9039637670", volume = .33, cap = 1.70},
	kick = {asset = "rbxassetid://9119326824", volume = .57, cap = .75},
	save = {asset = "rbxassetid://9119340059", volume = .53},
	offside = {asset = "rbxassetid://9117261163", volume = .31, cap = .84},
	goal = {asset = "rbxassetid://9120974708", volume = .50, cap = 2.20},
	whistle = {asset = "rbxassetid://9118113825", volume = .34, cap = .72},
	final = {asset = "rbxassetid://9042836235", volume = .44, cap = 3.40},
}

local function gain(db: number): number
	return 10 ^ (db / 20)
end

local function new()
	local function group(name: string): SoundGroup
		local bus = Instance.new("SoundGroup")
		bus.Name, bus.Parent = name, SoundService
		return bus
	end
	local music = group("Footbolapolia Music")
	local crowd = group("Footbolapolia Stadium")
	local effects = group("Footbolapolia Effects")
	local function make(bus: SoundGroup, name: string, asset: string): Sound
		local sound = Instance.new("Sound")
		sound.Name, sound.SoundId, sound.SoundGroup = name, asset, bus
		sound.Parent = bus
		return sound
	end
	local lobbyScore = make(music, "Feel That Move", "rbxassetid://9044946039")
	local matchScore = make(music, "Plug In and Party (match underscore)", "rbxassetid://9038650387")
	local stadium = make(crowd, "Stadium Crowd", "rbxassetid://9119562311")
	lobbyScore.Looped, matchScore.Looped, stadium.Looped = true, true, true
	lobbyScore.Volume, matchScore.Volume, stadium.Volume = 0, 0, 1
	local ambienceEQ = Instance.new("EqualizerSoundEffect")
	ambienceEQ.HighGain, ambienceEQ.MidGain, ambienceEQ.LowGain = -6, -2, -3
	ambienceEQ.Parent = crowd
	local samples: {[string]: Sound} = {}
	local preload: {Instance} = {lobbyScore, matchScore, stadium}
	for name, cue in cues do
		local sound = make(effects, name, cue.asset)
		samples[name] = sound
		table.insert(preload, sound)
	end
	local alternateStep = make(effects, "step alternate", "rbxassetid://9119983817")
	table.insert(preload, alternateStep)
	task.spawn(function() pcall(function() ContentProvider:PreloadAsync(preload) end) end)

	local generations: {[Sound]: number} = {}
	local tweens: {[Instance]: Tween} = {}
	local musicEnabled, enabled, inMatch = true, true, false
	local duckUntil, duckSerial = 0, 0
	local musicRevision = 0
	local currentScore: Sound? = nil
	local stepSide = false
	local rng = Random.new()
	local function fade(object: Sound | SoundGroup, value: number, seconds: number)
		local running = tweens[object]
		if running then running:Cancel() end
		if seconds == 0 then
			tweens[object] = nil
			object.Volume = value
		else
			local tween = TweenService:Create(object, TweenInfo.new(seconds, Enum.EasingStyle.Quad), {Volume = value})
			tweens[object] = tween
			tween:Play()
		end
	end

	local function mix(time: number)
		local ducking = os.clock() < duckUntil
		local wanted = if enabled and musicEnabled then (if inMatch then matchScore else lobbyScore) else nil
		if wanted ~= currentScore then
			musicRevision += 1
			local revision = musicRevision
			currentScore = wanted
			if wanted and not wanted.IsPlaying then wanted:Play() end
			for _, track in {lobbyScore, matchScore} do
				fade(track, if track == wanted then 1 else 0, time)
			end
			local function pauseInactive()
				if musicRevision ~= revision then return end
				for _, track in {lobbyScore, matchScore} do
					if track ~= wanted then track:Pause() end
				end
			end
			if time == 0 then pauseInactive() else task.delay(time + .03, pauseInactive) end
		end
		local duck = if ducking then 9 else 0
		fade(music, if enabled and musicEnabled then gain((if inMatch then -20 else -20.5) - duck) else 0, time)
		fade(crowd, if enabled and inMatch then gain(if ducking then -31 else -27.5) else 0, time)
		effects.Volume = if enabled then gain(-3) else 0
		if enabled and inMatch then
			if not stadium.IsPlaying then stadium:Play() end
		elseif time == 0 then stadium:Stop() end
	end

	local function play(name: string)
		local cue, sound = cues[name], samples[name]
		if not enabled or not cue or not sound then return end
		if name == "step" then
			stepSide = not stepSide
			if stepSide then sound = alternateStep end
		end
		local id = (generations[sound] or 0) + 1
		generations[sound] = id
		local old = tweens[sound]
		if old then old:Cancel(); tweens[sound] = nil end
		sound:Stop()
		sound.PlaybackSpeed = (cue.speed or 1) * (if name == "step" or name == "land" then rng:NextNumber(.94, 1.06) else 1)
		sound.Volume = cue.volume
		sound:Play()
		local cap = cue.cap
		if cap then
			task.delay(math.max(0, cap - .09), function()
				if generations[sound] ~= id or not sound.IsPlaying then return end
				fade(sound, 0, .09)
				task.delay(.10, function() if generations[sound] == id then sound:Stop() end end)
			end)
		end
		if name == "goal" and musicEnabled then play("goalMotif") end
		if name == "goal" or name == "final" or name == "offside" then
			local duration = if name == "final" then 2.8 elseif name == "goal" then 1.65 else .55
			duckUntil = math.max(duckUntil, os.clock() + duration)
			duckSerial += 1
			local serial = duckSerial
			mix(.10)
			task.delay(math.max(0, duckUntil - os.clock()), function()
				if serial == duckSerial then mix(.48) end
			end)
		end
	end

	mix(0)
	return {
		play = play,
		scene = function(playing: boolean)
			if inMatch == playing then return end
			inMatch = playing
			mix(.55)
			if not playing then task.delay(.57, function() if not inMatch then stadium:Stop() end end) end
		end,
		setEnabled = function(value: boolean)
			enabled = value
			if not enabled then
				for _, sample in samples do sample:Stop() end
				alternateStep:Stop()
			end
			mix(0)
		end,
		setMusic = function(value: boolean)
			musicEnabled = value
			if not value then samples.goalMotif:Stop() end
			mix(0)
		end,
	}
end

return new
