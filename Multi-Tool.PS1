# Load WPF Assemblies
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName PresentationCore

# Security and Utility Classes
class InputValidator {
    static [bool] IsValidHostname([string] $hostname) {
        return $hostname -match '^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$'
    }

    static [bool] IsValidIPv4([string] $ip) {
        return $ip -match '^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'
    }

    static [string] SanitizeInput([string] $input) {
        return $input.Trim() -replace '[^\w\.\-]', ''
    }

    static [bool] IsValidHostnameOrIP([string] $input) {
        $sanitized = [InputValidator]::SanitizeInput($input)
        return [InputValidator]::IsValidIPv4($sanitized) -or [InputValidator]::IsValidHostname($sanitized)
    }
}

class Logger {
    static [string] $LogPath = "$env:TEMP\MultiTool.log"

    static [void] WriteLog([string] $level, [string] $message) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$timestamp] [$level] $message"
        Add-Content -Path [Logger]::LogPath -Value $logEntry -ErrorAction SilentlyContinue
    }

    static [void] Info([string] $message) { [Logger]::WriteLog("INFO", $message) }
    static [void] Warn([string] $message) { [Logger]::WriteLog("WARN", $message) }
    static [void] Error([string] $message) { [Logger]::WriteLog("ERROR", $message) }
}

# Configuration
$Global:AppConfig = @{
    Network = @{
        DefaultTimeout = 30
        PingCount = 1
        MaxRetries = 3
    }
    URLs = @{
        Windows11Installer = "https://go.microsoft.com/fwlink/?linkid=2171764"
        Windows11InstallerHash = "" # Should be updated with actual hash
        IncidentIQ = "https://sidneycityschools.incidentiq.com/"
    }
}

# XAML GUI Definition
$XAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Multi_Tool" Height="650" Width="900" Background="#012456">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

        <!-- Status Label -->
        <Label Name="lblStatus" Content="Enter IP or Hostname" Foreground="White" FontSize="14" HorizontalAlignment="Center" Grid.Row="0"/>

        <!-- Hostname/IP Input -->
        <StackPanel Orientation="Horizontal" Grid.Row="1" HorizontalAlignment="Center">
            <TextBox Name="txtHostname" Width="300" Height="30" TextAlignment="Center" />
            <Button Name="btnResolve" Content="Resolve" Width="100" Margin="10,0,0,0"/>
        </StackPanel>

        <!-- Button Grid -->
        <WrapPanel Grid.Row="2" HorizontalAlignment="Center">
            <Button Name="btnPing" Content="Ping" Width="130" Margin="5"/>
            <Button Name="btnGetSystemInfo" Content="Get System Info" Width="180" Margin="5"/>
            <Button Name="btnGetUpTime" Content="Get Up Time" Width="180" Margin="5"/>
            <Button Name="btnOpenPSSession" Content="Open PS Session" Width="180" Margin="5"/>
            <Button Name="btnGpUpdate" Content="Run GPUpdate" Width="180" Margin="5"/>
            <Button Name="btnGetInstalledSoftware" Content="Get Installed Software" Width="180" Margin="5"/>
            <Button Name="btnMSRA" Content="Launch MSRA" Width="180" Margin="5"/>
            <Button Name="btnRDC" Content="Launch RDC" Width="180" Margin="5"/>
            <Button Name="btnEventLog" Content="Open Event Log" Width="180" Margin="5"/>
            <Button Name="btnIncident" Content="Open IncidentIQ" Width="150" Margin="5"/>
            <Button Name="btnFixMDT" Content="Fix MDT Error" Width="180" Margin="5"/>
            <Button Name="btnShowCurrentUser" Content="Show Current User" Width="180" Margin="5"/>
            <Button Name="btnClearPrintQueue" Content="Clear Print Queue" Width="180" Margin="5"/>
            <Button Name="btnClearDNS" Content="Clear DNS Cache" Width="180" Margin="5"/>
            <Button Name="btnShutdown" Content="Remote Shutdown" Width="180" Margin="5"/>
            <Button Name="btnGetComputerInfo" Content="Computer AD Info" Width="180" Margin="5"/>
            <Button Name="btnFirewallStatus" Content="Firewall Status" Width="180" Margin="5"/>
            <Button Name="btnBitLockerStatus" Content="BitLocker Status" Width="180" Margin="5"/>
            <Button Name="btnDefenderStatus" Content="Defender Status" Width="180" Margin="5"/>
        </WrapPanel>

        <!-- Progress Bar -->
        <ProgressBar Name="progressBar" Grid.Row="3" Width="850" Height="20" Margin="5" Visibility="Hidden" Maximum="100" Minimum="0"/>

        <!-- Output Box -->
        <TextBox Name="terminalOutputBox" Grid.Row="4" Width="850" Height="250" IsReadOnly="True"
                 VerticalScrollBarVisibility="Auto" Background="Black" Foreground="White"
                 AcceptsReturn="True" TextWrapping="Wrap"/>
    </Grid>
</Window>
"@

# Load XAML
$Window = [System.Windows.Markup.XamlReader]::Load([System.Xml.XmlReader]::Create([System.IO.StringReader]::new($XAML)))

# Retrieve controls
$txtHostname = $Window.FindName("txtHostname")
$btnResolve = $Window.FindName("btnResolve")
$btnPing = $Window.FindName("btnPing")
$btnGetSystemInfo = $Window.FindName("btnGetSystemInfo")
$btnOpenPSSession = $Window.FindName("btnOpenPSSession")
$terminalOutputBox = $Window.FindName("terminalOutputBox")
$btnGpUpdate = $Window.FindName("btnGpUpdate")
$btnMSRA = $Window.FindName("btnMSRA")
$btnRDC = $Window.FindName("btnRDC")
$btnEventLog = $Window.FindName("btnEventLog")
$btnIncident = $Window.FindName("btnIncident")
$btnGetInstalledSoftware = $Window.FindName("btnGetInstalledSoftware")
$btnGetUpTime = $Window.FindName("btnGetUpTime")
$btnFixMDT = $Window.FindName("btnFixMDT")
$btnShowCurrentUser = $Window.FindName("btnShowCurrentUser")
$btnClearPrintQueue = $Window.FindName("btnClearPrintQueue")
$btnClearDNS = $Window.FindName("btnClearDNS")
$btnShutdown = $Window.FindName("btnShutdown")
$btnGetComputerInfo = $Window.FindName("btnGetComputerInfo")
$btnFirewallStatus = $Window.FindName("btnFirewallStatus")
$btnBitLockerStatus = $Window.FindName("btnBitLockerStatus")
$btnDefenderStatus = $Window.FindName("btnDefenderStatus")
$progressBar = $Window.FindName("progressBar")

# Utility Functions
function Get-SafeDateTime {
    param($DateTimeValue)

    try {
        if ($DateTimeValue -is [DateTime]) {
            return $DateTimeValue
        }
        elseif ($DateTimeValue -is [string]) {
            return [System.Management.ManagementDateTimeConverter]::ToDateTime($DateTimeValue)
        }
        else {
            return [DateTime]::FromFileTime($DateTimeValue)
        }
    }
    catch {
        [Logger]::Warn("Could not parse datetime: $DateTimeValue")
        return $null
    }
}

function Test-RemoteConnectivity {
    param($ComputerName, $TimeoutSeconds = 10)

    $result = @{
        IsReachable = $false
        CanResolve = $false
        CanPing = $false
        CanWinRM = $false
    }

    try {
        $resolved = Resolve-DnsName -Name $ComputerName -ErrorAction Stop
        $result.CanResolve = $true
    } catch { }

    try {
        $ping = Test-Connection -ComputerName $ComputerName -Count 1 -Quiet -TimeoutSeconds $TimeoutSeconds
        $result.CanPing = $ping
    } catch { }

    try {
        $winrm = Test-WSMan -ComputerName $ComputerName -ErrorAction Stop
        $result.CanWinRM = $true
    } catch { }

    $result.IsReachable = $result.CanPing -or $result.CanWinRM
    return $result
}

