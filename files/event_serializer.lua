-- Serialize the SDL_Event
local function serialize_sdl_event(event)
    return ffi.string(event, ffi.sizeof(event))
end

-- Deserialize the SDL_Event
local function deserialize_sdl_event(serialized_data)
    local event = ffi.new("SDL_Event")
    ffi.copy(event, serialized_data, ffi.sizeof(event))
    return event
end

return {
    serialize = serialize_sdl_event,
    deserialize = deserialize_sdl_event
}