param($sourceId,$managedEntityId,$discoveryItem)

$api                 = New-Object -ComObject 'MOM.ScriptAPI'
$discoveryData       = $api.CreateDiscoveryData(0, $sourceId, $managedEntityId)

$computerName        = $env:COMPUTERNAME
$timeZone            =  ([TimeZoneInfo]::Local).Id
$scanDate            = Get-Date -Format 'yyyy-MM-dd hh:MM:ss' 
$WindowsVersion      = Get-WmiObject -Class Win32_OperatingSystem | Select-Object -ExpandProperty Caption

try {
	$computerDescription = Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\services\LanmanServer\Parameters | Select-Object -ExpandProperty srvcomment
} catch {
	$computerDescription = [string]::Empty
}

$localComputerDomain = ([System.DirectoryServices.ActiveDirectory.Domain]::GetComputerDomain()).Name
$computerName        = $computerName + '.' + $localComputerDomain

$api.LogScriptEvent('DiscoverLogDirectoryWachterItmes.ps1',200,4,"On computer $($computerName) with searching for $($discoveryItem)")	

if (([string]::IsNullOrEmpty($computerDescription)) -or ([string]::IsNullOrWhiteSpace($computerDescription))) {
	$computerDescription = 'Description-Not-Maintained'
} else {
	$noActionRequiredSo  = 'Keep description'
}
 