function Invoke-RemoteOperation {
    param($ComputerName, $ScriptBlock, $OperationName, $Credential)

    try {
        [Logger]::Info("Starting $OperationName on $ComputerName")
        $params = @{
            ComputerName = $ComputerName
            ScriptBlock = $ScriptBlock
            ErrorAction = 'Stop'
        }
        if ($Credential) {
            $params.Credential = $Credential
        }
        $result = Invoke-Command @params
        [Logger]::Info("$OperationName completed successfully")
        return @{
            Success = $true
            Data = $result
            Message = "$OperationName completed successfully"
        }
    }
    catch {
        [Logger]::Error("$OperationName failed: $($_.Exception.Message)")
        return @{
            Success = $false
            Data = $null
            Message = "$OperationName failed: $($_.Exception.Message)"
        }
    }
}

function Get-SystemInfoOptimized {
    param($ComputerName)

    $cimSession = $null
    try {
        $cimSession = New-CimSession -ComputerName $ComputerName -ErrorAction Stop

        # Batch multiple queries using the same session
        $osInfo = Get-CimInstance -CimSession $cimSession -ClassName Win32_OperatingSystem
        $cpuInfo = Get-CimInstance -CimSession $cimSession -ClassName Win32_Processor
        $memInfo = Get-CimInstance -CimSession $cimSession -ClassName Win32_PhysicalMemory
        $diskInfo = Get-CimInstance -CimSession $cimSession -ClassName Win32_LogicalDisk -Filter "DriveType=3"
        $networkInfo = Get-CimInstance -CimSession $cimSession -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True"

        return @{
            OS = $osInfo
            CPU = $cpuInfo
            Memory = $memInfo
            Disks = $diskInfo
            Network = $networkInfo
        }
    }
    finally {
        if ($cimSession) {
            Remove-CimSession -CimSession $cimSession -ErrorAction SilentlyContinue
        }
    }
}

function Download-VerifiedFile {
    param($Url, $OutputPath, $ExpectedHash = $null)

    try {
        Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing -ErrorAction Stop

        if ($ExpectedHash) {
            $actualHash = Get-FileHash -Path $OutputPath -Algorithm SHA256
            if ($actualHash.Hash -ne $ExpectedHash) {
                Remove-Item $OutputPath -Force
                throw "File hash verification failed. Expected: $ExpectedHash, Actual: $($actualHash.Hash)"
            }
        }
        return $true
    }
    catch {
        [Logger]::Error("Download failed: $($_.Exception.Message)")
        return $false
    }
}

# Function to get machine IP/hostname
function Get-LoggedInUserAndMachineInfo {
    $hostname = $env:COMPUTERNAME
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $txtHostname.Text = "$hostname - $currentUser"
}

# Function to check connection status and update TextBox background
function Update-ConnectionStatus {
    param($hostnameOrIp)

    # Validate and sanitize input
    $sanitizedInput = [InputValidator]::SanitizeInput($hostnameOrIp)
    if (-not [InputValidator]::IsValidHostnameOrIP($sanitizedInput)) {
        $txtHostname.Background = [System.Windows.Media.Brushes]::Red
        $terminalOutputBox.Text = "Invalid hostname or IP address format."
        [Logger]::Warn("Invalid input provided: $hostnameOrIp")
        return
    }

    try {
        $connectivityTest = Test-RemoteConnectivity -ComputerName $sanitizedInput -TimeoutSeconds $Global:AppConfig.Network.DefaultTimeout

        if ($connectivityTest.IsReachable) {
            $txtHostname.Background = [System.Windows.Media.Brushes]::Green
            $statusDetails = @()
            if ($connectivityTest.CanPing) { $statusDetails += "Ping: OK" }
            if ($connectivityTest.CanWinRM) { $statusDetails += "WinRM: OK" }
            if ($connectivityTest.CanResolve) { $statusDetails += "DNS: OK" }
            $terminalOutputBox.Text = "Connection to $sanitizedInput successful. ($($statusDetails -join ', '))"
            [Logger]::Info("Successful connection test to $sanitizedInput")
        } else {
            $txtHostname.Background = [System.Windows.Media.Brushes]::DarkOrange
            $terminalOutputBox.Text = "Connection to $sanitizedInput failed. Host may be unreachable or WinRM disabled."
            [Logger]::Warn("Connection test failed for $sanitizedInput")
        }
    } catch {
        $txtHostname.Background = [System.Windows.Media.Brushes]::Red
        $terminalOutputBox.Text = "Error testing connection: $($_.Exception.Message)"
        [Logger]::Error("Connection test error for ${sanitizedInput}: $($_.Exception.Message)")
    }
}

# Helper function for validating hostname/IP input
function Validate-Hostname {
    param($hostname)
    if ($hostname -eq "Enter Hostname/IP" -or $hostname -eq "" -or $hostname -eq $null) {
        return $true  # Invalid
    }
    return -not [InputValidator]::IsValidHostnameOrIP($hostname)
}

# Ping Button Click Event
$btnPing.Add_Click({
    $hostnameOrIp = [InputValidator]::SanitizeInput($txtHostname.Text)

    if (Validate-Hostname $hostnameOrIp) {
        $terminalOutputBox.Text = "Please enter a valid hostname/IP."
        return
    }

    Update-ConnectionStatus $hostnameOrIp
})

# Get System Info Button Click Event
$btnGetSystemInfo.Add_Click({
    $remoteMachine = [InputValidator]::SanitizeInput($txtHostname.Text)
    if (Validate-Hostname $remoteMachine) {
        $terminalOutputBox.Text = "Please enter a valid machine name or IP."
        return
    }

    try {
        # Use optimized system info gathering
        $systemData = Get-SystemInfoOptimized -ComputerName $remoteMachine

        # Calculate uptime using improved datetime handling
        $lastBootUpTime = Get-SafeDateTime -DateTimeValue $systemData.OS.LastBootUpTime
        if ($lastBootUpTime) {
            $currentTime = Get-Date
            $uptime = $currentTime - $lastBootUpTime
            $uptimeString = "{0:D2} days {1:D2} hrs {2:D2} mins {3:D2} secs" -f $uptime.Days, $uptime.Hours, $uptime.Minutes, $uptime.Seconds
        } else {
            $uptimeString = "Uptime data unavailable"
        }

        # Calculate memory more efficiently
        $totalMemoryGB = [math]::round(($systemData.Memory | Measure-Object -Property Capacity -Sum).Sum / 1GB, 2)

        # Format disk information
        $diskOutput = ($systemData.Disks | ForEach-Object {
            "$($_.DeviceID): Total: $([math]::round($_.Size / 1GB, 2)) GB Free: $([math]::round($_.FreeSpace / 1GB, 2)) GB"
        }) -join "`r`n"

        # Format network information
        $ipAddress = ($systemData.Network.IPAddress | Where-Object { $_ -match '\.' } | Select-Object -First 1) -join ", "
        $dnsServers = ($systemData.Network.DNSServerSearchOrder | Where-Object { $_ }) -join ", "

        # Build output more efficiently
        $systemInfo = @(
            "System Information for ${remoteMachine}:",
            "----------------------------------------",
            "OS Information:",
            "OS: $($systemData.OS.Caption)",
            "Architecture: $($systemData.OS.OSArchitecture)",
            "Machine Name: $($systemData.OS.CSName)",
            "Current User: $($systemData.OS.UserName)",
            "Uptime: $uptimeString",
            "",
            "Processor Information:",
            "CPU: $($systemData.CPU.Name)",
            "Cores: $($systemData.CPU.NumberOfCores)",
            "Clock Speed: $($systemData.CPU.MaxClockSpeed) MHz",
            "",
            "Memory Information:",
            "Total RAM: $totalMemoryGB GB",
            "",
            "Disk Information:",
            $diskOutput,
            "",
            "Network Information:",
            "IP Address: $ipAddress",
            "DNS Servers: $dnsServers"
        ) -join "`r`n"

        $terminalOutputBox.Text = $systemInfo
        [Logger]::Info("Retrieved system information for $remoteMachine")
    } catch {
        $errorMessage = "Error getting system information for ${remoteMachine}: $($_.Exception.Message)"
        $terminalOutputBox.Text = $errorMessage
        [Logger]::Error($errorMessage)
    }
})

