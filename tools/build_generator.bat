@echo off
REM Build script for test data generator on Windows

echo Building test data generator...

if not exist tools\build mkdir tools\build

odin build tools\generate_test_data.odin -file -out:tools\build\generate_test_data.exe -debug

echo Build complete! Run with: .\tools\build\generate_test_data.exe
