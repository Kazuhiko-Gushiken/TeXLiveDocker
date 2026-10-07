@echo off
setlocal

REM image builder

cd /d "%~dp0"

set "IMAGE=tex-live-docker"

cls
echo ========================================
echo       TeX Live Docker - Setup
echo ========================================
echo.

REM check for docker actually running
docker info >nul 2>&1

if errorlevel 1 (
    echo ERROR: Docker is not running.
    echo Please start Docker Desktop and try again.
    echo.
    pause
    exit /b 1
)

REM now check the docker file
if not exist "Dockerfile" (
    echo ERROR: Dockerfile not found.
    echo.
    pause
    exit /b 1
)

echo Building Docker image:
echo   %IMAGE%
echo.
echo This may take a while on the first build.
echo.

docker build -t %IMAGE% .

if errorlevel 1 (
    echo.
    echo ========================================
    echo              BUILD FAILED
    echo ========================================
    echo.
    pause
    exit /b 1
)

echo.
echo ========================================
echo            BUILD COMPLETE
echo ========================================
echo.
echo Docker image created:
echo   %IMAGE%
echo.
echo You can now use compile.bat.
echo.

pause
endlocal