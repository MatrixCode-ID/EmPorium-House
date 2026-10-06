@echo off
setlocal EnableExtensions DisableDelayedExpansion
where pwsh.exe >nul 2>&1
if errorlevel 1 (
    echo pwsh.exe ^(PowerShell 7^) tidak ditemukan di PATH. Pasang PowerShell 7 lalu ulangi.
    set "EXIT_CODE=1"
    goto :done
)
pwsh.exe -NoLogo -NoProfile -File "%~dp0publish-wpf\publish-wpf.ps1" %*
set "EXIT_CODE=%errorlevel%"
:done
echo.
if not "%EXIT_CODE%"=="0" echo Publish WPF gagal. Exit code: %EXIT_CODE%
pause
exit /b %EXIT_CODE%
