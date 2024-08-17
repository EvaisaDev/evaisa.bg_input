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
        return
    end

    -- if msg starts with index
    if string.sub(msg, 1, 5) == "index" then
        -- split by space
        local parts = strsplit(msg, " ")
        -- set client index
        client_index = tonumber(parts[2])
        return
    end

    local event = event_serializer.deserialize(msg)

    if event ~= nil and is_valid_event(event) then
        -- push SDL2 event
        local success = SDL2.SDL_PushEvent(event)
        if success == 0 then
            print("Failed to push event: " .. SDL2.SDL_GetError())
        end
    end
end

local function send_message_to_server(msg)
    if client_socket then
        client_socket:send(msg)
    else
        print("Not connected to server.")
    end
end

local function send_message_to_server_binary(msg)
    if client_socket then
        client_socket:send_binary(msg)
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

local function handle_event(event)
    -- if event is one of
    --[[
        SDL_KEYDOWN = 0x300,
        SDL_KEYUP,
        SDL_TEXTEDITING,
        SDL_TEXTINPUT,
        SDL_KEYMAPCHANGED,
        SDL_MOUSEMOTION = 0x400,
        SDL_MOUSEBUTTONDOWN,
        SDL_MOUSEBUTTONUP,
        SDL_MOUSEWHEEL,
    ]]

    if is_valid_event(event) then
        local msg = event_serializer.serialize(event)
        send_message_to_server_binary(msg)
    end
end

return {
    start_client = start_client,
    main_client = main_client,
    send_message_to_server = send_message_to_server,
    is_connected = is_connected,
    handle_event = handle_event
}
