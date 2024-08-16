@echo off

:: del "multi_kbm.dll"

setlocal

set OPTIMIZATION_LEVEL=-O3
set DEFINES=

set FLAGS=-Wno-deprecated-declarations -Wno-braced-scalar-init -Wno-c++11-narrowing -Wno-writable-strings -ferror-limit=0 -mmmx -msse -msse2 -msse3 -m32 -Wl,-DLL

set OPTIONS=%FLAGS% %OPTIMIZATION_LEVEL% %DEFINES%

set INCLUDES=-I "include"
set SOURCES="src/multi_kbm.cpp" "minhook_src/hde/hde32.c" "minhook_src/hook.c" "minhook_src/buffer.c" "minhook_src/trampoline.c"
set LIBS=-Llib -lSDL2.lib -lUser32

echo compiling...

clang %OPTIONS% -o "multi_kbm.dll" %INCLUDES% %SOURCES% %LIBS%

endlocal

echo done compiling

if not errorlevel 1 (
    pushd ..\..\..\..\
    noita.exe
    popd
) else (
    EXIT /B 1
)
