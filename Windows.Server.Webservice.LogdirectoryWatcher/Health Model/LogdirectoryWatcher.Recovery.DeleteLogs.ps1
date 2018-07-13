param($LogDirectory, $webServerType, $daysToKeepLogs, $scheduledTasksFolder)

$api = New-Object -ComObject 'MOM.ScriptAPI'
$api.LogScriptEvent('LogdirectoryWatcher.Recovery.DeleteLogs.ps1',3000,2,"Recovery kicks in with Supplement $($LogDirectory) and WebServerType: $($webServerType) and scheduled task folder $($scheduledTasksFolder)")	

$ComputerName         = $env:COMPUTERNAME
      
$logDirectoryClean    = $logDirectory      -Replace('\\','-')
$logDirectoryClean    = $logDirectoryClean -Replace(':','')

$scheduledTasksFolder = $scheduledTasksFolder -replace([char]34,'')
$scheduledTasksFolder = $scheduledTasksFolder -replace("`"",'')
$taskName             = "Auto-Log-Dir-Cleaner_Delete_for_$($logDirectoryClean)_on_$($ComputerName)"
$taskName             = $taskName -replace '\s',''
$scriptFileName       = $taskName + '.ps1'
$scriptPath           = Join-Path -Path $scheduledTasksFolder -ChildPath $scriptFileName

                       
if ($daysToKeepLogs -eq $null) {
	$daysToKeepLogs = 8
}

if ($scheduledTasksFolder -eq $null) {
	$scheduledTasksFolder = 'C:\ScheduledTasks'
}

Function Write-LogDirCleanScript {

	param(
		[string]$scheduledTasksFolder,
		[string]$logDirectory,		
		[int]$retainValue,		
		[string]$webServerType,
		[string]$scriptPath
	)
	
	if (Test-Path -Path $scheduledTasksFolder) {
		$foo = 'folder exists, no action requried'
	} else {
		& mkdir $scheduledTasksFolder
	}

	$fileContent   = '' 	

$iisLogContent = @"
`$now = Get-Date
$([System.Environment]::NewLine)
Get-ChildItem -Path `"${logDirectory}\*`" -Include *.log -ErrorAction SilentlyContinue | Where-Object { (New-TimeSpan -start `$_.LastWriteTime -end (`$now)).TotalDays -gt ${retainValue} } | Remove-Item -Force	
"@

$apacheTomcatLogContent = @"
`$now = Get-Date
$([System.Environment]::NewLine)
Get-ChildItem -Path `"${logDirectory}\*`" -Include *.log, *.txt -ErrorAction SilentlyContinue | Where-Object { (New-TimeSpan -start `$_.LastWriteTime -end (`$now)).TotalDays -gt ${retainValue} } | Remove-Item -Force
"@		

$apacheLogContent = @"
`$now = Get-Date
$([System.Environment]::NewLine)
& cd `"${logDirectory}`"
$([System.Environment]::NewLine)
Get-Service -Name *apache*   | Stop-Service
$([System.Environment]::NewLine)
Get-ChildItem -Path `"${logDirectory}`" -Include *.log, *.txt -ErrorAction SilentlyContinue | Where-Object { ((New-TimeSpan -start `$_.LastWriteTime -end (`$now)).TotalDays -gt ${retainValue}) } | Remove-Item -Force
$([System.Environment]::NewLine)
'' | Out-File -FilePath `"${logDirectory}\access.log`" -Encoding ascii
$([System.Environment]::NewLine)
'' | Out-File -FilePath `"${logDirectory}\error.log`" -Encoding ascii
$([System.Environment]::NewLine)
Get-Service -Name *apache* | Start-Service		
"@

	if ($webServerType -eq 'IIS') {		
		$fileContent = $iisLogContent		
	} elseif ($webServerType -eq 'ApacheTomcat' ) {
		$fileContent = $apacheTomcatLogContent
	} elseif ($webServertype -eq 'Apache') {
		$fileContent = $apacheLogContent			
	} else {		
		$api.LogScriptEvent('LogdirectoryWatcher.Recovery.DeleteLogs.ps1',3001,1,"Recovery script function (Write-LogDirCleanScript, scriptPath: $($scriptPath)) failed, no valid webServerType (IIS, Apache, ApacheTomcat) received: $($webServerType)")
	}

	if ($fileContent -ne '') {
		$fileContent | Set-Content -Path $scriptPath -Force
	} else {		
		$api.LogScriptEvent('LogdirectoryWatcher.Recovery.DeleteLogs.ps1',3001,1,"Recovery script function (Write-LogDirCleanScript, scriptPath: $($scriptPath)) failed. FileContent: `fileContent is empty")
	}	

	if ($error) {
		$api.LogScriptEvent('LogdirectoryWatcher.Recovery.DeleteLogs.ps1',3001,1,"Recovery script function (Write-LogDirCleanScript, scriptPath: $($scriptPath)) failed. $($error)")		
	} else {
		$foo = 'No error occured'		
	}

} #End Function Write-LogDirCleanScript


