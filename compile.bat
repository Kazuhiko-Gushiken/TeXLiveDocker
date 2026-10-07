@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================
REM TexLiveDocker - Windows
REM ============================================================

REM Always operate relative to this script.
cd /d "%~dp0"

REM Docker image.
set "IMAGE=tex-live-docker"

REM Create required directories.
if not exist "input" mkdir "input"
if not exist "output" mkdir "output"
if not exist "build" mkdir "build"
if not exist "failed" mkdir "failed"

cls
echo ========================================
echo       TexLiveDocker Compiler
echo ========================================
echo.

REM ============================================================
REM Check Docker
REM ============================================================

docker info >nul 2>&1

if errorlevel 1 (
    echo ERROR: Docker is not running.
    echo Please start Docker Desktop and try again.
    echo.
    pause
    exit /b 1
)

REM ============================================================
REM Display available input
REM ============================================================

echo Available:
echo.

set "FOUND=0"

REM Show loose .tex files.
for %%F in ("input\*.tex") do (
    if exist "%%F" (
        echo   %%~nxF
        set "FOUND=1"
    )
)

REM Show project directories.
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
echo Enter a file or project name to compile it.
echo Press ENTER to compile EVERYTHING.
echo.

set /p "SELECTION=Selection: "

echo.

REM ============================================================
REM Compile everything
REM ============================================================

if "%SELECTION%"=="" (

    REM Compile loose .tex files.
    for %%F in ("input\*.tex") do (
        if exist "%%F" (
            call :CompileFile "%%F"
        )
    )

    REM Compile project directories.
    for /d %%D in ("input\*") do (
        call :CompileProject "%%D"
    )

    goto Finished
)

REM ============================================================
REM Compile a specific selection
REM ============================================================

REM Project directory.
if exist "input\%SELECTION%\" (
    call :CompileProject "input\%SELECTION%"
    goto Finished
)

REM Exact .tex filename.
if exist "input\%SELECTION%" (
    if /i "%~xSELECTION%"==".tex" (
        call :CompileFile "input\%SELECTION%"
        goto Finished
    )
)

REM Allow omission of .tex extension.
if exist "input\%SELECTION%.tex" (
    call :CompileFile "input\%SELECTION%.tex"
    goto Finished
)

echo ERROR: "%SELECTION%" was not found in input.
echo.
goto Finished


REM ============================================================
REM Compile a loose .tex file
REM ============================================================

:CompileFile

set "SOURCE=%~1"
set "FILE=%~nx1"
set "NAME=%~n1"

echo ========================================
echo Compiling: !FILE!
echo ========================================
echo.

REM Delete previous build.
if exist "build\!NAME!" (
    rmdir /s /q "build\!NAME!"
)

mkdir "build\!NAME!"

REM Copy source into build directory.
copy /y "!SOURCE!" "build\!NAME!\!FILE!" >nul

REM Compile inside Docker.
docker run --rm ^
    -v "%~dp0build\!NAME!:/work" ^
    -w /work ^
    %IMAGE% ^
    latexmk -pdf -shell-escape "!FILE!"

REM ------------------------------------------------------------
REM Compilation failed
REM ------------------------------------------------------------

if errorlevel 1 (

    echo.
    echo [FAILED] !FILE!

    call :CreateErrorLog "!NAME!" "!NAME!"

    echo.
    echo Error report:
    echo   failed\!NAME!-errors.txt
    echo.
    echo Full build files:
    echo   build\!NAME!
    echo.

    goto :eof
)

REM Make sure PDF actually exists.
if not exist "build\!NAME!\!NAME!.pdf" (

    echo.
    echo [FAILED] Expected PDF was not created.

    call :CreateErrorLog "!NAME!" "!NAME!"

    echo.
    echo Error report:
    echo   failed\!NAME!-errors.txt
    echo.

    goto :eof
)

REM ------------------------------------------------------------
REM Compilation succeeded
REM ------------------------------------------------------------

REM Delete obsolete failure report.
if exist "failed\!NAME!-errors.txt" (
    del /q "failed\!NAME!-errors.txt"
)

REM Copy source and PDF to output.
REM Original input remains untouched.
copy /y "!SOURCE!" "output\!FILE!" >nul
copy /y "build\!NAME!\!NAME!.pdf" "output\!NAME!.pdf" >nul

echo.
echo [SUCCESS] !FILE!
echo Output: output
echo.

goto :eof


REM ============================================================
REM Compile a project directory
REM ============================================================

:CompileProject

set "SOURCE_DIR=%~1"
set "PROJECT=%~nx1"
set "MAIN=!PROJECT!.tex"

echo ========================================
echo Compiling: !PROJECT!
echo ========================================
echo.

REM ------------------------------------------------------------
REM Check main file
REM ------------------------------------------------------------

