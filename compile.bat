@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM compiler

cd /d "%~dp0"
set "IMAGE=tex-live-docker"

if not exist "input" mkdir "input"
if not exist "output" mkdir "output"
if not exist "build" mkdir "build"
if not exist "failed" mkdir "failed"

cls
echo ========================================
echo       TeXLiveDocker Compiler
echo ========================================
echo.

docker info >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker is not running.
    echo Please start Docker Desktop and try again.
    echo.
    pause
    exit /b 1
)

echo Available:
echo.
set "FOUND=0"

for %%F in ("input\*.tex") do (
    if exist "%%F" (
        echo   %%~nxF
        set "FOUND=1"
    )
)

for /d %%D in ("input\*") do (
    echo   %%~nxD
    set "FOUND=1"
)

if "!FOUND!"=="0" (
    echo   [EMPTY]
    echo.
    echo Nothing to compile.
    echo.
    pause
    exit /b 0
)

echo.
echo ----------------------------------------
echo.
echo Enter a file or directory name to compile it.
echo Selecting a directory compiles every .tex file directly inside it.
echo Press ENTER to compile EVERYTHING.
echo.
set /p "SELECTION=Selection: "
echo.

if "%SELECTION%"=="" (
    for %%F in ("input\*.tex") do (
        if exist "%%F" call :CompileLooseFile "%%F"
    )
    for /d %%D in ("input\*") do call :CompileDirectory "%%D"
    goto Finished
)

if exist "input\%SELECTION%\" (
    call :CompileDirectory "input\%SELECTION%"
    goto Finished
)

if exist "input\%SELECTION%" (
    if /i "%~xSELECTION%"==".tex" (
        call :CompileLooseFile "input\%SELECTION%"
        goto Finished
    )
)

if exist "input\%SELECTION%.tex" (
    call :CompileLooseFile "input\%SELECTION%.tex"
    goto Finished
)

echo ERROR: "%SELECTION%" was not found in input.
echo.
goto Finished


REM compiling the .tex from input
:CompileLooseFile

set "SOURCE=%~1"
set "FILE=%~nx1"
set "NAME=%~n1"
set "BUILD_DIR=build\!NAME!"
set "OUTPUT_DIR=output"
set "ERROR_DIR=failed"

echo ========================================
echo Compiling: !FILE!
echo ========================================
echo.

if exist "!BUILD_DIR!" rmdir /s /q "!BUILD_DIR!"
mkdir "!BUILD_DIR!"
copy /y "!SOURCE!" "!BUILD_DIR!\!FILE!" >nul

call :RunLatex "!BUILD_DIR!" "!FILE!" "!NAME!" "!ERROR_DIR!" "!NAME!"
if errorlevel 1 goto :eof

copy /y "!SOURCE!" "!OUTPUT_DIR!\!FILE!" >nul
copy /y "!BUILD_DIR!\!NAME!.pdf" "!OUTPUT_DIR!\!NAME!.pdf" >nul

if exist "!ERROR_DIR!\!NAME!-errors.txt" del /q "!ERROR_DIR!\!NAME!-errors.txt"

echo.
echo [SUCCESS] !FILE!
echo Output: !OUTPUT_DIR!
echo.
goto :eof


REM compile all the tex from in the directory
:CompileDirectory

set "SOURCE_DIR=%~1"
set "PROJECT=%~nx1"
set "DIR_FOUND=0"

echo ========================================
echo Compiling directory: !PROJECT!
echo ========================================
echo.

for %%F in ("!SOURCE_DIR!\*.tex") do (
    if exist "%%F" set "DIR_FOUND=1"
)

if "!DIR_FOUND!"=="0" (
    echo [SKIPPED] No .tex files found directly inside !SOURCE_DIR!
    echo.
    goto :eof
)

REM make an output copy of the source
if exist "output\!PROJECT!" rmdir /s /q "output\!PROJECT!"
mkdir "output\!PROJECT!"
xcopy "!SOURCE_DIR!\*" "output\!PROJECT!\" /E /I /Q /Y >nul

REM keeping documents isolated
for %%F in ("!SOURCE_DIR!\*.tex") do (
    if exist "%%F" call :CompileDirectoryFile "!SOURCE_DIR!" "!PROJECT!" "%%~nxF"
)

echo Finished directory: !PROJECT!
echo Output: output\!PROJECT!
echo.
goto :eof


REM compile the tex file
:CompileDirectoryFile

set "SOURCE_DIR=%~1"
set "PROJECT=%~2"
set "FILE=%~3"
set "NAME=%~n3"
set "BUILD_DIR=build\!PROJECT!\!NAME!"
set "ERROR_DIR=failed\!PROJECT!"

