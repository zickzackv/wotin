@echo off
REM Build script for wotin on Windows

echo Building wotin...

REM Create build directory if it doesn't exist
if not exist build mkdir build

REM Build in debug mode by default
set MODE=%1
if "%MODE%"=="" set MODE=debug

if "%MODE%"=="release" (
    echo Building in release mode...
    odin build src -out:build/wotin.exe -o:speed
) else (
    echo Building in debug mode...
    odin build src -out:build/wotin.exe -debug
)

echo Build complete! Binary located at: build\wotin.exe
