<#
.SYNOPSIS
   Enumeration script to gather data from hosts on a network that your computer is connected to.
.DESCRIPTION
    Performs an IP scan for a range appropriate to the adapater you are wanting to conduct the scan.
    Offers an optional TCP port scan from a list created by the administrator.
    Outputs a table with "live" hosts and the open ports deemed from the list created by the administrator.
    (In Development) With approved domain credentials PSremote (if enabled by the organization) into hosts to conduct
        host enumeration of settings, firewall rules, local users and groups, network connections, etc.
    Does not install:
.USAGE
    # Run powershell as administrator and type path to this script.
.NOTES
    Name:  enum_script.ps1
    Version: 1.1.1
    Authors: Hasselhuff, Magmonix
    Last Modified: 15 March 2020
.REFERENCES
    https://www.sans.org/blog/pen-test-poster-white-board-powershell-built-in-port-scanner/
#>

# Following is operational

#############################################################################################
#    Creating Table for Active Hosts
#############################################################################################

#Name for Table
$tabName = "Active Hosts"
#Create the Table object
$table = New-Object system.Data.DataTable “$tabName”

#Define Columns
$col1 = New-Object system.Data.DataColumn IPv4,([string])
$col2 = New-Object system.Data.DataColumn Node,([string])
$col3 = New-Object system.Data.DataColumn Ports,([string])

#Add the Columns
$table.columns.add($col1)
$table.columns.add($col2)
$table.columns.add($col3)

#############################################################################################
#    Determine Network adapter to run ping scan
#############################################################################################
$ethernet = ((Get-NetIPConfiguration | Where -Property InterfaceAlias -EQ "Ethernet").IPv4Address).IPAddress | Out-String -Stream
$wifi = ((Get-NetIPConfiguration | Where -Property InterfaceAlias -EQ "Wi-Fi").IPv4Address).IPAddress | Out-String -Stream

$adapter = 0
while($adapter -ne 1 -or $adapter -ne 2 -or $adapter -ne 3){
Write-Host "Which adapter would you like to utilize?" -ForegroundColor Cyan
Write-Host @"
1. Ethernet:  $ethernet
2. Wi-Fi:     $wifi  
3. Exit
"@
$adapter = Read-Host "Enter the number to the corresponding adapter"
    if($adapter -eq 1){
        if($ethernet -eq $null){
            Write-Host -ForegroundColor Red "Ethernet adapter has no assigned IP. Please choose an adapter with a valid IP."
            $adapter = 0}
        else{
            $myip = $ethernet
            break}}
    elseif($adapter -eq 2){
        if($wifi -eq $null){
            Write-Host -ForegroundColor Red "Wi-Fi adapter has no assigned IP. Please choose an adapter with a valid IP."
            $adapter = 0}
        else{
            $myip = $wifi
            break}}
    elseif($adapter -eq 3){
        Write-Host "Exiting script"
        return}
    else{ 
        $adapter = 0
        }}

### Clear Screen
cls
#############################################################################################
#    Selecting IP range for ping scan
############################################################################################# 

$myip = "10.10.200.52"
$first3 = $myip.Split('.',4)
$first3 = $first3[0..2] -join '.'
$first3 = $first3 + '.'
$start = Read-host "Enter start range for IP scan on $first3 " 
$end = Read-host "Enter end range for IP scan on $first3" 

### Clear Screen
cls

#############################################################################################
#    Selecting Ports to scan
#############################################################################################
$ports = @()
$select = 0
$all_ports = (1..65535)

