<#
Used to determine which hosts are online and state their IP address from an already esablished list of
hosts.

Text document must have each entry on a separate line.

# You must replace line 23 and 37 with the correct paths for your instance
#>

#Name for Table
$tabName = "Active Hosts"
#Create the Table object
$table = New-Object system.Data.DataTable “$tabName”

#Define Columns
$col1 = New-Object system.Data.DataColumn Hostname,([string])
$col2 = New-Object system.Data.DataColumn IPv4,([string])

#Add the Columns
$table.columns.add($col1)
$table.columns.add($col2)

$Path = "Insert Path to list of hostnames"
$ips = Get-Content -Path $Path
foreach ($ip in $ips){if ($ip4 = (Test-Connection -Count 1 $ip -ErrorAction SilentlyContinue).IPV4Address)
{
    #Create a row
    $row = $table.NewRow()
    #Enter data in the row
    $row.Hostname = "$ip"
    $row.IPv4 = "$ip4"
    #Add the row to the table
    $table.Rows.Add($row)

    #Display Hostname and IP to terminal
    Write-Host -ForegroundColor Green "$ip" 
    Write-Output -InputObject "$ip" >> "Path to new text file to contain list of live hosts"
 }};

#Display the table
$table | format-table -AutoSize
