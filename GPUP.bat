:::::::::::::::::::::::::::::::::::::::::
REM Automatically check & get admin rights
:::::::::::::::::::::::::::::::::::::::::
@echo off

:checkPrivileges
NET FILE 1>NUL 2>NUL
if '%errorlevel%' == '0' ( goto gotPrivileges ) else ( goto getPrivileges )

:getPrivileges
setlocal EnableDelayedExpansion
REM Double up any quotes in args
set "batchPath=%~f0"
set "batchPath=""%batchPath:"=%"""
REM Walk the args, stripping them if they're empty or only quotes
set "args=%*"
if NOT "!args!"=="" (
    set "argq=!args:"=""!"
    if NOT "!argq!" == "" (
        set "args= !args:"=""!"
    )
)
ECHO Set UAC = CreateObject^("Shell.Application"^) > "%temp%\OEgetPrivileges.vbs"
ECHO UAC.ShellExecute "cmd", "/c ""!batchPath!!args!""", "", "runas", 1 >> "%temp%\OEgetPrivileges.vbs"
"%temp%\OEgetPrivileges.vbs"
exit /B

:gotPrivileges
REM set the current directory to the batch file location
cd /d %~dp0
::::::::::::::::::::::::::::
::START
::::::::::::::::::::::::::::

setlocal enabledelayedexpansion

REM Setup some default values
set /a add.Count=0
set /a rem.Count=0
set "thisdir=%~dp0"
set "manual=false"

:process
set /a added.Count=0
set /a removed.Count=0
call :header
echo Gathering current tasks...
if /i "!manual!"=="false" (
    REM Check for any passed args
    if NOT "%~1" == "" (
        REM Verify the passed arg is a valid path
        set "added=%~1"
        if NOT EXIST "!added!" (
            echo   "!added!" does not exist...
            echo     Enabling manual mode...
            set "manual=true"
            timeout 3 > nul
            goto :mainmenu
        )
        if /i NOT "!added:~-4!" == ".exe" (
            echo   "!added!" is not an executable...
            echo     Enabling manual mode...
            set "manual=true"
            timeout 3 > nul
            goto :mainmenu
        )
        call :getperf "2" "val"
        echo   Found "!added!" - adding as !val!...
        set /a add.Count=1
        set "add[1].Name=!added!"
        set "add[1].Value=2"
    ) else (
        echo   No passed arguments...
        echo     Enabling manual mode...
        set "manual=true"
        REM timeout 3 > nul
        goto :mainmenu
    )
)
REM Let's check removals first
if not "!rem.Count!" == "0" (
    echo.
    echo Gathering existing preferences...
    REM Build a list of existing prefs
    call :getprefs "gpu"
    if not "!gpu.Count!" == "0" (
        if "!gpu.Count!" == "1" (
            echo   Found 1 existing preference:
        ) else (
            echo   Found !gpu.Count! existing preferences:
        )
        call :printlist "gpu" "    "
    ) else (
        echo   Found 0 existing preferences.
    )
    echo.
    if "!rem.Count!"=="1" (
        echo Iterating 1 preference to remove...
    ) else (
        echo Iterating !rem.Count! preferences to remove...
    )
    REM Now we iterate our current list of preferences, and if found,
    REM we can remove it
    for /l %%a in ( 1, 1, !rem.Count! ) do (
        set "found=false"
        for /l %%x in ( 1, 1, !gpu.Count! ) do (
            if /i "!rem[%%a].Name!" == "!gpu[%%x].Name!" (
                REM Remove the preference
                set "found=true"
                set /a removed.Count+=1
                echo   Found "!rem[%%a].Name!":
                echo     Removing preference...
                reg delete "HKCU\Software\Microsoft\DirectX\UserGpuPreferences" /v "!rem[%%a].Name!" /f > nul
            )
        )
        if /i "!found!"=="false" (
            echo   "!rem[%%a].Name!" doesn't exist, skipping...
        )
    )
    echo.
    if "!removed.Count!"=="1" (
        echo Removed !removed.Count! of 1 preference.
    ) else (
        echo Removed !removed.Count! of !rem.Count! preferences.
    )
)
REM Now we check additions
if not "!add.Count!" == "0" (
    echo.
    echo Gathering existing preferences...
    REM Build a list of existing prefs
    call :getprefs "gpu"
    if not "!gpu.Count!" == "0" (
        if "!gpu.Count!" == "1" (
            echo   Found 1 existing preference:
        ) else (
            echo   Found !gpu.Count! existing preferences:
        )
        call :printlist "gpu" "    "
    ) else (
        echo   Found 0 existing preferences.
    )
    echo.
    if "!add.Count!"=="1" (
        echo Iterating 1 preference to add...
    ) else (
        echo Iterating !add.Count! preferences to add...
    )
    REM Now we iterate our current list of preferences, and if not found,
    REM we can add it
    for /l %%a in ( 1, 1, !add.Count! ) do (
        set "found=false"
        call :getperf "!add[%%a].Value!" "val"
        for /l %%x in ( 1, 1, !gpu.Count! ) do (
            if /i "!add[%%a].Name!" == "!gpu[%%x].Name!" (
                echo   "!add[%%a].Name!" already exists, updating to !val!...
                set "found=true"
            )
        )
        if /i "!found!"=="false" (
            REM Add the preference
            set "found=true"
            set /a added.Count+=1
            echo   Didn't find "!add[%%a].Name!":
            echo     Adding preference as !val!...
            reg add "HKCU\Software\Microsoft\DirectX\UserGpuPreferences" /v "!add[%%a].Name!" /f /t REG_SZ /d "GpuPreference=!add[%%a].Value!;" > nul
        ) else (
            set /a added.Count+=1
            reg add "HKCU\Software\Microsoft\DirectX\UserGpuPreferences" /v "!add[%%a].Name!" /f /t REG_SZ /d "GpuPreference=!add[%%a].Value!;" > nul
        )
    )
    echo.
    if "!removed.Count!"=="1" (
        echo Added !added.Count! of 1 preference.
    ) else (
        echo Added !added.Count! of !add.Count! preferences.
    )
)
echo.
if /i "!manual!"=="false" (
    echo Press any key to exit...
    pause > nul
    exit /b
) else (
    echo Press any key to return to the menu...
    pause > nul
    goto :mainmenu
)

