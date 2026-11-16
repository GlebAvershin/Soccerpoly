local players = game:GetService("Players")
local me = players.LocalPlayer
local net = game:GetService("ReplicatedStorage"):WaitForChild("WorldDraft")
local report, intent, pushes = net:WaitForChild("StudioReport"), net.Intent, net.Snapshot
local hud = me:WaitForChild("PlayerGui"):WaitForChild("WorldDraftHUD", 8)
local last
local expected = script:GetAttribute("ExpectedPlayers") or 1
local verifyArt = script:GetAttribute("VerifyBlenderArt") == true

local function blenderCount(container)
	local count = 0
	for _, part in container:GetDescendants() do
		if part:IsA("MeshPart") and part:GetAttribute("BlenderMesh") then count += 1 end
	end
	return count
end
pushes.OnClientEvent:Connect(function(snapshot) last = snapshot end)
local function await(predicate, label, limit)
	local deadline = os.clock() + (limit or (if expected == 6 then 30 else 10))
	repeat
		if last and predicate(last) then return last end
		task.wait(0.04)
	until os.clock() > deadline
	local s = last and last.match
	local detail = if s then string.format("round=%d seat=%d phase=%s move=%d version=%d", s.round, s.active, s.phase, s.motion.serial, last.version)
		elseif last then "lobby=" .. #last.lobby else "no snapshot"
	error("Waiting for " .. label .. " (" .. detail .. ")")
end
local function button(name)
	local found = hud:FindFirstChild(name, true)
	assert(found and found:IsA("GuiButton"), "Missing HUD button " .. name)
	-- Studio can leave a background window without a drawable viewport while its client stays connected.
	if expected == 6 and workspace.CurrentCamera.ViewportSize.X < 2 then return found end
	assert(found.AbsoluteSize.X > 40 and found.AbsoluteSize.Y >= 40, "Button lacks touch target: " .. name)
	local canvas = hud:FindFirstChild("Viewport")
	local a, b = found.AbsolutePosition, found.AbsolutePosition + found.AbsoluteSize
	local lo, hi = canvas.AbsolutePosition, canvas.AbsolutePosition + canvas.AbsoluteSize
	assert(a.X >= lo.X and a.Y >= lo.Y and b.X <= hi.X + 1 and b.Y <= hi.Y + 1, "Action outside safe area: " .. name)
	return found
end
local function seatOf(s)
	for _, seat in s.seats do if seat.id == me.UserId then return seat end end
	error("Local participant missing")
