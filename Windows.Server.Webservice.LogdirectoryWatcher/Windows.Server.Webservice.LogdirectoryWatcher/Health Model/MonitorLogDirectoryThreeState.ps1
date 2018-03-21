﻿param($MonitorItem,$WarningThresholdMegaBytes,$ErrorThresholdMegaBytes)

$WarningThresholdMegaBytes = [double]::Parse($WarningThresholdMegaBytes)
$ErrorThresholdMegaBytes   = [double]::Parse($ErrorThresholdMegaBytes)

$Error.Clear()
$ErrorActionPreference = 'Stop'

$api = New-Object -ComObject 'MOM.ScriptAPI'

$computerName        = $env:COMPUTERNAME
$timeZone            =  ([TimeZoneInfo]::Local).Id
$testedAt            = "Tested on: $(Get-Date -Format u) / $(([TimeZoneInfo]::Local).DisplayName)"
$scanDate            = Get-Date -Format 'yyyy-MM-dd hh:MM:ss' 
$WindowsVersion      = Get-WmiObject -Class Win32_OperatingSystem | Select-Object -ExpandProperty Caption

try {
	$computerDescription = Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\services\LanmanServer\Parameters | Select-Object -ExpandProperty srvcomment
} catch {
	$computerDescription = [string]::Empty
}

$localComputerDomain = ([System.DirectoryServices.ActiveDirectory.Domain]::GetComputerDomain()).Name
$computerName        = $computerName + '.' + $localComputerDomain

$api.LogScriptEvent('MonitorLogDirectoryThreeState.ps1',300,4,"On computer $($computerName) with searching for $($MonitorItem)")	

if (([string]::IsNullOrEmpty($computerDescription)) -or ([string]::IsNullOrWhiteSpace($computerDescription))) {
	$computerDescription = 'Not-Maintained'
} else {
	$noActionRequiredSo  = 'Keep description'
}

Function Send-PropertyBag {

	param(
		[string]$Key,
		[string]$supplement,
		[string]$logDirPath,
		[string]$logDirModifiedDate,
		[double]$logDirNoOfFiles,
		[double]$logDirSize
	)

	if ($logDirSize -lt $WarningThresholdMegaBytes -and $logDirSize -lt $ErrorThresholdMegaBytes) {
		$state = 'Green'
	} elseif ($logDirSize -ge $WarningThresholdMegaBytes -and $logDirSize -lt $ErrorThresholdMegaBytes) {
		$state = 'Yellow'
	} elseif ($logDirSize -ge $ErrorThresholdMegaBytes) {
		$state = 'Red'
	} else {
		$state = 'Red'
	}

	$supplement  = "`nLog Directory Path: $logDirPath `n"
	$supplement += "Log Directory Modification Date: $logDirModifiedDate `n"
	$supplement += "Log Directory Number of Files: $logDirNoOfFiles `n"
	$supplement += "Log Directory Size in MB: $logDirSize `t"
	$supplement += "Warning threshold in MB: $WarningThresholdMegaBytes `t"
	$supplement += "Error threshold in MB: $ErrorThresholdMegaBytes `n" 	

	#$api.LogScriptEvent('MonitorLogDirectoryThreeState.ps1',302,2,"Send Bag for $($displayName)`n State: $($state) `n Supplement: $($supplement) `n Key: $($Key)`n testedAt $($testedAt)")
						
	$bag = $api.CreatePropertybag()					
	$bag.AddValue("Key",$Key)		
	$bag.AddValue("State",$state)
	$bag.AddValue("testedAt",$testedAt)
	$bag.AddValue("Supplement",$supplement)
	$bag.AddValue("WindowsVersion",$WindowsVersion)
	$bag.AddValue("ComputerDescription",$computerDescription)
	$bag

} 