# Resolve Button Event
$btnResolve.Add_Click({
    $hostnameOrIp = [InputValidator]::SanitizeInput($txtHostname.Text)

    if (Validate-Hostname $hostnameOrIp) {
        $terminalOutputBox.Text = "Please enter a valid hostname or IP address."
        return
    }

    try {
        if ([InputValidator]::IsValidIPv4($hostnameOrIp)) {
            # If input is an IP address, try reverse lookup
            $resolved = Resolve-DnsName -Name $hostnameOrIp -Type PTR -ErrorAction Stop
            $hostname = $resolved.NameHost
            $terminalOutputBox.Text = "Resolved IP address to hostname: $hostname"
            [Logger]::Info("Successfully resolved IP $hostnameOrIp to hostname $hostname")
        } elseif ([InputValidator]::IsValidHostname($hostnameOrIp)) {
            # Otherwise, resolve hostname to IP
            $resolved = Resolve-DnsName -Name $hostnameOrIp -ErrorAction Stop
            $ipAddresses = $resolved | Where-Object { $_.QueryType -eq "A" -or $_.QueryType -eq "AAAA" } | Select-Object -ExpandProperty IPAddress

            if ($ipAddresses) {
                $terminalOutputBox.Text = "Resolved hostname '$hostnameOrIp' to IP address(es):`r`n" + ($ipAddresses -join "`r`n")
                [Logger]::Info("Successfully resolved hostname $hostnameOrIp to IPs: $($ipAddresses -join ', ')")
            } else {
                $terminalOutputBox.Text = "No IP addresses found for '$hostnameOrIp'."
                [Logger]::Warn("No IP addresses found for hostname $hostnameOrIp")
            }
        } else {
            $terminalOutputBox.Text = "Invalid hostname or IP address format."
            [Logger]::Warn("Invalid input format provided for resolution: $hostnameOrIp")
        }
    } catch {
        $errorMessage = "Error resolving '$hostnameOrIp': $($_.Exception.Message)"
        $terminalOutputBox.Text = $errorMessage
        [Logger]::Error($errorMessage)
    }
})

# Open PowerShell Session Button Event
$btnOpenPSSession.Add_Click({
    $hostnameOrIp = [InputValidator]::SanitizeInput($txtHostname.Text)

    if (Validate-Hostname $hostnameOrIp) {
        $terminalOutputBox.Text = "Please enter a valid hostname or IP address."
        return
    }

    try {
        # Define the command to start a remote PowerShell session
        $command = "Enter-PSSession -ComputerName '$hostnameOrIp' -ErrorAction Stop"

        # Start a new PowerShell window with the specified command
        Start-Process powershell.exe -ArgumentList "-NoExit", "-Command", $command

        $terminalOutputBox.Text = "Successfully opened a remote PowerShell session with $hostnameOrIp in a new window."
        [Logger]::Info("Opened PowerShell session to $hostnameOrIp")
    } catch {
        $errorMessage = "Error opening PowerShell session for ${hostnameOrIp}: $($_.Exception.Message)"
        $terminalOutputBox.Text = $errorMessage
        [Logger]::Error($errorMessage)
    }
})

# GPUpdate Button Click Event
$btnGpUpdate.Add_Click({
    $hostnameOrIp = [InputValidator]::SanitizeInput($txtHostname.Text)

    if (Validate-Hostname $hostnameOrIp) {
        $terminalOutputBox.Text = "Please enter a valid hostname or IP address."
        return
    }

    try {
        $result = Invoke-RemoteOperation -ComputerName $hostnameOrIp -ScriptBlock { gpupdate /force } -OperationName "GPUpdate"
        if ($result.Success) {
            $terminalOutputBox.Text = "Successfully ran GPUpdate on ${hostnameOrIp}."
        } else {
            $terminalOutputBox.Text = $result.Message
        }
    } catch {
        $errorMessage = "Error running GPUpdate on ${hostnameOrIp}: $($_.Exception.Message)"
        $terminalOutputBox.Text = $errorMessage
        [Logger]::Error($errorMessage)
    }
})

# MSRA Button Click Event
$btnMSRA.Add_Click({
    $hostnameOrIp = [InputValidator]::SanitizeInput($txtHostname.Text)

    if (Validate-Hostname $hostnameOrIp) {
        $terminalOutputBox.Text = "Please enter a valid hostname or IP address."
        return
    }

    try {
        # Launch MSRA (Microsoft Remote Assistance) for the target machine
        Start-Process "msra" -ArgumentList "/offerRA $hostnameOrIp"
        $terminalOutputBox.Text = "Launching MSRA for $hostnameOrIp."
        [Logger]::Info("Launched MSRA for $hostnameOrIp")
    } catch {
        $errorMessage = "Error launching MSRA for ${hostnameOrIp}: $($_.Exception.Message)"
        $terminalOutputBox.Text = $errorMessage
        [Logger]::Error($errorMessage)
    }
})

# RDC Button Click Event
$btnRDC.Add_Click({
    $hostnameOrIp = [InputValidator]::SanitizeInput($txtHostname.Text)

    if (Validate-Hostname $hostnameOrIp) {
        $terminalOutputBox.Text = "Please enter a valid hostname or IP address."
        return
    }

    try {
        # Launch Remote Desktop Connection (RDC)
        Start-Process "mstsc" -ArgumentList "/v:$hostnameOrIp"
        $terminalOutputBox.Text = "Launching RDC for $hostnameOrIp."
        [Logger]::Info("Launched RDC for $hostnameOrIp")
    } catch {
        $errorMessage = "Error launching RDC for ${hostnameOrIp}: $($_.Exception.Message)"
        $terminalOutputBox.Text = $errorMessage
        [Logger]::Error($errorMessage)
    }
})

# Event Log Button Click Event
$btnEventLog.Add_Click({
    $hostnameOrIp = [InputValidator]::SanitizeInput($txtHostname.Text)

    if (Validate-Hostname $hostnameOrIp) {
        $terminalOutputBox.Text = "Please enter a valid hostname or IP address."
        return
    }

    try {
        # Create a temporary MSC file with Event Viewer configured for remote computer
        $mscContent = @"
<?xml version="1.0" encoding="UTF-8"?>
<MMC_CONSOLE_FILE ConsoleVersion="2.0">
<Console>
<ConsoleTree>
<NodeData>
<NodeType>Microsoft.EventViewer</NodeType>
<NodeData>
<ComputerName>$hostnameOrIp</ComputerName>
</NodeData>
</NodeData>
</ConsoleTree>
</Console>
</MMC_CONSOLE_FILE>
"@

        $tempMscPath = "$env:TEMP\EventViewer_$hostnameOrIp.msc"
        $mscContent | Out-File -FilePath $tempMscPath -Encoding UTF8 -Force

        # Launch MMC with the configured Event Viewer
        Start-Process "mmc.exe" -ArgumentList $tempMscPath

        $terminalOutputBox.Text = "Opening Event Log for $hostnameOrIp."
        [Logger]::Info("Opened Event Log for $hostnameOrIp")
    } catch {
        $errorMessage = "Error opening Event Log for ${hostnameOrIp}: $($_.Exception.Message)"
        $terminalOutputBox.Text = $errorMessage
        [Logger]::Error($errorMessage)
    }
})

# IncidentIQ Button Click Event
$btnIncident.Add_Click({
    Start-Process "https://sidneycityschools.incidentiq.com/"
})

