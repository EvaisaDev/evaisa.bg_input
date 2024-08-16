SDL2.SDL_SetHintWithPriority("SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS", "1", 2);

--[[
    Capture SDL2 events, and pass them to the bg_input client
]]

local minhook = dofile("mods/evaisa.bg_input/lib/minhook.lua")("mods/evaisa.bg_input/bin")
minhook.initialize()

local event_callback = function(event) end

local init = function(callback)
    event_callback = callback
end


local SDL_PollEvent_hook
SDL_PollEvent_hook = minhook.create_hook(SDL2.SDL_PollEvent, function(event)
    local success, result = pcall(function()
        if event ~= nil then
            event_callback(event)
        end
        return SDL_PollEvent_hook.original(event)
    end)

    if success then
        return result
    end

    print("Input error: " .. result)
    return 0
end)

minhook.enable(SDL2.SDL_PollEvent)

return {
    init = init
}