@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

set "IMAGE=tex-live-docker"
set "CONTAINER=tex-live-docker-live"
set "STATE=.texlivedocker-live"

if /i "%~1"=="--watch" goto Watch

if not exist "input" mkdir "input"
if not exist "output" mkdir "output"
if not exist "build" mkdir "build"
if not exist "failed" mkdir "failed"

cls
echo ========================================
echo       TeXLiveDocker Live Compiler
echo ========================================
echo.

docker info >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker is not running.
    echo.
    pause
    exit /b 1
)

docker rm -f "%CONTAINER%" >nul 2>&1

docker run -d --rm ^
    --name "%CONTAINER%" ^
    --mount "type=bind,source=%CD%,target=/repo" ^
    -w /repo ^
    "%IMAGE%" ^
    sh -c "while :; do sleep 3600; done" >nul

if errorlevel 1 (
    echo ERROR: Could not start the live container.
    echo.
    pause
    exit /b 1
)

if exist "%STATE%" rmdir /s /q "%STATE%"
mkdir "%STATE%\snapshot"
> "%STATE%\running" echo running

REM snapshot existing tex files
for /r "input" %%F in (*.tex) do (
    set "REL=%%~fF"
    set "REL=!REL:%CD%\input\=!"
    for %%D in ("%STATE%\snapshot\!REL!") do if not exist "%%~dpD" mkdir "%%~dpD"
    copy /y "%%~fF" "%STATE%\snapshot\!REL!" >nul
)

echo Watching all .tex files in input/
echo Save a .tex file to compile it.
echo Press ENTER to stop.
echo.

start "" /b cmd.exe /d /c call "%~f0" --watch

set /p "STOP="
del /q "%STATE%\running" >nul 2>&1

REM give the watcher time to stop
ping 127.0.0.1 -n 2 >nul

docker rm -f "%CONTAINER%" >nul 2>&1
rmdir /s /q "%STATE%" >nul 2>&1

echo.
echo Live compiler stopped.
echo.
pause
exit /b 0

:Watch
cd /d "%~dp0"

:WatchLoop
if not exist "%STATE%\running" exit /b 0

for /r "input" %%F in (*.tex) do (
    if not exist "%STATE%\running" exit /b 0

    set "REL=%%~fF"
    set "REL=!REL:%CD%\input\=!"
    set "SNAP=%STATE%\snapshot\!REL!"

    if not exist "!SNAP!" (
        for %%D in ("!SNAP!") do if not exist "%%~dpD" mkdir "%%~dpD"
        copy /y "%%~fF" "!SNAP!" >nul
    ) else (
        fc /b "%%~fF" "!SNAP!" >nul 2>&1
        if errorlevel 1 (
            copy /y "%%~fF" "!SNAP!" >nul
            call :CompileChanged "%%~fF" "!REL!"
        )
    )
)

ping 127.0.0.1 -n 2 >nul
goto WatchLoop

:CompileChanged
set "SOURCE=%~1"
set "REL=%~2"
set "FILE=%~nx1"
set "NAME=%~n1"
set "SOURCE_DIR=%~dp1"

set "REL_DIR=!REL:%~nx1=!"
if defined REL_DIR set "REL_DIR=!REL_DIR:~0,-1!"

if not defined REL_DIR (
    set "BUILD=build\!NAME!"
    set "OUTPUT=output"
) else (
    set "BUILD=build\!REL_DIR!\!NAME!"
    set "OUTPUT=output\!REL_DIR!"
)

if not exist "!BUILD!" mkdir "!BUILD!"
if not exist "!OUTPUT!" mkdir "!OUTPUT!"

REM refresh source files without overwriting latex build files
for /f "delims=" %%S in ('dir /b /a-d "!SOURCE_DIR!"') do (
    if /i not "%%~xS"==".aux" if /i not "%%~xS"==".log" if /i not "%%~xS"==".out" if /i not "%%~xS"==".fls" if /i not "%%~xS"==".fdb_latexmk" if /i not "%%~xS"==".synctex.gz" if /i not "%%~xS"==".toc" if /i not "%%~xS"==".lof" if /i not "%%~xS"==".lot" (
        copy /y "!SOURCE_DIR!%%S" "!BUILD!\%%S" >nul
    )
)

echo.
echo [CHANGE] !REL!

set "DOCKER_BUILD=/repo/!BUILD:\=/!"

docker exec "%CONTAINER%" ^
    sh -c "cd \"$1\" && latexmk -pdf -shell-escape \"$2\"" ^
    sh "!DOCKER_BUILD!" "!FILE!"

if errorlevel 1 (
    echo.
    echo [FAILED] !REL!
    goto :eof
)

if not exist "!BUILD!\!NAME!.pdf" (
    echo.
    echo [FAILED] !REL! - expected PDF was not created.
    goto :eof
)

copy /y "!BUILD!\!NAME!.pdf" "!OUTPUT!\!NAME!.pdf" >nul

echo.
echo [SUCCESS] !REL!
goto :eof
