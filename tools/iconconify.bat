@echo off
setlocal

set PYTHON=C:\Asura\Tools\Python312\python.exe

:: Installer rembg[cpu] et Pillow si absents
"%PYTHON%" -c "import rembg" >nul 2>&1
if errorlevel 1 (
    echo Installation de rembg ^(premiere utilisation^)...
    "%PYTHON%" -m pip install "rembg[cpu]" Pillow
)

set INITIAL_DIR=E:\Deva\projects\suites

:loop
set SELECTED=
for /f "usebackq delims=" %%F in (`powershell -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; $d = New-Object System.Windows.Forms.OpenFileDialog; $d.Title = 'Selectionner une icone a iconconifier'; $d.Filter = 'Images PNG (*.png)|*.png|Toutes les images|*.png;*.jpg;*.jpeg;*.webp'; $d.InitialDirectory = '%INITIAL_DIR%'; if ($d.ShowDialog() -eq 'OK') { $d.FileName }"`) do set SELECTED=%%F

if not defined SELECTED (
    echo Aucun fichier selectionne. Fin.
    goto end
)

echo Fichier : %SELECTED%
"%PYTHON%" "%~dp0iconconify.py" "%SELECTED%"

for %%F in ("%SELECTED%") do set INITIAL_DIR=%%~dpF
goto loop

:end
echo.
pause
endlocal
