# Load WPF Assemblies
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName Microsoft.VisualBasic

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
        Title="Multi-Tool" Height="800" Width="950" MinWidth="800" MinHeight="650"
        Background="#012456" ResizeMode="CanResizeWithGrip">
    <Window.Resources>
        <!-- Button style with rounded corners and hover effect -->
        <Style x:Key="ToolBtn" TargetType="Button">
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="Margin" Value="4"/>
            <Setter Property="Height" Value="30"/>
            <Setter Property="Width" Value="175"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Name="bd" Background="#1E3A5F" BorderBrush="#4A90D9" BorderThickness="1" CornerRadius="4">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="6,0"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="#4A90D9"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="#2E6DA4"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <!-- GroupBox style -->
        <Style x:Key="GroupHeader" TargetType="GroupBox">
            <Setter Property="Foreground" Value="#4A90D9"/>
            <Setter Property="BorderBrush" Value="#2A5A8F"/>
            <Setter Property="Margin" Value="6"/>
            <Setter Property="Padding" Value="6,4"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
        </Style>
    </Window.Resources>
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Input Row -->
        <StackPanel Orientation="Horizontal" Grid.Row="0" HorizontalAlignment="Center" Margin="0,10,0,8">
            <ComboBox Name="txtHostname" Width="320" Height="32" IsEditable="True" Text="Enter Hostname/IP" Background="White" FontSize="13" VerticalContentAlignment="Center"/>
            <Button Name="btnResolve" Content="Resolve" Width="100" Height="32" Margin="8,0,0,0" Style="{StaticResource ToolBtn}" ToolTip="Resolve hostname to IP or IP to hostname"/>
        </StackPanel>

        <!-- Grouped Buttons (2x2 Grid) -->
        <Grid Grid.Row="1" Margin="4,0,4,4">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <!-- Diagnostics -->
            <GroupBox Header="Diagnostics" Grid.Column="0" Grid.Row="0" Style="{StaticResource GroupHeader}">
                <WrapPanel>
                    <Button Name="btnPing" Content="Ping" Style="{StaticResource ToolBtn}" ToolTip="Test connectivity: DNS, ping, and WinRM reachability"/>
                    <Button Name="btnGetSystemInfo" Content="Get System Info" Style="{StaticResource ToolBtn}" ToolTip="OS, CPU, RAM, disk, and network adapter info"/>
                    <Button Name="btnGetUpTime" Content="Get Up Time" Style="{StaticResource ToolBtn}" ToolTip="How long the remote machine has been running since last boot"/>
                    <Button Name="btnFirewallStatus" Content="Firewall Status" Style="{StaticResource ToolBtn}" ToolTip="Check Windows Firewall state for Domain, Private, and Public profiles"/>
                    <Button Name="btnHealthScan" Content="Health Scan" Style="{StaticResource ToolBtn}" ToolTip="Full diagnostic: connectivity, uptime, disk, RAM, user, firewall, battery"/>
                    <Button Name="btnDiskCheck" Content="Disk Space Check" Style="{StaticResource ToolBtn}" ToolTip="Check all drives - warns if below 20% free"/>
                    <Button Name="btnResetWiFi" Content="Reset Wi-Fi Adapter" Style="{StaticResource ToolBtn}" ToolTip="Disable and re-enable the Intel AX211 Wi-Fi adapter to fix connectivity issues"/>
                </WrapPanel>
            </GroupBox>

            <!-- Remote Tools -->
            <GroupBox Header="Remote Tools" Grid.Column="1" Grid.Row="0" Style="{StaticResource GroupHeader}">
                <WrapPanel>
                    <Button Name="btnOpenPSSession" Content="Open PS Session" Style="{StaticResource ToolBtn}" ToolTip="Open an interactive PowerShell remoting session in a new window"/>
                    <Button Name="btnMSRA" Content="Launch MSRA" Style="{StaticResource ToolBtn}" ToolTip="Offer Remote Assistance to the target machine (requires Remote Assistance feature)"/>
                    <Button Name="btnRDC" Content="Launch RDC" Style="{StaticResource ToolBtn}" ToolTip="Connect via Remote Desktop Connection (mstsc)"/>
                    <Button Name="btnEventLog" Content="Open Event Log" Style="{StaticResource ToolBtn}" ToolTip="Open Event Viewer connected to the remote machine"/>
                </WrapPanel>
            </GroupBox>

            <!-- Management -->
            <GroupBox Header="Management" Grid.Column="0" Grid.Row="1" Style="{StaticResource GroupHeader}">
                <WrapPanel>
                    <Button Name="btnGpUpdate" Content="Run GPUpdate" Style="{StaticResource ToolBtn}" ToolTip="Force Group Policy refresh on remote machine (gpupdate /force)"/>
                    <Button Name="btnGetInstalledSoftware" Content="Get Installed Software" Style="{StaticResource ToolBtn}" ToolTip="List all installed software from registry (requires credentials)"/>
                    <Button Name="btnLogOff" Content="Remote Log Off" Style="{StaticResource ToolBtn}" ToolTip="View active sessions and log off a user remotely"/>
                    <Button Name="btnClearPrintQueue" Content="Clear Print Queue" Style="{StaticResource ToolBtn}" ToolTip="Stop Print Spooler, clear all stuck jobs, restart Spooler"/>
                    <Button Name="btnClearDNS" Content="Clear DNS Cache" Style="{StaticResource ToolBtn}" ToolTip="Flush DNS resolver cache on remote machine (ipconfig /flushdns)"/>
                    <Button Name="btnRestart" Content="Remote Restart" Style="{StaticResource ToolBtn}" ToolTip="Restart the remote machine  -  confirmation required"/>
                </WrapPanel>
            </GroupBox>

            <!-- Utilities -->
            <GroupBox Header="Utilities" Grid.Column="1" Grid.Row="1" Style="{StaticResource GroupHeader}">
                <WrapPanel>
                    <Button Name="btnIncident" Content="Open IncidentIQ" Style="{StaticResource ToolBtn}" ToolTip="Open the IncidentIQ ticketing portal in your browser"/>
                    <Button Name="btnFixMDT" Content="Fix MDT Error" Style="{StaticResource ToolBtn}" ToolTip="Remove MDT/WDT deployment artifacts from remote machine (requires credentials)"/>
                    <Button Name="btnClearOutput" Content="Clear Output" Style="{StaticResource ToolBtn}" ToolTip="Clear the output box and reset status"/>
                    <Button Name="btnCopyOutput" Content="Copy to Clipboard" Style="{StaticResource ToolBtn}" ToolTip="Copy output box contents to clipboard"/>
                </WrapPanel>
            </GroupBox>
        </Grid>

        <!-- Progress Bar -->
        <ProgressBar Name="progressBar" Grid.Row="2" Margin="10,0,10,6" Height="5"
                     Visibility="Hidden" Maximum="100" Minimum="0"
                     Foreground="#4A90D9" Background="#1E3A5F"/>

        <!-- Output Box (expands with window) -->
        <TextBox Name="terminalOutputBox" Grid.Row="3" Margin="10,0,10,6" IsReadOnly="True"
                 VerticalScrollBarVisibility="Auto" Background="#0D0D0D" Foreground="#D4D4D4"
                 AcceptsReturn="True" TextWrapping="Wrap" FontFamily="Consolas" FontSize="12"
                 BorderBrush="#2A5A8F" BorderThickness="1" Padding="6"/>

        <!-- Status Bar -->
        <StatusBar Grid.Row="4" Background="#011A40" BorderBrush="#2A5A8F" BorderThickness="0,1,0,0" Height="26">
            <StatusBarItem>
                <Label Name="lblStatus" Content="Ready  -  enter a hostname or IP above" Foreground="#8BB8D8" Padding="4,0" FontSize="12"/>
            </StatusBarItem>
        </StatusBar>
    </Grid>