pause

REM Following this is a list of helper methods
REM They do everything from pre-fill lists to
REM gather string length and such.

:header
cls
echo   ####################################
echo  #          GPU Performance         #
echo ####################################
if "!manual!"=="true" (
    echo   By CorpNewt  -- MANUAL MODE --
) else (
    echo   By CorpNewt
)
echo.
goto :EOF

:mainmenu
set "menu="
REM This is the interactive mode in case we have no defaults
call :header
REM Get our current prefs
call :getprefs "gpu"
echo Existing GPU Preferences:
echo.
if "!gpu.Count!"=="0" (
    echo   None
) else (
    call :printlist "gpu" "  "
)
echo.
echo 1. Add New Preference
echo 2. Remove Existing Preference
echo 3. Update Existing Preference
echo.
echo Q. Quit
echo.
set /p "menu=Please make a selection:  "
if "!menu!"=="" (
    goto :mainmenu
) else if /i "!menu!"=="q" (
    exit /b
) else if "!menu!"=="1" (
    goto :addpref
) else if "!menu!"=="2" (
    goto :rempref
) else if "!menu!"=="3" (
    goto :editpref
)
goto :mainmenu

:addpref
set "menu="
call :header
call :getprefs "gpu"
echo Existing GPU Preferences:
echo.
if "!gpu.Count!"=="0" (
    echo   None
) else (
    call :printlist "gpu" "  "
)
echo.
echo M. Main Menu
echo Q. Quit
echo.
set /p "menu=Please type the path to the exe to add:  "
if "!menu!"=="" (
    goto :addpref
) else if /i "!menu!"=="m" (
    goto :mainmenu
) else if /i "!menu!"=="q" (
    exit /b
)
goto :addprefperf

:addprefperf
set "menup="
REM At this point, we should have a path
REM Let's ask for the preference
call :header
echo Selected Path: !menu!
echo.
echo 1. System Default
echo 2. Power Saving
echo 3. High Performance
echo.
echo M. Main Menu
echo Q. Quit
echo.
set /p "menup=Please select the performance level:  "
if "!menup!"=="" (
    goto :addprefperf
) else if /i "!menup!" == "m" (
    goto :mainmenu
) else if /i "!menup!" == "q" (
    exit /b
) else if "!menup!" == "1" (
    set "add[1].Value=0"
) else if "!menup!" == "2" (
    set "add[1].Value=1"
) else if "!menup!" == "3" (
    set "add[1].Value=2"
) else (
    goto :addprefperf
)
set /a rem.Count=0
set /a add.Count=1
set "add[1].Name=!menu!"
goto :process

