param($logDirectory,$webServerType,$DaysBeforeDeleteCompressedLogs,$DaysBeforeCompressLogs,$ScheduledTasksFolder)


$api = New-Object -ComObject 'MOM.ScriptAPI'
$api.LogScriptEvent('LogdirectoryWatcher.Recovery.CompressLogs.ps1',4000,2,"Recovery kicks in with Supplement $($LogDirectory) and WebServerType: $($webServerType) and scheduled task folder $($scheduledTasksFolder)")	

$ComputerName         = $env:COMPUTERNAME
      
$logDirectoryClean    = $logDirectory      -Replace('\\','-')
$logDirectoryClean    = $logDirectoryClean -Replace(':','')

$scheduledTasksFolder = $scheduledTasksFolder -replace([char]34,'')
$scheduledTasksFolder = $scheduledTasksFolder -replace("`"",'')
$taskName             = "Auto-Log-Dir-Cleaner_Compress-Delete_for_$($logDirectoryClean)_on_$($ComputerName)"
$taskName             = $taskName -replace '\s',''
$scriptFileName       = $taskName + '.ps1'
$scriptPath           = Join-Path -Path $scheduledTasksFolder -ChildPath $scriptFileName

                       
if (($DaysBeforeCompressLogs -eq $null) -or ($DaysBeforeCompressLogs -notMatch '\d') -or ($DaysBeforeCompressLogs -le 0)) {		
	$msg = 'Script Error. DaysBeforeCompressLogs invalid.  Value: $($DaysBeforeCompressLogs) '
	$api.LogScriptEvent('CreateLogCompressDeletionJob',4100,1,$msg)	
	Exit
}

if ($scheduledTasksFolder -eq $null) {
	$scheduledTasksFolder = 'C:\ScheduledTasks'	
} else {
	$msg = 'Script info. ScheduledTasksFolder not defined. Defaulting to C:\ScheduledTasks'
	$api.LogScriptEvent('CreateLogCompressDeletionJob',4100,2,$msg)		
}

if ($logDirectory -match 'ThelogDirectory') {
	$msg =  'CreateLogCompressDeletionJob.ps1 - Script Error. logDirectory not defined. Script ends.'
	$api.LogScriptEvent('CreateLogCompressDeletionJob',4100,1,$msg)	
	Exit
}


Function Write-LogDirCleanScript {

	param(
		[string]$scheduledTasksFolder,
		[string]$logDirectory,		
		[int]$DaysBeforeCompressLogs,
		[int]$DaysBeforeDeleteCompressedLogs,
		[string]$webServerType,
		[string]$scriptPath
	)
	
	if (Test-Path -Path $scheduledTasksFolder) {
		$foo = 'folder exists, no action requried'
	} else {
		& mkdir $scheduledTasksFolder
	}
	
	if (Test-Path -Path $logDirectory) {
		$foo = 'folder exists, no action requried'
	} else {
		$msg = "Script function (Write-LogDirCleanScript, scriptPath: $($scriptPath)) failed. logDirectory not found $($logDirectory)"
		Write-Warning -Message $msg
		$api.LogScriptEvent('CreateLogCompressDeletionJob',4101,1,$msg)		
		Exit
	}

	$fileContent   = '' 	

	if ($webServerType -eq 'IIS') {	
		$LogFileTypes =  '*.log'
	} elseif ($webServerType -eq 'ApacheTomcat' ) {
		$LogFileTypes =  '*.log, *.txt'
	}  elseif ($webServertype -eq 'Apache') {
		$LogFileTypes =  '*.log'
	} else {		
		$api.LogScriptEvent('LogdirectoryWatcher.Recovery.CompressLogs.ps1',4001,1,"Recovery script function (Write-LogDirCleanScript, scriptPath: $($scriptPath)) failed, no valid webServerType (IIS, Apache, ApacheTomcat) received: $($webServerType)")
	}


	#ISSUE! - If Apache it must be the log-creation-day, not the modification day!

$fileContent = @"
if (`"${webServerType}`" -eq "Apache") {
	$([System.Environment]::NewLine)
	Get-Service -Name *apache*   | Stop-Service
	$([System.Environment]::NewLine)
} else {
	$([System.Environment]::NewLine)
	`$foo = 'Keep services running'
}
$([System.Environment]::NewLine)
& cd `"${logDirectory}`"
$([System.Environment]::NewLine)
`$timeStamp = Get-Date -Format 'yyyy-MM-dd_hh-mm'
$([System.Environment]::NewLine)
`$now = Get-Date
$([System.Environment]::NewLine)
`$tmpLogFolder = `"${logDirectory}`" + '_CompressLogsOn_' + `$timeStamp
$([System.Environment]::NewLine)
if (Test-Path -Path `$tmpLogFolder) {
$([System.Environment]::NewLine)
	`$foo = 'No action required, folder exists.'
$([System.Environment]::NewLine)
} else {
$([System.Environment]::NewLine)
	& mkdir `$tmpLogFolder
$([System.Environment]::NewLine)
}
$([System.Environment]::NewLine)
`$logDirectoryParent = `$tmpLogFolder.SubString(0,`$tmpLogFolder.LastIndexOf('\')) + '\'
$([System.Environment]::NewLine)
try {
	$([System.Environment]::NewLine)
	`$targetLogZip = `"${logDirectory}`" + '_CompressLogsOn_' + `$timeStamp + '.zip'
	$([System.Environment]::NewLine)	
	Add-Type -AssemblyName 'System.IO.Compression.FileSystem'
	$([System.Environment]::NewLine)	
	if (`"${webServerType}`" -eq "Apache") {
		$([System.Environment]::NewLine)
		Get-ChildItem -Path `"${logDirectory}\*`" -Include ${LogFileTypes} -ErrorAction SilentlyContinue | Where-Object { (New-TimeSpan -start `$_.CreationTime -end (`$now)).TotalDays -gt ${DaysBeforeCompressLogs} } | ForEach-Object {
			$([System.Environment]::NewLine)	
			Move-Item -Path `$_ -Destination `$tmpLogFolder				
			$([System.Environment]::NewLine)
		}
		$([System.Environment]::NewLine)
	} else {
		$([System.Environment]::NewLine)
		Get-ChildItem -Path `"${logDirectory}\*`" -Include ${LogFileTypes} -ErrorAction SilentlyContinue | Where-Object { (New-TimeSpan -start `$_.LastWriteTime -end (`$now)).TotalDays -gt ${DaysBeforeCompressLogs} } | ForEach-Object {
			$([System.Environment]::NewLine)	
			Move-Item -Path `$_ -Destination `$tmpLogFolder				
			$([System.Environment]::NewLine)
		}	
		$([System.Environment]::NewLine)
	}
	$([System.Environment]::NewLine)
	[System.IO.Compression.ZipFile]::CreateFromDirectory(`$tmpLogFolder,`$targetLogZip)	
	$([System.Environment]::NewLine)
	Get-ChildItem -Path `$tmpLogFolder -Recurse | ForEach-Object {
		$([System.Environment]::NewLine)
		Remove-Item -Path `$_.FullName
		$([System.Environment]::NewLine)
	}
	$([System.Environment]::NewLine)
	Remove-Item -Path `$tmpLogFolder
	$([System.Environment]::NewLine)	
	if ( ${DaysBeforeDeleteCompressedLogs} -gt 0 ) {
		$([System.Environment]::NewLine)
		Get-ChildItem -Path `$logDirectoryParent -Filter '*_CompressLogsOn_*.zip' -ErrorAction SilentlyContinue | Where-Object { (New-TimeSpan -start `$_.LastWriteTime -end (`$now)).TotalDays -gt ${DaysBeforeDeleteCompressedLogs} } | Remove-Item -Force		
		$([System.Environment]::NewLine)
	}
	$([System.Environment]::NewLine)

} catch {
	$([System.Environment]::NewLine)
	if (`"${webServerType}`" -eq "Apache") {
		$([System.Environment]::NewLine)
		Get-ChildItem -Path `"${logDirectory}\*`" -Include ${LogFileTypes} -ErrorAction SilentlyContinue | Where-Object { ((New-TimeSpan -start `$_.CreationTime -end (`$now)).TotalDays -gt ${DaysBeforeCompressLogs}) -and(`$_.Attributes -notMatch 'Compressed') } | ForEach-Object {	
			$([System.Environment]::NewLine)
			Move-Item -Path `$_ -Destination `$tmpLogFolder		
			$([System.Environment]::NewLine)
		}
		$([System.Environment]::NewLine)
	} else {
		$([System.Environment]::NewLine)
		Get-ChildItem -Path `"${logDirectory}\*`" -Include ${LogFileTypes} -ErrorAction SilentlyContinue | Where-Object { ((New-TimeSpan -start `$_.LastWriteTime -end (`$now)).TotalDays -gt ${DaysBeforeCompressLogs}) -and(`$_.Attributes -notMatch 'Compressed') } | ForEach-Object {	
			$([System.Environment]::NewLine)
			Move-Item -Path `$_ -Destination `$tmpLogFolder		
			$([System.Environment]::NewLine)
		}
		$([System.Environment]::NewLine)	
	}
	$([System.Environment]::NewLine)	
	& COMPACT /I /Q /C /S:`$tmpLogFolder    	
	$([System.Environment]::NewLine)

	if ( ${DaysBeforeDeleteCompressedLogs} -gt 0 ) {
		$([System.Environment]::NewLine)
		Get-ChildItem -Path "`$(`$logDirectoryParent)*_CompressLogsOn_*" -Recurse -ErrorAction SilentlyContinue | Where-Object { ((New-TimeSpan -start `$_.LastWriteTime -end (`$now)).TotalDays -gt ${DaysBeforeDeleteCompressedLogs}) -and (`$_.Attributes -match 'Compressed') } | Remove-Item -Force		
		$([System.Environment]::NewLine)
		Get-ChildItem -Path "`$(`$logDirectoryParent)*_CompressLogsOn_*" -ErrorAction SilentlyContinue | Where-Object { ((New-TimeSpan -start `$_.CreationTime -end (`$now)).TotalDays -gt ${DaysBeforeDeleteCompressedLogs}) -and (`$_.Attributes -match 'Compressed') } | Remove-Item -Force		
		$([System.Environment]::NewLine)
	}
	$([System.Environment]::NewLine)

}
$([System.Environment]::NewLine)
if (`"${webServerType}`" -eq "Apache") {
	$([System.Environment]::NewLine)
	'' | Out-File -FilePath `"${logDirectory}\access.log`" -Encoding ascii 
	$([System.Environment]::NewLine)
	'' | Out-File -FilePath `"${logDirectory}\error.log`" -Encoding ascii
	$([System.Environment]::NewLine)

	$([System.Environment]::NewLine)
	Get-Service -Name *apache* | Start-Service
	$([System.Environment]::NewLine)
} else {
	$([System.Environment]::NewLine)
	`$foo = 'Keep services running'
}
$([System.Environment]::NewLine)
"@

	if ($fileContent -ne '') {
		$fileContent | Set-Content -Path $scriptPath -Force
	} else {		
		$api.LogScriptEvent('LogdirectoryWatcher.Recovery.CompressLogs.ps1',4001,1,"Recovery script function (Write-LogDirCleanScript, scriptPath: $($scriptPath)) failed. FileContent: `fileContent is empty")
	}	

	if ($error) {
		$api.LogScriptEvent('LogdirectoryWatcher.Recovery.CompressLogs.ps1',4001,1,"Recovery script function (Write-LogDirCleanScript, scriptPath: $($scriptPath)) failed. $($error)")		
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
	$taskStartTimeOffset = 5
	$taskStartTime       = (Get-Date).AddMinutes($taskStartTimeOffset) | Get-date -Format 'HH:mm'						 						
	$taskSchedule        = 'DAILY'	
	& SCHTASKS /Create /SC $($taskSchedule) /RU `"NT AUTHORITY\SYSTEM`" /TN $($taskName) /TR $($taskRunFile) /ST $($taskStartTime) /F			
		
	if ($error) {
		$api.LogScriptEvent('LogdirectoryWatcher.Recovery.CompressLogs.ps1',4002,1,"Recovery script function (Invoke-ScheduledTaskCreation) Failure during task creation! $($error)")		
	} else {
		$api.LogScriptEvent('LogdirectoryWatcher.Recovery.CompressLogs.ps1',4002,4,"Recovery script function (Invoke-ScheduledTaskCreation) succeed.")		
	}	

} #End Function Invoke-ScheduledTaskCreation


Function Save-TaskDateInRegistry {

	param(
		[string]$taskName,
		[string]$scriptPath
	)

	$registryPath = "HKLM:\Software\ABCIT\LogDirectoryWatcher"
	
	$NameOfTask     = @{Name="TaskName"; Value=$taskName}
	$TypeOfTask     = @{Name="TaskType"; Value="Compression ( + Deletion )"}
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


$logDirCleanScriptParams = @{
	'scheduledTasksFolder'           = $scheduledTasksFolder
	'logDirectory'                   = $logDirectory	
	'DaysBeforeCompressLogs'         = $DaysBeforeCompressLogs	
	'DaysBeforeDeleteCompressedLogs' = $DaysBeforeDeleteCompressedLogs
	'webServerType'                  = $webServerType
	'scriptPath'                     = $scriptPath
}

Write-LogDirCleanScript @logDirCleanScriptParams


$taskCreationParams = @{
	'ComputerName'  = $ComputerName	
	'taskName'      = $taskName
	'scriptPath'    = $scriptPath
}

Invoke-ScheduledTaskCreation @taskCreationParams


Save-TaskDateInRegistry -taskName $taskName -scriptPath $scriptPath