# Get Installed Software Button Click Event
$btnGetInstalledSoftware.Add_Click({
    $remoteMachine = [InputValidator]::SanitizeInput($txtHostname.Text)

    if (Validate-Hostname $remoteMachine) {
        $terminalOutputBox.Text = "Please enter a valid hostname or IP address."
        return
    }

    try {
        # Get credentials for remote access
        $credential = Get-Credential -Message "Enter credentials for $remoteMachine"
        if (-not $credential) {
            $terminalOutputBox.Text = "Operation cancelled: No credentials provided."
            return
        }

        # Use the improved remote operation function
        $result = Invoke-RemoteOperation -ComputerName $remoteMachine -Credential $credential -OperationName "Get Installed Software" -ScriptBlock {
            Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*, `
                              HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*, `
                              HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |
                              Select-Object DisplayName, DisplayVersion, InstallDate |
                              Where-Object { $_.DisplayName -ne $null } |
                              Sort-Object DisplayName
        }

        if ($result.Success -and $result.Data) {
            # Format output more efficiently
            $softwareList = @(
                "Installed Software on ${remoteMachine}:",
                "---------------------------------"
            )
            $softwareList += $result.Data | ForEach-Object {
                "Name: $($_.DisplayName)",
                "Version: $($_.DisplayVersion)",
                "Installed On: $($_.InstallDate)",
                "---------------------------------"
            }
            $terminalOutputBox.Text = $softwareList -join "`r`n"
        } elseif ($result.Success) {
            $terminalOutputBox.Text = "No installed software found on ${remoteMachine}."
        } else {
            $terminalOutputBox.Text = $result.Message
        }
    } catch {
        $errorMessage = "Error retrieving installed software from ${remoteMachine}: $($_.Exception.Message)"
        $terminalOutputBox.Text = $errorMessage
        [Logger]::Error($errorMessage)
    }
})

# Get Up Time Button Click Event
$btnGetUpTime.Add_Click({
    $remoteMachine = [InputValidator]::SanitizeInput($txtHostname.Text)

    if (Validate-Hostname $remoteMachine) {
        $terminalOutputBox.Text = "Please enter a valid hostname or IP address."
        return
    }

    try {
        # Get OS information using optimized method
        $cimSession = New-CimSession -ComputerName $remoteMachine -ErrorAction Stop
        try {
            $osInfo = Get-CimInstance -CimSession $cimSession -ClassName Win32_OperatingSystem

            # Use improved datetime conversion
            $lastBootUpTime = Get-SafeDateTime -DateTimeValue $osInfo.LastBootUpTime

            if ($lastBootUpTime) {
                $currentTime = Get-Date
                $uptime = $currentTime - $lastBootUpTime
                $uptimeString = "{0:D2} days {1:D2} hrs {2:D2} mins {3:D2} secs" -f $uptime.Days, $uptime.Hours, $uptime.Minutes, $uptime.Seconds
                $terminalOutputBox.Text = "Uptime for ${remoteMachine}`r`n$uptimeString"
                [Logger]::Info("Retrieved uptime for ${remoteMachine}: $uptimeString")
            } else {
                $terminalOutputBox.Text = "Could not retrieve or parse last boot up time for $remoteMachine."
                [Logger]::Warn("Failed to parse LastBootUpTime for $remoteMachine")
            }
        }
        finally {
            Remove-CimSession -CimSession $cimSession -ErrorAction SilentlyContinue
        }
    } catch {
        $errorMessage = "Error retrieving uptime for ${remoteMachine}: $($_.Exception.Message)"
        $terminalOutputBox.Text = $errorMessage
        [Logger]::Error($errorMessage)
    }
})

