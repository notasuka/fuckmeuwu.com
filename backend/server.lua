local http = require'coro-http'
local json = require'json'
local fs = require'coro-fs'
local timer = require'timer'
local AsuDB = require'asu-db'
local roblox = require("rbx.lua");
local client = roblox.client();

local RBXKey = os.getenv("RBXKey")
local AuthorizationCode = os.getenv("ApiKey_Fuckmeuwu")

local ValidAssets

local Database_Names = {"PlayerAssetDB","ValidAssets"}
local Auto_Save_Interval = 1000*30
local Queue = {}

local Ranks = {
	--{RankID = 230, AssetsNeeded = 0},
	{RankID = 240, AssetsNeeded = 31},
	{RankID = 239, AssetsNeeded = 26},
	{RankID = 238, AssetsNeeded = 21},
	{RankID = 236, AssetsNeeded = 16},
	{RankID = 234, AssetsNeeded = 11},
	{RankID = 233, AssetsNeeded = 4},
	{RankID = 232, AssetsNeeded = 1}
}

--PlayerData
--[[
UserId:["OwnedAssets": 2, "Donated": 1000]
]]

function CheckQueue(userId)
	local list = table.concat(Queue, " ")
	if list:find(userId) then
		return true
	end
	return false
end

function RemoveFromQueue(userId)
	local Index, User = next(Queue, nil)
	while Index do
		if User == userId then
			table.remove(Queue, Index)
			return true
		end
		Index, User = next(Queue, Index)
	end
	return false
end

function GetData(req)
	local success, data = pcall(function()
		print(req.body)
		return json.decode(req.body)
	end)
	if not success then
		print('no req body')
	else
		return data
	end
end

local function SetRank(Group, UserId, Rank)
	return client.group.rankUser(Group, UserId, Rank)
end

function buildOwnedAssets(data)
	table.insert(Queue, data.player)

	coroutine.wrap(function()

		local Assets = 0
		table.foreach(ValidAssets, function(index, url)
			local assetId = string.match(url, "%d+")


			local res, body = pcall(function()
				return http.request("GET", "https://api.roblox.com/ownership/hasasset?userId="..data.player.."&assetId="..assetId)
			end)
			if res.code == 200 then
				if body == "true" then
					Assets=Assets+1
				end
			else
				print(res.code, body)
			end

		end)

		AsuDB.SetData("PlayerAssetDB", data.player, {OwnedAssets = Assets, Donated = data.donated})

		print("Player ("..data.player..")", AsuDB.GetData("PlayerAssetDB", data.player, "OwnedAssets"))
		RemoveFromQueue(data.player)

		CheckRank = function()
			local UnlockedRanks = {}
			local TableIndex, Table = next(Ranks, nil)
			if Assets ~= 0 then
				while TableIndex do

					if data.rank >= 240 then
						print'rank maxed out'
						return
					else
						if Assets >= Table.AssetsNeeded then
							table.insert(UnlockedRanks, Table.RankID)
						end
					end

					TableIndex, Table = next(Ranks, TableIndex)
				end

				if data.rank ~= UnlockedRanks[1] then
					local success, response = SetRank(3147431, data.player, UnlockedRanks[1])
					if success then
						print("Ranked player", data.player, "to", UnlockedRanks[1])
					end
				else
					print'already that rank or rank maxed out'
				end
			end
		end
		CheckRank()


		return coroutine.yield()
	end)()

end

function deleteAdvertisements(group)
	coroutine.wrap(function()

		local wall = client.group.getWall(group)
		if not wall then return end
	  local page = wall.getPage()

	  for i,v in pairs(page) do
	    local result = v.body:match("https://www.roblox.com/groups/(%d+)")
	    if result and result ~= "5166541" then --puffery id
	      client.group.deleteWallPost(group,v.id)
	      print'deleted advertisement'
	    end
	  end

		return coroutine.yield()
	end)()
end



client:on("ready",function()
	local success, response = client.user.setStatus("I'm a bot coded by iAsuka. >w<")
	AsuDB.LoadDatabases(Database_Names)
	timer.setInterval(Auto_Save_Interval, function()
		for Index, Database_Name in pairs(Database_Names) do
			if Database_Name=="ValidAssets" then
				AsuDB.LoadDatabases({"ValidAssets"})
			else
				AsuDB.SaveDatabases(Database_Name)
			end
		end
	end)
	ValidAssets = AsuDB.GetDatabase("ValidAssets")
	timer.setInterval(15000, function()
		deleteAdvertisements(3147431)
	end)
  print("rbx client ready");
end)


