@echo off
REM build.bat - Windows Named Shared Resource Demo 构建脚本
REM
REM 需要: Visual Studio 2019+ (带 MSVC 编译器)
REM 运行: 在 "Developer Command Prompt for VS" 中执行此脚本

echo ========================================
echo Building Windows Named Handle Demo
echo ========================================
echo.

REM 检查编译器
where cl >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: cl.exe not found
    echo.
    echo Please run this script in "Developer Command Prompt for VS"
    echo or run: "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
    pause
    exit /b 1
)

echo Compiler: cl.exe found
echo.

REM 创建 build 目录
if not exist build mkdir build
cd build

echo Building parent.exe...
cl.exe /nologo /EHsc /W3 /O2 ^
    ..\parent.cpp ^
    d3d11.lib dxgi.lib ^
    /Fe:parent.exe

if %errorlevel% neq 0 (
    echo ERROR: parent.exe build failed
    cd ..
    pause
    exit /b 1
)
echo   [OK] parent.exe

echo.
echo Building child.exe...
cl.exe /nologo /EHsc /W3 /O2 ^
    ..\child.cpp ^
    d3d11.lib dxgi.lib ^
    /Fe:child.exe

if %errorlevel% neq 0 (
    echo ERROR: child.exe build failed
    cd ..
    pause
    exit /b 1
)
echo   [OK] child.exe

cd ..

echo.
echo ========================================
echo Build SUCCESS
echo ========================================
echo Output: build\parent.exe
echo         build\child.exe
echo.
echo Run: cd build ^&^& parent.exe
echo.

pause
