local effil = require("effil")
local encoding = require("encoding")
local sampev = require 'lib.samp.events'
encoding.default = 'CP1251'
u8 = encoding.UTF8

local chat_id = '976221897'
local token = '5216765399:AAEM4XCWaNWtj70kkhgri0aKIkS1_h0KMD0'

local updateid -- ID ���������� ��������� ��� ���� ����� �� ���� �����

local nick = ''
local az = ''
local hp = ''
local lvl = ''
local exp = ''
local money = ''
local bank = ''
local deposite = ''
local satiety = ''

local state = false

function threadHandle(runner, url, args, resolve, reject)
    local t = runner(url, args)
    local r = t:get(0)
    while not r do
        r = t:get(0)
        wait(0)
    end
    local status = t:status()
    if status == 'completed' then
        local ok, result = r[1], r[2]
        if ok then resolve(result) else reject(result) end
    elseif err then
        reject(err)
    elseif status == 'canceled' then
        reject(status)
    end
    t:cancel(0)
end

function requestRunner()
    return effil.thread(function(u, a)
        local https = require 'ssl.https'
        local ok, result = pcall(https.request, u, a)
        if ok then
            return {true, result}
        else
            return {false, result}
        end
    end)
end

function async_http_request(url, args, resolve, reject)
    local runner = requestRunner()
    if not reject then reject = function() end end
    lua_thread.create(function()
        threadHandle(runner, url, args, resolve, reject)
    end)
end

function encodeUrl(str)
    str = str:gsub(' ', '%+')
    str = str:gsub('\n', '%%0A')
    return u8:encode(str, 'CP1251')
end

function sendTelegramNotification(msg) -- ������� ��� �������� ��������� �����
    msg = msg:gsub('{......}', '') --��� ���� ������� ����
    msg = encodeUrl(msg) -- �� ��� �� ���������� ������
    async_http_request('https://api.telegram.org/bot' .. token .. '/sendMessage?chat_id=' .. chat_id .. '&text='..msg,'', function(result) end) -- � ��� ��� ��������
end

function get_telegram_updates() -- ������� ��������� ��������� �� �����
    while not updateid do wait(1) end -- ���� ���� �� ������ ��������� ID
    local runner = requestRunner()
    local reject = function() end
    local args = ''
    while true do
        url = 'https://api.telegram.org/bot'..token..'/getUpdates?chat_id='..chat_id..'&offset=-1' -- ������� ������
        threadHandle(runner, url, args, processing_telegram_messages, reject)
        wait(0)
    end
end

function processing_telegram_messages(result) -- #CMDS
    if result then
        local proc_table = decodeJson(result)
        if proc_table.ok then
            if #proc_table.result > 0 then
                local res_table = proc_table.result[1]
                if res_table then
                    if res_table.update_id ~= updateid then
                        updateid = res_table.update_id
                        local message_from_user = res_table.message.text 
                        if message_from_user then
                                local text = u8:decode(message_from_user)
                            if text == 'stats' then
								f_stats()
                            else
                                sendTelegramNotification('����������� �������!')
                            end
                        end
                    end
                end
            end
        end
    end
end

function f_stats()
    lua_thread.create(function ()
        state = true
        sampSendChat('/stats')
            wait(500)
            sampSendChat('/satiety')
            wait(500)
            sendTelegramNotification('���������� '..nick..':\n\n\t'..az..'\n\t��������: '..hp..'\n\t�����: '..satiety..'\n\t�������: '..lvl..'\n\t��������: '..exp..'\n\t������: '..separator(money)..'\n\t������ � �����: '..separator(bank)..'\n\t������ �� ��������: '..separator(deposite))
            wait(200)
            state = false
	end)
end
function getLastUpdate() -- ��� �� �������� ��������� ID ���������, ���� �� � ��� � ���� ����� ��������� ������ � chat_id, �������� ��� ������� ��� ���� ���� �������� ��������� ���������
    async_http_request('https://api.telegram.org/bot'..token..'/getUpdates?chat_id='..chat_id..'&offset=-1','',function(result)
        if result then
            local proc_table = decodeJson(result)
            if proc_table.ok then
                if #proc_table.result > 0 then
                    local res_table = proc_table.result[1]
                    if res_table then
                        updateid = res_table.update_id
                    end
                else
                    updateid = 1 -- ��� ������� �������� 1, ���� ������� ����� ������
                end
            end
        end
    end)
end

function main()
    while not isSampAvailable() do wait(0) end
    getLastUpdate()
    lua_thread.create(get_telegram_updates)
    autoupdate("https://raw.githubusercontent.com/sidney31/tghelper/main/tghelper.lua", '['..string.upper(thisScript().name)..']: ', "https://raw.githubusercontent.com/sidney31/tghelper/main/tghelper.lua")
    while true do
        wait(0)
        result, id = sampGetPlayerIdByCharHandle(PLAYER_PED)
        nick = sampGetPlayerNickname(id)
    end
end

function sampev.onShowDialog(dialogId, style, title, button1, button2, text)
    if dialogId == 235 and state then
        for line in text:gmatch("[^\n]+") do
            if line:find('������� ��������� �����: (.*) ') then
                az = line:match('(%d+)')
                az = '����� ����: '..az..' az'
            end
            if line:find('��������: %{......%}%[(%d+/%d+)%]') then
                hp = line:match('��������: %{......%}%[(%d+/%d+)%]')
            end
            if line:find('�������: %{......%}%[(%d+)%]') then
                lvl = line:match('�������: %{......%}%[(%d+)%]')
            end
            if line:find('��������: %{......%}%[(%d+/%d+)%]') then
                exp = line:match('��������: %{......%}%[(%d+/%d+)%]')
            end
            if line:find('������: %{......%}%[($%d+)%]') then
                money = line:match('������: %{......%}%[($%d+)%]')
            end
            if line:find('������ � �����: %{......%}%[($%d+)%]') then
                bank = line:match('������ � �����: %{......%}%[($%d+)%]')
            end
            if line:find('������ �� ��������: %{......%}%[($%d+)%]') then
                deposite = line:match('������ �� ��������: %{......%}%[($%d+)%]')
            end
        end
		return false
    end
    if dialogId == 0 and state then
        if text:find('���� �������: {......}(%d+/%d+).') then
            satiety = text:match('���� �������: {......}(%d+/%d+).')
        end
		return false
    end
