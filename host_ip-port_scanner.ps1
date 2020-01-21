<#
 
Version 2.1
 
Used to determine which hosts are online and state their IP address from an already esablished list of
hosts as well as scan for open ports from a custom array.

Text document must have each entry on a separate line.

*** You must replace line 37, 47, 76 with the information for your instance

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
$col5 = New-Object system.Data.DataColumn Ports,([string])

#Add the Columns
$table.columns.add($col1)
$table.columns.add($col2)
$table.columns.add($col3)
$table.columns.add($col4)
$table.columns.add($col5)

# Path to list of hostnames
$Path = "<inset path>"
$ips = Get-Content -Path $Path
foreach ($ip in $ips){if ($ip4 = (Test-Connection -Count 1 $ip -ErrorAction SilentlyContinue).IPV4Address)
{
    $ip4 = "$ip4"
    # Separating the IPv4 by subnet and node
    $sep = $ip4.lastindexof(".") 
    $subnet = $ip4.substring(0,$sep) 
    $node = $ip4.substring($sep+1)
    # List of ports to scan
    $ports = 135,139,445,5939
    # Make $portsopen null so that it does not carry the values from previous IP connections
    $portsopen = @()
    # Try connecting to open ports
    foreach($p in $ports){
      # Connect to port and if it succeeds add to the portsopen array 
      try {$p | % {((new-object Net.Sockets.TcpClient).Connect("$ip4",$_))} 2>$null
          # Add the port to the array
          $portsopen = $portsopen += $p 
          }
      # If the port is closed do nothing and show no errors
       Catch{
          }}
    # Make the $portsopen array into a single line with commas between ports
    $portsopenline = ($portsopen | group |Select -ExpandProperty Name) -join ","
    #Create a row
    $row = $table.NewRow()
    #Enter data in the row
    $row.Hostname = "$ip"
    $row.IPv4 = "$ip4"
    $row.Subnet = "$subnet"
    $row.Node = $node
    $row.Ports = "$portsopenline"
    #Add the row to the table
    $table.Rows.Add($row)

    # Display Hostname and IP to terminal
    Write-Host -ForegroundColor Green "$ip is online"
    # Create file with list of online hosts
    Write-Output -InputObject "$ip" >> "<insert path>"
 }};

#Display the table on the terminal
$table | Select-Object Hostname,IPv4,Subnet,@{l='Node';e={[int]$_.Node}},Ports | Sort Node | Format-Table -AutoSize