# Fix MDT Error Button Click Event
$btnFixMDT.Add_Click({
    try {
        $remoteMachine = [InputValidator]::SanitizeInput($txtHostname.Text)

        if (Validate-Hostname $remoteMachine) {
            $terminalOutputBox.Text = "Please enter a valid hostname or IP address."
            return
        }

        $terminalOutputBox.Text = "Starting MDT/WDT Cleanup on ${remoteMachine}...`r`n`r`nThis will fix the LiteTouch.wsf startup error by removing MDT artifacts.`r`n"
        [Logger]::Info("Starting embedded MDT cleanup on $remoteMachine")

        # Prompt for credentials
        $credential = Get-Credential -Message "Enter administrator credentials for $remoteMachine"
        if (-not $credential) {
            $terminalOutputBox.Text = "Operation cancelled: No credentials provided."
            return
        }

        $progressBar.Visibility = [System.Windows.Visibility]::Visible
        $progressBar.Value = 10

        # Define the cleanup script block to run on remote machine
        $cleanupScriptBlock = {
            $issuesFound = 0
            $issuesFixed = 0
            $output = @()

            # First, let's search specific high-probability locations
            $output += "=== TARGETED DIAGNOSTIC SCAN ==="
            $output += "Checking common startup locations..."
            $output += ""

            # Check Winlogon keys specifically (common for persistent startup)
            $output += "[DIAGNOSTIC] Checking Winlogon Registry Keys..."
            $winlogonKeys = @(
                "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon",
                "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
            )

            foreach ($wlKey in $winlogonKeys) {
                if (Test-Path $wlKey) {
                    $output += "  Path: $wlKey"
                    $props = Get-ItemProperty -Path $wlKey -ErrorAction SilentlyContinue
                    $checkProps = @("Shell", "Userinit", "VmApplet", "System", "TaskMan", "UIHost", "LogonScript")
                    foreach ($propName in $checkProps) {
                        if ($props.$propName) {
                            $output += "    $propName = $($props.$propName)"
                            if ($props.$propName -match "LiteTouch|MININT") {
                                $output += "    *** MATCH FOUND ***"
                                $issuesFound++
                            }
                        }
                    }
                }
            }
            $output += ""

            # Check for WMI Event Consumers (advanced startup method)
            try {
                $wmiConsumers = Get-WmiObject -Namespace "root\subscription" -Class CommandLineEventConsumer -ErrorAction SilentlyContinue
                foreach ($consumer in $wmiConsumers) {
                    if ($consumer.CommandLineTemplate -match "LiteTouch|MININT") {
                        $output += "[FOUND] WMI Event Consumer: $($consumer.Name)"
                        $output += "  Command: $($consumer.CommandLineTemplate)"
                        $issuesFound++
                    }
                }
            } catch { }

            # Check Startup Folders and list ALL files
            $output += "[DIAGNOSTIC] Checking Startup Folders..."
            $startupDirs = @(
                "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup",
                "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
                "$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs\StartUp"
            )

            foreach ($dir in $startupDirs) {
                if (Test-Path $dir) {
                    $output += "  Folder: $dir"
                    $items = Get-ChildItem -Path $dir -ErrorAction SilentlyContinue
                    if ($items) {
                        foreach ($item in $items) {
                            $output += "    - $($item.Name)"

                            # Check if filename contains MDT keywords
                            $filenameMatch = $item.Name -match "LiteTouch|MININT|MDT"

                            if ($item.Extension -eq ".lnk") {
                                try {
                                    $shell = New-Object -ComObject WScript.Shell
                                    $shortcut = $shell.CreateShortcut($item.FullName)
                                    $output += "      Target: $($shortcut.TargetPath)"
                                    $output += "      Arguments: $($shortcut.Arguments)"

                                    # Check target, arguments, or filename
                                    if ($shortcut.TargetPath -match "LiteTouch|MININT|MDT" -or
                                        $shortcut.Arguments -match "LiteTouch|MININT|MDT" -or
                                        $filenameMatch) {
                                        $output += "      *** MATCH FOUND - REMOVING ***"
                                        $issuesFound++
                                        Remove-Item -Path $item.FullName -Force -ErrorAction Stop
                                        $output += "      [OK] Removed shortcut successfully"
                                        $issuesFixed++
                                    }
                                }
                                catch {
                                    $output += "      [FAIL] Failed to remove shortcut: $($_.Exception.Message)"
                                }
                            } elseif ($filenameMatch) {
                                # Non-shortcut file with MDT in name
                                $output += "      *** MATCH FOUND - REMOVING ***"
                                $issuesFound++
                                try {
                                    Remove-Item -Path $item.FullName -Force -ErrorAction Stop
                                    $output += "      [OK] Removed file successfully"
                                    $issuesFixed++
                                }
                                catch {
                                    $output += "      [FAIL] Failed to remove: $($_.Exception.Message)"
                                }
                            }
                        }
                    } else {
                        $output += "    (empty)"
                    }
                } else {
                    $output += "  Folder not found: $dir"
                }
            }
            $output += ""

            # Check running processes
            $output += "[DIAGNOSTIC] Checking Running Processes..."
            $ltProcesses = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match "LiteTouch|MININT" }
            if ($ltProcesses) {
                foreach ($proc in $ltProcesses) {
                    $output += "  ACTIVE PROCESS FOUND:"
                    $output += "    ProcessId: $($proc.ProcessId)"
                    $output += "    Name: $($proc.Name)"
                    $output += "    CommandLine: $($proc.CommandLine)"
                    $output += "    ParentProcessId: $($proc.ParentProcessId)"

                    $parent = Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -eq $proc.ParentProcessId }
                    if ($parent) {
                        $output += "    Parent Process: $($parent.Name) (PID $($parent.ProcessId))"
                    }
                    $output += "    *** LITETOUCH IS RUNNING ***"
                    $issuesFound++
                }
            } else {
                $output += "  No LiteTouch processes currently running"
            }
            $output += ""

            # [1] Check and Remove Registry Run Entries
            $output += "[DIAGNOSTIC] Checking ALL Registry Run Keys..."
            $registryPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunServicesOnce",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunServicesOnce",
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunServices",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunServices",
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run",
            "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components"
        )

        # Also check all user hives
        $userHives = Get-ChildItem "Registry::HKEY_USERS" -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'S-1-5-21' }
        foreach ($hive in $userHives) {
            $registryPaths += "$($hive.PSPath)\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
            $registryPaths += "$($hive.PSPath)\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
        }

        $mdtPatterns = @("LiteTouch", "MININT", "DeploymentShare", "BDD", "MDT")

        foreach ($regPath in $registryPaths) {
            if (Test-Path $regPath) {
                try {
                    $properties = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
                    if ($properties) {
                        $hasValues = $false
                        foreach ($prop in $properties.PSObject.Properties) {
                            if ($prop.Name -match "^PS") { continue }

                            if (-not $hasValues) {
                                $output += "  Path: $regPath"
                                $hasValues = $true
                            }

                            $output += "    $($prop.Name) = $($prop.Value)"

                            $matched = $false
                            foreach ($pattern in $mdtPatterns) {
                                if ($prop.Value -match $pattern) {
                                    $matched = $true
                                    break
                                }
                            }

                            if ($matched) {
                                $output += "    *** MATCH FOUND - WILL REMOVE ***"
                                $issuesFound++
                                try {
                                    Remove-ItemProperty -Path $regPath -Name $prop.Name -Force -ErrorAction Stop
                                    $output += "    [OK] Removed successfully"
                                    $issuesFixed++
                                }
                                catch {
                                    $output += "    [FAIL] Failed to remove"
                                }
                            }
                        }
                    }
                }
                catch { }
            }
        }
        $output += ""

        # [2] Remove Auto-Logon Settings
        $winlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

        try {
            $autoLogonEnabled = (Get-ItemProperty -Path $winlogonPath -Name "AutoAdminLogon" -ErrorAction SilentlyContinue).AutoAdminLogon

            if ($autoLogonEnabled -eq "1") {
                $issuesFound++
                $defaultUser = (Get-ItemProperty -Path $winlogonPath -Name "DefaultUserName" -ErrorAction SilentlyContinue).DefaultUserName
                $defaultDomain = (Get-ItemProperty -Path $winlogonPath -Name "DefaultDomainName" -ErrorAction SilentlyContinue).DefaultDomainName

                try {
                    # Disable auto-logon
                    Set-ItemProperty -Path $winlogonPath -Name "AutoAdminLogon" -Value "0" -Force -ErrorAction Stop

                    # Remove stored password (security risk!)
                    Remove-ItemProperty -Path $winlogonPath -Name "DefaultPassword" -ErrorAction SilentlyContinue

                    # Remove auto-logon count
                    Remove-ItemProperty -Path $winlogonPath -Name "AutoLogonCount" -ErrorAction SilentlyContinue

                    $output += "  [OK] Disabled auto-logon for: $defaultDomain\$defaultUser"
                    $issuesFixed++
                }
                catch {
                    $output += "  [FAIL] Failed to disable auto-logon"
                }
            }
        }
        catch { }

        # [3] Remove Scheduled Tasks
        try {
            $allTasks = Get-ScheduledTask -ErrorAction SilentlyContinue
            $mdtTasks = $allTasks | Where-Object {
                $_.TaskName -match "LiteTouch|MDT|BDD|DeploymentShare" -or
                ($_.Actions -and $_.Actions.Execute -match "LiteTouch|MININT")
            }

            foreach ($task in $mdtTasks) {
                $issuesFound++
                try {
                    Unregister-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -Confirm:$false -ErrorAction Stop
                    $output += "  [OK] Removed task: $($task.TaskPath)$($task.TaskName)"
                    $issuesFixed++
                }
                catch {
                    $output += "  [FAIL] Failed to remove task: $($task.TaskName)"
                }
            }
        }
        catch { }

        # [4] Remove Directories
        $criticalPaths = @("C:\MININT", "C:\DeploymentShare", "C:\_SMSTaskSequence")

        foreach ($path in $criticalPaths) {
            if (Test-Path $path) {
                $issuesFound++
                try {
                    # Take ownership and remove
                    $null = takeown /F $path /R /D Y 2>&1
                    $null = icacls $path /grant administrators:F /T 2>&1
                    Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
                    $output += "  [OK] Removed directory: $path"
                    $issuesFixed++
                }
                catch {
                    $output += "  [FAIL] Failed to remove: $path"
                }
            }
        }

        # [5] Startup Shortcuts already handled in diagnostic section above

        # [6] Check Group Policy Startup Scripts
        $output += ""
        $output += "[CHECKING] Group Policy startup scripts..."

        $gpStartupPaths = @(
            "C:\Windows\System32\GroupPolicy\Machine\Scripts\Startup",
            "C:\Windows\System32\GroupPolicy\User\Scripts\Logon",
            "$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs\StartUp"
        )

        foreach ($gpPath in $gpStartupPaths) {
            if (Test-Path $gpPath) {
                $scripts = Get-ChildItem -Path $gpPath -Include *.bat,*.cmd,*.vbs,*.ps1,*.wsf -Recurse -ErrorAction SilentlyContinue
                foreach ($script in $scripts) {
                    $content = Get-Content $script.FullName -Raw -ErrorAction SilentlyContinue
                    if ($content -match "LiteTouch|MININT|MDT") {
                        $issuesFound++
                        try {
                            Remove-Item -Path $script.FullName -Force -ErrorAction Stop
                            $output += "  [OK] Removed GP script: $($script.FullName)"
                            $issuesFixed++
                        }
                        catch {
                            $output += "  [FAIL] Failed to remove: $($script.FullName)"
                        }
                    }
                }
            }
        }

        # Return results
        return @{
            IssuesFound = $issuesFound
            IssuesFixed = $issuesFixed
            Output = $output
        }
        }

        # Execute cleanup on remote machine
        $terminalOutputBox.Text += "Running comprehensive MDT cleanup...`r`n"
        $progressBar.Value = 20

        try {
            $result = Invoke-Command -ComputerName $remoteMachine -Credential $credential -ScriptBlock $cleanupScriptBlock -ErrorAction Stop

            $progressBar.Value = 100

            # Display results
            $terminalOutputBox.Text += "`r`n" + ("=" * 50) + "`r`n"
            $terminalOutputBox.Text += "CLEANUP COMPLETE`r`n"
            $terminalOutputBox.Text += ("=" * 50) + "`r`n`r`n"
            $terminalOutputBox.Text += "Issues Found: $($result.IssuesFound)`r`n"
            $terminalOutputBox.Text += "Issues Fixed: $($result.IssuesFixed)`r`n`r`n"

            if ($result.Output.Count -gt 0) {
                $terminalOutputBox.Text += "Details:`r`n"
                $terminalOutputBox.Text += ($result.Output -join "`r`n") + "`r`n`r`n"
            }

            if ($result.IssuesFound -eq 0) {
                $terminalOutputBox.Text += "No MDT artifacts found. System is clean.`r`n"
            }
            elseif ($result.IssuesFixed -gt 0) {
                $terminalOutputBox.Text += "SUCCESS: MDT artifacts have been removed.`r`n"
                $terminalOutputBox.Text += "`r`nNEXT STEPS:`r`n"
                $terminalOutputBox.Text += "  1. Restart the computer`r`n"
                $terminalOutputBox.Text += "  2. Verify the error no longer appears`r`n"
            }
            else {
                $terminalOutputBox.Text += "WARNING: Issues were found but could not be fixed.`r`n"
                $terminalOutputBox.Text += "Check that you have administrator credentials.`r`n"
            }

            [Logger]::Info("MDT cleanup completed on ${remoteMachine}: $($result.IssuesFixed)/$($result.IssuesFound) fixed")
        }
        catch {
            $terminalOutputBox.Text = "Error executing remote cleanup: $($_.Exception.Message)`r`n`r`nMake sure:`r`n- WinRM is enabled on $remoteMachine`r`n- You have administrator credentials`r`n- Firewall allows remote administration"
            [Logger]::Error("Remote MDT cleanup failed for ${remoteMachine}: $($_.Exception.Message)")
        }

    } catch {
        $errorMessage = "Error during MDT cleanup: $($_.Exception.Message)"
        $terminalOutputBox.Text = $errorMessage
        [Logger]::Error($errorMessage)
    }
    finally {
        $progressBar.Visibility = [System.Windows.Visibility]::Hidden
    }
})

