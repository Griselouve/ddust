@echo off
setlocal enabledelayedexpansion

set PYTHON=C:\Asura\Tools\Python312\python.exe

:: Installer numpy, scipy, Pillow, rembg[cpu] si absents
"%PYTHON%" -c "import numpy, scipy, PIL, rembg" >nul 2>&1
if errorlevel 1 (
    echo Installation des dependances ^(premiere utilisation^)...
    "%PYTHON%" -m pip install numpy scipy Pillow "rembg[cpu]"
)

set INITIAL_DIR=E:\Deva\projects\suites

:loop
set ANY=
for /f "usebackq delims=" %%F in (`powershell -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; $d = New-Object System.Windows.Forms.OpenFileDialog; $d.Title = 'Selectionner une ou plusieurs feuilles d''icones'; $d.Filter = 'Images PNG (*.png)|*.png|Toutes les images|*.png;*.jpg;*.jpeg;*.webp'; $d.Multiselect = $true; $d.InitialDirectory = '%INITIAL_DIR%'; if ($d.ShowDialog() -eq 'OK') { $d.FileNames }"`) do (
    echo Fichier : %%F
    "%PYTHON%" "%~dp0iconmakify.py" "%%F"
    set ANY=1
    set "INITIAL_DIR=%%~dpF"
)

if not defined ANY (
    echo Aucun fichier selectionne. Fin.
    goto end
)

goto loop

:end
echo.
pause
endlocal
