-- Run through sponsor_pass_test.py, which embeds the production modules.
local function signal()
	return {Connect = function(self, callback) self.fire = callback end}
end

local function passId()
	-- INSERT SPONSOR CONFIG
end
local accounts = {}
local inventory = {}
local marketplace = {PromptGamePassPurchaseFinished = signal()}
function marketplace:UserOwnsGamePassAsync(id, pass)
	assert(pass == passId())
	if inventory[id] == "error" then error("Marketplace unavailable") end
	return inventory[id] == true
end
local players = {PlayerAdded = signal(), PlayerRemoving = signal(), connected = {}}
function players:GetPlayers() return {} end
function players:GetPlayerByUserId(id) return self.connected[id] end
local store = {}
function store:GetAsync(id) return accounts[id] end
function store:UpdateAsync(id, update) accounts[id] = update(accounts[id]) end

local services = {
	Players = players,
	MarketplaceService = marketplace,
	ReplicatedStorage = {League = {SponsorPass = {}}},
	RunService = {IsStudio = function() return false end},
	HttpService = {JSONEncode = function() return "{}" end},
	DataStoreService = {GetDataStore = function() return store end},
}
local game = {GameId = 10777507892, GetService = function(_, name) return services[name] end, BindToClose = function() end}
local require = function(module) assert(module == services.ReplicatedStorage.League.SponsorPass); return passId() end
local DateTime = {now = function() return {UnixTimestampMillis = 10} end}
local scheduled = {}
local task = {wait = function() end, spawn = function(work) table.insert(scheduled, work) end}
local function flush()
	while #scheduled > 0 do table.remove(scheduled, 1)() end
end
local remotes = {}
local Instance = {new = function()
	local r = {OnServerEvent = signal()}
	table.insert(remotes, r)
	return r
end}
local function server()
	-- INSERT CAREER STORE
end
local career = server()
career.init({})
local function join(id)
	local player = {UserId = id, Parent = players, attrs = {}}
	function player:SetAttribute(k, v) self.attrs[k] = v end
	players.connected[id] = player
	players.PlayerAdded.fire(player)
	return player
end
local function leave(player)
	players.PlayerRemoving.fire(player)
	players.connected[player.UserId] = nil
	player.Parent = nil
	flush()
end
local function check(player, owned)
	local profile = assert(career.get(player.UserId))
	assert(player.attrs.CareerIsVip == owned and profile.isVip == owned)
	assert((profile.unlockedCosmetics.obsidian_gold == true) == owned)
	assert((profile.unlockedCosmetics.champions_halo == true) == owned)
end

accounts["12"] = {isVip = true, unlockedCosmetics = {obsidian_gold = true, champions_halo = true},
	equippedAura = "champions_halo", equippedDice = "obsidian_gold"}
local p = join(12)
check(p, false)
assert(p.attrs.CareerEquippedAura == "mint_classic" and p.attrs.CareerEquippedDice == "ivory_classic")
assert(p.attrs.FirstCompletedMatch == nil)
career.recordMatchResult(12, false, 40, 8)
assert(p.attrs.FirstCompletedMatch == 8 and p.attrs.CareerMatches == 1)
marketplace.PromptGamePassPurchaseFinished.fire(p, passId(), false)
check(p, false)
leave(p)
p = join(12)
check(p, false)
assert(p.attrs.FirstCompletedMatch == nil and p.attrs.CareerMatches == 1)
career.recordMatchResult(12, false, 20, 9)
assert(p.attrs.FirstCompletedMatch == nil)
marketplace.PromptGamePassPurchaseFinished.fire(p, passId()+1, true)
check(p, false)
inventory[12] = true
marketplace.PromptGamePassPurchaseFinished.fire(p, passId(), true)
marketplace.PromptGamePassPurchaseFinished.fire(p, passId(), true)
check(p, true)
assert(career.equip(p, "dice", "obsidian_gold"))
leave(p)
career = server()
career.init({})
p = join(12)
check(p, true)
assert(p.attrs.CareerEquippedDice == "obsidian_gold")
local other = join(14)
check(other, false)
inventory[16] = "error"
local unknown = join(16)
check(unknown, false)
assert(not unknown.attrs.CareerVipVerified)
print("Sponsor pass passed: legacy migration, first final only, cancel and rejoin, wrong ID, confirmed purchase, fresh-server rejoin, separate inventories, unavailable marketplace.")