Function Invoke-ScheduledTaskCreation {

	param(
		[string]$ComputerName,		
		[string]$taskName
	)         	 		
	
	$taskRunFile         = "C:\WINDOWS\system32\WindowsPowerShell\v1.0\powershell.exe -NoLogo -NonInteractive -File $($scriptPath)"	
	$taskStartTimeOffset = Get-Random -Minimum 1 -Maximum 10
	$taskStartTime       = (Get-Date).AddMinutes($taskStartTimeOffset) | Get-date -Format 'HH:mm'						 						
	$taskSchedule        = 'DAILY'	
	& SCHTASKS /Create /SC $($taskSchedule) /RU `"NT AUTHORITY\SYSTEM`" /TN $($taskName) /TR $($taskRunFile) /ST $($taskStartTime) /F				
		
	if ($error) {
		$api.LogScriptEvent('LogdirectoryWatcher.Recovery.DeleteLogs.ps1',3002,1,"Recovery script function (Invoke-ScheduledTaskCreation) Failure during task creation! $($error)")		
	} else {
		$api.LogScriptEvent('LogdirectoryWatcher.Recovery.DeleteLogs.ps1',3002,4,"Recovery script function (Invoke-ScheduledTaskCreation) succeed.")		
	}	

} #End Function Invoke-ScheduledTaskCreation


Function Save-TaskDateInRegistry {

	param(
		[string]$taskName,
		[string]$scriptPath
	)

	$registryPath = "HKLM:\Software\ABCIT\LogDirectoryWatcher"
	
	$NameOfTask     = @{Name="TaskName"; Value=$taskName}
	$TypeOfTask     = @{Name="TaskType"; Value="Deletion"}
	$scriptLocation = @{Name="ScriptPath"; Value=$scriptPath}

	$regKeys = @($NameOfTask,$TypeOfTask,$scriptLocation)

	foreach($rkey in $regKeys) {
		if ( Test-Path $registryPath)  {
			New-ItemProperty -Path $registryPath -Name $rkey.Name -Value $rkey.Value -PropertyType STRING -Force | Out-Null
		} else {
			New-Item -Path $registryPath -Force | Out-Null
			New-ItemProperty -Path $registryPath -Name $rkey.Name -Value $rkey.Value -PropertyType STRING -Force | Out-Null
		}
	}

} #end Function Save-TaskDateInRegistry


$logDirCleanScriptParams   = @{
	'scheduledTasksFolder' = $scheduledTasksFolder
	'logDirectory'         = $logDirectory	
	'retainValue'          = $daysToKeepLogs	
	'webServerType'        = $webServerType
	'scriptPath'           = $scriptPath
}

Write-LogDirCleanScript @logDirCleanScriptParams


$taskCreationParams = @{
	'ComputerName'  = $ComputerName	
	'taskName'      = $taskName
	'scriptPath'    = $scriptPath
}

Invoke-ScheduledTaskCreation @taskCreationParams


Save-TaskDateInRegistry -taskName $taskName -scriptPath $scriptPath