# Show Current User Button Click Event
$btnShowCurrentUser.Add_Click({
    try {
        $remoteMachine = [InputValidator]::SanitizeInput($txtHostname.Text)

        if (Validate-Hostname $remoteMachine) {
            $terminalOutputBox.Text = "Please enter a valid hostname or IP address."
            return
        }

        [Logger]::Info("Querying current user on $remoteMachine")

        $result = Invoke-RemoteOperation -ComputerName $remoteMachine -ScriptBlock {
            $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
            $currentUser = $computerSystem.UserName

            # Get session information using quser
            $quserOutput = quser 2>$null

            # Parse quser output to get session details
            $sessionInfo = ""
            if ($quserOutput) {
                $sessionInfo = $quserOutput | Out-String
            }

            # Get logon time from Win32_LogonSession
            try {
                $logonSessions = Get-CimInstance -ClassName Win32_LogonSession | Where-Object { $_.LogonType -eq 2 -or $_.LogonType -eq 10 }
                $latestLogon = $logonSessions | Sort-Object StartTime -Descending | Select-Object -First 1

                if ($latestLogon) {
                    $logonTime = [Management.ManagementDateTimeConverter]::ToDateTime($latestLogon.StartTime)
                    $duration = (Get-Date) - $logonTime
                    $sessionDuration = "{0:D2}h {1:D2}m" -f $duration.Hours, $duration.Minutes
                } else {
                    $sessionDuration = "Unknown"
                }
            } catch {
                $sessionDuration = "Unknown"
            }

            $output = @(
                "Current User Information:",
                "=" * 50,
                "Logged In User: $(if ($currentUser) { $currentUser } else { 'No user logged in' })",
                "Session Duration: $sessionDuration",
                "",
                "Session Details:",
                "-" * 50,
                $sessionInfo
            ) -join "`r`n"

            return $output
        } -OperationName "Get Current User"

        if ($result.Success) {
            $terminalOutputBox.Text = $result.Data
        } else {
            $terminalOutputBox.Text = "ERROR: $($result.Message)"
        }
    }
    catch {
        $errorMessage = "Error querying current user on ${remoteMachine}: $($_.Exception.Message)"
        $terminalOutputBox.Text = $errorMessage
        [Logger]::Error($errorMessage)
    }
})

# Clear Print Queue Button Click Event
$btnClearPrintQueue.Add_Click({
    try {
        $remoteMachine = [InputValidator]::SanitizeInput($txtHostname.Text)

        if (Validate-Hostname $remoteMachine) {
            $terminalOutputBox.Text = "Please enter a valid hostname or IP address."
            return
        }

        $confirmResult = [System.Windows.MessageBox]::Show(
            "This will clear all print jobs on $remoteMachine and restart the Print Spooler service.`r`n`r`nContinue?",
            "Clear Print Queue",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Warning
        )

        if ($confirmResult -ne [System.Windows.MessageBoxResult]::Yes) {
            $terminalOutputBox.Text = "Print queue clear operation cancelled."
            return
        }

        [Logger]::Info("Clearing print queue on $remoteMachine")
        $terminalOutputBox.Text = "Clearing print queue on ${remoteMachine}...`r`nPlease wait..."

        $result = Invoke-RemoteOperation -ComputerName $remoteMachine -ScriptBlock {
            $output = @()

            # Stop the Print Spooler service
            $output += "Stopping Print Spooler service..."
            Stop-Service -Name Spooler -Force -ErrorAction Stop
            Start-Sleep -Seconds 2

            # Clear the spool folder
            $spoolPath = "$env:SystemRoot\System32\spool\PRINTERS"
            if (Test-Path $spoolPath) {
                $files = Get-ChildItem -Path $spoolPath -File
                $fileCount = $files.Count

                if ($fileCount -gt 0) {
                    $output += "Removing $fileCount print job file(s) from spool folder..."
                    $files | Remove-Item -Force -ErrorAction SilentlyContinue
                } else {
                    $output += "No print job files found in spool folder."
                }
            }

            # Clear print jobs using PowerShell cmdlet
            try {
                $printers = Get-Printer -ErrorAction SilentlyContinue
                $totalJobsCleared = 0

                foreach ($printer in $printers) {
                    $jobs = Get-PrintJob -PrinterName $printer.Name -ErrorAction SilentlyContinue
                    if ($jobs) {
                        $jobCount = $jobs.Count
                        $totalJobsCleared += $jobCount
                        $jobs | Remove-PrintJob -ErrorAction SilentlyContinue
                    }
                }

                if ($totalJobsCleared -gt 0) {
                    $output += "Cleared $totalJobsCleared queued print job(s)."
                }
            } catch {
                $output += "Note: Could not query/clear printer queues via cmdlet."
            }

            # Start the Print Spooler service
            $output += "Starting Print Spooler service..."
            Start-Service -Name Spooler -ErrorAction Stop
            Start-Sleep -Seconds 2

            $spoolerStatus = (Get-Service -Name Spooler).Status
            $output += "Print Spooler service status: $spoolerStatus"
            $output += ""
            $output += "Print queue clear operation completed successfully!"

            return $output -join "`r`n"
        } -OperationName "Clear Print Queue"

        if ($result.Success) {
            $terminalOutputBox.Text = $result.Data
        } else {
            $terminalOutputBox.Text = "ERROR: $($result.Message)"
        }
    }
    catch {
        $errorMessage = "Error clearing print queue on ${remoteMachine}: $($_.Exception.Message)"
        $terminalOutputBox.Text = $errorMessage
        [Logger]::Error($errorMessage)
    }
})

