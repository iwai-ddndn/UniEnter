@echo off
setlocal
cd /d "%~dp0.."
if not exist build mkdir build
cl /nologo /std:c++17 /EHsc /W4 /Fe:build\core_tests.exe tests\core_tests.cpp /Fo:build\core_tests.obj
if errorlevel 1 exit /b 1
build\core_tests.exe
if errorlevel 1 exit /b 1
cl /nologo /std:c++17 /EHsc /W4 /DUNICODE /D_UNICODE /Fe:build\unienter-probe.exe src\windows_probe.cpp src\windows_input.cpp /Fo:build\ /link user32.lib ole32.lib oleaut32.lib uiautomationcore.lib uuid.lib
exit /b %errorlevel%
