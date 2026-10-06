@echo off
setlocal EnableExtensions DisableDelayedExpansion
powershell.exe -NoLogo -NoProfile -File "%~dp0upload-api-ghcr\publish.ps1" %*
set "PUBLISH_EXIT_CODE=%errorlevel%"
if not "%PUBLISH_EXIT_CODE%"=="0" (
    echo.
    echo Publish gagal. Exit code: %PUBLISH_EXIT_CODE%
    echo Salin pesan error di atas sebelum menutup jendela.
    pause
)
exit /b %PUBLISH_EXIT_CODE%