end
local ok, failure = pcall(function()
	assert(hud, "HUD never loaded")
	local device = script:GetAttribute("Device")
	if device then
		local size = workspace.CurrentCamera.ViewportSize
		local ready = os.clock() + 5
		while size.X <= 1 and os.clock() < ready do
			task.wait()
			size = workspace.CurrentCamera.ViewportSize
		end
		assert((size.Y > size.X) == (device == "portrait"), "Device orientation failed: " .. tostring(size))
		assert(size.X < 700, "Device was not emulated: " .. tostring(size))
	end
	task.spawn(function()
		while not last or #last.lobby < expected do
			intent:FireServer("sync")
			task.wait(0.5)
		end
	end)
	intent:FireServer("sync")
	local lobby = await(function(data) return data.match == nil and #data.lobby == expected end, "full test lobby", if expected == 6 then 82 else 42)
	task.wait(0.18)
	button("StartSeason")
	local stage = workspace:WaitForChild("WorldDraftArena")
	local board = stage:WaitForChild("Board")
	local center = stage:WaitForChild("Continental Cup stadium")
	assert(center:FindFirstChild("Grandstands") and center:FindFirstChild("Pitch and goals"), "Incomplete stadium")
	local overlays = hud.Viewport:WaitForChild("BoardLabels")
	local catalog = require(game:GetService("ReplicatedStorage").League.Board)
	local tileCount, indices = 0, {}
	local camera = workspace.CurrentCamera
	local cameraDeadline = os.clock() + 4
	while expected ~= 6 and camera.CameraType ~= Enum.CameraType.Scriptable and os.clock() < cameraDeadline do
		task.wait(.05)
		camera = workspace.CurrentCamera
	end
	local drawable = camera.CameraType == Enum.CameraType.Scriptable
	assert(drawable or expected == 6, "Board camera not active")
	for _, part in board:GetDescendants() do
		if part.Name == "Printed tile" then
			local index = part:GetAttribute("BoardIndex")
			assert(index and not indices[index], "Missing or duplicate board index")
			tileCount += 1
			indices[index] = true
			if drawable then
				local _, visible = camera:WorldToViewportPoint(part.Position + Vector3.yAxis * .11)
				assert(visible, "Board camera loses cell " .. index .. " at " .. tostring(camera.ViewportSize))
			end
			local tile = catalog.tiles[index]
			local label = assert(overlays:FindFirstChild("Cell" .. index))
			assert(label.Title:IsA("TextLabel") and label.Title:GetAttribute("FullName") ~= "", "Unlabelled board cell")
			if drawable then assert(label.Visible and label.Title.Text ~= "", "Label never projected") end
			if tile.price > 0 then
				assert(label.Price.Text == tostring(tile.price) .. " CR", "Wrong club price on board cell " .. index)
			end
		end
	end
	assert(tileCount == 24, "Incomplete board")
	if expected == 1 and not device then
		local virtual = game:GetService("UserInputService"):CreateVirtualInput()
		if virtual then
			local tile
			for _, candidate in board:GetDescendants() do
				if candidate:GetAttribute("BoardIndex") == 8 then tile = candidate break end
			end
			local screen = camera:WorldToViewportPoint(tile.Position + Vector3.yAxis * .11)
			local function click(point)
				virtual:SendMouseButton(point, Enum.UserInputType.MouseButton1, true, 0)
				task.wait(.05)
				virtual:SendMouseButton(point, Enum.UserInputType.MouseButton1, false, 0)
				task.wait(.12)
			end
			click(Vector2.new(screen.X, screen.Y))
			local details = hud:FindFirstChild("CellDetails", true)
			assert(details, "Tap did not open cell details")
			local close = hud:FindFirstChild("Close", true)
			click(close.AbsolutePosition + close.AbsoluteSize * .5 + game:GetService("GuiService"):GetGuiInset())
			assert(not hud.Viewport.DismissBackdrop.Visible, "Cell details did not close")
		end
	end
	local figurePreview = assert(hud:FindFirstChild("FootballerPreview", true), "No figure preview")
	assert(figurePreview:FindFirstChild("Left leg", true) and figurePreview:FindFirstChild("Right arm", true), "Figure rig missing")
	if verifyArt then
		local limit = os.clock() + 9
		while (blenderCount(stage) < 55 or blenderCount(figurePreview) < 11) and os.clock() < limit do task.wait(.10) end
		assert(blenderCount(stage) == 55, "Incomplete Blender stadium")
		assert(blenderCount(figurePreview) == 11, "Incomplete Blender figure")
		local audio = game:GetService("SoundService")
		local music = audio:WaitForChild("Footbolapolia Music", 4)
		local score = music and music:FindFirstChildOfClass("Sound")
		local audioLimit = os.clock() + 9
		while score and not score.IsLoaded and os.clock() < audioLimit do task.wait(.15) end
		assert(score and score.TimeLength > 0 and score.IsPlaying, "Lobby score is unavailable")
	end
	report:FireServer("READY")
	if lobby.host == me.UserId then
		local waitUntil = os.clock() + 24
		while report:GetAttribute("ReadyCount") < expected and os.clock() < waitUntil do task.wait(.08) end
		assert(report:GetAttribute("ReadyCount") == expected, "Clients not ready for kickoff")
		if expected == 1 then
			intent:FireServer("figure", lobby.version, 4)
			lobby = await(function(data) return data.lobby[1].figure == 4 end, "figure update")
		end
		task.wait(0.7)
		intent:FireServer("start", lobby.version)
	end
	local begun = await(function(data) return data.match ~= nil end, "kickoff", 14)
	local playStarted = workspace:GetServerTimeNow()
	local seats = math.max(expected, 3)
	assert(#begun.match.seats == seats)
	assert(begun.match.seats[1].id == begun.host)
	local figures = {}
	for slot, seat in begun.match.seats do
		assert(seat.bot == (slot > expected), "Unexpected human/bot seat")
		assert(not figures[seat.figure], "Duplicate figure")
		figures[seat.figure] = true
	end
	assert(begun.match.decks == nil, "Private card decks replicated")
	local own = seatOf(begun.match)
	assert(own.position == 1 and own.cash == 700)
	if begun.host == me.UserId then
		for _, action in {"RouteShort", "RouteLong"} do
			local route = button(action)
			assert(route.Destination.Text ~= "" and route.Stake.Text ~= "", "Missing route information")
		end
		local shownBy = os.clock() + (if expected == 6 then 0 else 4)
		local viewport = hud.Viewport
		while not (viewport.RouteBadge1.Visible and viewport.RouteBadge2.Visible) and os.clock() < shownBy do task.wait(.05) end
		assert(expected == 6 or (viewport.RouteBadge1.Visible and viewport.RouteBadge2.Visible), "Route markers not shown")
		assert((hud:FindFirstChild("CoachHint", true) ~= nil) == (begun.variant == "coach"), "First route hint does not match assignment")
		task.wait(0.28)
		intent:FireServer("long", begun.version - 1)
		task.wait(0.20)
		assert(last.version == begun.version and seatOf(last.match).position == 1, "Stale action mutated match")
		intent:FireServer("short", begun.version)
		local offer = await(function(data) return data.match.phase == "offer" end, "contract")
		assert(seatOf(offer.match).position == 2)
		button("SignClub")
		task.wait(0.88)
		intent:FireServer("skip", offer.version)
	end
	local opened = await(function(data) return data.auction ~= nil end, "opening auction")
	assert(opened.auction.tile == 2 and opened.auction.replies == nil and opened.match.auction == nil)
	button("AuctionMinimum")
	button("AuctionListPrice")
	button("AuctionPass")
	task.wait(math.max(.02, opened.availableAt - workspace:GetServerTimeNow() + .08))
	local token = opened.auction.token
	if begun.host == me.UserId then
		intent:FireServer("bid", token - 1, 2)
		intent:FireServer("bid", token, 99999)
		if expected ~= 6 then
			local eligible = await(function(data)
				if not data.auction or data.auction.token ~= token then return false end
				for i = 2, #data.match.seats do if not data.auction.responded[i] then return false end end
				return true
			end, "other bids")
			assert(not eligible.auction.responded[1] and eligible.version > opened.version, "Stale or malformed bid accepted")
			assert(seatOf(eligible.match).cash == 700 and eligible.match.clubs[2].owner == 0, "Bid settled before the auction closed")
		end
		intent:FireServer("bid", token, 2)
		intent:FireServer("bid", token, 2)
	else
		intent:FireServer("bid", token, if expected == 6 then 0 else 1)
	end
	local signed = await(function(data) return data.match.clubs[2].owner == begun.host end, "auction result")
	assert(not signed.auction and signed.match.seats[1].cash == 700 - catalog.tiles[2].price)

	-- Round two exercises both directions. Other seats verify that terms stay private.
	local seller, buyer = begun.host, begun.match.seats[2].id
	local party = me.UserId == seller or me.UserId == buyer
	if expected >= 2 then
		if me.UserId == buyer then
			task.wait(math.max(.02, signed.availableAt - workspace:GetServerTimeNow() + .20))
			intent:FireServer("long", signed.version)
			local contract = await(function(data) return data.match.phase == "offer" and seatOf(data.match).position == 5 end, "second club")
			task.wait(math.max(.02, contract.availableAt - workspace:GetServerTimeNow() + .20))
			intent:FireServer("buy", contract.version)
		elseif me.UserId == seller then
			local turn = await(function(data) return data.match.round == 2 and data.match.active == 1 end, "seller's round two")
			task.wait(math.max(.02, turn.availableAt - workspace:GetServerTimeNow() + .20))
			button("ClubDeals")
			button("FigurePower")
			intent:FireServer("ability", turn.version)
			local powered = await(function(data) return seatOf(data.match).ability == "spent" end, "through pass")
			assert(powered.deadline == turn.deadline and powered.availableAt == turn.availableAt and powered.match.short == 2)
			assert(seatOf(powered.match).cash == seatOf(turn.match).cash - catalog.abilityAmounts.route)
			intent:FireServer("trade", powered.version, {buyer = buyer, offered = 2, requested = 5, option = 0})
		else
			local turn = await(function(data)
				return data.match.round == 1 and data.match.seats[data.match.active].id == me.UserId
			end, "opening visit")
			task.wait(math.max(.02, turn.availableAt - workspace:GetServerTimeNow() + .20))
			intent:FireServer("short", turn.version)
		end
		local offered = await(function(data)
			local s = data.match
			return s.round == 2 and s.active == 1 and s.tradeUsed
		end, "swap offered")
		if party then
			assert(offered.trade and offered.trade.expires <= offered.deadline and offered.trade.terms.requested == 5)
			assert(offered.trade.expires - workspace:GetServerTimeNow() <= catalog.tradeSeconds)
			if me.UserId == seller then
				intent:FireServer("tradeAccept", offered.trade.token)
			else
				button("TradeAccept")
				button("TradeDecline")
				intent:FireServer("tradeAccept", offered.trade.token - 1)
				task.wait(.60)
				assert(last.trade and last.match.clubs[2].owner == seller and last.match.clubs[5].owner == buyer)
				intent:FireServer("tradeAccept", offered.trade.token)
				intent:FireServer("tradeAccept", offered.trade.token)
			end
		else
			assert(not offered.trade and not hud:FindFirstChild("TradeAccept", true))
			intent:FireServer("tradeAccept", offered.version)
		end
		assert(offered.match.trade == nil)
		local swapped = await(function(data) return data.match.last.kind == "tradeSwap" end, "swap confirmed")
		assert(swapped.match.clubs[2].owner == buyer and swapped.match.clubs[5].owner == seller and not swapped.trade)
		assert(swapped.deadline == offered.deadline and swapped.availableAt == offered.availableAt)
		assert(swapped.match.seats[1].cash == offered.match.seats[1].cash and swapped.match.seats[2].cash == offered.match.seats[2].cash)
	end

	local directSale, soloPower, expired, exercisedPower = false, false, false, false
	local expiryBefore, expiryAfter = nil, nil
	local steps, visitedCup, visitedBench, sold = 0, false, false, false
	while last.match.phase ~= "final" do
		local data = await(function(next)
			local s = next.match
			return s and (s.phase == "final" or next.auction or (next.trade and next.trade.terms.buyer == me.UserId) or s.seats[s.active].id == me.UserId)
		end, "next personal turn", if expected == 6 then 34 else 12)
		if data.match.phase == "final" then break end
		if data.auction then
			local token = data.auction.token
			task.wait(math.max(.02, data.availableAt - workspace:GetServerTimeNow() + .07))
			intent:FireServer("bid", token, 0)
			await(function(newer) return not newer.auction or newer.auction.token ~= token end, "auction closed", 12)
			continue
		end
		if expected >= 2 and party and not directSale and data.match.round == 2 then
			if data.trade and data.trade.terms.buyer == me.UserId then
				button("TradeAccept")
				intent:FireServer("tradeAccept", data.trade.token)
			elseif me.UserId ~= begun.host and data.match.phase == "move" then
				task.wait(math.max(.02, data.availableAt - workspace:GetServerTimeNow() + .08))
				intent:FireServer("trade", data.version, {buyer = begun.host, offered = 2, requested = 0, option = 1})
				data = await(function(next) return next.trade ~= nil end, "direct sale offer")
			end
			if data.trade and data.trade.terms.requested == 0 then
				local receipt = await(function(next) return next.match.last.kind == "tradeSale" end, "direct sale")
				assert(receipt.deadline == data.deadline and receipt.availableAt == data.availableAt)
				local price = math.floor(catalog.tiles[2].price * catalog.tradeRates[1] / 100)
				assert(receipt.match.clubs[2].owner == begun.host and receipt.match.last.amount == price)
				assert(receipt.match.seats[1].cash == data.match.seats[1].cash - price)
				assert(receipt.match.seats[2].cash == data.match.seats[2].cash + price)
				directSale = true
				continue
			end
		end
		if expected >= 2 and party and not expired and data.match.round == 3 then
			if me.UserId == seller and data.match.phase == "move" then
				task.wait(math.max(.02, data.availableAt - workspace:GetServerTimeNow() + .08))
				intent:FireServer("trade", data.version, {buyer = buyer, offered = 2, requested = 0, option = 2})
				data = await(function(next) return next.trade ~= nil end, "unanswered offer")
			end
			if data.trade then
				local pending = data.trade
				local closed = await(function(next) return not next.trade end, "trade timed out", catalog.tradeSeconds + 3)
				assert(closed.deadline == data.deadline and closed.availableAt == data.availableAt)
				assert(closed.match.motion.serial == data.match.motion.serial and closed.match.clubs[2].owner == seller)
				assert(workspace:GetServerTimeNow() >= pending.expires)
				expiryBefore, expiryAfter = pending.expires, workspace:GetServerTimeNow()
				if me.UserId == buyer then
					intent:FireServer("tradeAccept", pending.token)
				else
					task.wait(.45)
					assert(last.version == closed.version, "Expired trade changed game state")
					assert(last.match.seats[1].cash == data.match.seats[1].cash and last.match.seats[2].cash == data.match.seats[2].cash)
				end
				expired = true
				continue
			end
		end
		if expected == 6 and not exercisedPower and data.match.phase == "move" then
			local before = seatOf(data.match)
			if before.ability == "ready" then
				task.wait(math.max(.02, data.availableAt - workspace:GetServerTimeNow() + .08))
				button("FigurePower")
				intent:FireServer("ability", data.version)
				local powered = await(function(next) return seatOf(next.match).ability ~= "ready" end, "figure activated")
				assert(powered.deadline == data.deadline and powered.availableAt == data.availableAt)
				exercisedPower = true
				continue
			end
			exercisedPower = true
		end
		if expected == 1 and not soloPower and data.match.phase == "move" then
			task.wait(math.max(.04, data.availableAt - workspace:GetServerTimeNow() + .07))
			local control = button("FigurePower")
			if not device then
				local virtual = game:GetService("UserInputService"):CreateVirtualInput()
				local inset = game:GetService("GuiService"):GetGuiInset()
				local function click(target)
					local point = target.AbsolutePosition + target.AbsoluteSize * .5 + inset
					virtual:SendMouseButton(point, Enum.UserInputType.MouseButton1, true, 0)
					task.wait(.05)
					virtual:SendMouseButton(point, Enum.UserInputType.MouseButton1, false, 0)
					task.wait(.16)
				end
				click(control)
				click(button("ActivatePower"))
			else
				intent:FireServer("ability", data.version)
			end
			local armed = await(function(next) return seatOf(next.match).ability == "armed" end, "keeper power")
			assert(armed.deadline == data.deadline and armed.availableAt == data.availableAt)
			soloPower = true
			continue
		end
		if expected == 1 and not sold and data.match.phase == "move" then
			task.wait(math.max(.04, data.availableAt - workspace:GetServerTimeNow() + .07))
			intent:FireServer("sell", data.version, 2)
			local receipt = await(function(next)
				return next.match and next.match.soldThisTurn and next.match.last.kind == "sold"
			end, "bank sale")
			assert(receipt.match.clubs[2].owner == 0 and receipt.deadline == data.deadline)
			assert(seatOf(receipt.match).cash == seatOf(data.match).cash + 96)
			sold = true
			continue
		end
		steps += 1
		assert(steps < 27)
		local verb
		if data.match.phase == "bench" then
			button("BenchShort")
			button("BenchRelease")
			visitedBench = true
			verb = if seatOf(data.match).cash >= catalog.benchFee then "release" else "short"
		elseif data.match.phase == "matchday" then
			button("Shoot")
			button("SafePlay")
			visitedCup = true
			verb = "shoot"
		else
			verb = if data.match.phase == "move" then "long" elseif data.match.phase == "offer" then "buy" else "upgrade"
		end
		task.wait(math.max(0.04, data.availableAt - workspace:GetServerTimeNow() + 0.07))
		intent:FireServer(verb, data.version)
		await(function(newer) return newer.version > data.version end, "action accepted")
	end
	local final = last
	assert(expected == 1 or not party or directSale, "Direct sale not exercised")
	if expected >= 2 then
		assert(not party or expired, "Trade expiration not exercised")
		if final.host == me.UserId then
			report:FireServer(string.format("METRIC %d clients, %d moves, %.1fs from kickoff, trade closed +%.2fs after offer expiry",
				expected, final.match.motion.serial, workspace:GetServerTimeNow() - playStarted, expiryAfter - expiryBefore))
		end
	end
	if expected == 6 then assert(exercisedPower and seatOf(final.match).ability ~= "ready") end
	assert(#final.match.standings == seats and final.match.round == 8)
	assert(final.match.motion.serial == 8 * seats)
	assert(final.match.standings[1].score >= final.match.standings[seats].score)
	button("BackToLobby")
	assert(hud:FindFirstChild("Rank1", true))
	if final.host == me.UserId then
		assert(visitedBench and visitedCup and seatOf(final.match).trophies > 0, "Host did not exercise bench and cup gameplay")
		local cup = workspace.LocalTablePieces.Markers:FindFirstChild("Continental Cup")
		assert(cup, "Cup visualization missing")
		if verifyArt then assert(cup:IsA("MeshPart") and cup:GetAttribute("BlenderMesh"), "Missing Blender cup") end
		task.wait(if expected == 6 then 1.20 else 0.25)
		intent:FireServer("lobby", final.version)
	end
	await(function(data) return data.match == nil end, "replay lobby")
	button("StartSeason")
end)
report:FireServer(if ok then "PASS" else "FAIL " .. tostring(failure))
