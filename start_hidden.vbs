Set WshShell = CreateObject("WScript.Shell")
Dim scriptDir, batPath
scriptDir = Left(WScript.ScriptFullName, Len(WScript.ScriptFullName) - Len(WScript.ScriptName))
batPath = scriptDir & "run_keep_alive.bat"
WshShell.Run "cmd /c """ & batPath & """", 0, False
Set WshShell = Nothing