</Window>
"@

# Load XAML
$Window = [System.Windows.Markup.XamlReader]::Load([System.Xml.XmlReader]::Create([System.IO.StringReader]::new($XAML)))

# Retrieve controls
$txtHostname = $Window.FindName("txtHostname")
$lblStatus = $Window.FindName("lblStatus")
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
$btnLogOff = $Window.FindName("btnLogOff")
$btnClearPrintQueue = $Window.FindName("btnClearPrintQueue")
$btnClearDNS = $Window.FindName("btnClearDNS")
$btnRestart = $Window.FindName("btnRestart")
$btnFirewallStatus = $Window.FindName("btnFirewallStatus")
$btnClearOutput = $Window.FindName("btnClearOutput")
$btnCopyOutput = $Window.FindName("btnCopyOutput")
$btnHealthScan = $Window.FindName("btnHealthScan")
$btnDiskCheck = $Window.FindName("btnDiskCheck")
$btnResetWiFi = $Window.FindName("btnResetWiFi")
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

# Host history helpers
function Load-HostHistory {
    $historyPath = "$env:APPDATA\MultiTool\hostHistory.txt"
    if (Test-Path $historyPath) {
        return Get-Content $historyPath | Select-Object -First 10
    }
    return @()
}

function Save-HostHistory {
    param([string]$hostname)
    $historyPath = "$env:APPDATA\MultiTool\hostHistory.txt"
    $dir = Split-Path $historyPath
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $existing = @()
    if (Test-Path $historyPath) { $existing = Get-Content $historyPath }
    $updated = @($hostname) + ($existing | Where-Object { $_ -ne $hostname }) | Select-Object -First 10
    $updated | Set-Content $historyPath
}

