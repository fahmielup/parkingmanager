$projectPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$vbsPath = Join-Path $projectPath "start_hidden.vbs"
$startupPath = [Environment]::GetFolderPath("Startup")
$shortcutPath = Join-Path $startupPath "Parking Manager.lnk"

$WshShell = New-Object -ComObject WScript.Shell
$shortcut = $WshShell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $vbsPath
$shortcut.WorkingDirectory = $projectPath
$shortcut.IconLocation = "shell32.dll,21"
$shortcut.Save()

Write-Host "Shortcut created at: $shortcutPath"
Write-Host "Parking Manager will start automatically when you log in."