:rempref
set "menu="
call :header
call :getprefs "gpu"
echo Existing GPU Preferences:
echo.
if "!gpu.Count!"=="0" (
    echo   None
    echo.
) else (
    call :printlist "gpu" "  " "numbers"
    echo.
    echo A. Remove All
)
echo M. Main Menu
echo Q. Quit
echo.
set /p "menu=Please select the preference to remove:  "
if "!menu!"=="" (
    goto :rempref
) else if /i "!menu!"=="m" (
    goto :mainmenu
) else if /i "!menu!"=="q" (
    exit /b
) else if /i "!menu!"=="a" (
    if /i not "!gpu.Count!"=="0" (
        REM We have at least one, and we'll remove it
        call :copylist "gpu" "rem"
        set /a add.Count=0
        goto :process
    )
) else if !menu! GTR 0 (
    if !menu! LEQ !gpu.Count! (
        REM Found it!
        set /a rem.Count=1
        set /a add.Count=0
        set "rem[1].Name=!gpu[%menu%].Name!"
        goto :process
    )
)
goto :rempref

:editpref
set "menu="
call :header
call :getprefs "gpu"
echo Existing GPU Preferences:
echo.
if "!gpu.Count!"=="0" (
    echo   None
) else (
    call :printlist "gpu" "  " "numbers"
)
echo.
echo M. Main Menu
echo Q. Quit
echo.
set /p "menu=Please select the preference to edit:  "
if "!menu!"=="" (
    goto :editpref
) else if /i "!menu!"=="m" (
    goto :mainmenu
) else if /i "!menu!"=="q" (
    exit /b
) else if !menu! GTR 0 (
    if !menu! LEQ !gpu.Count! (
        REM Found it!
        set "menu=!gpu[%menu%].Name!"
        goto :addprefperf
    )
)
goto :editpref

:copylist <prefix_from> <prefix_to>
set /a %~2.Count=!%~1.Count!
for /l %%a in (1, 1, !%~1.Count!) do (
    set "%~2[%%a].Name=!%~1[%%a].Name!"
    set "%~2[%%a].Value=!%~1[%%a].Value!"
)
goto :EOF

:getperf <value> <return> <pad>
if not "%~3" == "" (
    if "%~1" == "0" (
        set "%~2=  System Default"
    ) else if "%~1" == "1" (
        set "%~2=Power Saving    "
    ) else if "%~1" == "2" (
        set "%~2=High Performance"
    ) else (
        set "%~2=Unknown (%~1)     "
    )
) else (
    if "%~1" == "0" (
        set "%~2=System Default"
    ) else if "%~1" == "1" (
        set "%~2=Power Saving"
    ) else if "%~1" == "2" (
        set "%~2=High Performance"
    ) else (
        set "%~2=Unknown (%~1)"
    )
)
goto :EOF

:printlist <prefix> <pad>
for /l %%a in (1, 1, !%~1.Count!) do (
    call :getperf "!%~1[%%a].Value!" "val" "true"
    if /i "%~3"=="numbers" (
        echo %~2%%a. !val! - !%~1[%%a].Name!
    ) else (
        echo %~2!val! - !%~1[%%a].Name!
    )
)
goto :EOF

:getprefs <var_prefix>
set "prefix=%~1"
set /a !prefix!.Count=0
for /f "tokens=*" %%i in ('reg.exe query "HKCU\Software\Microsoft\DirectX\UserGpuPreferences" 2^> nul') do (
    REM Verify that we have "    REG_SZ    GpuPreference" in our string
    set "temp=%%i"
    set "tcheck=!temp:    REG_SZ    GpuPreference=!"
    if NOT "!tcheck!" == "!temp!" (
        set /a !prefix!.Count+=1
        call :setvar "!prefix![!%prefix%.Count!].Name" "!tcheck:~0,-3!"
        call :setvar "!prefix![!%prefix%.Count!].Value" "!tcheck:~-2,1!"
    )
)
goto :EOF

:setvar <var_name> <value>
set %~1=%~2
goto :EOF

REM Pulled from here: https://stackoverflow.com/a/22971891
:len <string> <length_variable> - note: string must be quoted because it may have spaces
setlocal enabledelayedexpansion&set l=0&set str=%~1
:len_loop
set x=!str:~%l%,1!&if not defined x (endlocal&set "%~2=%l%"&goto :eof)
set /a l=%l%+1&goto :len_loop
goto :EOF