# Function to check connection status and update TextBox background
function Update-ConnectionStatus {
    param($hostnameOrIp)

    # Validate and sanitize input
    $sanitizedInput = [InputValidator]::SanitizeInput($hostnameOrIp)

    # Helper: sets color on both the ComboBox and its inner editable TextBox
    function Set-HostnameColor($brush) {
        $txtHostname.Background = $brush
        if ($script:HostnameInnerBox) { $script:HostnameInnerBox.Background = $brush }
    }

    if (-not [InputValidator]::IsValidHostnameOrIP($sanitizedInput)) {
        Set-HostnameColor ([System.Windows.Media.Brushes]::Red)
        $terminalOutputBox.Text = "Invalid hostname or IP address format."
        [Logger]::Warn("Invalid input provided: $hostnameOrIp")
        return
    }

    try {
        $connectivityTest = Test-RemoteConnectivity -ComputerName $sanitizedInput -TimeoutSeconds $Global:AppConfig.Network.DefaultTimeout

        if ($connectivityTest.IsReachable) {
            Set-HostnameColor ([System.Windows.Media.Brushes]::Green)
            $statusDetails = @()
            if ($connectivityTest.CanPing) { $statusDetails += "Ping: OK" }
            if ($connectivityTest.CanWinRM) { $statusDetails += "WinRM: OK" }
            if ($connectivityTest.CanResolve) { $statusDetails += "DNS: OK" }

            # Try to get logged-in user via quser (no AD/CIM dependency)
            try {
                $quserResult = Invoke-Command -ComputerName $sanitizedInput -ScriptBlock {
                    quser 2>$null | Select-Object -Skip 1 | ForEach-Object {
                        if ($_ -match '^\s*>?\s*(\S+)') { $matches[1] }
                    } | Select-Object -First 1
                } -ErrorAction SilentlyContinue
                if ($quserResult) { $statusDetails += "User: $quserResult" }
            } catch { }

            Save-HostHistory -hostname $sanitizedInput
            if (-not $txtHostname.Items.Contains($sanitizedInput)) {
                $txtHostname.Items.Insert(0, $sanitizedInput)
            }

            $lblStatus.Content = "$sanitizedInput  -  $($statusDetails -join ' | ')"
            $terminalOutputBox.Text = "Connection to $sanitizedInput successful. ($($statusDetails -join ', '))"
            [Logger]::Info("Successful connection test to $sanitizedInput")
        } else {
            Set-HostnameColor ([System.Windows.Media.Brushes]::DarkOrange)
            $terminalOutputBox.Text = "Connection to $sanitizedInput failed. Host may be unreachable or WinRM disabled."
            [Logger]::Warn("Connection test failed for $sanitizedInput")
        }
    } catch {
        Set-HostnameColor ([System.Windows.Media.Brushes]::Red)
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
        Start-Process "eventvwr.msc" -ArgumentList "/computer:$hostnameOrIp"
        $terminalOutputBox.Text = "Opening Event Viewer for $hostnameOrIp."
        [Logger]::Info("Opened Event Viewer for $hostnameOrIp")
    } catch {
        $errorMessage = "Error opening Event Viewer for ${hostnameOrIp}: $($_.Exception.Message)"
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

# Disk Space Check Button Click Event
$btnDiskCheck.Add_Click({
    $remoteMachine = [InputValidator]::SanitizeInput($txtHostname.Text)
    if (Validate-Hostname $remoteMachine) {
        $terminalOutputBox.Text = "Please enter a valid hostname or IP address."
        return
    }

    [Logger]::Info("Running disk space check on $remoteMachine")
    $result = Invoke-RemoteOperation -ComputerName $remoteMachine -ScriptBlock {
        $disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
        $output = @(
            "Disk Space Report: $env:COMPUTERNAME",
            "=" * 45,
            ""
        )
        foreach ($disk in $disks) {
            $totalGB = [math]::Round($disk.Size / 1GB, 1)
            $freeGB  = [math]::Round($disk.FreeSpace / 1GB, 1)
            $usedGB  = [math]::Round(($disk.Size - $disk.FreeSpace) / 1GB, 1)
            $pctFree = if ($disk.Size -gt 0) { [math]::Round(($disk.FreeSpace / $disk.Size) * 100, 0) } else { 0 }
            $filled  = [math]::Round((100 - $pctFree) / 5)
            $bar     = "[" + ("#" * $filled) + ("-" * (20 - $filled)) + "]"
            $status  = if ($pctFree -lt 10) { "!! CRITICAL - Immediate action needed" }
                       elseif ($pctFree -lt 20) { "! WARNING - Running low" }
                       else { "OK" }
            $output += "Drive $($disk.DeviceID)"
            $output += "  $bar  $pctFree% used"
            $output += "  Total: $totalGB GB   Used: $usedGB GB   Free: $freeGB GB"
            $output += "  Status: $status"
            $output += ""
        }
        return $output -join "`r`n"
    } -OperationName "Disk Space Check"

    if ($result.Success) {
        $terminalOutputBox.Text = $result.Data
    } else {
        $terminalOutputBox.Text = "ERROR: $($result.Message)"
    }
})

# Reset Wi-Fi Adapter Button Click Event
$btnResetWiFi.Add_Click({
    $remoteMachine = [InputValidator]::SanitizeInput($txtHostname.Text)
    if (Validate-Hostname $remoteMachine) {
        $terminalOutputBox.Text = "Please enter a valid hostname or IP address."
        return
    }

    try {
        [Logger]::Info("Resetting Wi-Fi adapter on $remoteMachine")
        $terminalOutputBox.Text = "Resetting Wi-Fi adapter on ${remoteMachine}...`r`nPlease wait..."

        $result = Invoke-RemoteOperation -ComputerName $remoteMachine -ScriptBlock {
            $WiFiDevice = Get-PnpDevice -Class Net -ErrorAction SilentlyContinue |
                Where-Object { $_.FriendlyName -match 'Wi-Fi|WiFi|Wireless|WLAN|802\.11' -and $_.InstanceId -notmatch 'ROOT\\' }

            if ($WiFiDevice) {
                # If multiple adapters found, use the first one
                if ($WiFiDevice -is [array]) { $WiFiDevice = $WiFiDevice[0] }

                $output = @(
                    "Wi-Fi Adapter Reset",
                    "=" * 50,
                    "Target: $($WiFiDevice.FriendlyName)",
                    "Current Status: $($WiFiDevice.Status)",
                    ""
                )

                $output += "Disabling adapter..."
                $WiFiDevice | Disable-PnpDevice -Confirm:$false
                Start-Sleep -Seconds 3

                $output += "Enabling adapter..."
                $WiFiDevice | Enable-PnpDevice -Confirm:$false
                Start-Sleep -Seconds 2

                $Check = Get-PnpDevice -InstanceId $WiFiDevice.InstanceId
                $output += ""
                if ($Check.Status -eq "OK") {
                    $output += "SUCCESS: Wi-Fi adapter is now responding normally."
                    $output += "Status: $($Check.Status)"
                } else {
                    $output += "WARNING: Device status is '$($Check.Status)'. A hard reboot may be required."
                }

                return $output -join "`r`n"
            } else {
                return "ERROR: Could not find a Wi-Fi adapter on this machine."
            }
        } -OperationName "Reset Wi-Fi Adapter"

        if ($result.Success) {
            $terminalOutputBox.Text = $result.Data
        } else {
            $terminalOutputBox.Text = "ERROR: $($result.Message)"
        }
    }
    catch {
        $errorMessage = "Error resetting Wi-Fi adapter on ${remoteMachine}: $($_.Exception.Message)"
        $terminalOutputBox.Text = $errorMessage
        [Logger]::Error($errorMessage)
    }
})

# Health Scan Button Click Event
$btnHealthScan.Add_Click({
    $remoteMachine = [InputValidator]::SanitizeInput($txtHostname.Text)
    if (Validate-Hostname $remoteMachine) {
        $terminalOutputBox.Text = "Please enter a valid hostname or IP address."
        return
    }

    [Logger]::Info("Starting health scan on $remoteMachine")
    $terminalOutputBox.Text = "Running health scan on ${remoteMachine}. Please wait..."
    $progressBar.Visibility = [System.Windows.Visibility]::Visible
    $progressBar.Value = 10

    try {
        $conn = Test-RemoteConnectivity -ComputerName $remoteMachine
        $progressBar.Value = 30

        $remoteData = Invoke-Command -ComputerName $remoteMachine -ErrorAction Stop -ScriptBlock {
            $os       = Get-CimInstance Win32_OperatingSystem
            $disks    = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
            $battery  = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
            $firewall = Get-NetFirewallProfile | Select-Object Name, Enabled
            $user     = quser 2>$null | Select-Object -Skip 1 | ForEach-Object {
                if ($_ -match '^\s*>?\s*(\S+)') { $matches[1] }
            } | Select-Object -First 1
            return @{ OS = $os; Disks = $disks; Battery = $battery; Firewall = $firewall; User = $user }
        }
        $progressBar.Value = 80

        $uptime    = (Get-Date) - (Get-SafeDateTime -DateTimeValue $remoteData.OS.LastBootUpTime)
        $uptimeStr = "{0}d {1}h {2}m" -f $uptime.Days, $uptime.Hours, $uptime.Minutes
        $freeRamGB = [math]::Round($remoteData.OS.FreePhysicalMemory / 1MB, 1)
        $totRamGB  = [math]::Round($remoteData.OS.TotalVisibleMemorySize / 1MB, 1)

        $output = @(
            "========================================",
            "  HEALTH SCAN: $remoteMachine",
            "  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
            "========================================",
            "",
            "[CONNECTIVITY]",
            "  Ping:  $(if ($conn.CanPing) { 'OK' } else { 'FAIL' })",
            "  WinRM: $(if ($conn.CanWinRM) { 'OK' } else { 'FAIL' })",
            "  DNS:   $(if ($conn.CanResolve) { 'OK' } else { 'FAIL' })",
            "",
            "[SYSTEM]",
            "  OS:     $($remoteData.OS.Caption)",
            "  Uptime: $uptimeStr",
            "  User:   $(if ($remoteData.User) { $remoteData.User } else { 'None logged in' })",
            "  RAM:    $freeRamGB GB free of $totRamGB GB",
            ""
        )

        $output += "[DISK SPACE]"
        $diskWarnings = @()
        foreach ($disk in $remoteData.Disks) {
            $totalGB = [math]::Round($disk.Size / 1GB, 1)
            $freeGB  = [math]::Round($disk.FreeSpace / 1GB, 1)
            $pctFree = if ($disk.Size -gt 0) { [math]::Round(($disk.FreeSpace / $disk.Size) * 100, 0) } else { 0 }
            $flag    = if ($pctFree -lt 10) { " !! CRITICAL" } elseif ($pctFree -lt 20) { " ! WARNING" } else { "" }
            $output += "  $($disk.DeviceID)  $freeGB GB free / $totalGB GB  ($pctFree% free)$flag"
            if ($pctFree -lt 20) { $diskWarnings += $disk.DeviceID }
        }
        $output += ""

        $output += "[FIREWALL]"
        $fwDisabled = @()
        foreach ($profile in $remoteData.Firewall) {
            $fwState = if ($profile.Enabled) { "ENABLED" } else { "!! DISABLED"; $fwDisabled += $profile.Name }
            $output += "  $($profile.Name): $fwState"
        }
        $output += ""

        if ($remoteData.Battery) {
            $output += "[BATTERY]"
            foreach ($bat in $remoteData.Battery) {
                $chargeStatus = switch ($bat.BatteryStatus) {
                    1 { "Discharging" } 2 { "AC Power" } 3 { "Fully Charged" } default { "Unknown" }
                }
                $output += "  Charge: $($bat.EstimatedChargeRemaining)%   Status: $chargeStatus"
            }
            $output += ""
        }

        $issues = @()
        if (-not $conn.CanPing)   { $issues += "Host not pingable" }
        if (-not $conn.CanWinRM)  { $issues += "WinRM not responding" }
        if ($diskWarnings)        { $issues += "Low disk space: $($diskWarnings -join ', ')" }
        if ($fwDisabled)          { $issues += "Firewall disabled: $($fwDisabled -join ', ')" }

        $output += "[SUMMARY]"
        if ($issues.Count -eq 0) {
            $output += "  No issues detected. System looks healthy."
        } else {
            $issues | ForEach-Object { $output += "  !! $_" }
        }

        $terminalOutputBox.Text = $output -join "`r`n"
        [Logger]::Info("Health scan complete on $remoteMachine - $($issues.Count) issue(s) found")
    }
    catch {
        $terminalOutputBox.Text = "ERROR during health scan: $($_.Exception.Message)"
        [Logger]::Error("Health scan failed on ${remoteMachine}: $($_.Exception.Message)")
    }
    finally {
        $progressBar.Visibility = [System.Windows.Visibility]::Hidden
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

# Remote Restart Button Click Event
$btnRestart.Add_Click({
    try {
        $remoteMachine = [InputValidator]::SanitizeInput($txtHostname.Text)
        if (Validate-Hostname $remoteMachine) {
            $terminalOutputBox.Text = "Please enter a valid hostname or IP address."
            return
        }
        $confirmResult = [System.Windows.MessageBox]::Show(
            "This will RESTART $remoteMachine.`r`n`r`nUnsaved work will be lost.`r`n`r`nContinue?",
            "Confirm Restart",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Warning
        )
        if ($confirmResult -ne [System.Windows.MessageBoxResult]::Yes) {
            $terminalOutputBox.Text = "Restart cancelled."
            return
        }
        [Logger]::Info("Initiating restart on $remoteMachine")
        Restart-Computer -ComputerName $remoteMachine -Force -ErrorAction Stop
        $terminalOutputBox.Text = @(
            "Restart Command Sent Successfully",
            "=" * 50,
            "Computer: $remoteMachine",
            "Action: Restart",
            "Status: Command executed successfully",
            "",
            "The remote computer should restart within a few seconds."
        ) -join "`r`n"
        [Logger]::Info("Restart command sent successfully to $remoteMachine")
    }
    catch {
        $terminalOutputBox.Text = "ERROR: Failed to restart ${remoteMachine}`r`n$($_.Exception.Message)"
        [Logger]::Error("Restart failed for ${remoteMachine}: $($_.Exception.Message)")
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


# Remote Log Off Button Click Event
$btnLogOff.Add_Click({
    try {
        $remoteMachine = [InputValidator]::SanitizeInput($txtHostname.Text)
        if (Validate-Hostname $remoteMachine) {
            $terminalOutputBox.Text = "Please enter a valid hostname or IP address."
            return
        }

        [Logger]::Info("Querying sessions on $remoteMachine for log off")
        $terminalOutputBox.Text = "Querying active sessions on ${remoteMachine}..."

        $result = Invoke-RemoteOperation -ComputerName $remoteMachine -ScriptBlock {
            $sessions = quser 2>$null
            if (-not $sessions) { return "No active user sessions found." }

            $output = @("Active sessions on $env:COMPUTERNAME:", "-" * 40)
            $output += $sessions
            return $output -join "`r`n"
        } -OperationName "Query Sessions"

        if (-not $result.Success) {
            $terminalOutputBox.Text = "ERROR: $($result.Message)"
            return
        }

        $terminalOutputBox.Text = $result.Data

        $sessionInput = [Microsoft.VisualBasic.Interaction]::InputBox(
            "Enter the session ID to log off (see list above):",
            "Remote Log Off",
            ""
        )
        if (-not $sessionInput -or $sessionInput -notmatch '^\d+$') {
            $terminalOutputBox.Text = "Log off cancelled or invalid session ID."
            return
        }

        Invoke-Command -ComputerName $remoteMachine -ScriptBlock {
            param($sid)
            logoff $sid 2>&1 | Out-Null
        } -ArgumentList $sessionInput -ErrorAction Stop

        $terminalOutputBox.Text = "Session $sessionInput logged off successfully on $remoteMachine."
        [Logger]::Info("Logged off session $sessionInput on $remoteMachine")
    }
    catch {
        $terminalOutputBox.Text = "ERROR: $($_.Exception.Message)"
        [Logger]::Error("Log off failed on ${remoteMachine}: $($_.Exception.Message)")
    }
})

# Clear Output Button Click Event
$btnClearOutput.Add_Click({
    $terminalOutputBox.Text = ""
    $lblStatus.Content = "Ready  -  enter a hostname or IP above"
    $txtHostname.Background = [System.Windows.Media.Brushes]::White
    if ($script:HostnameInnerBox) { $script:HostnameInnerBox.Background = [System.Windows.Media.Brushes]::White }
})

# Copy to Clipboard Button Click Event
$btnCopyOutput.Add_Click({
    if ($terminalOutputBox.Text) {
        Set-Clipboard -Value $terminalOutputBox.Text
        $lblStatus.Content = "Output copied to clipboard."
    } else {
        $lblStatus.Content = "Nothing to copy."
    }
})

# Clear ComboBox placeholder on focus
$txtHostname.Add_GotFocus({
    if ($txtHostname.Text -eq "Enter Hostname/IP") {
        $txtHostname.Text = ""
    }
})
$txtHostname.Add_LostFocus({
    if ($txtHostname.Text -eq "") {
        $txtHostname.Text = "Enter Hostname/IP"
    }
})

# Populate recent hosts dropdown
Load-HostHistory | ForEach-Object { $txtHostname.Items.Add($_) }

# Grab the inner editable TextBox after the ComboBox template is applied
# Setting .Background on the ComboBox itself doesn't reach the text area
$Window.Add_Loaded({
    $script:HostnameInnerBox = $txtHostname.Template.FindName("PART_EditableTextBox", $txtHostname)
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
