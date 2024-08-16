#define WIN32_LEAN_AND_MEAN

#include <cstdint>
#include <windows.h>
#include <SDL.h>
#include "scancodes_windows.h"
#include <MinHook.h>
#include <stdio.h>

typedef unsigned int uint;
typedef int16_t int16;
typedef int32_t int32;
typedef uint8_t uint8;
typedef uint32_t uint32;
typedef uint64_t uint64;

#define len(x) (sizeof(x)/sizeof((x)[0]))

#define SDL_WindowID int
#define SDL_Surface void
#define SDL_DisplayID int
#define SDL_HDROutputProperties int
#define SDL_PropertiesID int
#define SDL_WindowData void

struct SDL_Window
{
    SDL_WindowID id;
    char *title;
    SDL_Surface *icon;
    int x, y;
    int w, h;
    int min_w, min_h;
    int max_w, max_h;
    float min_aspect;
    float max_aspect;
    int last_pixel_w, last_pixel_h;
    SDL_WindowFlags flags;
    SDL_WindowFlags pending_flags;
    float display_scale;
    SDL_bool external_graphics_context;
    SDL_bool fullscreen_exclusive;  /* The window is currently fullscreen exclusive */
    SDL_DisplayID last_fullscreen_exclusive_display;  /* The last fullscreen_exclusive display */
    SDL_DisplayID last_displayID;

    /* Stored position and size for the window in the non-fullscreen state,
     * including when the window is maximized or tiled.
     *
     * This is the size and position to which the window should return when
     * leaving the fullscreen state.
     */
    SDL_Rect windowed;

    /* Stored position and size for the window in the base 'floating' state;
     * when not fullscreen, nor in a state such as maximized or tiled.
     *
     * This is the size and position to which the window should return when
     * it's maximized and SDL_RestoreWindow() is called.
     */
    SDL_Rect floating;

    /* Toggle for drivers to indicate that the current window state is tiled,
     * and sizes set non-programmatically shouldn't be cached.
     */
    SDL_bool tiled;

    /* Whether or not the initial position was defined */
    SDL_bool undefined_x;
    SDL_bool undefined_y;

    SDL_DisplayMode requested_fullscreen_mode;
    SDL_DisplayMode current_fullscreen_mode;
    SDL_HDROutputProperties HDR;

    float opacity;

    SDL_Surface *surface;
    SDL_bool surface_valid;

    SDL_bool is_repositioning; /* Set during an SDL_SetWindowPosition() call. */
    SDL_bool is_hiding;
    SDL_bool restore_on_show; /* Child was hidden recursively by the parent, restore when shown. */
    SDL_bool is_destroying;
    SDL_bool is_dropping; /* drag/drop in progress, expecting SDL_SendDropComplete(). */

    int safe_inset_left;
    int safe_inset_right;
    int safe_inset_top;
    int safe_inset_bottom;
    SDL_Rect safe_rect;

    SDL_PropertiesID text_input_props;
    SDL_bool text_input_active;
    SDL_Rect text_input_rect;
    int text_input_cursor;

    SDL_Rect mouse_rect;

    SDL_HitTest hit_test;
    void *hit_test_data;

    SDL_PropertiesID props;

    SDL_WindowData *internal;

    SDL_Window *prev;
    SDL_Window *next;

    SDL_Window *parent;
    SDL_Window *first_child;
    SDL_Window *prev_sibling;
    SDL_Window *next_sibling;
};

typedef int (*SDL_PollEvent_f)(SDL_Event* event);
SDL_PollEvent_f original_SDL_PollEvent = nullptr;

int SDL_PollEvent_hook(SDL_Event* event)
{
    while(original_SDL_PollEvent(event)) {
        switch(event->type) {
            case SDL_MOUSEWHEEL: {
                if(event->wheel.which == 69) return 1;
            } break;
            case SDL_MOUSEBUTTONDOWN:
            case SDL_MOUSEBUTTONUP: {
                if(event->button.which == 69) return 1;
            } break;
            case SDL_KEYDOWN:
            case SDL_KEYUP: {
                if(event->key.padding2 == 69) return 1;
            } break;
            case SDL_MOUSEMOTION: {
                if(event->motion.which == 69) return 1;
            } break;
            default:
                return 1;
        }
    }

    return 0;
}