end

function onScriptTerminate(script, state)
    if script == thisScript() then
        sendTelegramNotification('script terminated')
    end
end

function sampev.onServerMessage(color, text)
    if text:find('%[������%] {......}������������ ����� � ����� ����� ��� � 30 �����! �������� (%d+):%d+') then
        time = text:match('%[������%] {......}������������ ����� � ����� ����� ��� � 30 �����! �������� (%d+):%d+')
        sendTelegramNotification('��� �������� ����� ����� '..time+2 ..' �����.')
		print('��� �������� ����� ����� '..time+2 ..' �����.')
        lua_thread.create(function()
            wait(tonumber(time)*60000)
            sampSendChat('/meatbag')
        end)
    end
    if text==(nick..' ������(�) �� ����� �� ������ ����� ���� � ������(�)') then
        sendTelegramNotification('��� �������� ����.')
		print('��� �������� ����.')
        math.randomseed(os.clock())
        local cd = math.random(33, 45)
        sendTelegramNotification('��������� ���� ���� ����� '..cd..' �����.')
		print('��������� ���� ���� ����� '..cd..' �����.')
        lua_thread.create(function()
            wait(cd*60000)
        end)
        sampSendChat('/meatbag')
    end
    if text:find('����� ���������� �� Arizona Role Play!') then
        sendTelegramNotification('�� �������������� � �������!')
		print('�� �������������� � �������!')
    end
end

function comma_value(n)
	local left,num,right = string.match(n,'^([^%d]*%d)(%d*)(.-)$')
	return left..(num:reverse():gsub('(%d%d%d)','%1,'):reverse())..right
end

function separator(text)
	if text:find("$") then
	    for S in string.gmatch(text, "%$%d+") do
	    	local replace = comma_value(S)
	    	text = string.gsub(text, S, replace)
	    end
	    for S in string.gmatch(text, "%d+%$") do
	    	S = string.sub(S, 0, #S-1)
	    	local replace = comma_value(S)
	    	text = string.gsub(text, S, replace)
	    end
	end
	return text
end
--
--     _   _   _ _____ ___  _   _ ____  ____    _  _____ _____   ______   __   ___  ____  _     _  __
--    / \ | | | |_   _/ _ \| | | |  _ \|  _ \  / \|_   _| ____| | __ ) \ / /  / _ \|  _ \| |   | |/ /
--   / _ \| | | | | || | | | | | | |_) | | | |/ _ \ | | |  _|   |  _ \\ V /  | | | | |_) | |   | ' /
--  / ___ \ |_| | | || |_| | |_| |  __/| |_| / ___ \| | | |___  | |_) || |   | |_| |  _ <| |___| . \
-- /_/   \_\___/  |_| \___/ \___/|_|   |____/_/   \_\_| |_____| |____/ |_|    \__\_\_| \_\_____|_|\_\                                                                                                                                                                                                                  
--
-- Author: http://qrlk.me/samp
--
function autoupdate(json_url, prefix, url)
    local dlstatus = require('moonloader').download_status
    local json = getWorkingDirectory() .. '\\'..thisScript().name..'-version.json'
    if doesFileExist(json) then os.remove(json) end
    downloadUrlToFile(json_url, json,
      function(id, status, p1, p2)
        if status == dlstatus.STATUSEX_ENDDOWNLOAD then
          if doesFileExist(json) then
            local f = io.open(json, 'r')
            if f then
              local info = decodeJson(f:read('*a'))
              updatelink = info.updateurl
              updateversion = info.latest
              f:close()
              os.remove(json)
              if updateversion ~= thisScript().version then
                lua_thread.create(function(prefix)
                  local dlstatus = require('moonloader').download_status
                  local color = -1
                  sampAddChatMessage((prefix..'���������� ����������. ������� ���������� c '..thisScript().version..' �� '..updateversion), color)
                  wait(250)
                  downloadUrlToFile(updatelink, thisScript().path,
                    function(id3, status1, p13, p23)
                      if status1 == dlstatus.STATUS_DOWNLOADINGDATA then
                        print(string.format('��������� %d �� %d.', p13, p23))
                      elseif status1 == dlstatus.STATUS_ENDDOWNLOADDATA then
                        print('�������� ���������� ���������.')
                        sampAddChatMessage((prefix..'���������� ���������!'), color)
                        goupdatestatus = true
                        lua_thread.create(function() wait(500) thisScript():reload() end)
                      end
                      if status1 == dlstatus.STATUSEX_ENDDOWNLOAD then
                        if goupdatestatus == nil then
                          sampAddChatMessage((prefix..'���������� ������ ��������. �������� ���������� ������..'), color)
                          update = false
                        end
                      end
                    end
                  )
                  end, prefix
                )
              else
                update = false
                print('v'..thisScript().version..': ���������� �� ���������.')
              end
            end
          else
            print('v'..thisScript().version..': �� ���� ��������� ����������. ��������� ��� ��������� �������������� �� '..url)
            update = false
          end
        end
      end
    )
    while update ~= false do wait(100) end
  end