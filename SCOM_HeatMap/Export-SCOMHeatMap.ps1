Param($SortByHealth, $TargetId)

#$ManagementGroupConn = 'SetToSuppressPrompt'

If ($SortByHealth -eq 'true'){
	$SortByHealth = $true
}
Else {$SortByHealth = $false}

If (!$TargetId){
	[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic') | Out-Null
	$TargetId = [Microsoft.VisualBasic.Interaction]::InputBox("Please provide an Object Id (GUID)...","Object Id Prompt","")
}

If (Get-Module -ListAvailable OperationsManager){

	If (!(Get-Module OperationsManager)){
		Import-Module OperationsManager
	}
	If (!$ManagementGroupConn){
		[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic') | Out-Null
		$ManagementGroupConn = [Microsoft.VisualBasic.Interaction]::InputBox("Connect To Management Group...","Management Group Connection","")
	}
	
	$MGconn = New-SCOMManagementGroupConnection $ManagementGroupConn
	$ObectToMap = Get-SCOMClassInstance -Id $TargetId
	
	If ($ObectToMap){

		Function MapHealthState {
			Param($Object)
			
			Switch ($Object.HealthState){
				Error {$HealthState='A_error'}
				Warning {$HealthState='B_warning'}
				Success {$HealthState='D_success'}
			}
			If($Object.InMaintenanceMode){
				$HealthState='E_maintenancemode'
			}
			ElseIf(!($Object.IsAvailable)){
				$HealthState='C_unavailable'
			}
			return $HealthState
		}
		
		$WebConsoleURL = Get-SCOMWebAddressSetting | Select -ExpandProperty WebConsoleUrl
		$WebConsoleURLindexOfLastSlash=$WebConsoleURL.LastIndexOf('/')
		$WebConsoleURLshort = $WebConsoleURL.Substring(0,$WebConsoleURLindexOfLastSlash)
		
		$RelatedObjects = @()
		
		$HealthState = MapHealthState $ObectToMap
		
			$properties = @{
				'Id'=$ObectToMap.Id
		    	'HealthState'=$HealthState
		       	'DisplayName'=$ObectToMap.DisplayName
			}
			$object = New-Object –TypeName PSObject –Prop $properties
			$RelatedObjects += $object
		
		$ObectToMap.GetRelatedMonitoringObjects() | ForEach {

			$HealthState = MapHealthState $_
			
			$properties = @{
				'Id'=$_.Id
		    	'HealthState'=$HealthState
		       	'DisplayName'=$_.DisplayName
			}
			$object = New-Object –TypeName PSObject –Prop $properties
			$RelatedObjects += $object
			
			$_.GetRelatedMonitoringObjects() | ForEach {
			
				$HealthState = MapHealthState $_
				
				$properties = @{
					'Id'=$_.Id
		    		'HealthState'=$HealthState
		        	'DisplayName'=$_.DisplayName
				}
				$object = New-Object –TypeName PSObject –Prop $properties
				$RelatedObjects += $object
				
				{$_.GetRelatedMonitoringObjects() | ForEach {
				
					$HealthState = MapHealthState $_
					
					$properties = @{
						'Id'=$_.Id
			    		'HealthState'=$HealthState
			        	'DisplayName'=$_.DisplayName
					}
					$object = New-Object –TypeName PSObject –Prop $properties
					$RelatedObjects += $object
					
					$_.GetRelatedMonitoringObjects() | ForEach {
				
						$HealthState = MapHealthState $_
						
						$properties = @{
							'Id'=$_.Id
				    		'HealthState'=$HealthState
				        	'DisplayName'=$_.DisplayName
						}
						$object = New-Object –TypeName PSObject –Prop $properties
						$RelatedObjects += $object
					}
				}
			}
		}
		
		Switch ($RelatedObjects.Count){
			{$_ -le 6} {$TilesPerRow = 3;$TileSize = 90}
			{(($_ -gt 6) -and ($_ -le 10))} {$TilesPerRow = 4;$TileSize = 80}
			{(($_ -gt 10) -and ($_ -le 20))} {$TilesPerRow = 5;$TileSize = 70}
			{(($_ -gt 20) -and ($_ -le 30))} {$TilesPerRow = 7;$TileSize = 60}
			{(($_ -gt 30) -and ($_ -le 50))} {$TilesPerRow = 8;$TileSize = 50}
			{$_ -gt 50} {$TilesPerRow = 20;$TileSize = 30}
		}
			
		If ($SortByHealth){
			$RelatedObjects = $RelatedObjects | Sort HealthState
		}
		$HTMLtableData = @()
		$count = 1
		ForEach ($RelatedObj in $RelatedObjects){

			Switch ($count){
				1 {$line = '<tr><td title="' + $RelatedObj.DisplayName + '" class="'+$RelatedObj.HealthState+'" onclick="location.href='+"'$WebConsoleURLshort/MonitoringView/default.aspx?DisplayMode=Pivot&ViewType=DiagramView&PmoID="+$RelatedObj.Id+"'"+'"></td>'}
				Default {$line = '<td title="' + $RelatedObj.DisplayName + '" class="'+$RelatedObj.HealthState+'" onclick="location.href='+"'$WebConsoleURLshort/MonitoringView/default.aspx?DisplayMode=Pivot&ViewType=DiagramView&PmoID="+$RelatedObj.Id+"'"+'"></td>'}
			}
			If ($count -eq $TilesPerRow){
				$line += "</tr>"
				$count = 0
			}
			$count++
			$HTMLtableData += $line
		}

		$head =  '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">'
		$head += '<html xmlns="http://www.w3.org/1999/xhtml">'
		$head += "<head>"
		$head +=   "<style>"
		$head +=     "body{background-color:white}"
		$head +=     "td{cursor:hand; height:"+$TileSize+"px;width:"+$TileSize+"px;border: 1px solid black;}"
		$head +=     "td.A_error{background-color:red}"
		$head +=     "td.B_warning{background-color:yellow}"
		$head +=     "td.C_unavailable{background-color:DarkGrey}"
		$head +=     "td.D_success{background-color:green}"
		$head +=     "td.E_maintenancemode{background-color:LightGray}"
		$head +=   "</style>"
		$head += "</head>"

		$body = "<body><H2>"+ $ObectToMap.DisplayName +" Heat Map</H2></body><table><colgroup><col/><col/><col/></colgroup>"
		$end = '</table><button type="button" onclick="location.href='+"'"+$WebConsoleURL+"'"+'">Go to Web Console</button></body></html>'

		$HTML = $head + $body + $HTMLtableData + $end
		$HTML | Out-File $env:USERPROFILE\SCOM_HeatMapExport.html
		Invoke-Item $env:USERPROFILE\SCOM_HeatMapExport.html
		
	}
	Else {
		Write-Host "This object was not found, perhaps you connected to the wrong Management Group."
	}
}
Else {
	Write-host 'The OperationsManager PowerShell Module Is Not Available.'
}