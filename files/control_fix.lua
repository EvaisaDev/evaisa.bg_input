ffi = require("ffi")
ffi.cdef([[
    int SDL_SetHintWithPriority(const char*, const char*, int);
    ]])
SDL2 = ffi.load("SDL2")
SDL2.SDL_SetHintWithPriority("SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS", "1", 2);

multi_kbm = ffi.load("mods/evaisa.bg_input/files/multi_kbm/multi_kbm.dll")
