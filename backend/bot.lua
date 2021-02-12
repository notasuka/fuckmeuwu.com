local http = require'coro-http'
local json = require'json'
local fs = require'coro-fs'
local timer = require'timer'
local AsuDB = require'asu-db'
local AsuPerms = require'asu-perms'
local AsuVerification = require'asu-verification'
local AsuCommands = require'asu-commands'
local Discordia = require'Discordia'
local Client = Discordia.Client{
	cacheAllMembers = true,
}

_G["http"] = http
_G["json"] = json
_G["AsuDB"] = AsuDB
_G["AsuPerms"] = AsuPerms
_G["AsuVerification"] = AsuVerification

local Commands = {"Verify","SetRank", "CheckPermission", "AddAsset", "RemoveAsset"}

local Database_Names = {"DiscordVerificationDB", "PermissionsDB", "ValidAssets"}
local Auto_Save_Interval = 1000*30

local AuditChannel

_G["GroupRanks"] = {
	[0]="600287487348441088", --guest
	[230]="599914310801686549", --baby cherry
	[232]="599914310730252298", --blossom
	[233]="599914310504022026", --floweret
	[234]="599914310206095361", --ethereal
	[236]="599914309480611872", --dainty
	[238]="599914309052792843", --daisy
	[239]="599914308889214977", --rosy
	[240]="599914308507271192", --qt
	[241]="599914308008280075", --icon
	[244]="599914307982983229", --designers
	[245]="599914307656089600", --engineer
}

_G["AuthorizationCode"] = os.getenv("ApiKey_Fuckmeuwu")
_G["ApiHost"] = "https://api.fuckmeuwu.com"
_G["HTTPRequest"] = function(method, path, headers, payload)
	return http.request(method, ApiHost..path, headers, payload)
end
_G["AddRole"] = function(User, Role)
	Client:getGuild("560720375101652993"):getMember(User):addRole(Role)
end


local CommandPrefix = ";"

local GetArguments = function(str)
	local t = {}
	local debounce = true
	for argument in str:gmatch("[%w%_]+") do
		if not debounce then
			if argument:find("%a+") then
				table.insert(t,argument)
			elseif argument:find("%d+") then
				table.insert(t,tonumber(argument))
			else
				table.insert(t,argument)
			end
		end
		if table.concat(Commands, " "):lower():find(argument:lower()) and debounce then
			debounce = false
		end
	end

	return t
end

local CommandHandler = function(Cmd, DiscordID)
	if Cmd:find(CommandPrefix)==1 then
		local Table, Command = next(Commands, nil)
		while Table do
			if Cmd:sub(2,#Command+1):lower()==Command:lower() then --Cmd:lower():sub(2,#Command)==Command:lower()
				if not AsuPerms.CheckPermission(AsuDB.GetDatabase("PermissionsDB"), DiscordID, Command) then
					return false, "You do not have permission to run this command."
				else
					return true, Command, GetArguments(Cmd)
				end
			end
			Table, Command = next(Commands, Table)
		end
		return false, "Command does not exist."
	end
	return nil
end

Client:on('ready', function()

    AsuDB.LoadDatabases(Database_Names)
	timer.setInterval(Auto_Save_Interval, function()
		for Index, Name in pairs(Database_Names) do
			AsuDB.SaveDatabases(Name)
		end
	end)

	_G["MemberList"] = function(Guild, User)
		return Client:getGuild(Guild):getMember(User)
	end

	local g = Client:getGuild("560720375101652993")

	AuditChannel = Client:getChannel("766708682112368640")
end)

Client:on('messageCreate', function(Message)
	local Content = Message.content

	local Bool, String, Args = CommandHandler(Content, Message.author.id)

	if Bool==nil then return end

	if Bool then
		local Response, Info = AsuCommands:Run(String, Message.author.id, Args)
		Message.channel:send(Response)
	else
		Message.channel:send(String)
	end
end)




local Audit = function(...)
	local Type, Object, Deleted, UserId = unpack(...)

	local Content = {
		["MessageSent"] = Object["content"],
		["MessageDeleted"] = Object[""],
		["AddReaction"] = Object["emojiURL"]
	}

	Packet = {
		embed = {
			title = "Aduit: "..Type,
	    fields = {
	      {name = "Content", value = Content[Type], inline = false},
	      {name = "Author", value = UserId or Object.author.id, inline = false},
				{name = "Deleted", value = tostring(Deleted), inline = false},
	    },
	    color = Discordia.Color.fromRGB(114, 137, 218).value,
	    timestamp = Discordia.Date():toISO('T', 'Z')
		}
  }


	return Packet
end

Client:on('messageCreate', function(Message)
	if Message.author.id ~= "776727074709962772" then
		local Packet = Audit{'MessageSent', Message, false}

		--Message.channel:send(Packet)
		--Message:delete()

	end
end)

local t = Discordia.Time.fromSeconds(2):toMilliseconds()
local retries = 3
local function getMessageDeletor(message, n)
	timer.sleep(t)

	local g = Client:getGuild("560720375101652993")
	local logs = g:getAuditLogs({type=Discordia.enums.actionType.messageDelete})
	for log in logs:iter() do
		local target = log:getTarget()
		if target and target.id == message.id then
			return log:getUser()
		end
	end

	n = n or 1
	if n < retries then
		return getMessageDeletor(message, n + 1)
	end

end
Client:on('messageDelete', function(Message)

	if not Message.guild then return end

	local creator = getMessageDeletor(Message)

	if creator then
		print(string.format("%s deleted message %s", creator.username, Message.content))
	else
		print(string.format("could not find deletor of message %s", Message.content))
	end

end)

Client:on('reactionAdd', function(reaction, userId)
	--[[print(reaction, userId)
	local formatMessage=string.format("Adding a reaction, eh? Lemme tell ya, <@%s>, in the future eligible staff will be able to use reactions to handle moderation work.", userId)
	reaction.message.channel:send(formatMessage)]]
	--Audit("AddReaction", reaction, false)
	if not reaction.me then
		local Packet = Audit{'AddReaction', reaction, false, userId}

			--reaction.message.channel:send(Packet)

	end
end)


Client:run(os.getenv("Vond_DiscordBot"))
