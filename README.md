# Community.HeatMap
Community developed Operations Manager Heat Map Creator

# Requirements #
- PowerShell 2 (or higher)
- Operations Manager 2012 Operations Console (w/ PowerShell Module)

# Setup #
1. Copy the "SCOM_HeatMap" directory, including its content, to the root of C:\
1. Import the Management Pack from \Community.HeatMap\bin\Debug\Community.HeatMap.xml
1. (optional) Set the $ManagementGroupConn variable in the script C:\SCOM_HeatMap\Export-SCOMHeatMap.ps1. This will suppress the Management Group Connection prompt.