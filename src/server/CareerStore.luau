--!strict
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local VIP_GAMEPASS_ID = 0

export type Quest = {
	id: string,
	progress: number,
	goal: number,
	rewardXp: number,
	claimed: boolean,
}

export type CareerProfile = {
	matchesPlayed: number,
	matchesWon: number,
	trophies: number,
	managerXp: number,
	careerEarnings: number,
	equippedDice: string,
	equippedAura: string,
	unlockedCosmetics: {[string]: boolean},
	loginStreak: number,
	lastLoginTimestamp: number,
	lastDailySpin: number,
	isVip: boolean,
	quests: {[string]: Quest},
	questsDay: number,
	savedAt: number,
}

local WHEEL_SECTORS = {
	{kind = "cash", amount = 100, label = "+100 CR"},
	{kind = "xp", amount = 150, label = "+150 XP"},
	{kind = "cash", amount = 200, label = "+200 CR"},
	{kind = "trophy", amount = 1, label = "+1 Cup"},
	{kind = "xp", amount = 250, label = "+250 XP"},
	{kind = "cash", amount = 300, label = "+300 CR"},
}

local function defaultQuests(): {[string]: Quest}
	return {
		match = {id = "match", progress = 0, goal = 1, rewardXp = 150, claimed = false},
		sign = {id = "sign", progress = 0, goal = 2, rewardXp = 200, claimed = false},
		upgrade = {id = "upgrade", progress = 0, goal = 1, rewardXp = 250, claimed = false},
	}
end

local DEFAULT_PROFILE: CareerProfile = table.freeze({
	matchesPlayed = 0,
	matchesWon = 0,
	trophies = 0,
	managerXp = 0,
	careerEarnings = 0,
	equippedDice = "ivory_classic",
	equippedAura = "mint_classic",
	unlockedCosmetics = {
		["ivory_classic"] = true,
		["mint_classic"] = true,
	},
	loginStreak = 1,
	lastLoginTimestamp = 0,
	lastDailySpin = 0,
	isVip = false,
	quests = defaultQuests(),
	questsDay = 0,
	savedAt = 0,
}) :: any

local STORE_NAME = "PlayerCareerV1"
local store = if game.GameId > 0 and not RunService:IsStudio()
	then DataStoreService:GetDataStore(STORE_NAME) else nil

local cache: {[number]: CareerProfile} = {}
local pendingSaves: {[number]: boolean} = {}
local isSaving: {[number]: boolean} = {}

local function managerLevelFromXp(xp: number): (number, number, number)
	-- Level = floor(sqrt(xp / 120)) + 1
	-- Returns: level, currentLevelXp, nextLevelRequiredXp
	local level = math.clamp(math.floor(math.sqrt(xp / 120)) + 1, 1, 100)
	local curBase = 120 * (level - 1) * (level - 1)
	local nextBase = 120 * level * level
	return level, xp - curBase, nextBase - curBase
end

local function applyAttributes(player: Player, profile: CareerProfile)
	local level, curXp, neededXp = managerLevelFromXp(profile.managerXp)
	player:SetAttribute("CareerMatches", profile.matchesPlayed)
	player:SetAttribute("CareerWins", profile.matchesWon)
	player:SetAttribute("CareerTrophies", profile.trophies)
	player:SetAttribute("CareerLevel", level)
	player:SetAttribute("CareerLevelCurXp", curXp)
	player:SetAttribute("CareerLevelNeededXp", neededXp)
	player:SetAttribute("CareerTotalXp", profile.managerXp)
	player:SetAttribute("CareerEarnings", profile.careerEarnings)
	player:SetAttribute("CareerEquippedDice", profile.equippedDice)
	player:SetAttribute("CareerEquippedAura", profile.equippedAura)
	player:SetAttribute("CareerLoginStreak", profile.loginStreak)
	player:SetAttribute("CareerIsVip", profile.isVip)
	local now = os.time()
	local canSpin = (now - (profile.lastDailySpin or 0)) >= 20 * 3600
	player:SetAttribute("CareerCanSpin", canSpin)
	pcall(function()
		player:SetAttribute("CareerUnlocked", HttpService:JSONEncode(profile.unlockedCosmetics))
		player:SetAttribute("CareerQuests", HttpService:JSONEncode(profile.quests))
	end)
end

local function refreshDailyQuests(profile: CareerProfile)
	local dayKey = math.floor(os.time() / 86400)
	if profile.questsDay ~= dayKey or not profile.quests then
		profile.questsDay = dayKey
		profile.quests = defaultQuests()
	end
end

