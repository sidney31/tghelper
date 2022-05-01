--[[

   _____  _      _                      ____  __ 
  / ____|(_)    | |                    |___ \/_ |
 | (___   _   __| | _ __    ___  _   _   __) || |
  \___ \ | | / _` || '_ \  / _ \| | | | |__ < | |
  ____) || || (_| || | | ||  __/| |_| | ___) || |
 |_____/ |_| \__,_||_| |_| \___| \__, ||____/ |_|
                                  __/ |
                                 |___/

]]

script_name('tghelper')

local effil = require("effil")
local encoding = require("encoding")
local dlstatus = require('moonloader').download_status
local sampev = require 'lib.samp.events'
encoding.default = 'CP1251'
u8 = encoding.UTF8
local inicfg = require("inicfg")
local directIni = ('tgconfig.ini')
local ini = inicfg.load(inicfg.load({
    config = {
        id = '0',
        token = '0',
    },
}, directIni))
inicfg.save(ini, directIni)

local chat_id = ini.config.id
local token = ini.config.token

local updateid -- ID последнего сообщения для того чтобы не было флуда

local nick = ''
local az = ''
local hp = ''
local lvl, exp = '', ''
local money = ''
local bank = ''
local deposite = ''
local satiety = ''
local deppd = ''
local alldeppd = ''
local lvlpd, exppd = '', ''

local state = false

update_state = false

local script_vers = 21
local script_vers_text = '1.19.2'

local update_url = 'https://raw.githubusercontent.com/sidney31/tghelper/main/update.ini'
local update_path = getWorkingDirectory()..'/update.ini'

local change_log = 'https://raw.githubusercontent.com/sidney31/tghelper/main/changelog.txt'

local script_url = 'https://github.com/sidney31/tghelper/blob/main/tghelper.luac?raw=true'
local script_path = thisScript().path

function main()
    while not isSampAvailable() do wait(0) end

    getLastUpdate()
    lua_thread.create(get_telegram_updates)

    downloadUrlToFile(update_url, update_path, function(id, status)
        if status == dlstatus.STATUS_ENDDOWNLOADDATA then
            updateIni = inicfg.load(nil, update_path)
            if tonumber(updateIni.info.vers) > script_vers then
                sendTelegramNotification('Доступна новая версия скрипта! - '..updateIni.info.vers_text..'\n/changelog - для просмотра изменений\n/update - для установки обновления')
                update_state = true
            end
            os.remove(update_path)
        end
    end)

    sampRegisterChatCommand('setid', function(num)
        if num ~= nil then
            ini.config.id = num
            inicfg.save(ini, directIni)
            sampAddChatMessage('Id установлен', 0xAAAAAA)
        else
            sampAddChatMessage('Используйте {f80000}"/setid *id*"', 0xAAAAAA)
        end
    end)
    sampRegisterChatCommand('settoken',function(num)
        if num ~= nil then
            ini.config.token = num
            inicfg.save(ini, directIni)
            sampAddChatMessage('Токен установлен', 0xAAAAAA)
        else
            sampAddChatMessage('Используйте {f80000}"/settoken *token*"', 0xAAAAAA)
        end
    end)
    while true do
        wait(0)

        result, id = sampGetPlayerIdByCharHandle(PLAYER_PED)
        if result then
            nick = sampGetPlayerNickname(id)
        end

    end
end

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

function sendTelegramNotification(msg) -- функция для отправки сообщения юзеру
    msg = msg:gsub('{......}', '') --тут типо убираем цвет
    msg = encodeUrl(msg) -- ну тут мы закодируем строку
    async_http_request('https://api.telegram.org/bot' .. token .. '/sendMessage?chat_id=' .. chat_id .. '&text='..msg,'', function(result) end) -- а тут уже отправка
end

function get_telegram_updates() -- функция получения сообщений от юзера
    while not updateid do wait(1) end -- ждем пока не узнаем последний ID
    local runner = requestRunner()
    local reject = function() end
    local args = ''
    while true do
        url = 'https://api.telegram.org/bot'..token..'/getUpdates?chat_id='..chat_id..'&offset=-1' -- создаем ссылку
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
                            if text == '/stats' then
								f_stats()
                            elseif text == '/meatbag' then
                                sampSendChat('/meatbag')
                            elseif text == '/changelog' then
                                sendTelegramNotification(change_log)
                            elseif text == '/checkupd' then
                                if tonumber(updateIni.info.vers) > script_vers then
                                    sendTelegramNotification('Доступна новая версия.')
                                else
                                    sendTelegramNotification('У вас установлена акуальная версия.')
                                end
                            elseif text == '/update' then
                                if update_state then
                                    downloadUrlToFile(script_url, script_path, function(id, status)
                                        if status == dlstatus.STATUS_ENDDOWNLOADDATA then
                                            sendTelegramNotification('Обновление успешно установлено!')
                                            thisScript():reload()
                                        end
                                    end)
                                end
                            elseif text == '/cmds' then
                                sendTelegramNotification('Список команд:\n/stats - вывод основных пунктов из статистики;'..
                                '\n/meatbag - использование мешка с мясом;\n/setid - установить id тг-аккаунта;'..
                                '\n/settoken - установить токен тг-бота;\n/checkupd- проверка на наличие обновлений;'..
                                '\n/changelog - просмотр изменений;\n/cmds - обзор команд;')
                            else
                                sendTelegramNotification('Неизвестная команда, используйте "/cmds" для помощи')
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
            sendTelegramNotification('Статистика '..nick..':\n\n\t'..az..'\n\tЗдоровье: '..hp..'\n\tГолод: '..satiety..'\n\tУровень: '..lvl..'\n\tУважение: '..exp..'\n\tДеньги: '..separator(money)..'\n\tДеньги в банке: '..separator(bank)..'\n\tДеньги на депозите: '..separator(deposite))
            wait(200)
            state = false
	end)
end


function getLastUpdate() -- тут мы получаем последний ID сообщения, если же у вас в коде будет настройка токена и chat_id, вызовите эту функцию для того чтоб получить последнее сообщение
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
                    updateid = 1 -- тут зададим значение 1, если таблица будет пустая
                end
            end
        end
    end)
end

function sampev.onShowDialog(dialogId, style, title, button1, button2, text)
    if dialogId == 235 and state then
        for line in text:gmatch("[^\n]+") do
            if line:find('Текущее состояние счета: (.*) ') then
                az = line:match('(%d+)')
                az = 'Донат счёт: '..az..' az'
            end
            if line:find('Здоровье: %{......%}%[(%d+/%d+)%]') then
                hp = line:match('Здоровье: %{......%}%[(%d+/%d+)%]')
            end
            if line:find('Уровень: %{......%}%[(%d+)%]') then
                lvl = line:match('Уровень: %{......%}%[(%d+)%]')
            end
            if line:find('Уважение: %{......%}%[(%d+/%d+)%]') then
                exp = line:match('Уважение: %{......%}%[(%d+/%d+)%]')
            end
            if line:find('Деньги: %{......%}%[($%d+)%]') then
                money = line:match('Деньги: %{......%}%[($%d+)%]')
            end
            if line:find('Деньги в банке: %{......%}%[($%d+)%]') then
                bank = line:match('Деньги в банке: %{......%}%[($%d+)%]')
            end
            if line:find('Деньги на депозите: %{......%}%[($%d+)%]') then
                deposite = line:match('Деньги на депозите: %{......%}%[($%d+)%]')
            end
        end
		return false
    end
    if dialogId == 0 and state then
        if text:find('Ваша сытость: {......}(%d+/%d+).') then
            satiety = text:match('Ваша сытость: {......}(%d+/%d+).')
        end
		return false
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

function sampev.onDisplayGameText(style, time, text)
    if text:find('You are hungry!') then
        sampSendChat('/meatbag')
        sendTelegramNotification('Ваш персонаж был голоден и съел кусок мяса с мешка.')
    end
end

function sampev.onServerMessage(color, text)
    if text:find('Добро пожаловать на Arizona Role Play!') then
        sendTelegramNotification('Вы присоеденились к серверу!')
    end

    if text:find('Банковский чек')then
        if text:find('Депозит в банке: $(%d+)') then
            deppd = text:match('Депозит в банке: $(%d+)')
        end
        if text:find('Текущая сумма не депозите: $(%d+)') then
            alldeppd = text:match('Текущая сумма не депозите: $(%d+)')
        end
        if text:find('В данный момент у вас (%d+)-й уровень и (%d+/%d+) респектов') then
            lvlpd, exppd = text:match('В данный момент у вас (%d+)-й уровень и (%d+/%d+) респектов')
        end
        sendTelegramNotification('\t\t\t===PayDay===\nДепозит: '..separator(deppd)..'\nТекущая сумма на депозите: '..separator(alldeppd)..'\nУровень: '..lvlpd..', уважение: '..exppd)
    end
end