LRESULT CALLBACK llkeyboard_hook(int nCode, WPARAM wParam, LPARAM lParam)
{
    if(nCode < 0)
        return CallNextHookEx(0, nCode, wParam, lParam);

    KBDLLHOOKSTRUCT *keyboard = (KBDLLHOOKSTRUCT *) lParam;

    SDL_Scancode scancode = windows_scancode_table[keyboard->scanCode];

    if(scancode == SDL_SCANCODE_UNKNOWN)
        return CallNextHookEx(0, nCode, wParam, lParam);

    SDL_Event event = {};
    event.key.keysym.scancode = scancode;
    event.key.keysym.sym = SDL_SCANCODE_TO_KEYCODE(scancode);
    event.key.padding2 = 69; //used to filter normal events

    switch(wParam) {
        case WM_KEYDOWN: {
            event.type = SDL_KEYDOWN;
        } break;
        case WM_KEYUP: {
            event.type = SDL_KEYUP;
        } break;
        default:
            return CallNextHookEx(0, nCode, wParam, lParam);
    }

    SDL_PushEvent(&event);

    return CallNextHookEx(0, nCode, wParam, lParam);
}

//this sort of works but causes a ton of lag when you move the mouse quickly, even when WM_MOUSEMOVE is skipped
LRESULT CALLBACK llmouse_hook(int nCode, WPARAM wParam, LPARAM lParam)
{
    if(nCode < 0)
        return CallNextHookEx(0, nCode, wParam, lParam);

    MSLLHOOKSTRUCT *mouse = (MSLLHOOKSTRUCT *) lParam;

    SDL_Event event = {};
    event.button.which = 69;

    switch(wParam) {
        case WM_LBUTTONDOWN: {
            event.type = SDL_MOUSEBUTTONDOWN;
            event.button.button = SDL_BUTTON_LEFT;
        } break;
        case WM_LBUTTONUP: {
            event.type = SDL_MOUSEBUTTONUP;
            event.button.button = SDL_BUTTON_LEFT;
        } break;
        case WM_MBUTTONDOWN: {
            event.type = SDL_MOUSEBUTTONDOWN;
            event.button.button = SDL_BUTTON_MIDDLE;
        } break;
        case WM_MBUTTONUP: {
            event.type = SDL_MOUSEBUTTONUP;
            event.button.button = SDL_BUTTON_MIDDLE;
        } break;
        case WM_RBUTTONDOWN: {
            event.type = SDL_MOUSEBUTTONDOWN;
            event.button.button = SDL_BUTTON_RIGHT;
        } break;
        case WM_RBUTTONUP: {
            event.type = SDL_MOUSEBUTTONUP;
            event.button.button = SDL_BUTTON_RIGHT;
        } break;
        case WM_XBUTTONDOWN: {
            event.type = SDL_MOUSEBUTTONDOWN;
            event.button.button = (mouse->mouseData>>16) - XBUTTON1 + SDL_BUTTON_X1;
        } break;
        case WM_XBUTTONUP: {
            event.type = SDL_MOUSEBUTTONUP;
            event.button.button = (mouse->mouseData>>16) - XBUTTON1 + SDL_BUTTON_X1;
        } break;
        case WM_MOUSEMOVE: { //this is too laggy
            // event.type = SDL_MOUSEMOTION;
            // event.motion.x = mouse->pt.x - mouse_offset_x;
            // event.motion.y = mouse->pt.y - mouse_offset_y;
        } break;
        case WM_MOUSEWHEEL: {
            event.type = SDL_MOUSEWHEEL;
            event.wheel.y = mouse->mouseData>>16;
        } break;
        default:
            return CallNextHookEx(0, nCode, wParam, lParam);
    }

    SDL_PushEvent(&event);

    return CallNextHookEx(0, nCode, wParam, lParam);
}

typedef void (*SDL_GL_SwapWindow_f)(SDL_Window*);
SDL_GL_SwapWindow_f original_SDL_GL_SwapWindow = nullptr;

