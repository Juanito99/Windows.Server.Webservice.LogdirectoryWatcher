param([string]$ComputerName,[string]$LogDirPath)

$LogDirPath | Out-File -FilePath  C:\errorCreatTasks.txt -Append

$remoteLogs = $LogDirPath -replace ':','$'
$remoteURL = [char]34 + '\\' + $ComputerName + '\' + $remoteLogs + [char]34

& $env:windir\explorer.exe $($remoteURL) 