REM Project convention:
REM
REM input\PhysicsLab\
REM     PhysicsLab.tex
REM     image.png
REM     data.csv
REM
REM Folder name must match main .tex filename.

if not exist "!SOURCE_DIR!\!MAIN!" (

    echo [FAILED] Main TeX file not found.
    echo.
    echo Expected:
    echo   !SOURCE_DIR!\!MAIN!
    echo.
    echo Project directories must contain a .tex file
    echo with the same name as the directory.
    echo.

    goto :eof
)

REM ------------------------------------------------------------
REM Prepare build directory
REM ------------------------------------------------------------

if exist "build\!PROJECT!" (
    rmdir /s /q "build\!PROJECT!"
)

mkdir "build\!PROJECT!"

REM Copy entire project into build.
xcopy "!SOURCE_DIR!\*" "build\!PROJECT!\" /E /I /Q /Y >nul

REM ------------------------------------------------------------
REM Compile
REM ------------------------------------------------------------

docker run --rm ^
    -v "%~dp0build\!PROJECT!:/work" ^
    -w /work ^
    %IMAGE% ^
    latexmk -pdf -shell-escape "!MAIN!"

REM ------------------------------------------------------------
REM Compilation failed
REM ------------------------------------------------------------

if errorlevel 1 (

    echo.
    echo [FAILED] !PROJECT!

    call :CreateErrorLog "!PROJECT!" "!PROJECT!"

    echo.
    echo Error report:
    echo   failed\!PROJECT!-errors.txt
    echo.
    echo Full build files:
    echo   build\!PROJECT!
    echo.

    goto :eof
)

REM Make sure PDF actually exists.
if not exist "build\!PROJECT!\!PROJECT!.pdf" (

    echo.
    echo [FAILED] Expected PDF was not created.

    call :CreateErrorLog "!PROJECT!" "!PROJECT!"

    echo.
    echo Error report:
    echo   failed\!PROJECT!-errors.txt
    echo.

    goto :eof
)

REM ------------------------------------------------------------
REM Compilation succeeded
REM ------------------------------------------------------------

REM Delete obsolete failure report.
if exist "failed\!PROJECT!-errors.txt" (
    del /q "failed\!PROJECT!-errors.txt"
)

REM Remove previous output version.
if exist "output\!PROJECT!" (
    rmdir /s /q "output\!PROJECT!"
)

mkdir "output\!PROJECT!"

REM Copy ORIGINAL project to output.
xcopy "!SOURCE_DIR!\*" "output\!PROJECT!\" /E /I /Q /Y >nul

REM Add newly compiled PDF.
copy /y ^
    "build\!PROJECT!\!PROJECT!.pdf" ^
    "output\!PROJECT!\!PROJECT!.pdf" >nul

echo.
echo [SUCCESS] !PROJECT!
echo Output: output\!PROJECT!
echo.

goto :eof


REM ============================================================
REM Create simplified error report
REM ============================================================

:CreateErrorLog

set "BUILD_NAME=%~1"
set "LOG_NAME=%~2"

set "LOGFILE=build\!BUILD_NAME!\!LOG_NAME!.log"
set "ERRORFILE=failed\!BUILD_NAME!-errors.txt"

REM Create report header.
(
    echo TexLiveDocker Compiler - Error Report
    echo =================================
    echo.
    echo Project: !BUILD_NAME!
    echo Status: FAILED
    echo.
    echo ERRORS
    echo ------
    echo.
) > "!ERRORFILE!"

REM ------------------------------------------------------------
REM Extract errors from LaTeX log
REM ------------------------------------------------------------

if exist "!LOGFILE!" (

    REM Actual TeX errors normally begin with !
    findstr /N /B /C:"!" "!LOGFILE!" >> "!ERRORFILE!"

    echo. >> "!ERRORFILE!"
    echo SOURCE LINES >> "!ERRORFILE!"
    echo ------------ >> "!ERRORFILE!"
    echo. >> "!ERRORFILE!"

    REM Extract lines such as:
    REM l.42 \someBrokenCommand
    findstr /N /R /C:"^l\.[0-9][0-9]*" "!LOGFILE!" >> "!ERRORFILE!"

) else (

    echo No LaTeX log file was generated. >> "!ERRORFILE!"
    echo. >> "!ERRORFILE!"
    echo The failure may have occurred before LaTeX >> "!ERRORFILE!"
    echo was able to create a log file. >> "!ERRORFILE!"

)

REM ------------------------------------------------------------
REM Footer
REM ------------------------------------------------------------

echo. >> "!ERRORFILE!"
echo --------------------------------- >> "!ERRORFILE!"
echo Full log: !LOGFILE! >> "!ERRORFILE!"

goto :eof


REM ============================================================
REM Finished
REM ============================================================

:Finished

echo.
echo ========================================
echo              Finished
echo ========================================
echo.
pause

endlocal