local function checkUnlocksForLevel(profile: CareerProfile)
	local level = managerLevelFromXp(profile.managerXp)
	if level >= 2 and not profile.unlockedCosmetics["carbon_stealth"] then
		profile.unlockedCosmetics["carbon_stealth"] = true
	end
	if level >= 3 and not profile.unlockedCosmetics["flame_trail"] then
		profile.unlockedCosmetics["flame_trail"] = true
	end
	if level >= 4 and not profile.unlockedCosmetics["neon_cyber"] then
		profile.unlockedCosmetics["neon_cyber"] = true
	end
	if level >= 5 and not profile.unlockedCosmetics["golden_radiance"] then
		profile.unlockedCosmetics["golden_radiance"] = true
	end
	if level >= 6 and not profile.unlockedCosmetics["gold_championship"] then
		profile.unlockedCosmetics["gold_championship"] = true
	end
	if profile.isVip then
		profile.unlockedCosmetics["obsidian_gold"] = true
		profile.unlockedCosmetics["champions_halo"] = true
	end
end

local function saveProfile(userId: number)
	if isSaving[userId] or not store then return end
	isSaving[userId] = true
	task.spawn(function()
		while pendingSaves[userId] do
			task.wait(1.5)
			pendingSaves[userId] = nil
			local current = cache[userId]
			if not current then break end
			current.savedAt = DateTime.now().UnixTimestampMillis
			local ok, err = pcall(function()
				store:UpdateAsync(tostring(userId), function(old)
					if typeof(old) == "table" and old.savedAt and old.savedAt > current.savedAt then
						return nil
					end
					return current
				end)
			end)
			if not ok then
				pendingSaves[userId] = true
				task.wait(4)
			end
		end
		isSaving[userId] = nil
	end)
end

local function loadProfile(player: Player)
	local userId = player.UserId
	local profile: CareerProfile
	if store then
		local ok, saved = pcall(function()
			return store:GetAsync(tostring(userId))
		end)
		if ok and typeof(saved) == "table" then
			profile = {
				matchesPlayed = saved.matchesPlayed or 0,
				matchesWon = saved.matchesWon or 0,
				trophies = saved.trophies or 0,
				managerXp = saved.managerXp or 0,
				careerEarnings = saved.careerEarnings or 0,
				equippedDice = saved.equippedDice or "ivory_classic",
				equippedAura = saved.equippedAura or "mint_classic",
				unlockedCosmetics = saved.unlockedCosmetics or {["ivory_classic"] = true, ["mint_classic"] = true},
				loginStreak = saved.loginStreak or 1,
				lastLoginTimestamp = saved.lastLoginTimestamp or 0,
				lastDailySpin = saved.lastDailySpin or 0,
				isVip = saved.isVip or false,
				quests = saved.quests or defaultQuests(),
				questsDay = saved.questsDay or 0,
				savedAt = saved.savedAt or 0,
			}
		else
			profile = table.clone(DEFAULT_PROFILE)
		end
	else
		profile = table.clone(DEFAULT_PROFILE)
	end

	refreshDailyQuests(profile)

	-- Check gamepass ownership if configured
	if VIP_GAMEPASS_ID > 0 then
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, VIP_GAMEPASS_ID)
		end)
		if ok and owns then
			profile.isVip = true
		end
	end

	-- Daily streak logic
	local now = os.time()
	local last = profile.lastLoginTimestamp
	if last > 0 then
		local diffHours = (now - last) / 3600
		if diffHours >= 20 and diffHours <= 48 then
			profile.loginStreak += 1
			profile.managerXp += 50 * math.min(profile.loginStreak, 7)
		elseif diffHours > 48 then
			profile.loginStreak = 1
		end
	end
	profile.lastLoginTimestamp = now

	checkUnlocksForLevel(profile)
	cache[userId] = profile
	if player.Parent then
		applyAttributes(player, profile)
	end
end

local CareerStore = {}

function CareerStore.get(userId: number): CareerProfile?
	return cache[userId]
end

function CareerStore.recordMatchResult(userId: number, won: boolean, cashGained: number)
	local profile = cache[userId]
	if not profile then return end
	profile.matchesPlayed += 1
	local baseGain = if won then 220 else 85
	if profile.isVip then
		baseGain = math.floor(baseGain * 1.25)
	end
	if won then
		profile.matchesWon += 1
		profile.trophies += 1
	end
	profile.managerXp += baseGain
	if cashGained > 0 then
		profile.careerEarnings += cashGained
	end
	checkUnlocksForLevel(profile)
	local player = Players:GetPlayerByUserId(userId)
	if player then
		applyAttributes(player, profile)
	end
	pendingSaves[userId] = true
	saveProfile(userId)
end

function CareerStore.equip(player: Player, category: string, itemId: string): boolean
	local profile = cache[player.UserId]
	if not profile then return false end
	if not profile.unlockedCosmetics[itemId] then return false end
	if category == "dice" then
		profile.equippedDice = itemId
	elseif category == "aura" then
		profile.equippedAura = itemId
	else
		return false
	end
	applyAttributes(player, profile)
	pendingSaves[player.UserId] = true
	saveProfile(player.UserId)
	return true