# Clear DNS Cache Button Click Event
$btnClearDNS.Add_Click({
    try {
        $remoteMachine = [InputValidator]::SanitizeInput($txtHostname.Text)

        if (Validate-Hostname $remoteMachine) {
            $terminalOutputBox.Text = "Please enter a valid hostname or IP address."
            return
        }

        [Logger]::Info("Clearing DNS cache on $remoteMachine")
        $terminalOutputBox.Text = "Clearing DNS cache on ${remoteMachine}..."

        $result = Invoke-RemoteOperation -ComputerName $remoteMachine -ScriptBlock {
            # Flush DNS cache
            $flushOutput = ipconfig /flushdns 2>&1 | Out-String

            # Get DNS client cache statistics (if available)
            try {
                $cacheStats = Get-DnsClientCache -ErrorAction SilentlyContinue
                $cacheCount = if ($cacheStats) { $cacheStats.Count } else { 0 }
            } catch {
                $cacheCount = "Unknown"
            }

            $output = @(
                "DNS Cache Clear Operation:",
                "=" * 50,
                $flushOutput.Trim(),
                "",
                "DNS Client Cache Status:",
                "Current cached entries: $cacheCount",
                "",
                "DNS cache has been successfully flushed on this machine."
            ) -join "`r`n"

            return $output
        } -OperationName "Clear DNS Cache"

        if ($result.Success) {
            $terminalOutputBox.Text = $result.Data
        } else {
            $terminalOutputBox.Text = "ERROR: $($result.Message)"
        }
    }
    catch {
        $errorMessage = "Error clearing DNS cache on ${remoteMachine}: $($_.Exception.Message)"
        $terminalOutputBox.Text = $errorMessage
        [Logger]::Error($errorMessage)
    }
})

# Remote Shutdown Button Click Event
$btnShutdown.Add_Click({
    try {
        $remoteMachine = [InputValidator]::SanitizeInput($txtHostname.Text)

        if (Validate-Hostname $remoteMachine) {
            $terminalOutputBox.Text = "Please enter a valid hostname or IP address."
            return
        }

        $confirmResult = [System.Windows.MessageBox]::Show(
            "This will SHUT DOWN $remoteMachine immediately.`r`n`r`nThe computer will power off and any unsaved work will be lost.`r`n`r`nAre you sure you want to continue?",
            "Confirm Shutdown",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Stop
        )

        if ($confirmResult -ne [System.Windows.MessageBoxResult]::Yes) {
            $terminalOutputBox.Text = "Shutdown operation cancelled."
            return
        }

        [Logger]::Info("Initiating shutdown on $remoteMachine")
        $terminalOutputBox.Text = "Initiating shutdown on ${remoteMachine}..."

        try {
            Stop-Computer -ComputerName $remoteMachine -Force -ErrorAction Stop
            $terminalOutputBox.Text = @(
                "Shutdown Command Sent Successfully",
                "=" * 50,
                "Computer: $remoteMachine",
                "Action: Shutdown",
                "Status: Command executed successfully",
                "",
                "The remote computer should shut down within a few seconds."
            ) -join "`r`n"
            [Logger]::Info("Shutdown command sent successfully to $remoteMachine")
        }
        catch {
            $terminalOutputBox.Text = "ERROR: Failed to shutdown $remoteMachine`r`n$($_.Exception.Message)"
            [Logger]::Error("Shutdown failed for ${remoteMachine}: $($_.Exception.Message)")
        }
    }
    catch {
        $errorMessage = "Error during shutdown operation for ${remoteMachine}: $($_.Exception.Message)"
        $terminalOutputBox.Text = $errorMessage
        [Logger]::Error($errorMessage)
    }
})

# Computer AD Info Button Click Event
$btnGetComputerInfo.Add_Click({
    try {
        $remoteMachine = [InputValidator]::SanitizeInput($txtHostname.Text)

        if (Validate-Hostname $remoteMachine) {
            $terminalOutputBox.Text = "Please enter a valid hostname or IP address."
            return
        }

        [Logger]::Info("Querying Active Directory computer information for $remoteMachine")
        $terminalOutputBox.Text = "Querying Active Directory information for ${remoteMachine}..."

        try {
            $computerInfo = Get-ADComputer -Identity $remoteMachine -Properties * -ErrorAction Stop

            $output = @(
                "Active Directory Computer Information:",
                "=" * 50,
                "Computer Name: $($computerInfo.Name)",
                "DNS Hostname: $($computerInfo.DNSHostName)",
                "Distinguished Name: $($computerInfo.DistinguishedName)",
                "",
                "Operating System:",
                "  OS: $($computerInfo.OperatingSystem)",
                "  Version: $($computerInfo.OperatingSystemVersion)",
                "  Service Pack: $($computerInfo.OperatingSystemServicePack)",
                "",
                "Account Information:",
                "  Enabled: $($computerInfo.Enabled)",
                "  Created: $($computerInfo.Created)",
                "  Modified: $($computerInfo.Modified)",
                "  Last Logon: $($computerInfo.LastLogonDate)",
                "  Password Last Set: $($computerInfo.PasswordLastSet)",
                "",
                "Location:",
                "  Organizational Unit: $($computerInfo.DistinguishedName -replace '^CN=[^,]+,','')",
                "  Description: $($computerInfo.Description)",
                "  Location: $($computerInfo.Location)",
                "",
                "Security:",
                "  SID: $($computerInfo.SID.Value)"
            ) -join "`r`n"

            $terminalOutputBox.Text = $output
            [Logger]::Info("Successfully retrieved AD info for $remoteMachine")
        }
        catch {
            if ($_.Exception.Message -match "Cannot find an object") {
                $terminalOutputBox.Text = "ERROR: Computer account '$remoteMachine' not found in Active Directory.`r`n`r`nPlease verify:`r`n- Computer name is correct`r`n- Computer is joined to the domain`r`n- You have permission to query AD"
            }
            else {
                $terminalOutputBox.Text = "ERROR: Failed to query Active Directory`r`n$($_.Exception.Message)"
            }
            [Logger]::Error("AD query failed for ${remoteMachine}: $($_.Exception.Message)")
        }
    }
    catch {
        $errorMessage = "Error querying AD computer info for ${remoteMachine}: $($_.Exception.Message)"
        $terminalOutputBox.Text = $errorMessage
        [Logger]::Error($errorMessage)
    }
})

# Firewall Status Button Click Event
$btnFirewallStatus.Add_Click({
    try {
        $remoteMachine = [InputValidator]::SanitizeInput($txtHostname.Text)

        if (Validate-Hostname $remoteMachine) {
            $terminalOutputBox.Text = "Please enter a valid hostname or IP address."
            return
        }

        [Logger]::Info("Querying Windows Firewall status on $remoteMachine")
        $terminalOutputBox.Text = "Querying Windows Firewall status on ${remoteMachine}..."

        $result = Invoke-RemoteOperation -ComputerName $remoteMachine -ScriptBlock {
            $profiles = Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction

            $output = @(
                "Windows Firewall Status:",
                "=" * 50
            )

            foreach ($profile in $profiles) {
                $status = if ($profile.Enabled) { "ENABLED" } else { "DISABLED" }
                $output += ""
                $output += "Profile: $($profile.Name)"
                $output += "  Status: $status"
                $output += "  Default Inbound: $($profile.DefaultInboundAction)"
                $output += "  Default Outbound: $($profile.DefaultOutboundAction)"
            }

            $output += ""
            $output += "=" * 50

            $enabledCount = ($profiles | Where-Object { $_.Enabled }).Count
            $totalCount = $profiles.Count

            if ($enabledCount -eq $totalCount) {
                $output += "Status: All firewall profiles are ENABLED (Secure)"
            }
            elseif ($enabledCount -eq 0) {
                $output += "WARNING: All firewall profiles are DISABLED (Security Risk!)"
            }
            else {
                $output += "WARNING: Some firewall profiles are disabled (Inconsistent State)"
            }

            return $output -join "`r`n"
        } -OperationName "Get Firewall Status"

        if ($result.Success) {
            $terminalOutputBox.Text = $result.Data
        } else {
            $terminalOutputBox.Text = "ERROR: $($result.Message)"
        }
    }
    catch {
        $errorMessage = "Error querying firewall status on ${remoteMachine}: $($_.Exception.Message)"
        $terminalOutputBox.Text = $errorMessage
        [Logger]::Error($errorMessage)
    }
})

