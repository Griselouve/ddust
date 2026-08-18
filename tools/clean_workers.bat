@echo off
setlocal
title Clean Workers - Ddust

echo ============================================
echo  Nettoyage Firestore eu-workers (dvddust)
echo ============================================
echo.

set GCLOUD=E:\Deva\deva\binaries\google\bin\gcloud.cmd
set CLOUDSDK_PYTHON=C:\Asura\Tools\Python312\python.exe

echo Verification des credentials gcloud...
call "%GCLOUD%" auth application-default print-access-token >nul 2>&1
if %errorlevel% neq 0 (
    echo Authentification requise, ouverture du navigateur...
    echo Une fois valide dans le navigateur, appuyez sur une touche ici pour continuer.
    echo.
    start "" cmd /c ""%GCLOUD%" auth application-default login & pause"
    pause
)
echo Credentials valides.

echo.
"C:\Asura\Tools\Python312\python.exe" "%~dp0clean_workers.py"

echo.
pause