if ($discoveryItem -eq 'IIS') {

	Import-Module -Name Webadministration
		
	$webSitesIIS   = Get-Website | Select-Object -Property name, id, state, physicalpath, 
			@{Name = "Bindings"; Expression = { ($_.bindings | Select-Object -ExpandProperty collection) -join ';' }} , 
			@{Name = "LogFile"; Expression = { $_.logfile | Select-Object -ExpandProperty directory }} 

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
			
			try {
				$rawLogDirNoOfFiles   = 0	
				$rawLogDirNoOfFiles   = (Get-ChildItem -Path $webLogDirectory).Count
				$webLogDirNoOfFiles   = $rawLogDirNoOfFiles -as [double]

				$rawLogDirSize        = (Get-ChildItem -Path $webLogDirectory | Measure-Object -property length -sum).Sum / 1MB
				$doubleLogDirSize     = $rawLogDirSize -as [double]
				$webLogDirSizeMB      = [Math]::Round($doubleLogDirSize, 1)
			} catch {
				$rawLogDirNoOfFiles   = 0	
				$webLogDirSizeMB      = 0
				
				$exceptionFullName    = $_.Exception.GetType().FullName
				$exceptionMessage     = $_.Exception.Message

				$api.LogScriptEvent('DiscoverLogDirectoryWachterItmes.ps1',200,1,"Computer: $($computerName) checking for unconsidered $($discoveryItem) got errors for rawSize: $($doubleLogDirSize). `n $($exceptionFullName) `n $($exceptionMessage)")	
			}
			
		} elseif (Test-Path -Path $webLogRootDir) {
			$webLogDirectory      = $webLogRootDir
			$webLogDirTmp         = Get-Item -Path $webLogDirectory | Select-Object -Property Name, LastWriteTime, CreationTime
			$webLogDirLastChanged = $webLogDirTmp | Select-Object -ExpandProperty LastWriteTime | Get-Date -Format 'yyyy-MM-dd hh:MM:ss' 
			$webLogDirCreated     = $webLogDirTmp | Select-Object -ExpandProperty CreationTime  | Get-Date -Format 'yyyy-MM-dd hh:MM:ss' 

			try { 
				$rawLogDirNoOfFiles   = 0	
				$rawLogDirNoOfFiles   = (Get-ChildItem -Path $webLogDirectory).Count
				$webLogDirNoOfFiles   = $rawLogDirNoOfFiles -as [double]

				$rawLogDirSize        = (Get-ChildItem -Path $webLogDirectory | Measure-Object -property length -sum).Sum / 1MB
				$doubleLogDirSize     = $rawLogDirSize -as [double]
				$webLogDirSizeMB      = [Math]::Round($doubleLogDirSize, 1)
			} catch {
				$rawLogDirNoOfFiles   = 0	
				$webLogDirSizeMB      = 0
				
				$exceptionFullName    = $_.Exception.GetType().FullName
				$exceptionMessage     = $_.Exception.Message

				$api.LogScriptEvent('DiscoverLogDirectoryWachterItmes.ps1',200,1,"Computer: $($computerName) checking for unconsidered $($discoveryItem) got errors for rawSize: $($doubleLogDirSize). `n $($exceptionFullName) `n $($exceptionMessage)")	
			}
			
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

	} #End foreach ($webSite in $webSitesIIS)
	
	foreach ($wbSite in $webSitesAll) {
		
		$healthInstance = $discoveryData.CreateClassInstance("$MPElement[Name='SC!Microsoft.SystemCenter.HealthService']$")		
		$healthInstance.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $computerName)			
		$discoveryData.AddInstance($healthInstance)		
		
		$Key         = $ComputerName + '-' + $($wbSite.SiteName)
		$key         = $Key -replace ' ','_'
		$displayName = 'IISWebSite ' + $($wbSite.SiteName) + ' On ' + $ComputerName

		$instance = $discoveryData.CreateClassInstance("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.IIS']$")
		$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.Base']/ComputerName$",$ComputerName)
		$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.Base']/WindowsVersion$",$WindowsVersion)
		$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.Base']/ComputerDescription$",$computerDescription)					
		$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.Base']/TimeZone$",$wbSite.TimeZone)	
		$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.Base']/LogDirPath$",$wbSite.LogDirPath)	
		$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.Base']/LogDirCreationDate$",$wbSite.LogDirCreationDate)	
		$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.Base']/LogDirModifiedDate$",$wbSite.LogDirModifiedDate)		
		$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.Base']/LogDirScanDate$",$wbSite.LogDirScanDate)
		$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.Base']/LogDirSizeInMB$",$wbSite.LogDirSizeInMB)
		$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.Base']/LogDirNoOfFiles$",$wbSite.LogDirNoOfFiles)			
		$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.IIS']/SiteName$",$wbSite.SiteName)	
		$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.IIS']/Bindings$",$wbSite.Bindings)	
		$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.IIS']/SiteId$",$wbSite.SiteId)	
		$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.IIS']/SitePath$",$wbSite.SitePath)	
		$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.IIS']/Key$",$Key)
		$instance.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $displayName)
		$discoveryData.AddInstance($instance)	
				
		$relHealthInstance        = $discoveryData.CreateRelationShipInstance("$MPElement[Name='SC!Microsoft.SystemCenter.HealthServiceShouldManageEntity']$")
		$relHealthInstance.Source = $healthInstance
		$relHealthInstance.Target = $instance									
		$discoveryData.AddInstance($relHealthInstance)
		
	} #End foreach ($wbSite in $webSitesAll)	

} elseIf ($discoveryItem -eq 'Apache') {

	$apacheReg = Get-ChildItem -Path HKLM:\SYSTEM\CurrentControlSet\services\Apa* | Select-Object -ExpandProperty Name
	$apacheReg = $apacheReg -replace 'HKEY_LOCAL_MACHINE','HKLM:\\'

	$apachePath = Get-ItemProperty -Path $apacheReg | Select-Object -ExpandProperty ImagePath
	$apacheDescription = Get-ItemProperty -Path $apacheReg | Select-Object -ExpandProperty Description
	$apacheDisplayName = Get-ItemProperty -Path $apacheReg | Select-Object -ExpandProperty DisplayName

	$apacheBaseDirectory = [Regex]::Matches($apachePath,'(?i)[a-z\\0-9\.()_\-: ]{1,}(?=bin\\httpd.exe)') | Select-Object -ExpandProperty Value 
	$apacheLogDirectory = $apacheBaseDirectory + 'logs'

	$apacheVersion = $apacheReg.Substring($apacheReg.LastIndexOf('\'),($apacheReg.Length - $apacheReg.LastIndexOf('\'))) 
	$apacheVersion = $apacheVersion -replace '\\',''
	
	if (Test-Path -Path $apacheLogDirectory) {
		$webLogDirTmp         = Get-Item -Path $apacheLogDirectory | Select-Object -Property Name, LastWriteTime, CreationTime
		$webLogDirLastChanged = $webLogDirTmp | Select-Object -ExpandProperty LastWriteTime | Get-Date -Format 'yyyy-MM-dd hh:MM:ss' 
		$webLogDirCreated     = $webLogDirTmp | Select-Object -ExpandProperty CreationTime  | Get-Date -Format 'yyyy-MM-dd hh:MM:ss' 
				
		try { 
			$rawLogDirNoOfFiles   = 0	
			$rawLogDirNoOfFiles   = (Get-ChildItem -Path $apacheLogDirectory).Count
			$webLogDirNoOfFiles   = $rawLogDirNoOfFiles -as [double]

			$rawLogDirSize        = (Get-ChildItem -Path $apacheLogDirectory | Measure-Object -property length -sum).Sum / 1MB
			$doubleLogDirSize     = $rawLogDirSize -as [double]
			$webLogDirSizeMB      = [Math]::Round($doubleLogDirSize, 1)
		} catch {
			$rawLogDirNoOfFiles   = 0	
			$webLogDirSizeMB      = 0
				
			$exceptionFullName    = $_.Exception.GetType().FullName
			$exceptionMessage     = $_.Exception.Message

			$api.LogScriptEvent('DiscoverLogDirectoryWachterItmes.ps1',200,1,"Computer: $($computerName) checking for unconsidered $($discoveryItem) got errors for rawSize: $($doubleLogDirSize). `n $($exceptionFullName) `n $($exceptionMessage)")	
		}

	} else {
		$webLogDirectory      = 'Not found: ' + $webLogDirectory
		$webLogDirLastChanged = 'Na'
		$webLogDirCreated     = 'Na'
		$webLogDirNoOfFiles   = [double]::Parse('0')
		$webLogDirSizeMB      = [double]::Parse('0')
	}	
		
	$healthInstance = $discoveryData.CreateClassInstance("$MPElement[Name='SC!Microsoft.SystemCenter.HealthService']$")		
	$healthInstance.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $computerName)			
	$discoveryData.AddInstance($healthInstance)		
	
	$Key         = $ComputerName + '-' + 'ApacheWebSite'
	$key         = $Key -replace ' ','_'
	$displayName = 'ApacheWebSite ' + ' On ' + $ComputerName

	$instance = $discoveryData.CreateClassInstance("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.Apache']$")			
	$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.Base']/ComputerName$",$ComputerName)
	$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.Base']/WindowsVersion$",$WindowsVersion)
	$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.Base']/ComputerDescription$",$computerDescription)				
	$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.Base']/TimeZone$",$timeZone)	
	$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.Base']/LogDirPath$",$apacheLogDirectory)	
	$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.Base']/LogDirCreationDate$",$webLogDirCreated)	
	$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.Base']/LogDirModifiedDate$",$webLogDirLastChanged)	
	$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.Base']/LogDirScanDate$",$scanDate)	
	$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.Base']/LogDirSizeInMB$",$webLogDirSizeMB)	
	$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.Base']/LogDirNoOfFiles$",$webLogDirNoOfFiles)			
	$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.ApacheBase']/SvcVersion$",$apacheVersion)			
	$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.ApacheBase']/SvcDisplayName$",$apacheDisplayName)			
	$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.ApacheBase']/SvcDescription$",$apacheDescription)	
	$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.ApacheBase']/Key$",$Key)
	$instance.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $displayName)
	$discoveryData.AddInstance($instance)	
		
	$relHealthInstance        = $discoveryData.CreateRelationShipInstance("$MPElement[Name='SC!Microsoft.SystemCenter.HealthServiceShouldManageEntity']$")
	$relHealthInstance.Source = $healthInstance
	$relHealthInstance.Target = $instance									
	$discoveryData.AddInstance($relHealthInstance)
	
} elseIf ($discoveryItem -eq 'ApacheTomcat') {

	$apacheReg = Get-ChildItem -Path HKLM:\SYSTEM\CurrentControlSet\services\Tomcat* | Select-Object -ExpandProperty Name
	$apacheReg = $apacheReg -replace 'HKEY_LOCAL_MACHINE','HKLM:\\'

	$apachePath = Get-ItemProperty -Path $apacheReg | Select-Object -ExpandProperty ImagePath
	$apacheDescription = Get-ItemProperty -Path $apacheReg | Select-Object -ExpandProperty Description
	$apacheDisplayName = Get-ItemProperty -Path $apacheReg | Select-Object -ExpandProperty DisplayName

	$apacheBaseDirectory = [Regex]::Matches($apachePath,'(?i)[a-z\\0-9\._()\-: ]{1,}(?=bin\\tomcat\d{1}.exe)') | Select-Object -ExpandProperty Value 
	$apacheLogDirectory = $apacheBaseDirectory + 'logs'

	$apacheVersion = $apacheReg.Substring($apacheReg.LastIndexOf('\'),($apacheReg.Length - $apacheReg.LastIndexOf('\'))) 
	$apacheVersion = $apacheVersion -replace '\\',''
	
	if (Test-Path -Path $apacheLogDirectory) {
		$webLogDirTmp         = Get-Item -Path $apacheLogDirectory | Select-Object -Property Name, LastWriteTime, CreationTime
		$webLogDirLastChanged = $webLogDirTmp | Select-Object -ExpandProperty LastWriteTime | Get-Date -Format 'yyyy-MM-dd hh:MM:ss' 
		$webLogDirCreated     = $webLogDirTmp | Select-Object -ExpandProperty CreationTime  | Get-Date -Format 'yyyy-MM-dd hh:MM:ss' 
		
		try { 
			$rawLogDirNoOfFiles   = 0	
			$rawLogDirNoOfFiles   = (Get-ChildItem -Path $apacheLogDirectory).Count
			$webLogDirNoOfFiles   = $rawLogDirNoOfFiles -as [double]

			$rawLogDirSize        = (Get-ChildItem -Path $apacheLogDirectory | Measure-Object -property length -sum).Sum / 1MB
			$doubleLogDirSize     = $rawLogDirSize -as [double]
			$webLogDirSizeMB      = [Math]::Round($doubleLogDirSize, 1)
		} catch {
			$rawLogDirNoOfFiles   = 0	
			$webLogDirSizeMB      = 0
				
			$exceptionFullName    = $_.Exception.GetType().FullName
			$exceptionMessage     = $_.Exception.Message

			$api.LogScriptEvent('DiscoverLogDirectoryWachterItmes.ps1',200,1,"Computer: $($computerName) checking for unconsidered $($discoveryItem) got errors for rawSize: $($doubleLogDirSize). `n $($exceptionFullName) `n $($exceptionMessage)")	
		}

	} else {
		$webLogDirectory      = 'Not found: ' + $webLogDirectory
		$webLogDirLastChanged = 'Na'
		$webLogDirCreated     = 'Na'
		$webLogDirNoOfFiles   = [double]::Parse('0')
		$webLogDirSizeMB      = [double]::Parse('0')
	}		
		
	$healthInstance = $discoveryData.CreateClassInstance("$MPElement[Name='SC!Microsoft.SystemCenter.HealthService']$")		
	$healthInstance.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $computerName)			
	$discoveryData.AddInstance($healthInstance)		
	
	$Key         = $ComputerName + '-' + 'ApacheTomcatWebSite'
	$key         = $Key -replace ' ','_'
	$displayName = 'ApacheTomcatWebSite ' + ' On ' + $ComputerName

	$instance = $discoveryData.CreateClassInstance("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.ApacheTomcat']$")			
	$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.Base']/ComputerName$",$ComputerName)
	$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.Base']/WindowsVersion$",$WindowsVersion)
	$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.Base']/ComputerDescription$",$computerDescription)			
	$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.Base']/TimeZone$",$timeZone)	
	$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.Base']/LogDirPath$",$apacheLogDirectory)	
	$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.Base']/LogDirCreationDate$",$webLogDirCreated)	
	$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.Base']/LogDirModifiedDate$",$webLogDirLastChanged)	
	$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.Base']/LogDirScanDate$",$scanDate)	
	$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.Base']/LogDirSizeInMB$",$webLogDirSizeMB)	
	$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.Base']/LogDirNoOfFiles$",$webLogDirNoOfFiles)			
	$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.ApacheBase']/SvcVersion$",$apacheVersion)			
	$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.ApacheBase']/SvcDisplayName$",$apacheDisplayName)			
	$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.ApacheBase']/SvcDescription$",$apacheDescription)
	$instance.AddProperty("$MPElement[Name='Windows.Server.Webservice.LogdirectoryWatcher.WebSite.ApacheBase']/Key$",$Key)
	$instance.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $displayName)
	$discoveryData.AddInstance($instance)		
		
	$relHealthInstance        = $discoveryData.CreateRelationShipInstance("$MPElement[Name='SC!Microsoft.SystemCenter.HealthServiceShouldManageEntity']$")
	$relHealthInstance.Source = $healthInstance
	$relHealthInstance.Target = $instance									
	$discoveryData.AddInstance($relHealthInstance)
	
} else {

	$api.LogScriptEvent('DiscoverLogDirectoryWachterItmes.ps1',200,1,"On computer $($computerName) with searching for unconsidered $($discoveryItem)")	

}
 
$discoveryData