while( $select -eq 0){
Write-Host "Which ports would you like to scan?" -ForegroundColor Cyan
Write-Host @"
1. <Enter port number>
2. Enter "cont" to continue script
3. Enter "quit" to exit script
"@
$select = Read-Host ":"
    if($select -icontains "cont"){
        Write-Host -ForegroundColor Gray "Continuing..."
            break}
    elseif($select -icontains "quit"){
        Write-Host "Exiting script"
        return}
    elseif($select -in $total_ports){
        $ports += $select
        $sample_ports = ($ports | group |Select -ExpandProperty Name) -join ", "
        cls
        Write-Host -ForegroundColor Green "Ports currently selected: $sample_ports"
        $select = 0}
    else{ 
        Write-Host -ForegroundColor Red "Selection invalid"
        $select = 0
        }}


#############################################################################################
#    Begin IP Scan
#############################################################################################
Write-Host -ForegroundColor Gray "##########    Scanning IPs    ##########"
foreach ($i in $start..$end){
    $ip = $first3 + $i
    if (Test-Connection -Count 1 $ip -ErrorAction SilentlyContinue){
        $ip4 = "$ip"
        # Separating the IPv4 by subnet and node
        $sep = $ip4.lastindexof(".")  
        $node = $ip4.substring($sep+1)
        # Make $portsopen null so that it does not carry the values from previous IP connections
        $open_ports = @()
        # Try connecting to open ports
        foreach($p in $ports){
          # Connect to port and if it succeeds add to the portsopen array 
          try {$p | % {((new-object Net.Sockets.TcpClient).Connect($ip4,$_))} 2>$null
              # Add the port to the array
              $open_ports += $p
              }
          # If the port is closed do nothing and show no errors
           Catch{
              }}
        # Make the $portsopen array into a single line with commas between ports
        $open_ports_list = $open_ports -join ", "
        #Create a row
        $row = $table.NewRow()
        #Enter data in the row
        $row.IPv4 = "$ip4"
        $row.Node = $node
        $row.Ports = "$open_ports_list"
        #Add the row to the table
        $table.Rows.Add($row)

        # Display Hostname and IP to terminal
        Write-Host -ForegroundColor Green "$ip is online"
        # Create file with list of online hosts
        # Write-Output -InputObject "$ip" >> "<insert path>"
        }}

#Display the table on the terminal
$table | Select-Object IPv4,@{l='Node';e={[int]$_.Node}},Ports | Sort Node | Format-Table -AutoSize



##################################################################################################################################
##################################################################################################################################
##################################################################################################################################
##################################################################################################################################
##################################################################################################################################
##################################################################################################################################
##################################################################################################################################
##################################################################################################################################


<#  
set-item WSMAN:\localhost\Client\TrustedHosts -value "$(echo $first3'.'$i)" -Force
$session = New-PSSession -computername "$(echo $first3'.'$i)" -Credential $cred
sleep 2
Invoke-Command -Session $session -ScriptBlock {
}

#Powershell SCP
#copy-item -path '<to file>' -Destination '<destination path>' -tosession $session
#Remote Launcher
#Invoke-Command -Session $session -Command {powershell <recieved file>}
#>
<#
# Create a text file with the current date on the desktop of the PSRemoted user
$date = Get-Date -Format M-d-yy
$file = New-Item -Name scan-$date.txt -ItemType File -Path "C:$env:HOMEPATH\Desktop\"

$start_time = Get-Date | Out-String -Stream
Add-Content -Value "Enumeration Start Time: $start_time" $file
Add-Content -Value " " $file

Add-Content -Value "################    System Information    ################" $file
Get-CimInstance Win32_OperatingSystem | Select -Property Caption,OSArchitecture,Manufacturer,InstallDate,LastBootUpTime,LocalDateTime,CountryCode,MUILanguages >> $file
(Get-CimInstance Win32_TimeZone).Caption >> $file
Get-CimInstance Win32_ComputerSystem | Select Name,Domain,Model,Manufacturer >> $file
Add-Content -Value " " $file
Get-CimInstance Win32_OperatingSystem | Select Version,Build,SystemDirectory >> $file
Get-WinSystemLocale | Select -Property DisplayName >> $file
Get-CimInstance Win32_BIOS | Select -Property SMBIOSBIOSVersion >> $file
Get-CimInstance Win32_Processor | Select -Property Name,MaxClockSpeed >> $file
Get-CimInstance Win32_BootConfiguration | Select -Property BootDirectory,Name,Caption >> $file
Add-Content -Value " " $file

