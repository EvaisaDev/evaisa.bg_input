package.path = package.path .. ";./mods/evaisa.bg_input/lib/?.lua"
package.path = package.path .. ";./mods/evaisa.bg_input/lib/?/init.lua"
package.cpath = package.cpath .. ";./mods/evaisa.bg_input/bin/?.dll"
package.cpath = package.cpath .. ";./mods/evaisa.bg_input/bin/?.exe"

local function load(modulename)
	local errmsg = ""
	for path in string.gmatch(package.path, "([^;]+)") do
		local filename = string.gsub(path, "%?", modulename)
		local file = io.open(filename, "rb")
		if file then
			-- Compile and return the module
			return assert(loadstring(assert(file:read("*a")), filename))
		end
		errmsg = errmsg .. "\n\tno file '" .. filename .. "' (checked with custom loader)"
	end
	return errmsg
end


dofile_once("mods/evaisa.bg_input/lib/NoitaPatcher/load.lua")
local np = require("noitapatcher")

ffi = require("ffi")
SDL2 = dofile("mods/evaisa.bg_input/lib/sdl2_ffi.lua")

event_serializer = dofile("mods/evaisa.bg_input/files/event_serializer.lua")

dofile("data/scripts/lib/coroutines.lua")
local control_fix = dofile("mods/evaisa.bg_input/files/control_fix.lua")
local client = dofile("mods/evaisa.bg_input/files/client.lua")
local server = dofile("mods/evaisa.bg_input/files/server.lua")

local is_server = false
dead = false

client_index = nil
local positions_restored = false

local kill_after_frames = -1

local window

function OnWorldInitialized()
    window = SDL2.SDL_GL_GetCurrentWindow()
end

function window_get_pos(w)
    local coord = ffi.new("int[2]")
    SDL2.SDL_GetWindowPosition(w, coord, coord+1)
    return coord[0], coord[1]
end

function window_set_pos(w, x, y)
    SDL2.SDL_SetWindowPosition(w, x, y)
end

function close_window()
    print("killing client")
    kill_after_frames = 60
end

local old_print = print

function print(...)
    if(client_index==nil)then
        old_print(...)
        GamePrint(...)
        return
    end
    -- if we are the server, print to the server file, otherwise print to the client file
    local file_path = "multinoita_instance_"..tostring(client_index or "server")..".txt"

    local file = io.open(file_path, "a")
    if file then
        local str = ""
        for i, v in ipairs({...}) do
            str = str .. tostring(v) .. "\t"
        end
        file:write(str .. "\n")
        file:close()
    end
end


function SaveWindowPos()
    if(window == nil)then
        return
    end
    if(client_index == nil)then
        return
    end
    local x, y = window_get_pos(window)
    local file_path = "mods/evaisa.bg_input/instance_"..tostring(client_index).."_position.txt"

    local file = io.open(file_path, "w")
    if file then
        file:write(tostring(x) .. "\t" .. tostring(y))
        file:close()
    end

end

function LoadWindowPos()
    positions_restored = true
    if(window == nil)then
        return
    end
    if(client_index == nil)then
        return
    end
    local file_path = "mods/evaisa.bg_input/instance_"..tostring(client_index).."_position.txt"

    local file = io.open(file_path, "r")
    if file then
        local x, y = file:read("*n", "*n")
        window_set_pos(window, x, y)
        file:close()
    end
end


function OnMagicNumbersAndWorldSeedInitialized()

    client.start_client(function()
        if client.is_connected() then
            is_server = false
        else
            server.start_server()
            is_server = true
            client_index = 1
        end
    end)

end

function handlePositions()

    if(not positions_restored and window and client_index ~= nil)then
        LoadWindowPos()
    end

    if(positions_restored and window and client_index ~= nil and GameGetFrameNum() % 60 == 0)then
        SaveWindowPos()
    end
end

local initialized_sdlhooks = false

local clients_spawned = false

function OnWorldPreUpdate()
    if(kill_after_frames > 0)then
        kill_after_frames = kill_after_frames - 1
        if(kill_after_frames == 0)then
            -- push a quit event
            local event = ffi.new("SDL_Event")
            event.type = 0x100
            SDL2.SDL_PushEvent(event)
        end
    end

    wake_up_waiting_threads(1)
    if is_server then
        server.main_server()

        if(not initialized_sdlhooks)then
            control_fix.init(function(event)
                server.handle_event(event)
            end)
            initialized_sdlhooks = true
        end

        if not clients_spawned then
            clients_spawned = true
            local client_count = math.ceil((tonumber(ModSettingGet("evaisa.bg_input.client_count") or 2) - 1))

            for i = 1, client_count do
                local save_folder = os.getenv('APPDATA'):gsub("\\Roaming", "") .. "\\LocalLow\\Nolla_Games_Noita\\save0"..tostring(i)

                -- remove folder if it exists
                os.execute("rmdir /s /q \""..save_folder.."\"")

                local gamemode = np.GetGameModeNr()

                print("Starting client with save slot "..tostring(i).." gamemode: "..tostring(gamemode))

                os.execute("start Noita.exe -no_logo_splashes -gamemode "..tostring(gamemode).." -save_slot "..tostring(i))
            end
        end

    elseif client.is_connected() then
        client.main_client()

        -- This creates an infinite feedback loop, and would introduce latency anyway
        -- if(not initialized_sdlhooks)then
        --     control_fix.init(function(event)
        --         client.handle_event(event)
        --     end)
        --     initialized_sdlhooks = true
        -- end
    end

    handlePositions()
end



function OnPausePreUpdate()
    if(kill_after_frames > 0)then
        kill_after_frames = kill_after_frames - 1
        if(kill_after_frames == 0)then
            -- push a quit event
            local event = ffi.new("SDL_Event")
            event.type = 0x100
            SDL2.SDL_PushEvent(event)
        end
    end

    wake_up_waiting_threads(1)
    if is_server then
        server.main_server(true)
    elseif client.is_connected() then
        client.main_client(true)
    end

    handlePositions()
end


function OnPlayerDied()
    dead = true
    if is_server then
        server.broadcast_message("died")
    elseif client.is_connected() then
        client.send_message_to_server("died")
    end
end

function OnPlayerSpawned()
    -- write to `mods/evaisa.bg_input/force_restarter.txt` with a random value to force restart the clients
    local file = io.open("mods/evaisa.bg_input/force_restarter.txt", "w")
    if file then
        file:write(tostring(math.random(1, 10000000)))
        file:close()
    end
end