# BitLocker Status Button Click Event
$btnBitLockerStatus.Add_Click({
    try {
        $remoteMachine = [InputValidator]::SanitizeInput($txtHostname.Text)

        if (Validate-Hostname $remoteMachine) {
            $terminalOutputBox.Text = "Please enter a valid hostname or IP address."
            return
        }

        [Logger]::Info("Querying BitLocker status on $remoteMachine")
        $terminalOutputBox.Text = "Querying BitLocker encryption status on ${remoteMachine}..."

        $result = Invoke-RemoteOperation -ComputerName $remoteMachine -ScriptBlock {
            try {
                $volumes = Get-BitLockerVolume -ErrorAction Stop

                $output = @(
                    "BitLocker Encryption Status:",
                    "=" * 50
                )

                foreach ($volume in $volumes) {
                    $output += ""
                    $output += "Drive: $($volume.MountPoint)"
                    $output += "  Volume Status: $($volume.VolumeStatus)"
                    $output += "  Encryption Method: $($volume.EncryptionMethod)"
                    $output += "  Encryption Percentage: $($volume.EncryptionPercentage)%"
                    $output += "  Protection Status: $($volume.ProtectionStatus)"
                    $output += "  Key Protectors: $($volume.KeyProtector.Count) configured"
                    $output += "  Lock Status: $($volume.LockStatus)"
                }

                $output += ""
                $output += "=" * 50

                $encryptedCount = ($volumes | Where-Object { $_.VolumeStatus -eq "FullyEncrypted" }).Count
                $totalCount = $volumes.Count

                $output += "Summary: $encryptedCount of $totalCount volume(s) fully encrypted"

                return $output -join "`r`n"
            }
            catch {
                return "ERROR: Unable to query BitLocker status.`r`n`r`nPossible reasons:`r`n- BitLocker is not available on this system`r`n- Insufficient permissions`r`n- BitLocker service not running`r`n`r`nDetails: $($_.Exception.Message)"
            }
        } -OperationName "Get BitLocker Status"

        if ($result.Success) {
            $terminalOutputBox.Text = $result.Data
        } else {
            $terminalOutputBox.Text = "ERROR: $($result.Message)"
        }
    }
    catch {
        $errorMessage = "Error querying BitLocker status on ${remoteMachine}: $($_.Exception.Message)"
        $terminalOutputBox.Text = $errorMessage
        [Logger]::Error($errorMessage)
    }
})

# Windows Defender Status Button Click Event
$btnDefenderStatus.Add_Click({
    try {
        $remoteMachine = [InputValidator]::SanitizeInput($txtHostname.Text)

        if (Validate-Hostname $remoteMachine) {
            $terminalOutputBox.Text = "Please enter a valid hostname or IP address."
            return
        }

        [Logger]::Info("Querying Windows Defender status and threats on $remoteMachine")
        $terminalOutputBox.Text = "Querying Windows Defender status on ${remoteMachine}..."
        $progressBar.Visibility = [System.Windows.Visibility]::Visible
        $progressBar.Value = 10

        $result = Invoke-RemoteOperation -ComputerName $remoteMachine -ScriptBlock {
            try {
                # Get Defender service status
                $service = Get-Service -Name WinDefend -ErrorAction SilentlyContinue
                $serviceStatus = if ($service) { $service.Status } else { "Not Available" }

                # Get Defender configuration status
                $status = Get-MpComputerStatus -ErrorAction Stop

                $output = @(
                    "=== Windows Defender Status for $env:COMPUTERNAME ===",
                    "",
                    "Service Status: $serviceStatus",
                    "Real-Time Protection: $(if ($status.RealTimeProtectionEnabled) { 'Enabled' } else { 'DISABLED' })",
                    "Last Quick Scan: $($status.QuickScanEndTime)",
                    "Last Full Scan: $($status.FullScanEndTime)",
                    "",
                    "Antivirus Signature Version: $($status.AntivirusSignatureVersion)",
                    "Signature Last Updated: $($status.AntivirusSignatureLastUpdated)",
                    "Signature Age (days): $($status.AntivirusSignatureAge)",
                    "",
                    "Behavior Monitor: $(if ($status.BehaviorMonitorEnabled) { 'Enabled' } else { 'Disabled' })",
                    "On Access Protection: $(if ($status.OnAccessProtectionEnabled) { 'Enabled' } else { 'Disabled' })",
                    "I/O Protection: $(if ($status.IoavProtectionEnabled) { 'Enabled' } else { 'Disabled' })",
                    "",
                    "=== Recent Threats (Last 24 Hours) ===",
                    ""
                )

                # Query Defender event log for threats (Event ID 1116)
                $yesterday = (Get-Date).AddDays(-1)
                $threatEvents = @()

                try {
                    $threatEvents = Get-WinEvent -LogName "Microsoft-Windows-Windows Defender/Operational" -ErrorAction Stop |
                        Where-Object { $_.Id -eq 1116 -and $_.TimeCreated -ge $yesterday }
                } catch {
                    $output += "[WARNING] Could not query Defender event log: $($_.Exception.Message)"
                    $output += ""
                }

                if ($threatEvents.Count -eq 0) {
                    $output += "[+] No threats detected in the last 24 hours"
                } else {
                    $output += "[!] $($threatEvents.Count) threat(s) detected in the last 24 hours:"
                    $output += ""

                    foreach ($event in $threatEvents) {
                        $output += "[!] THREAT DETECTED"
                        $output += "    Time: $($event.TimeCreated)"

                        # Extract threat details from event properties
                        # Event 1116 structure: Properties[0] = Threat Name, Properties[1] = Severity, etc.
                        if ($event.Properties.Count -ge 2) {
                            $threatName = if ($event.Properties[0].Value) { $event.Properties[0].Value } else { "Unknown" }
                            $output += "    Threat: $threatName"
                        }

                        if ($event.Properties.Count -ge 7) {
                            $threatPath = if ($event.Properties[6].Value) { $event.Properties[6].Value } else { "Unknown" }
                            $output += "    Path: $threatPath"
                        }

                        if ($event.Properties.Count -ge 14) {
                            $action = if ($event.Properties[13].Value) { $event.Properties[13].Value } else { "Unknown" }
                            $output += "    Action: $action"
                        }

                        $output += ""
                    }
                }

                # Add health summary
                $output += "=== Health Summary ==="
                $issues = @()
                if ($serviceStatus -ne "Running") { $issues += "Windows Defender service is not running" }
                if (-not $status.RealTimeProtectionEnabled) { $issues += "Real-Time Protection is DISABLED" }
                if ($status.AntivirusSignatureAge -gt 7) { $issues += "Definitions are outdated (>7 days old)" }
                if (-not $status.AntivirusEnabled) { $issues += "Antivirus is DISABLED" }
                if ($threatEvents.Count -gt 0) { $issues += "$($threatEvents.Count) threat(s) detected in last 24 hours" }

                if ($issues.Count -eq 0) {
                    $output += "Status: HEALTHY - All checks passed"
                }
                else {
                    $output += "Status: ATTENTION REQUIRED"
                    $output += ""
                    $output += "Issues:"
                    foreach ($issue in $issues) {
                        $output += "  - $issue"
                    }
                }

                return $output -join "`r`n"
            }
            catch {
                return "ERROR: Unable to query Windows Defender.`r`n`r`nPossible reasons:`r`n- Windows Defender is not available on this system`r`n- Third-party antivirus is installed`r`n- Insufficient permissions`r`n`r`nDetails: $($_.Exception.Message)"
            }
        } -OperationName "Get Defender Status and Threats"

        $progressBar.Value = 90

        if ($result.Success) {
            $terminalOutputBox.Text = $result.Data
            [Logger]::Info("Successfully retrieved Defender status and threats for $remoteMachine")
        } else {
            $terminalOutputBox.Text = "ERROR: $($result.Message)"
            [Logger]::Error("Failed to retrieve Defender status for ${remoteMachine}: $($result.Message)")
        }
    }
    catch {
        $errorMessage = "Error querying Windows Defender on ${remoteMachine}: $($_.Exception.Message)"
        $terminalOutputBox.Text = $errorMessage
        [Logger]::Error($errorMessage)
    }
    finally {
        $progressBar.Visibility = [System.Windows.Visibility]::Hidden
    }
})

# Show the window
$Window.ShowDialog()

# Cleanup runspaces on window close
$Window.Add_Closed({
    if ($runspacePool) {
        $runspacePool.Close()
        $runspacePool.Dispose()
    }
})