void SDL_GL_SwapWindow_hook(SDL_Window* window)
{
    original_SDL_GL_SwapWindow(window);

    { //poll mouse motion
        HWND hwnd = GetForegroundWindow();
        POINT offset = {0, 0};
        ClientToScreen(hwnd, &offset);
        POINT cursor = {};
        GetCursorPos(&cursor);

        SDL_Event event = {};
        event.type = SDL_MOUSEMOTION;
        event.motion.x = cursor.x - offset.x;
        event.motion.y = cursor.y - offset.y;
        event.motion.which = 69;
        SDL_PushEvent(&event);
    }

    //poll mouse buttons, this can miss sub-frame clicks but I think noita does that anyway
    int vk_codes[] = {VK_LBUTTON,VK_RBUTTON,VK_MBUTTON,VK_XBUTTON1,VK_XBUTTON2};
    int sdl_buttons[] = {SDL_BUTTON_LEFT,SDL_BUTTON_RIGHT,SDL_BUTTON_MIDDLE,SDL_BUTTON_X1,SDL_BUTTON_X2};
    static bool prev_down[len(vk_codes)] = {};

    for(int i = 0; i < len(vk_codes); i++) {
        SHORT key_state = GetAsyncKeyState(vk_codes[i]);
        bool down = (key_state&0x8000);
        if(down != prev_down[i]) {
            SDL_Event event = {};
            event.type = down ? SDL_MOUSEBUTTONDOWN : SDL_MOUSEBUTTONUP;
            event.button.button = sdl_buttons[i];
            event.button.which = 69;
            SDL_PushEvent(&event);
            prev_down[i] = down;
        }
    }
}

void* hooked_addresses[256];
uint n_hooks = 0;

int start_hook(void* address, void* hook, void* original)
{
    MH_STATUS status = MH_CreateHook(address, (void*) hook, reinterpret_cast<void**>(original));
    if(status != MH_OK) {
        printf("could not install hook, status: %s\n", MH_StatusToString(status));
        return status;
    }
    hooked_addresses[n_hooks++] = address;

    status = MH_EnableHook(address);
    if(status != MH_OK) {
        printf("could not enable hook, status: %s\n", MH_StatusToString(status));
        return status;
    }
    return status;
}

int end_hook(void* address)
{
    MH_STATUS status = MH_RemoveHook(address);
    if(status != MH_OK) {
        printf("could not remove hook, status: %s\n", MH_StatusToString(status));
        return status;
    }
    // printf("removed hook\n");
    return status;
}

BOOL WINAPI DllMain(
    HINSTANCE hinstDLL,  // handle to DLL module
    DWORD fdwReason,     // reason for calling function
    LPVOID lpvReserved )  // reserved
{
    switch(fdwReason) {
        case DLL_PROCESS_ATTACH:
        {
            HMODULE sdl_lib = LoadLibraryA("SDL2.dll");
            if(!sdl_lib) {
                printf("could not load SDL2.dll\n");
            }

            HMODULE user32 = LoadLibraryA("User32.dll");
            if(!user32) {
                printf("could not load User32.dll\n");
            }

            MH_STATUS status = MH_Initialize();
            if(status != MH_OK) {
                printf("could not initialize MinHook, status: %s\n", MH_StatusToString(status));
                break;
            }

#define hook(lib, fn) if(lib) start_hook((void*) GetProcAddress(lib, #fn), (void*) fn##_hook, (void*) &original_##fn);

            hook(sdl_lib, SDL_PollEvent);
            hook(sdl_lib, SDL_GL_SwapWindow);

#undef hook

            FreeLibrary(sdl_lib); //noita should still have a reference that we are hooked into

            SetWindowsHookExA(WH_KEYBOARD_LL, llkeyboard_hook, 0, 0);
            // SetWindowsHookExA(WH_MOUSE_LL, llmouse_hook, 0, 0);
        } break;

        // lua will randomly garbage collect and unload the dll, so we don't remove hooks when this happens
        // noita will restart anyway if the mod is disabled
        // case DLL_PROCESS_DETACH: {
        //     for(int h = 0; h < n_hooks; h++)
        //         end_hook(hooked_addresses[h]);
        // } break;
    }

    return true;
}
