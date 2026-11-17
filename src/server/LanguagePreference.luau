--!strict
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

return function(network: Folder)
	local channel = Instance.new("RemoteEvent")
	channel.Name, channel.Parent = "Language", network
	local store = if game.GameId > 0 and not game:GetService("RunService"):IsStudio()
		then DataStoreService:GetDataStore("TableLanguageV1") else nil
	local pending = {}
	local running = {}
	local function save(id: number)
		if running[id] or not store then return end
		running[id] = true
		task.spawn(function()
			while pending[id] do
				task.wait(2)
				local choice = pending[id]
				local ok = pcall(function()
					store:UpdateAsync(tostring(id), function(old)
						if typeof(old) == "table" and old.at > choice.at then return nil end
						return choice
					end)
				end)
				if ok and pending[id] == choice then pending[id] = nil end
				if not ok then task.wait(4) end
			end
			running[id] = nil
		end)
	end
	local function load(player: Player)
		if not store then return end
		local ok, row = pcall(function() return store:GetAsync(tostring(player.UserId)) end)
		if ok and typeof(row) == "table" and (row.lang == "en" or row.lang == "ru")
			and player.Parent and not player:GetAttribute("TableLanguage") then
			player:SetAttribute("TableLanguage", row.lang)
		end
	end
	channel.OnServerEvent:Connect(function(player, lang)
		if lang ~= "en" and lang ~= "ru" then return end
		if player:GetAttribute("TableLanguage") == lang then return end
		player:SetAttribute("TableLanguage", lang)
		if store then
			pending[player.UserId] = {lang=lang, at=DateTime.now().UnixTimestampMillis}
			save(player.UserId)
		end
	end)
	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do task.spawn(load, player) end
	if store then
		game:BindToClose(function()
			local deadline = os.clock()+24
			while next(pending) and os.clock()<deadline do task.wait(.2) end
		end)
	end
end
