local pollnet = dofile("mods/evaisa.bg_input/lib/pollnet.lua")
local settings = dofile("mods/evaisa.bg_input/files/settings.lua")

local host_url = settings.ip .. ":" .. tostring(settings.port)
local client_socket = nil

local function start_client(callback)
    client_socket = pollnet.open_ws("ws://"..host_url)

    -- poll connection to server
    local happy, msg = client_socket:poll()

    -- poll until not happy or status is open
    async(function()
        while happy and client_socket:status() ~= "open" do
            happy, msg = client_socket:poll()
            print("Happy? " .. tostring(happy))
            print(tostring(client_socket))
            wait(0)
        end

        print("Client socket status: " .. client_socket:status())

        if happy and client_socket:status() == "open" then
            print(client_socket:status())
            print("Connected to server as client.")
        else
            print("Failed to connect to server.")
        end
        callback()

    end)



end

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

local function _handle_server_message(msg)
    if(msg == "died" and not dead)then
        dead = true
        close_window()
        GamePrint("Other client died!")
    end

    -- if msg starts with index
    if string.sub(msg, 1, 5) == "index" then
        -- split by space
        local parts = strsplit(msg, " ")
        -- set client index
        client_index = tonumber(parts[2])
    end

    print("Server message: " .. msg)
end

local function send_message_to_server(msg)
    if client_socket then
        client_socket:send(msg)
    else
        print("Not connected to server.")
    end
end

local function main_client(paused)
    if not client_socket then return end
    local happy, msg = client_socket:poll()
    if not happy then
        -- check status
        print("Client socket status: " .. client_socket:status())

        print("Client socket closed or error: " .. tostring(msg))
        client_socket = nil

        return
    elseif msg then
        _handle_server_message(msg)
    end
end

local function is_connected()
    return client_socket ~= nil and (client_socket:status() == "open" or client_socket:status() == "opening")
end

return {
    start_client = start_client,
    main_client = main_client,
    send_message_to_server = send_message_to_server,
    is_connected = is_connected,
}
