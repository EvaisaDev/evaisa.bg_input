local event = ffi.new("SDL_Event")

-- Serialize the SDL_Event
local function serialize_sdl_event(this_event)
    return ffi.string(this_event, ffi.sizeof(event))
end

-- Deserialize the SDL_Event
local function deserialize_sdl_event(serialized_data)
    ffi.copy(event, serialized_data, ffi.sizeof(event))
    return event
end

return {
    event =  event,
    event_size =  ffi.sizeof(event),
    serialize = serialize_sdl_event,
    deserialize = deserialize_sdl_event
}