echo ----------------------------------------
echo Compiling: !PROJECT!\!FILE!
echo ----------------------------------------
echo.

if exist "!BUILD_DIR!" rmdir /s /q "!BUILD_DIR!"
mkdir "!BUILD_DIR!"
xcopy "!SOURCE_DIR!\*" "!BUILD_DIR!\" /E /I /Q /Y >nul

if not exist "!ERROR_DIR!" mkdir "!ERROR_DIR!"

call :RunLatex "!BUILD_DIR!" "!FILE!" "!NAME!" "!ERROR_DIR!" "!PROJECT!\!FILE!"
if errorlevel 1 goto :eof

copy /y "!BUILD_DIR!\!NAME!.pdf" "output\!PROJECT!\!NAME!.pdf" >nul
if exist "!ERROR_DIR!\!NAME!-errors.txt" del /q "!ERROR_DIR!\!NAME!-errors.txt"

REM remove the failed dir
dir /b "!ERROR_DIR!" >nul 2>&1
if errorlevel 1 rmdir "!ERROR_DIR!" >nul 2>&1

echo.
echo [SUCCESS] !FILE!
echo.
goto :eof


REM run latexmk to ensure pdf is good
:RunLatex

set "RUN_BUILD=%~1"
set "RUN_FILE=%~2"
set "RUN_NAME=%~3"
set "RUN_ERROR_DIR=%~4"
set "RUN_DISPLAY=%~5"

if not exist "!RUN_ERROR_DIR!" mkdir "!RUN_ERROR_DIR!"

docker run --rm ^
    -v "%~dp0!RUN_BUILD!:/work" ^
    -w /work ^
    %IMAGE% ^
    latexmk -pdf -shell-escape "!RUN_FILE!"

if errorlevel 1 (
    echo.
    echo [FAILED] !RUN_DISPLAY!
    call :CreateErrorLog "!RUN_BUILD!" "!RUN_NAME!" "!RUN_ERROR_DIR!" "!RUN_DISPLAY!"
    echo.
    echo Error report:
    echo   !RUN_ERROR_DIR!\!RUN_NAME!-errors.txt
    echo.
    echo Full build files:
    echo   !RUN_BUILD!
    echo.
    exit /b 1
)

if not exist "!RUN_BUILD!\!RUN_NAME!.pdf" (
    echo.
    echo [FAILED] !RUN_DISPLAY! - expected PDF was not created.
    call :CreateErrorLog "!RUN_BUILD!" "!RUN_NAME!" "!RUN_ERROR_DIR!" "!RUN_DISPLAY!"
    echo.
    echo Error report:
    echo   !RUN_ERROR_DIR!\!RUN_NAME!-errors.txt
    echo.
    exit /b 1
)

exit /b 0


REM error report
:CreateErrorLog

set "ERR_BUILD=%~1"
set "ERR_NAME=%~2"
set "ERR_DIR=%~3"
set "ERR_DISPLAY=%~4"
set "LOGFILE=!ERR_BUILD!\!ERR_NAME!.log"
set "ERRORFILE=!ERR_DIR!\!ERR_NAME!-errors.txt"

if not exist "!ERR_DIR!" mkdir "!ERR_DIR!"

(
    echo TeXLiveDocker Compiler - Error Report
    echo =====================================
    echo.
    echo Document: !ERR_DISPLAY!
    echo Status: FAILED
    echo.
    echo ERRORS
    echo ------
    echo.
) > "!ERRORFILE!"

if exist "!LOGFILE!" (
    findstr /N /B /C:"!" "!LOGFILE!" >> "!ERRORFILE!" 2>nul
    echo. >> "!ERRORFILE!"
    echo SOURCE LINES >> "!ERRORFILE!"
    echo ------------ >> "!ERRORFILE!"
    echo. >> "!ERRORFILE!"
    findstr /N /R /C:"^l\.[0-9][0-9]*" "!LOGFILE!" >> "!ERRORFILE!" 2>nul
) else (
    echo No LaTeX log file was generated. >> "!ERRORFILE!"
    echo. >> "!ERRORFILE!"
    echo The failure may have occurred before LaTeX >> "!ERRORFILE!"
    echo was able to create a log file. >> "!ERRORFILE!"
)

echo. >> "!ERRORFILE!"
echo --------------------------------- >> "!ERRORFILE!"
echo Full log: !LOGFILE! >> "!ERRORFILE!"
goto :eof


:Finished
echo.
echo ========================================
echo              Finished
echo ========================================
echo.
pause
endlocal