if ($MonitorItem -eq 'IIS') {

	Import-Module -Name Webadministration
		
	$webSitesIIS   = Get-Website | Select-Object -Property name, id, state, physicalpath, 
			@{Name = "Bindings"; Expression = { ($_.bindings | Select-Object -ExpandProperty collection) -join ';' }} , 
			@{Name = "LogFile"; Expression = { $_.logfile | Select-Object -ExpandProperty directory }} 

	$api.LogScriptEvent('MonitorLogDirectoryThreeState.ps1',301,4,"Found IIS Websites No: $($webSitesIIS.count)")	

	$webSitesAll = New-Object -TypeName System.Collections.ArrayList

	foreach ($webSite in $webSitesIIS) {

		$webBindings = $webSite.Bindings 

		if ($webBindings -match 'http') {
			$webType = 'W3SVC'
		} 

		if ($webBindings -match 'ftp') {
			$webType = 'FTPSVC'
		}
	
		$webSiteId       = 0
		$null            = [double]::TryParse($webSite.id,[ref]$webSiteId)
		$webLogRootDir   = $webSite.LogFile		
		$webLogDirectory = $webSite.LogFile + '\' + $webType + $webSiteId

		if ($webLogDirectory -match 'SystemDrive') {
			$webLogDirectory = $webLogDirectory -replace '%SystemDrive%','C:'
		} 
		
		if (Test-Path -Path $webLogDirectory) {
			$webLogDirTmp         = Get-Item -Path $webLogDirectory | Select-Object -Property Name, LastWriteTime, CreationTime
			$webLogDirLastChanged = $webLogDirTmp | Select-Object -ExpandProperty LastWriteTime | Get-Date -Format 'yyyy-MM-dd hh:MM:ss' 
			$webLogDirCreated     = $webLogDirTmp | Select-Object -ExpandProperty CreationTime  | Get-Date -Format 'yyyy-MM-dd hh:MM:ss' 
		    $webLogDirNoOfFiles   = 0	
			$null                 = [double]::TryParse((Get-ChildItem -Path $webLogDirectory).Count,[ref]$webLogDirNoOfFiles)		
			$webLogDirSizeMB      = 0
			$null                 = [double]::TryParse(([Math]::Round(((Get-ChildItem -Path $webLogDirectory | Measure-Object -property length -sum).Sum / 1MB), 1)),[ref]$webLogDirSizeMB)
		} elseif (Test-Path -Path $webLogRootDir) {
			$webLogDirectory      = $webLogRootDir
			$webLogDirTmp         = Get-Item -Path $webLogDirectory | Select-Object -Property Name, LastWriteTime, CreationTime
			$webLogDirLastChanged = $webLogDirTmp | Select-Object -ExpandProperty LastWriteTime | Get-Date -Format 'yyyy-MM-dd hh:MM:ss' 
			$webLogDirCreated     = $webLogDirTmp | Select-Object -ExpandProperty CreationTime  | Get-Date -Format 'yyyy-MM-dd hh:MM:ss' 
			$webLogDirNoOfFiles   = 0	
			$null                 = [double]::TryParse((Get-ChildItem -Path $webLogDirectory).Count,[ref]$webLogDirNoOfFiles)		
			$webLogDirSizeMB      = 0
			$null                 = [double]::TryParse(([Math]::Round(((Get-ChildItem -Path $webLogDirectory | Measure-Object -property length -sum).Sum / 1MB), 1)),[ref]$webLogDirSizeMB)
		} else {
			$webLogDirectory      = 'Not found: ' + $webLogDirectory
			$webLogDirLastChanged = 'Na'
			$webLogDirCreated     = 'Na'
			$webLogDirNoOfFiles   = [double]::Parse('0')
			$webLogDirSizeMB      = [double]::Parse('0')
		}
	
		$logInfoHash = @{'SiteName' = $webSite.name}
		$logInfoHash.Add('SiteId', $webSiteId)  
		$logInfoHash.Add('Status', $webSite.state)  
		$logInfoHash.Add('SitePath', $webSite.physicalPath)
		$logInfoHash.Add('Bindings', $webBindings)
		$logInfoHash.Add('LogDirScanDate', $scanDate) 
		$logInfoHash.Add('TimeZone', $timeZone)
		$logInfoHash.Add('LogDirPath', $webLogDirectory)  
		$logInfoHash.Add('LogDirModifiedDate', $webLogDirLastChanged)    
		$logInfoHash.Add('LogDirCreationDate', $webLogDirCreated)    
		$logInfoHash.Add('LogDirNoOfFiles', $webLogDirNoOfFiles)    
		$logInfoHash.Add('LogDirSizeInMB', $webLogDirSizeMB)   
		$logInfoObj = New-Object -TypeName psobject -Property $logInfoHash
		$null       = $webSitesAll.Add($logInfoObj)		

	} 
	
	foreach ($wbSite in $webSitesAll) {
						
		$Key         = $ComputerName + '-' + $($wbSite.SiteName)
		$Key         = $Key -replace ' ','_'
		$displayName = 'IISWebSite ' + $($wbSite.SiteName) + ' On ' + $ComputerName		
	
		Send-PropertyBag -Key $Key -supplement $supplement -logDirSize $wbSite.LogDirSizeInMB -logDirPath $wbSite.LogDirPath `
						 -logDirModifiedDate $wbSite.LogDirModifiedDate  -logDirNoOfFiles $wbSite.LogDirNoOfFiles 		

	} 

} elseIf ($MonitorItem -eq 'Apache') {

	$apacheReg = Get-ChildItem -Path HKLM:\SYSTEM\CurrentControlSet\services\Apa* | Select-Object -ExpandProperty Name
	$apacheReg = $apacheReg -replace 'HKEY_LOCAL_MACHINE','HKLM:\\'

	$apachePath        = Get-ItemProperty -Path $apacheReg | Select-Object -ExpandProperty ImagePath
	$apacheDescription = Get-ItemProperty -Path $apacheReg | Select-Object -ExpandProperty Description
	$apacheDisplayName = Get-ItemProperty -Path $apacheReg | Select-Object -ExpandProperty DisplayName

	$apacheBaseDirectory = [Regex]::Matches($apachePath,'(?i)[a-z\\0-9\.()_\-: ]{1,}(?=bin\\httpd.exe)') | Select-Object -ExpandProperty Value 
	$apacheLogDirectory  = $apacheBaseDirectory + 'logs'

	$apacheVersion = $apacheReg.Substring($apacheReg.LastIndexOf('\'),($apacheReg.Length - $apacheReg.LastIndexOf('\'))) 
	$apacheVersion = $apacheVersion -replace '\\',''
	
	if (Test-Path -Path $apacheLogDirectory) {
		$webLogDirTmp         = Get-Item -Path $apacheLogDirectory | Select-Object -Property Name, LastWriteTime, CreationTime
		$webLogDirLastChanged = $webLogDirTmp | Select-Object -ExpandProperty LastWriteTime | Get-Date -Format 'yyyy-MM-dd hh:MM:ss' 
		$webLogDirCreated     = $webLogDirTmp | Select-Object -ExpandProperty CreationTime  | Get-Date -Format 'yyyy-MM-dd hh:MM:ss' 
		$webLogDirNoOfFiles   = (Get-ChildItem -Path $apacheLogDirectory).Count		
		$webLogDirSizeMB      = [Math]::Round(((Get-ChildItem -Path $apacheLogDirectory | Measure-Object -property length -sum).Sum / 1MB), 1)	
	} else {
		$webLogDirectory      = 'Not found: ' + $webLogDirectory
		$webLogDirLastChanged = 'Na'
		$webLogDirCreated     = 'Na'
		$webLogDirNoOfFiles   = [double]::Parse('0')
		$webLogDirSizeMB      = [double]::Parse('0')
	}		
	
	$Key         = $ComputerName + '-' + 'ApacheWebSite'
	$displayName = 'ApacheWebSite ' + ' On ' + $ComputerName			
	
	Send-PropertyBag -Key $Key -supplement $supplement -logDirSize $webLogDirSizeMB -logDirPath $wbSite.LogDirPath `
						-logDirModifiedDate $wbSite.LogDirModifiedDate  -logDirNoOfFiles $wbSite.LogDirNoOfFiles 		
	
} elseIf ($MonitorItem -eq 'ApacheTomcat') {

	$apacheReg = Get-ChildItem -Path HKLM:\SYSTEM\CurrentControlSet\services\Tomcat* | Select-Object -ExpandProperty Name
	$apacheReg = $apacheReg -replace 'HKEY_LOCAL_MACHINE','HKLM:\\'

	$apachePath        = Get-ItemProperty -Path $apacheReg | Select-Object -ExpandProperty ImagePath
	$apacheDescription = Get-ItemProperty -Path $apacheReg | Select-Object -ExpandProperty Description
	$apacheDisplayName = Get-ItemProperty -Path $apacheReg | Select-Object -ExpandProperty DisplayName

	$apacheBaseDirectory = [Regex]::Matches($apachePath,'(?i)[a-z\\0-9\._()\-: ]{1,}(?=bin\\tomcat\d{1}.exe)') | Select-Object -ExpandProperty Value 
	$apacheLogDirectory  = $apacheBaseDirectory + 'logs'

	$apacheVersion = $apacheReg.Substring($apacheReg.LastIndexOf('\'),($apacheReg.Length - $apacheReg.LastIndexOf('\'))) 
	$apacheVersion = $apacheVersion -replace '\\',''
	
	if (Test-Path -Path $apacheLogDirectory) {
		$webLogDirTmp         = Get-Item -Path $apacheLogDirectory | Select-Object -Property Name, LastWriteTime, CreationTime
		$webLogDirLastChanged = $webLogDirTmp | Select-Object -ExpandProperty LastWriteTime | Get-Date -Format 'yyyy-MM-dd hh:MM:ss' 
		$webLogDirCreated     = $webLogDirTmp | Select-Object -ExpandProperty CreationTime  | Get-Date -Format 'yyyy-MM-dd hh:MM:ss' 
		$webLogDirNoOfFiles   = (Get-ChildItem -Path $apacheLogDirectory).Count		
		$webLogDirSizeMB      = [Math]::Round(((Get-ChildItem -Path $apacheLogDirectory | Measure-Object -property length -sum).Sum / 1MB), 1)
	} else {
		$webLogDirectory      = 'Not found: ' + $webLogDirectory
		$webLogDirLastChanged = 'Na'
		$webLogDirCreated     = 'Na'
		$webLogDirNoOfFiles   = [double]::Parse('0')
		$webLogDirSizeMB      = [double]::Parse('0')
	}			
		
	$Key         = $ComputerName + '-' + 'ApacheTomcatWebSite'
	$displayName = 'ApacheTomcatWebSite ' + ' On ' + $ComputerName
		
	Send-PropertyBag -Key $Key -supplement $supplement -logDirSize $webLogDirSizeMB -logDirPath $wbSite.LogDirPath `
						-logDirModifiedDate $wbSite.LogDirModifiedDate  -logDirNoOfFiles $wbSite.LogDirNoOfFiles 		

} else {

	$api.LogScriptEvent('MonitorLogDirectoryThreeState.ps1',300,1,"On computer $($computerName) with searching for unconsidered $($MonitorItem)")	

}