Add-Content -Value "################      System Paths      ################" $file
Get-CimInstance Win32_Environment | Format-Table -AutoSize -Wrap >> $file
Add-Content -Value " " $file

Add-Content -Value "################     Installed KBs     ################" $file
Get-HotFix | Select -Property HotFixID >> $file
Add-Content -Value " " $file

Add-Content -Value "################    Network Adapters    ################" $file
Get-NetIPConfiguration
Add-Content -Value "Logon Server: $env:LOGONSERVER" $file
Add-Content -Value " " $file

Add-Content -Value "################       DNS Cache       ################" $file
Get-DnsClientCache | Format-Table -AutoSize >> $file
Add-Content -Value " " $file

Add-Content -Value "########   Network Connections and Processes   ########" $file
Get-NetTCPConnection | Select -Property LocalAddress,LocalPort,RemoteAddress,RemotePort,State,OwningProcess | Format-Table -AutoSize -Wrap >> $file
Get-Process | Select -Property Id,ProcessName,Path | Sort -Property Id | Format-Table -AutoSize -Wrap >> $file
Add-Content -Value " " $file

Add-Content -Value "################       Host File       ################" $file
Get-Content -Path C:\Windows\System32\drivers\etc\hosts >> $file
Add-Content -Value " " $file

Add-Content -Value "##############     Users and Groups    ###############" $file
Get-CimInstance Win32_useraccount | select -property Domain,Name,AccountType,SID | Format-Table -Autosize -Wrap >> $file
Get-LocalGroup | format-table name, sid, principalsource >> $file
Add-Content -Value " " $file

Add-Content -Value "##############     Network Shares    ###############" $file
Get-CimInstance Win32_Share >> $file
Get-PSDrive | Where {$_.Root -ne ""} >> $file
Add-Content -Value " " $file

Add-Content -Value "###############     Route Table    ################" $file
arp -a | findstr /V "224.0.0.22 224.0.0.252 255.255.255.255 ff-ff-ff-ff-ff-ff" >> $file
route print -4 >> $file
Add-Content -Value " " $file

Add-Content -Value "###############     Route Table    ################" $file
netsh advfirewall show allprofiles | findstr /i "State Setting" >> $file
netsh firewall show state | findstr /V "IMPORTANT However instead information microsoft.com" >> $file
netsh firewall show config | findstr /i "enable configuration --  " >> $file
netsh wlan export profile key=clear >> $file
Add-Content -Value " " $file

Add-Content -Value "##########     Run Registry Entries    ###########" $file
Get-Item -path HKLM:\Software\Microsoft\Windows\CurrentVersion\Run >> $file
Get-Item -Path HKCU:\\Software\Microsoft\Windows\CurrentVersion\Run >> $file
Add-Content -Value " " $file

Add-Content -Value "############     Scheduled Tasks    #############" $file
Get-Scheduledtask
Add-Content -Value " " $file

Add-Content -Value "###########     Installed Drivers    ############" $file
driverquery | findstr /i "2018 2019 2020" >> $file
Add-Content -Value " " $file

$end_time = Get-Date | Out-String -Stream
Add-Content -Value "Enumeration Start Time: $end_time" $file
Add-Content -Value " " $file



} | Out-File .\hostlastoctet$i.txt -Append

Remove-PSSession -Session $session 

cls

Write-Host -ForegroundColor Green "IP $(echo $first3'.'$i) query is done "

sleep 2 
cls
echo "########  Please wait  ##########"

# Remove-Item -Path "C:$env:HOMEPATH\Desktop\scan-$date.txt"
#>
