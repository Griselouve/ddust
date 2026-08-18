@echo off
setlocal enabledelayedexpansion

set PYTHON=C:\Asura\Tools\Python312\python.exe

set INITIAL_DIR=E:\Deva\projects\suites

:: 1. Choix du repertoire cible (vrai explorateur Windows avec miniatures) :
::    on entre dans le dossier voulu (ou on clique une image dedans) puis Ouvrir,
::    et on recupere le repertoire du chemin retourne.
for /f "usebackq delims=" %%D in (`powershell -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; $d = New-Object System.Windows.Forms.OpenFileDialog; $d.Title = 'Repertoire cible : entrez dans le dossier (ou cliquez une image dedans) puis Ouvrir'; $d.Filter = 'Images (*.png;*.jpg;*.jpeg;*.webp)|*.png;*.jpg;*.jpeg;*.webp|Tous les fichiers|*.*'; $d.CheckFileExists = $false; $d.ValidateNames = $false; $d.FileName = 'Choisir ce dossier'; $d.InitialDirectory = '%INITIAL_DIR%'; if ($d.ShowDialog() -eq 'OK') { [System.IO.Path]::GetDirectoryName($d.FileName) }"`) do (
    set "TARGET=%%D"
)

if not defined TARGET (
    echo Aucun repertoire cible selectionne. Fin.
    goto end
)

echo Repertoire cible : !TARGET!
echo.

:: 2. Boucle de selection multiple des fichiers a deplacer
set SRC_DIR=%INITIAL_DIR%

:loop
set ANY=
for /f "usebackq delims=" %%F in (`powershell -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; $d = New-Object System.Windows.Forms.OpenFileDialog; $d.Title = 'Selectionner un ou plusieurs fichiers a deplacer/renommer'; $d.Filter = 'Images (*.png;*.jpg;*.jpeg;*.webp)|*.png;*.jpg;*.jpeg;*.webp|Tous les fichiers|*.*'; $d.Multiselect = $true; $d.InitialDirectory = '!SRC_DIR!'; if ($d.ShowDialog() -eq 'OK') { $d.FileNames }"`) do (
    "%PYTHON%" "%~dp0organise.py" "!TARGET!" "%%F"
    set ANY=1
    set "SRC_DIR=%%~dpF"
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
