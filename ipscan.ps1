<#
Used to determine which hosts are online and state their IP address from an already esablished list of
hosts.

Text document must have each entry on a separate line.
#>

$Path = #Insert path to document containing hostnames
$ips = Get-Content -Path $Path
foreach ($ip in $ips){if ($ip4 = (Test-Connection -Count 1 $ip -ErrorAction SilentlyContinue).IPV4Address)
{Write-Host -ForegroundColor Green "$ip"
 Write-Host -ForegroundColor Cyan "$ip4"
 }};