end

function CareerStore.addQuestProgress(userId: number, questType: string, amount: number)
	local profile = cache[userId]
	if not profile then return end
	refreshDailyQuests(profile)
	local quest = profile.quests[questType]
	if quest and not quest.claimed then
		quest.progress = math.clamp(quest.progress + amount, 0, quest.goal)
		local player = Players:GetPlayerByUserId(userId)
		if player then applyAttributes(player, profile) end
		pendingSaves[userId] = true
	end
end

function CareerStore.claimQuest(player: Player, questId: string): boolean
	local profile = cache[player.UserId]
	if not profile then return false end
	refreshDailyQuests(profile)
	local quest = profile.quests[questId]
	if not quest or quest.claimed or quest.progress < quest.goal then return false end
	quest.claimed = true
	local xpEarned = quest.rewardXp
	if profile.isVip then xpEarned = math.floor(xpEarned * 1.25) end
	profile.managerXp += xpEarned
	checkUnlocksForLevel(profile)
	applyAttributes(player, profile)
	pendingSaves[player.UserId] = true
	saveProfile(player.UserId)
	return true
end

function CareerStore.spinWheel(player: Player): (boolean, number, string, number)
	local profile = cache[player.UserId]
	if not profile then return false, 1, "", 0 end
	local now = os.time()
	if profile.lastDailySpin and profile.lastDailySpin > 0 and (now - profile.lastDailySpin) < 20 * 3600 then
		return false, 1, "", 0
	end
	profile.lastDailySpin = now

	local sectorIdx = math.random(1, #WHEEL_SECTORS)
	local sector = WHEEL_SECTORS[sectorIdx]
	if sector.kind == "cash" then
		profile.careerEarnings += sector.amount
	elseif sector.kind == "xp" then
		local gain = sector.amount
		if profile.isVip then gain = math.floor(gain * 1.25) end
		profile.managerXp += gain
		checkUnlocksForLevel(profile)
	elseif sector.kind == "trophy" then
		profile.trophies += sector.amount
	end

	applyAttributes(player, profile)
	pendingSaves[player.UserId] = true
	saveProfile(player.UserId)
	return true, sectorIdx, sector.kind, sector.amount
end

function CareerStore.init(network: Folder)
	local channel = Instance.new("RemoteEvent")
	channel.Name, channel.Parent = "CareerAction", network

	local wheelChannel = Instance.new("RemoteEvent")
	wheelChannel.Name, wheelChannel.Parent = "WheelAction", network

	wheelChannel.OnServerEvent:Connect(function(player)
		local ok, sectorIdx, kind, amount = CareerStore.spinWheel(player)
		wheelChannel:FireClient(player, ok, sectorIdx, kind, amount)
	end)

	local emoteChannel = Instance.new("RemoteEvent")
	emoteChannel.Name, emoteChannel.Parent = "EmoteAction", network
	local lastEmoteTime: {[Player]: number} = {}

	emoteChannel.OnServerEvent:Connect(function(player, emoteId)
		if type(emoteId) ~= "string" then return end
		local now = os.clock()
		local last = lastEmoteTime[player] or 0
		if now - last < 1.4 then return end
		lastEmoteTime[player] = now
		emoteChannel:FireAllClients(player.UserId, emoteId)
	end)

	channel.OnServerEvent:Connect(function(player, action: string, category: string?, itemId: string?)
		if action == "equip" and type(category) == "string" and type(itemId) == "string" then
			CareerStore.equip(player, category, itemId)
		elseif action == "claim_quest" and type(category) == "string" then
			CareerStore.claimQuest(player, category)
		elseif action == "buy_vip" then
			if VIP_GAMEPASS_ID > 0 then
				pcall(function()
					MarketplaceService:PromptGamePassPurchase(player, VIP_GAMEPASS_ID)
				end)
			else
				local profile = cache[player.UserId]
				if profile then
					profile.isVip = true
					checkUnlocksForLevel(profile)
					applyAttributes(player, profile)
					pendingSaves[player.UserId] = true
					saveProfile(player.UserId)
				end
			end
		end
	end)

	Players.PlayerAdded:Connect(loadProfile)
	for _, player in Players:GetPlayers() do
		task.spawn(loadProfile, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local userId = player.UserId
		if pendingSaves[userId] then
			saveProfile(userId)
		end
		cache[userId] = nil
	end)

	if store then
		game:BindToClose(function()
			local deadline = os.clock() + 15
			for userId in pendingSaves do
				saveProfile(userId)
			end
			while next(pendingSaves) and os.clock() < deadline do
				task.wait(0.2)
			end
		end)
	end
end

return CareerStore
