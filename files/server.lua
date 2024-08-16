local pollnet = dofile("mods/evaisa.bg_input/lib/pollnet.lua")
local settings = dofile("mods/evaisa.bg_input/files/settings.lua")

local host_url = settings.ip .. ":" .. tostring(settings.port)
local socket = nil
local ws_clients = {}

local strfind = string.find
local tinsert = table.insert
local strsub = string.sub
local function strsplit(text, delimiter)
    local list = {}
    local pos = 1
    if strfind("", delimiter, 1) then -- this would result in endless loops
        error("Delimiter matches empty string!")
    end
    while 1 do
        local first, last = strfind(text, delimiter, pos)
        if first then -- found?
            tinsert(list, strsub(text, pos, first-1))
            pos = last+1
        else
            tinsert(list, strsub(text, pos))
            break
        end
    end
    return list
end

local function close_client(client)
    if client.sock then
        client.sock:close()
        client.sock = nil
    end
    ws_clients[client.addr] = nil
end

local function client_send(client, msg)
    if client.sock then
        client.stat_out = (client.stat_out or 0) + 1
        client.sock:send(msg)
    else
        client:close()
    end
end

local function on_new_client(sock, addr)
    print("New client: " .. addr)
    if ws_clients[addr] then ws_clients[addr].sock:close() end
    local new_client = {addr = addr, sock = sock, authorized = false, close = close_client, send = client_send, stat_in=0, stat_out=0}
    ws_clients[addr] = new_client

    -- send index to client
    local client_count = 1
    for _, _ in pairs(ws_clients) do client_count = client_count + 1 end

    new_client:send("index " .. tostring(client_count))
end

local function start_server()
    print("Starting WS server on " .. host_url)
    socket = pollnet.listen_ws(host_url)
    socket:on_connection(on_new_client)
    print("Started WS server on " .. host_url)
end

local function is_localhost(addr)
    local parts = strsplit(addr, ":")
    return parts[1] == "127.0.0.1" -- IPV6?
end

local function check_authorization(client, msg)
    if not is_localhost(client.addr) then
        client.sock:send("SYS> UNAUTHORIZED: NOT LOCALHOST!")
        client.sock:close()
        client.sock = nil
        return
    end

    client.authorized = true
    client.sock:send("SYS> AUTHORIZED")
    print("Accepted console connection: " .. client.addr)
    return true
end

local function close_console_connections()
    for _, sock in pairs(ws_clients) do sock:close() end
    ws_clients = {}
    if socket then socket:close() end
    socket = nil
end

local function broadcast_message(msg)
    for _, client in pairs(ws_clients) do
        client:send(msg)
    end
end

local function _handle_client_message(client, msg, paused)
    if not client.authorized then
        if not check_authorization(client, msg) then
            return
        end
    end

    if(msg == "died" and not dead)then
        local players = EntityGetWithTag("player_unit")
        for _, player in ipairs(players) do
            local x, y = EntityGetTransform(player)
            EntityInflictDamage(player, 1000000, "DAMAGE_HOLY", "Died in other session!", "BLOOD_EXPLOSION", 0, 0, player, x, y, 0)
        end

        local polymorphed_players = EntityGetWithTag("polymorphed_player")
        for _, player in ipairs(polymorphed_players) do
            local x, y = EntityGetTransform(player)
            EntityInflictDamage(player, 1000000, "DAMAGE_HOLY", "Died in other session!", "BLOOD_EXPLOSION", 0, 0, player, x, y, 0)
        end
        --broadcast_message("died")

        -- send to all except the sender
        for _, other_client in pairs(ws_clients) do
            if other_client.addr ~= client.addr then
                other_client:send("died")
            end
        end

        --EntityKill(GameGetWorldStateEntity())
        GamePrint("Other client died!")
        dead = true
        -- close this window
        close_window()
    
    end
end

local function main_server(paused)
    if not socket then return end

    local happy, msg = socket:poll()
    if not happy then
        print("Main WS server closed?")
        close_console_connections()
        return
    end

    for addr, client in pairs(ws_clients) do
        if client.sock then
            local happy, msg = client.sock:poll()
            if not happy then
                print("Sock error: " .. tostring(msg))
                client.sock:close()
                client.sock = nil
                ws_clients[addr] = nil
            elseif msg then
                print("Received: " .. tostring(msg))
                _handle_client_message(client, msg, paused)
            end
        else
            ws_clients[addr] = nil
        end
    end    
end


return {
    start_server = start_server,
    main_server = main_server,
    broadcast_message = broadcast_message,
}
