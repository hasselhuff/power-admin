<#
Used to determine which hosts are online and state their IP address from an already esablished list of
hosts.

Text document must have each entry on a separate line.

*** You must replace line 23 and 37 with the correct paths for your instance

If you are not running PowerShell as a different user you can utilize the Desktop variable to shorten your Paths if your files
are located there/ want to output to your desktop:
$DesktopPath = [Environment]::GetFolderPath("Desktop")

Example: -Path $DesktopPath\IpScan.txt

#>

#Name for Table
$tabName = "Active Hosts"
#Create the Table object
$table = New-Object system.Data.DataTable “$tabName”

#Define Columns
$col1 = New-Object system.Data.DataColumn Hostname,([string])
$col2 = New-Object system.Data.DataColumn IPv4,([string])
$col3 = New-Object system.Data.DataColumn Subnet,([string])
$col4 = New-Object system.Data.DataColumn Node,([string])

#Add the Columns
$table.columns.add($col1)
$table.columns.add($col2)
$table.columns.add($col3)
$table.columns.add($col4)

$Path = "path to file"
$ips = Get-Content -Path $Path
foreach ($ip in $ips){if ($ip4 = (Test-Connection -Count 1 $ip -ErrorAction SilentlyContinue).IPV4Address)
{
    $ip4 = "$ip4"
    #Separating the IPv4 by subnet and node
    $sep = $ip4.lastindexof(".") 
    $subnet = $ip4.substring(0,$sep) 
    $node = $ip4.substring($sep+1)
    #Create a row
    $row = $table.NewRow()
    #Enter data in the row
    $row.Hostname = "$ip"
    $row.IPv4 = "$ip4"
    $row.Subnet = "$subnet"
    $row.Node = $node
    #Add the row to the table
    $table.Rows.Add($row)

    #Display Hostname and IP to terminal
    Write-Host -ForegroundColor Green "$ip" 
    Write-Output -InputObject "$ip" >> "path to file showing list of IPs"
 }};

#Display the table
$table | Select-Object Hostname,IPv4,Subnet,@{l='Node';e={[int]$_.Node}} |Sort Node