client:run(RBXKey)



local static = require('weblit-static')
require('weblit-app')

  .use(require('weblit-logger'))
  .use(require('weblit-auto-headers'))

  .bind({
  host = "0.0.0.0",
  port = 80
  })

  .bind({
  host = "0.0.0.0",
  port = 443,
  tls = {
    cert = module:load("origincert.pem"),
    key = module:load("originpriv.pem")
  }
  })

--				Webpage
.route({
	method = "GET",
	path = "/",
	host = "fuckmeuwu.com"
}, static("articles/index"))

.route({
	method = "GET",
	path = "/stream",
	host = "fuckmeuwu.com"
}, function(req,res,go)
	res.code=200
	res.body = fs.readFile("./articles/stream/stream.html")
	res.headers["Content-Type"] = "text/html"
end)

.route({
	method = "GET",
	path = "/",
	host = "www.fuckmeuwu.com"
}, function(req,res,go)
	res.code = 301
	res.headers.Location = "https://fuckmeuwu.com/"
end)



--						API
.route({
	method = "POST",
	path = "/RankPlayer",
	host = "api.fuckmeuwu.com"
}, function(req, res, go)
	local data = GetData(req)
	if data.AuthorizationCode ==  AuthorizationCode then
		local success, response = SetRank(data.group, data.player, data.rank)
		if success then
			res.code = 200
			res.body = json.encode{"Success", "Player has been successfully ranked."}
		else
			res.code = 200
			res.body = json.encode{"Failed", response}
		end
	else
		res.code = 401
		res.body = json.encode{"Not Authorized"}
	end
end)

.route({
	method = "POST",
	path = "/CheckPlayerData",
	host="api.fuckmeuwu.com"
}, function(req, res, go)
	local data = GetData(req)
	if data.AuthorizationCode == AuthorizationCode then
		if AsuDB.GetData("PlayerAssetDB", data.player) ~= nil and not CheckQueue(data.player) then
			res.code = 200
			res.body = json.encode(AsuDB.GetData("PlayerAssetDB", data.player))
		else
			res.code = 200
			res.body = json.encode{"Failed", "Player data does not exist or they are already inside the queue!"}
		end
	else
		res.code = 401
		res.body = json.encode{"Not Authorized"}
	end
end)

.route({
	method = "POST",
	path = "/UpdatePlayerData",
	host="api.fuckmeuwu.com"
}, function(req, res, go)
	local data = GetData(req)
	if data.AuthorizationCode == AuthorizationCode and not CheckQueue(data.player) then
		if AsuDB.GetData("PlayerAssetDB", data.player) ~= nil then
			buildOwnedAssets(data)
			print'db exists'

			res.code = 200
			res.body = json.encode{"Success", "Player's data will be updated in about 5 minutes."}
		else
			AsuDB.AddData("PlayerAssetDB", data.player, {OwnedAssets = nil,Donated = nil})
			print'db created'
			buildOwnedAssets(data)

			res.code = 200
			res.body = json.encode{"Success", "Player's data will be updated in about 5 minutes."}
		end
	else
		if CheckQueue(data.player) then
			res.code = 200
			res.body = json.encode{"Player already in queue"}
		else
			res.code = 401
			res.body = json.encode{"Not Authorized"}
		end
	end
end)

.route({
	method="GET",
	path="/PlayerInGroup",
	host="api.fuckmeuwu.com"
}, function(req,res,go)
	return go()
end)

--[[.route({
	method="POST",
	path="/TestPost",
	host="api.fuckmeuwu.com"
}, function(req,res,go)
	local data = GetData(req)
	--if req.headers.host == "" then return go() end
	--[[if data.AuthorizationCode==AuthorizationCode then
		UpdatePlayerData("17900059")
		res.code = 200
		res.body = json.encode{"Success", "Data has been sent."}
	else
		res.code = 401
		res.body = json.encode{"Not Authorized"}
	end
	print(req.body)
	res.code = 200
	res.body = json.encode{"Success", "Data has been sent."}
end)]]

.start()
