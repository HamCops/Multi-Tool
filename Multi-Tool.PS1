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
                                <Setter TargetName="bd" Property="Background" Value="#5AA9E6"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="#2E6DA4"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="bd" Property="Background" Value="#0F2640"/>
                                <Setter TargetName="bd" Property="BorderBrush" Value="#2A3F5F"/>
                                <Setter Property="Foreground" Value="#5A7A9A"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <!-- Expander section style -->
        <Style x:Key="ExpanderSection" TargetType="Expander">
            <Setter Property="Foreground" Value="#4A90D9"/>
            <Setter Property="BorderBrush" Value="#2A5A8F"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Margin" Value="6"/>
            <Setter Property="Padding" Value="6,4"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Background" Value="Transparent"/>
        </Style>
    </Window.Resources>
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="2*" MinHeight="80"/>
            <RowDefinition Height="5"/>
            <RowDefinition Height="5*" MinHeight="100"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Input Row -->
        <StackPanel Orientation="Horizontal" Grid.Row="0" HorizontalAlignment="Center" Margin="0,10,0,8">
            <ComboBox Name="txtHostname" Width="320" Height="32" IsEditable="True" Text="Enter Hostname/IP" Background="White" FontSize="13" VerticalContentAlignment="Center" Foreground="Gray"/>
            <Button Name="btnResolve" Content="Resolve" Width="100" Height="32" Margin="8,0,0,0" Style="{StaticResource ToolBtn}">
                <Button.ToolTip><ToolTip Background="#1E3A5F" BorderBrush="#4A90D9" Foreground="White"><StackPanel MaxWidth="280"><TextBlock FontWeight="Bold" Text="DNS Resolve"/><TextBlock TextWrapping="Wrap" Margin="0,4,0,0" Text="Resolves a hostname to its IP address, or performs a reverse PTR lookup of an IP to a hostname."/><TextBlock FontStyle="Italic" Foreground="#8BB8D8" Margin="0,4,0,0" Text="Command: Resolve-DnsName"/></StackPanel></ToolTip></Button.ToolTip>
            </Button>
        </StackPanel>

        <!-- Buttons + Progress + Search all in Row 1 -->
        <StackPanel Grid.Row="1">

        <!-- Grouped Buttons (2x2 Grid) -->
        <Grid Margin="4,0,4,4">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <!-- Diagnostics -->
            <Expander Header="Diagnostics" Grid.Column="0" Grid.Row="0" IsExpanded="True" Style="{StaticResource ExpanderSection}">
                <WrapPanel>
                    <Button Name="btnPing" Content="Ping" Style="{StaticResource ToolBtn}">
                        <Button.ToolTip><ToolTip Background="#1E3A5F" BorderBrush="#4A90D9" Foreground="White"><StackPanel MaxWidth="280"><TextBlock FontWeight="Bold" Text="Ping / Connectivity Test"/><TextBlock TextWrapping="Wrap" Margin="0,4,0,0" Text="Tests DNS resolution, ICMP ping, and WinRM connectivity to the target machine."/><TextBlock FontStyle="Italic" Foreground="#8BB8D8" Margin="0,4,0,0" Text="Command: Test-Connection, Test-WSMan"/></StackPanel></ToolTip></Button.ToolTip>
                    </Button>
                    <Button Name="btnGetSystemInfo" Content="Get System Info" Style="{StaticResource ToolBtn}">
                        <Button.ToolTip><ToolTip Background="#1E3A5F" BorderBrush="#4A90D9" Foreground="White"><StackPanel MaxWidth="280"><TextBlock FontWeight="Bold" Text="Get System Info"/><TextBlock TextWrapping="Wrap" Margin="0,4,0,0" Text="Retrieves OS, CPU, RAM, disk usage, and network adapter details from the remote machine."/><TextBlock FontStyle="Italic" Foreground="#8BB8D8" Margin="0,4,0,0" Text="Command: Get-CimInstance Win32_*"/></StackPanel></ToolTip></Button.ToolTip>
                    </Button>
                    <Button Name="btnGetUpTime" Content="Get Up Time" Style="{StaticResource ToolBtn}">
                        <Button.ToolTip><ToolTip Background="#1E3A5F" BorderBrush="#4A90D9" Foreground="White"><StackPanel MaxWidth="280"><TextBlock FontWeight="Bold" Text="Get Uptime"/><TextBlock TextWrapping="Wrap" Margin="0,4,0,0" Text="Shows how long the remote machine has been running since its last boot."/><TextBlock FontStyle="Italic" Foreground="#8BB8D8" Margin="0,4,0,0" Text="Command: Get-CimInstance Win32_OperatingSystem"/></StackPanel></ToolTip></Button.ToolTip>
                    </Button>
                    <Button Name="btnFirewallStatus" Content="Firewall Status" Style="{StaticResource ToolBtn}">
                        <Button.ToolTip><ToolTip Background="#1E3A5F" BorderBrush="#4A90D9" Foreground="White"><StackPanel MaxWidth="280"><TextBlock FontWeight="Bold" Text="Firewall Status"/><TextBlock TextWrapping="Wrap" Margin="0,4,0,0" Text="Checks Windows Firewall state for Domain, Private, and Public profiles on the remote machine."/><TextBlock FontStyle="Italic" Foreground="#8BB8D8" Margin="0,4,0,0" Text="Command: Get-NetFirewallProfile"/></StackPanel></ToolTip></Button.ToolTip>
                    </Button>
                    <Button Name="btnHealthScan" Content="Health Scan" Style="{StaticResource ToolBtn}">
                        <Button.ToolTip><ToolTip Background="#1E3A5F" BorderBrush="#4A90D9" Foreground="White"><StackPanel MaxWidth="280"><TextBlock FontWeight="Bold" Text="Full Health Scan"/><TextBlock TextWrapping="Wrap" Margin="0,4,0,0" Text="Runs a full diagnostic: connectivity, uptime, disk space, RAM, logged-in user, firewall state, and battery status."/><TextBlock FontStyle="Italic" Foreground="#8BB8D8" Margin="0,4,0,0" Text="Command: Multiple diagnostic checks"/></StackPanel></ToolTip></Button.ToolTip>
                    </Button>
                    <Button Name="btnDiskCheck" Content="Disk Space Check" Style="{StaticResource ToolBtn}">
                        <Button.ToolTip><ToolTip Background="#1E3A5F" BorderBrush="#4A90D9" Foreground="White"><StackPanel MaxWidth="280"><TextBlock FontWeight="Bold" Text="Disk Space Check"/><TextBlock TextWrapping="Wrap" Margin="0,4,0,0" Text="Checks all fixed drives and warns if any drive is below 20% free space."/><TextBlock FontStyle="Italic" Foreground="#8BB8D8" Margin="0,4,0,0" Text="Command: Get-CimInstance Win32_LogicalDisk"/></StackPanel></ToolTip></Button.ToolTip>
                    </Button>
                    <Button Name="btnResetWiFi" Content="Reset Wi-Fi Adapter" Style="{StaticResource ToolBtn}">
                        <Button.ToolTip><ToolTip Background="#1E3A5F" BorderBrush="#4A90D9" Foreground="White"><StackPanel MaxWidth="280"><TextBlock FontWeight="Bold" Text="Reset Wi-Fi Adapter"/><TextBlock TextWrapping="Wrap" Margin="0,4,0,0" Text="Disables and re-enables the Wi-Fi adapter on the remote machine to fix connectivity issues."/><TextBlock FontStyle="Italic" Foreground="#8BB8D8" Margin="0,4,0,0" Text="Command: Disable/Enable-PnpDevice"/></StackPanel></ToolTip></Button.ToolTip>
                    </Button>
                </WrapPanel>
            </Expander>

            <!-- Remote Tools -->
            <Expander Header="Remote Tools" Grid.Column="1" Grid.Row="0" IsExpanded="True" Style="{StaticResource ExpanderSection}">
                <WrapPanel>
                    <Button Name="btnOpenPSSession" Content="Open PS Session" Style="{StaticResource ToolBtn}">
                        <Button.ToolTip><ToolTip Background="#1E3A5F" BorderBrush="#4A90D9" Foreground="White"><StackPanel MaxWidth="280"><TextBlock FontWeight="Bold" Text="Open PS Session"/><TextBlock TextWrapping="Wrap" Margin="0,4,0,0" Text="Opens an interactive PowerShell remoting session to the target machine in a new window."/><TextBlock FontStyle="Italic" Foreground="#8BB8D8" Margin="0,4,0,0" Text="Command: Enter-PSSession"/></StackPanel></ToolTip></Button.ToolTip>
                    </Button>
                    <Button Name="btnMSRA" Content="Launch MSRA" Style="{StaticResource ToolBtn}">
                        <Button.ToolTip><ToolTip Background="#1E3A5F" BorderBrush="#4A90D9" Foreground="White"><StackPanel MaxWidth="280"><TextBlock FontWeight="Bold" Text="Remote Assistance (MSRA)"/><TextBlock TextWrapping="Wrap" Margin="0,4,0,0" Text="Offers Remote Assistance to the target machine. Requires the Remote Assistance feature to be enabled."/><TextBlock FontStyle="Italic" Foreground="#8BB8D8" Margin="0,4,0,0" Text="Command: msra.exe /offerRA"/></StackPanel></ToolTip></Button.ToolTip>
                    </Button>
                    <Button Name="btnRDC" Content="Launch RDC" Style="{StaticResource ToolBtn}">
                        <Button.ToolTip><ToolTip Background="#1E3A5F" BorderBrush="#4A90D9" Foreground="White"><StackPanel MaxWidth="280"><TextBlock FontWeight="Bold" Text="Remote Desktop (RDC)"/><TextBlock TextWrapping="Wrap" Margin="0,4,0,0" Text="Connects to the target machine via Remote Desktop Connection."/><TextBlock FontStyle="Italic" Foreground="#8BB8D8" Margin="0,4,0,0" Text="Command: mstsc.exe /v:"/></StackPanel></ToolTip></Button.ToolTip>
                    </Button>
                    <Button Name="btnEventLog" Content="Open Event Log" Style="{StaticResource ToolBtn}">
                        <Button.ToolTip><ToolTip Background="#1E3A5F" BorderBrush="#4A90D9" Foreground="White"><StackPanel MaxWidth="280"><TextBlock FontWeight="Bold" Text="Open Event Viewer"/><TextBlock TextWrapping="Wrap" Margin="0,4,0,0" Text="Opens Event Viewer connected to the remote machine to browse system, application, and security logs."/><TextBlock FontStyle="Italic" Foreground="#8BB8D8" Margin="0,4,0,0" Text="Command: eventvwr.msc /computer:"/></StackPanel></ToolTip></Button.ToolTip>
                    </Button>
                </WrapPanel>
            </Expander>

            <!-- Management -->
            <Expander Header="Management" Grid.Column="0" Grid.Row="1" IsExpanded="True" Style="{StaticResource ExpanderSection}">
                <WrapPanel>
                    <Button Name="btnGpUpdate" Content="Run GPUpdate" Style="{StaticResource ToolBtn}">
                        <Button.ToolTip><ToolTip Background="#1E3A5F" BorderBrush="#4A90D9" Foreground="White"><StackPanel MaxWidth="280"><TextBlock FontWeight="Bold" Text="Run GPUpdate"/><TextBlock TextWrapping="Wrap" Margin="0,4,0,0" Text="Forces a Group Policy refresh on the remote machine. May briefly affect the user's session."/><TextBlock FontStyle="Italic" Foreground="#8BB8D8" Margin="0,4,0,0" Text="Command: gpupdate /force"/></StackPanel></ToolTip></Button.ToolTip>
                    </Button>
                    <Button Name="btnGetInstalledSoftware" Content="Get Installed Software" Style="{StaticResource ToolBtn}">
                        <Button.ToolTip><ToolTip Background="#1E3A5F" BorderBrush="#4A90D9" Foreground="White"><StackPanel MaxWidth="280"><TextBlock FontWeight="Bold" Text="Get Installed Software"/><TextBlock TextWrapping="Wrap" Margin="0,4,0,0" Text="Lists all installed software by reading the Uninstall registry keys. Requires credentials."/><TextBlock FontStyle="Italic" Foreground="#8BB8D8" Margin="0,4,0,0" Text="Command: Registry query (HKLM\...\Uninstall)"/></StackPanel></ToolTip></Button.ToolTip>
                    </Button>
                    <Button Name="btnLogOff" Content="Remote Log Off" Style="{StaticResource ToolBtn}">
                        <Button.ToolTip><ToolTip Background="#1E3A5F" BorderBrush="#4A90D9" Foreground="White"><StackPanel MaxWidth="280"><TextBlock FontWeight="Bold" Text="Remote Log Off"/><TextBlock TextWrapping="Wrap" Margin="0,4,0,0" Text="Lists active sessions on the remote machine and lets you log off a selected session by ID."/><TextBlock FontStyle="Italic" Foreground="#8BB8D8" Margin="0,4,0,0" Text="Command: quser, logoff"/></StackPanel></ToolTip></Button.ToolTip>
                    </Button>
                    <Button Name="btnClearPrintQueue" Content="Clear Print Queue" Style="{StaticResource ToolBtn}">
                        <Button.ToolTip><ToolTip Background="#1E3A5F" BorderBrush="#4A90D9" Foreground="White"><StackPanel MaxWidth="280"><TextBlock FontWeight="Bold" Text="Clear Print Queue"/><TextBlock TextWrapping="Wrap" Margin="0,4,0,0" Text="Stops the Print Spooler, clears all stuck print jobs, then restarts the Spooler service."/><TextBlock FontStyle="Italic" Foreground="#8BB8D8" Margin="0,4,0,0" Text="Command: Stop/Start-Service Spooler, Remove-PrintJob"/></StackPanel></ToolTip></Button.ToolTip>
                    </Button>
                    <Button Name="btnClearDNS" Content="Clear DNS Cache" Style="{StaticResource ToolBtn}">
                        <Button.ToolTip><ToolTip Background="#1E3A5F" BorderBrush="#4A90D9" Foreground="White"><StackPanel MaxWidth="280"><TextBlock FontWeight="Bold" Text="Clear DNS Cache"/><TextBlock TextWrapping="Wrap" Margin="0,4,0,0" Text="Flushes the DNS resolver cache on the remote machine to force fresh lookups."/><TextBlock FontStyle="Italic" Foreground="#8BB8D8" Margin="0,4,0,0" Text="Command: ipconfig /flushdns"/></StackPanel></ToolTip></Button.ToolTip>
                    </Button>
                    <Button Name="btnRestart" Content="Remote Restart" Style="{StaticResource ToolBtn}">
                        <Button.ToolTip><ToolTip Background="#1E3A5F" BorderBrush="#4A90D9" Foreground="White"><StackPanel MaxWidth="280"><TextBlock FontWeight="Bold" Text="Remote Restart"/><TextBlock TextWrapping="Wrap" Margin="0,4,0,0" Text="Restarts the remote machine. Confirmation required. Unsaved work on the target will be lost."/><TextBlock FontStyle="Italic" Foreground="#8BB8D8" Margin="0,4,0,0" Text="Command: Restart-Computer"/></StackPanel></ToolTip></Button.ToolTip>
                    </Button>
                </WrapPanel>
            </Expander>

            <!-- Utilities -->
            <Expander Header="Utilities" Grid.Column="1" Grid.Row="1" IsExpanded="True" Style="{StaticResource ExpanderSection}">
                <WrapPanel>
                    <Button Name="btnIncident" Content="Open IncidentIQ" Style="{StaticResource ToolBtn}" ToolTip="Open the IncidentIQ ticketing portal in your browser"/>
                    <Button Name="btnFixMDT" Content="Fix MDT Error" Style="{StaticResource ToolBtn}">
                        <Button.ToolTip><ToolTip Background="#1E3A5F" BorderBrush="#4A90D9" Foreground="White"><StackPanel MaxWidth="280"><TextBlock FontWeight="Bold" Text="Fix MDT Error"/><TextBlock TextWrapping="Wrap" Margin="0,4,0,0" Text="Removes MDT/WDT deployment artifacts from the remote machine: registry keys, scheduled tasks, directories, and startup shortcuts. Requires credentials."/><TextBlock FontStyle="Italic" Foreground="#8BB8D8" Margin="0,4,0,0" Text="Command: MDT/WDT artifact cleanup via Invoke-Command"/></StackPanel></ToolTip></Button.ToolTip>
                    </Button>
                    <Button Name="btnClearOutput" Content="Clear Output" Style="{StaticResource ToolBtn}" ToolTip="Clear the output box and reset status (Ctrl+L)"/>
                    <Button Name="btnCopyOutput" Content="Copy to Clipboard" Style="{StaticResource ToolBtn}" ToolTip="Copy output box contents to clipboard (Ctrl+Shift+C)"/>
                </WrapPanel>
            </Expander>
        </Grid>

        <!-- Progress Bar (indeterminate) -->
        <ProgressBar Name="progressBar" Margin="10,0,10,6" Height="5"
                     Visibility="Hidden" IsIndeterminate="True"
                     Foreground="#4A90D9" Background="#1E3A5F"/>

        <!-- Search Bar (collapsed by default, Ctrl+F) -->
        <Border Name="searchBorder" Margin="10,0,10,6"
                Background="#1E3A5F" BorderBrush="#4A90D9" BorderThickness="1" CornerRadius="4"
                Visibility="Collapsed" Height="32">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <Label Grid.Column="0" Content="Find:" Foreground="#8BB8D8" VerticalAlignment="Center" Padding="8,0"/>
                <TextBox Name="txtSearch" Grid.Column="1" Background="#0D0D0D" Foreground="#D4D4D4"
                         VerticalAlignment="Center" Margin="0,4,4,4" FontFamily="Consolas" FontSize="12" Padding="4,2"/>
                <Label Name="lblSearchStatus" Grid.Column="2" Content="" Foreground="#8BB8D8"
                       VerticalAlignment="Center" Padding="4,0" FontSize="11"/>
                <Button Name="btnCloseSearch" Grid.Column="3" Content="X" Width="24" Height="24"
                        Margin="0,4,8,4" Style="{StaticResource ToolBtn}" ToolTip="Close search (Esc)"/>
            </Grid>
        </Border>

        </StackPanel>

        <!-- GridSplitter: drag to resize button area vs output area -->
        <GridSplitter Grid.Row="2" Height="5" HorizontalAlignment="Stretch"
                      Background="#2A5A8F" Cursor="SizeNS" ResizeBehavior="PreviousAndNext"/>

        <!-- Output Box (expands with window) -->
        <RichTextBox Name="terminalOutputBox" Grid.Row="3" Margin="10,0,10,6" IsReadOnly="True"
                     VerticalScrollBarVisibility="Auto" Background="#0D0D0D" Foreground="#D4D4D4"
                     FontFamily="Consolas" FontSize="12" IsDocumentEnabled="True"
                     BorderBrush="#2A5A8F" BorderThickness="1" Padding="6">
            <RichTextBox.Document>
                <FlowDocument PageWidth="5000"/>
            </RichTextBox.Document>
            <RichTextBox.ContextMenu>
                <ContextMenu Background="#1E3A5F" BorderBrush="#4A90D9" Foreground="White">
                    <MenuItem Name="ctxCopy" Header="Copy" InputGestureText="Ctrl+Shift+C"/>
                    <MenuItem Name="ctxSelectAll" Header="Select All"/>
                    <Separator/>
                    <MenuItem Name="ctxSearch" Header="Search" InputGestureText="Ctrl+F"/>
                    <MenuItem Name="ctxClear" Header="Clear" InputGestureText="Ctrl+L"/>
                    <Separator/>
                    <MenuItem Name="ctxSaveToFile" Header="Save to File..."/>
                </ContextMenu>
            </RichTextBox.ContextMenu>
        </RichTextBox>

        <!-- Status Bar -->
        <StatusBar Grid.Row="4" Background="#011A40" BorderBrush="#2A5A8F" BorderThickness="0,1,0,0" Height="26">
            <StatusBarItem>
                <Label Name="lblStatus" Content="Ready  -  enter a hostname or IP above  |  Ctrl+F: Search  |  Enter: Ping" Foreground="#8BB8D8" Padding="4,0" FontSize="12"/>
            </StatusBarItem>
            <StatusBarItem HorizontalAlignment="Right">
                <Label Name="lblOpCount" Content="Ops: 0" Foreground="#8BB8D8" Padding="4,0" FontSize="12"/>
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
$searchBorder = $Window.FindName("searchBorder")
$txtSearch = $Window.FindName("txtSearch")
$btnCloseSearch = $Window.FindName("btnCloseSearch")
$lblSearchStatus = $Window.FindName("lblSearchStatus")
$lblOpCount = $Window.FindName("lblOpCount")
$ctxCopy = $terminalOutputBox.ContextMenu.Items | Where-Object { $_ -is [System.Windows.Controls.MenuItem] -and $_.Header -eq "Copy" } | Select-Object -First 1
$ctxSelectAll = $terminalOutputBox.ContextMenu.Items | Where-Object { $_ -is [System.Windows.Controls.MenuItem] -and $_.Header -eq "Select All" } | Select-Object -First 1
$ctxSearch = $terminalOutputBox.ContextMenu.Items | Where-Object { $_ -is [System.Windows.Controls.MenuItem] -and $_.Header -eq "Search" } | Select-Object -First 1
$ctxClear = $terminalOutputBox.ContextMenu.Items | Where-Object { $_ -is [System.Windows.Controls.MenuItem] -and $_.Header -eq "Clear" } | Select-Object -First 1
$ctxSaveToFile = $terminalOutputBox.ContextMenu.Items | Where-Object { $_ -is [System.Windows.Controls.MenuItem] -and $_.Header -eq "Save to File..." } | Select-Object -First 1

# ============================================================
# Async Infrastructure
# ============================================================

# Operation counter
$script:OperationCount = 0

# RunspacePool for background operations
$script:RunspacePool = [runspacefactory]::CreateRunspacePool(1, 5)
$script:RunspacePool.ApartmentState = "STA"
$script:RunspacePool.Open()
$script:ActiveRunspaces = [System.Collections.ArrayList]::new()

# All action buttons that should be disabled during operations
$script:AllActionButtons = @(
    $btnResolve, $btnPing, $btnGetSystemInfo, $btnGpUpdate, $btnGetInstalledSoftware,
    $btnGetUpTime, $btnDiskCheck, $btnResetWiFi, $btnHealthScan, $btnFixMDT,
    $btnClearPrintQueue, $btnClearDNS, $btnRestart, $btnFirewallStatus, $btnLogOff,
    $btnOpenPSSession, $btnMSRA, $btnRDC, $btnEventLog
)

# ============================================================
# Utility Functions
# ============================================================

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
    param($ComputerName)

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
        $ping = Test-Connection -ComputerName $ComputerName -Count 1 -Quiet
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
        return Get-Content $historyPath | Select-Object -First 15
    }
    return @()
}

function global:Save-HostHistory {
    param([string]$hostname)
    $historyPath = "$env:APPDATA\MultiTool\hostHistory.txt"
    $dir = Split-Path $historyPath
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $existing = @()
    if (Test-Path $historyPath) { $existing = Get-Content $historyPath }
    $updated = @($hostname) + ($existing | Where-Object { $_ -ne $hostname }) | Select-Object -First 15
    $updated | Set-Content $historyPath
}

# Helper function for validating hostname/IP input
function Validate-Hostname {
    param($hostname)
    if ($hostname -eq "Enter Hostname/IP" -or $hostname -eq "" -or $hostname -eq $null) {
        return $true  # Invalid
    }
    return -not [InputValidator]::IsValidHostnameOrIP($hostname)
}

# ============================================================
# UI Helper Functions
# ============================================================

function global:Set-ButtonsEnabled {
    param([bool]$Enabled)
    foreach ($btn in $script:AllActionButtons) {
        if ($btn) { $btn.IsEnabled = $Enabled }
    }
}

function global:Update-StatusBar {
    param([string]$Message)
    $timestamp = Get-Date -Format 'HH:mm:ss'
    $lblStatus.Content = "[$timestamp] $Message"
}

function global:Get-OutputText {
    $range = New-Object System.Windows.Documents.TextRange(
        $terminalOutputBox.Document.ContentStart,
        $terminalOutputBox.Document.ContentEnd)
    return $range.Text
}

function global:Append-Output {
    param([string]$Text, [string]$Header = $null)

    $doc = $terminalOutputBox.Document
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $separator = "=" * 60

    $conv = [System.Windows.Media.BrushConverter]::new()
    $headerBrush    = $conv.ConvertFromString("#4A90D9")
    $timestampBrush = $conv.ConvertFromString("#8BB8D8")
    $separatorBrush = $conv.ConvertFromString("#3A5A7F")
    $errorBrush     = $conv.ConvertFromString("#E06C75")
    $successBrush   = $conv.ConvertFromString("#98C379")
    $warningBrush   = $conv.ConvertFromString("#E5C07B")
    $sectionBrush   = $conv.ConvertFromString("#4A90D9")
    $normalBrush    = $conv.ConvertFromString("#D4D4D4")

    if ($Header) {
        $headerPara = New-Object System.Windows.Documents.Paragraph
        $headerPara.Margin = [System.Windows.Thickness]::new(0, 8, 0, 0)
        $tsRun = New-Object System.Windows.Documents.Run("[$timestamp] ")
        $tsRun.Foreground = $timestampBrush
        $hRun = New-Object System.Windows.Documents.Run($Header)
        $hRun.Foreground = $headerBrush
        $hRun.FontWeight = [System.Windows.FontWeights]::Bold
        $headerPara.Inlines.Add($tsRun)
        $headerPara.Inlines.Add($hRun)
        $doc.Blocks.Add($headerPara)

        $sepPara = New-Object System.Windows.Documents.Paragraph
        $sepPara.Margin = [System.Windows.Thickness]::new(0)
        $sepRun = New-Object System.Windows.Documents.Run($separator)
        $sepRun.Foreground = $separatorBrush
        $sepPara.Inlines.Add($sepRun)
        $doc.Blocks.Add($sepPara)
    }

    foreach ($line in ($Text -split "`r?`n")) {
        $para = New-Object System.Windows.Documents.Paragraph
        $para.Margin = [System.Windows.Thickness]::new(0)
        $run = New-Object System.Windows.Documents.Run($line)

        if     ($line -match '(?i)^(ERROR|FAIL|OFFLINE|NOT REACHABLE|CRITICAL|\!\!)') { $run.Foreground = $errorBrush }
        elseif ($line -match '(?i)^(SUCCESS|PASS|ONLINE|REACHABLE|COMPLETED|FIXED)')  { $run.Foreground = $successBrush }
        elseif ($line -match '(?i)^(WARNING|WARN|CAUTION|LOW|DISABLED)')               { $run.Foreground = $warningBrush }
        elseif ($line -match '^\[.+\]') {
            $run.Foreground = $sectionBrush
            $run.FontWeight = [System.Windows.FontWeights]::SemiBold
        } else { $run.Foreground = $normalBrush }

        $para.Inlines.Add($run)
        $doc.Blocks.Add($para)
    }

    $terminalOutputBox.ScrollToEnd()

    # Cap document to prevent memory growth in long sessions
    while ($doc.Blocks.Count -gt 600) {
        $doc.Blocks.Remove($doc.Blocks.FirstBlock)
    }
}

function global:Show-Progress {
    param([bool]$Show)
    if ($Show) {
        $progressBar.Visibility = [System.Windows.Visibility]::Visible
    } else {
        $progressBar.Visibility = [System.Windows.Visibility]::Hidden
    }
}

function global:Update-WindowTitle {
    param([string]$Hostname = $null)
    if ($Hostname -and $Hostname -ne "Enter Hostname/IP") {
        $Window.Title = "Multi-Tool - $Hostname"
    } else {
        $Window.Title = "Multi-Tool"
    }
}

function global:Set-HostnameColor {
    param($brush)
    $txtHostname.Background = $brush
    if ($script:HostnameInnerBox) { $script:HostnameInnerBox.Background = $brush }
}

# ============================================================
# Core Async Wrapper
# ============================================================

function global:Invoke-Async {
    param(
        [scriptblock]$ScriptBlock,
        [object[]]$Arguments = @(),
        [scriptblock]$OnComplete,
        [string]$Label = "Operation",
        [hashtable]$Context = @{}
    )

    Set-ButtonsEnabled -Enabled $false
    Show-Progress -Show $true
    Update-StatusBar "Running $Label..."

    $ps = [powershell]::Create()
    $ps.RunspacePool = $script:RunspacePool
    [void]$ps.AddScript($ScriptBlock)
    foreach ($arg in $Arguments) {
        [void]$ps.AddArgument($arg)
    }

    $handle = $ps.BeginInvoke()

    [void]$script:ActiveRunspaces.Add(@{
        PowerShell  = $ps
        Handle      = $handle
        OnComplete  = $OnComplete
        Label       = $Label
        StartTime   = Get-Date
        Context     = $Context
    })

    # Start timer if not already running
    if (-not $script:AsyncTimer.IsEnabled) {
        $script:AsyncTimer.Start()
    }
}

# DispatcherTimer to poll runspace completion
$script:AsyncTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:AsyncTimer.Interval = [TimeSpan]::FromMilliseconds(500)

$script:AsyncTimer.Add_Tick({
    $completed = @()

    foreach ($item in $script:ActiveRunspaces) {
        if ($item.Handle.IsCompleted) {
            $completed += $item

            try {
                $result = $item.PowerShell.EndInvoke($item.Handle)
                $duration = [math]::Round(((Get-Date) - $item.StartTime).TotalSeconds, 1)

                # Check for errors in the stream
                $errors = $item.PowerShell.Streams.Error
                if ($errors.Count -gt 0) {
                    $errMsg = ($errors | ForEach-Object { $_.Exception.Message }) -join "`r`n"
                    $Window.Dispatcher.Invoke([action]{
                        Append-Output "ERROR: $errMsg" -Header "$($item.Label) Failed"
                        Update-StatusBar "$($item.Label) failed after ${duration}s"
                    }.GetNewClosure())
                } elseif ($item.OnComplete) {
                    $completionBlock = $item.OnComplete
                    $ctx = $item.Context
                    $Window.Dispatcher.Invoke([action]{
                        & $completionBlock $result $ctx
                        Update-StatusBar "$($item.Label) completed in ${duration}s"
                        $script:OperationCount++
                        $lblOpCount.Content = "Ops: $script:OperationCount"
                    }.GetNewClosure())
                }
            }
            catch {
                $errMessage = $_.Exception.Message
                $lbl = $item.Label
                $Window.Dispatcher.Invoke([action]{
                    Append-Output "ERROR: $errMessage" -Header "$lbl Failed"
                    Update-StatusBar "$lbl failed"
                }.GetNewClosure())
                [Logger]::Error("Async operation '$($item.Label)' failed: $errMessage")
            }
            finally {
                $item.PowerShell.Dispose()
            }
        }
    }

    foreach ($item in $completed) {
        [void]$script:ActiveRunspaces.Remove($item)
    }

    if ($script:ActiveRunspaces.Count -eq 0 -and $completed.Count -gt 0) {
        Set-ButtonsEnabled -Enabled $true
        Show-Progress -Show $false
        $script:AsyncTimer.Stop()
    }
    elseif ($script:ActiveRunspaces.Count -gt 0) {
        # Show live elapsed time in status bar
        $running = $script:ActiveRunspaces[0]
        $elapsed = [math]::Round(((Get-Date) - $running.StartTime).TotalSeconds, 0)
        $lblStatus.Content = "[Running] $($running.Label) ... ${elapsed}s elapsed"
    }
})

# ============================================================
# Keyboard Shortcuts
# ============================================================

$Window.Add_KeyDown({
    param($sender, $e)

    # Ctrl+Shift+C - Copy output
    if ($e.Key -eq 'C' -and
        ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Control) -and
        ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Shift)) {
        $txt = Get-OutputText
        if ($txt.Trim()) {
            Set-Clipboard -Value $txt
            Update-StatusBar "Output copied to clipboard"
        }
        $e.Handled = $true
        return
    }

    # Ctrl+L - Clear output
    if ($e.Key -eq 'L' -and
        ([System.Windows.Input.Keyboard]::Modifiers -eq [System.Windows.Input.ModifierKeys]::Control)) {
        $terminalOutputBox.Document.Blocks.Clear()
        Update-StatusBar "Output cleared"
        Update-WindowTitle
        $e.Handled = $true
        return
    }

    # Ctrl+F - Toggle search
    if ($e.Key -eq 'F' -and
        ([System.Windows.Input.Keyboard]::Modifiers -eq [System.Windows.Input.ModifierKeys]::Control)) {
        if ($searchBorder.Visibility -eq [System.Windows.Visibility]::Collapsed) {
            $searchBorder.Visibility = [System.Windows.Visibility]::Visible
            $txtSearch.Focus()
        } else {
            $searchBorder.Visibility = [System.Windows.Visibility]::Collapsed
            $txtSearch.Text = ""
        }
        $e.Handled = $true
        return
    }

    # Escape - Close search
    if ($e.Key -eq 'Escape' -and $searchBorder.Visibility -eq [System.Windows.Visibility]::Visible) {
        $searchBorder.Visibility = [System.Windows.Visibility]::Collapsed
        $txtSearch.Text = ""
        $e.Handled = $true
        return
    }
})

# Enter key in hostname ComboBox triggers Ping
$txtHostname.Add_KeyDown({
    param($sender, $e)
    if ($e.Key -eq 'Return') {
        $btnPing.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))
        $e.Handled = $true
    }
})

# ============================================================
# Search Functionality (TextPointer-based for RichTextBox)
# ============================================================

# Stores the TextPointer of the last found match start
$script:SearchLastPointer = $null

function global:Find-InRichTextBox {
    param([string]$SearchText, [System.Windows.Documents.TextPointer]$StartPointer = $null)

    if (-not $StartPointer) {
        $StartPointer = $terminalOutputBox.Document.ContentStart
    }

    $endRange = New-Object System.Windows.Documents.TextRange(
        $StartPointer,
        $terminalOutputBox.Document.ContentEnd)
    $fullText = $endRange.Text

    $index = $fullText.IndexOf($SearchText, [System.StringComparison]::OrdinalIgnoreCase)
    if ($index -lt 0) { return $null }

    # Walk forward through TextPointers to find the character position
    $pointer = $StartPointer
    $charsTraversed = 0
    while ($pointer -ne $null -and $charsTraversed -lt $index) {
        $ctx = $pointer.GetPointerContext([System.Windows.Documents.LogicalDirection]::Forward)
        if ($ctx -eq [System.Windows.Documents.TextPointerContext]::Text) {
            $run = $pointer.GetTextInRun([System.Windows.Documents.LogicalDirection]::Forward)
            $remaining = $index - $charsTraversed
            if ($run.Length -ge $remaining) {
                $pointer = $pointer.GetPositionAtOffset($remaining)
                $charsTraversed = $index
                break
            }
            $charsTraversed += $run.Length
        }
        $next = $pointer.GetNextContextPosition([System.Windows.Documents.LogicalDirection]::Forward)
        if ($next -eq $null) { break }
        $pointer = $next
    }

    if ($pointer) {
        $endPointer = $pointer.GetPositionAtOffset($SearchText.Length, [System.Windows.Documents.LogicalDirection]::Forward)
        if ($endPointer) {
            return @{ Start = $pointer; End = $endPointer }
        }
    }
    return $null
}

$txtSearch.Add_TextChanged({
    $searchText = $txtSearch.Text
    $script:SearchLastPointer = $null

    if (-not $searchText) {
        $terminalOutputBox.Selection.Select(
            $terminalOutputBox.Document.ContentStart,
            $terminalOutputBox.Document.ContentStart)
        $lblSearchStatus.Content = ""
        return
    }

    $fullText = Get-OutputText
    if (-not $fullText.Trim()) {
        $lblSearchStatus.Content = "No content"
        return
    }

    $match = Find-InRichTextBox -SearchText $searchText
    if ($match) {
        $script:SearchLastPointer = $match.Start
        $terminalOutputBox.Selection.Select($match.Start, $match.End)
        $terminalOutputBox.ScrollToVerticalOffset(
            $terminalOutputBox.VerticalOffset)
        # Count total matches
        $count = 0; $pos = 0
        while (($pos = $fullText.IndexOf($searchText, $pos, [System.StringComparison]::OrdinalIgnoreCase)) -ge 0) {
            $count++; $pos += $searchText.Length
        }
        $lblSearchStatus.Content = "$count match$(if($count -ne 1){'es'})"
        $txtSearch.Focus()
    } else {
        $terminalOutputBox.Selection.Select(
            $terminalOutputBox.Document.ContentStart,
            $terminalOutputBox.Document.ContentStart)
        $lblSearchStatus.Content = "No matches"
    }
})

# F3 or Enter in search box - find next
$txtSearch.Add_KeyDown({
    param($sender, $e)
    if ($e.Key -eq 'F3' -or $e.Key -eq 'Return') {
        $searchText = $txtSearch.Text
        $fullText = Get-OutputText
        if (-not $searchText -or -not $fullText.Trim()) { $e.Handled = $true; return }

        # Start search after current match, or from beginning
        $startPtr = $null
        if ($script:SearchLastPointer) {
            $startPtr = $script:SearchLastPointer.GetPositionAtOffset(
                $searchText.Length, [System.Windows.Documents.LogicalDirection]::Forward)
        }

        $match = Find-InRichTextBox -SearchText $searchText -StartPointer $startPtr
        if (-not $match) {
            # Wrap around from document start
            $match = Find-InRichTextBox -SearchText $searchText
        }
        if ($match) {
            $script:SearchLastPointer = $match.Start
            $terminalOutputBox.Selection.Select($match.Start, $match.End)
            $txtSearch.Focus()
        }
        $e.Handled = $true
    }
    if ($e.Key -eq 'Escape') {
        $searchBorder.Visibility = [System.Windows.Visibility]::Collapsed
        $txtSearch.Text = ""
        $e.Handled = $true
    }
})

$btnCloseSearch.Add_Click({
    $searchBorder.Visibility = [System.Windows.Visibility]::Collapsed
    $txtSearch.Text = ""
})

# ============================================================
# Context Menu Handlers
# ============================================================

$ctxCopy.Add_Click({
    $txt = Get-OutputText
    if ($txt.Trim()) {
        Set-Clipboard -Value $txt
        Update-StatusBar "Output copied to clipboard"
    } else {
        Update-StatusBar "Nothing to copy"
    }
})

$ctxSelectAll.Add_Click({
    $terminalOutputBox.SelectAll()
})

$ctxSearch.Add_Click({
    if ($searchBorder.Visibility -eq [System.Windows.Visibility]::Collapsed) {
        $searchBorder.Visibility = [System.Windows.Visibility]::Visible
        $txtSearch.Focus()
    } else {
        $searchBorder.Visibility = [System.Windows.Visibility]::Collapsed
        $txtSearch.Text = ""
    }
})

$ctxClear.Add_Click({
    $terminalOutputBox.Document.Blocks.Clear()
    Update-StatusBar "Output cleared"
    Update-WindowTitle
    Set-HostnameColor ([System.Windows.Media.Brushes]::White)
})

$ctxSaveToFile.Add_Click({
    $txt = Get-OutputText
    if (-not $txt.Trim()) {
        Update-StatusBar "Nothing to save"
        return
    }
    $dlg = New-Object Microsoft.Win32.SaveFileDialog
    $dlg.Filter = "Text Files (*.txt)|*.txt|All Files (*.*)|*.*"
    $dlg.FileName = "MultiTool-Output-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    if ($dlg.ShowDialog()) {
        try {
            $txt | Out-File -FilePath $dlg.FileName -Encoding UTF8
            Update-StatusBar "Output saved to $($dlg.FileName)"
            [Logger]::Info("Output saved to $($dlg.FileName)")
        } catch {
            Update-StatusBar "Save failed: $($_.Exception.Message)"
            [Logger]::Error("Save to file failed: $($_.Exception.Message)")
        }
    }
})

# ============================================================
# Event Handlers
# ============================================================

# Ping Button Click Event
$btnPing.Add_Click({
    $hostnameOrIp = [InputValidator]::SanitizeInput($txtHostname.Text)

    if (Validate-Hostname $hostnameOrIp) {
        Append-Output "Please enter a valid hostname/IP." -Header "Validation Error"
        return
    }

    Update-WindowTitle -Hostname $hostnameOrIp
    $computer = $hostnameOrIp

    Invoke-Async -Label "Ping Test on $computer" -Arguments @($computer) -Context @{ Computer = $computer } -ScriptBlock {
        param($comp)

        $result = @{ IsReachable = $false; CanResolve = $false; CanPing = $false; CanWinRM = $false; User = $null }

        try { Resolve-DnsName -Name $comp -ErrorAction Stop | Out-Null; $result.CanResolve = $true } catch { }
        try { $result.CanPing = Test-Connection -ComputerName $comp -Count 1 -Quiet } catch { }
        try { Test-WSMan -ComputerName $comp -ErrorAction Stop | Out-Null; $result.CanWinRM = $true } catch { }
        $result.IsReachable = $result.CanPing -or $result.CanWinRM

        if ($result.CanWinRM) {
            try {
                $result.User = Invoke-Command -ComputerName $comp -ScriptBlock {
                    quser 2>$null | Select-Object -Skip 1 | ForEach-Object {
                        if ($_ -match '^\s*>?\s*(\S+)') { $matches[1] }
                    } | Select-Object -First 1
                } -ErrorAction SilentlyContinue
            } catch { }
        }

        return $result
    } -OnComplete {
        param($result, $ctx)
        $r = $result | Select-Object -First 1

        if ($r.IsReachable) {
            Set-HostnameColor ([System.Windows.Media.Brushes]::Green)
            $statusParts = @()
            if ($r.CanPing) { $statusParts += "Ping: OK" }
            if ($r.CanWinRM) { $statusParts += "WinRM: OK" }
            if ($r.CanResolve) { $statusParts += "DNS: OK" }
            if ($r.User) { $statusParts += "User: $($r.User)" }

            Save-HostHistory -hostname $ctx.Computer
            if (-not $txtHostname.Items.Contains($ctx.Computer)) {
                $txtHostname.Items.Insert(0, $ctx.Computer)
            }

            Append-Output ($statusParts -join "`r`n") -Header "Connection Successful - $($ctx.Computer)"
            [Logger]::Info("Successful connection test to $($ctx.Computer)")
        } else {
            Set-HostnameColor ([System.Windows.Media.Brushes]::Orange)
            Append-Output "Host may be unreachable or WinRM disabled." -Header "Connection Failed - $($ctx.Computer)"
            [Logger]::Warn("Connection test failed for $($ctx.Computer)")
        }
    }
})

# Get System Info Button Click Event
$btnGetSystemInfo.Add_Click({
    $remoteMachine = [InputValidator]::SanitizeInput($txtHostname.Text)
    if (Validate-Hostname $remoteMachine) {
        Append-Output "Please enter a valid machine name or IP." -Header "Validation Error"
        return
    }

    Update-WindowTitle -Hostname $remoteMachine
    $computer = $remoteMachine

    Invoke-Async -Label "System Info on $computer" -Arguments @($computer) -Context @{ Computer = $computer } -ScriptBlock {
        param($comp)

        $cimSession = New-CimSession -ComputerName $comp -ErrorAction Stop
        try {
            $osInfo = Get-CimInstance -CimSession $cimSession -ClassName Win32_OperatingSystem
            $cpuInfo = Get-CimInstance -CimSession $cimSession -ClassName Win32_Processor
            $memInfo = Get-CimInstance -CimSession $cimSession -ClassName Win32_PhysicalMemory
            $diskInfo = Get-CimInstance -CimSession $cimSession -ClassName Win32_LogicalDisk -Filter "DriveType=3"
            $networkInfo = Get-CimInstance -CimSession $cimSession -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True"

            $lastBoot = $osInfo.LastBootUpTime
            if ($lastBoot) {
                $uptime = (Get-Date) - $lastBoot
                $uptimeString = "{0:D2} days {1:D2} hrs {2:D2} mins {3:D2} secs" -f $uptime.Days, $uptime.Hours, $uptime.Minutes, $uptime.Seconds
            } else {
                $uptimeString = "Unavailable"
            }

            $totalMemoryGB = [math]::round(($memInfo | Measure-Object -Property Capacity -Sum).Sum / 1GB, 2)

            $diskOutput = ($diskInfo | ForEach-Object {
                "$($_.DeviceID): Total: $([math]::round($_.Size / 1GB, 2)) GB  Free: $([math]::round($_.FreeSpace / 1GB, 2)) GB"
            }) -join "`r`n"

            $ipAddress = ($networkInfo.IPAddress | Where-Object { $_ -match '\.' } | Select-Object -First 1) -join ", "
            $dnsServers = ($networkInfo.DNSServerSearchOrder | Where-Object { $_ }) -join ", "

            return @{
                Success = $true
                Data = @(
                    "OS: $($osInfo.Caption)",
                    "Architecture: $($osInfo.OSArchitecture)",
                    "Machine Name: $($osInfo.CSName)",
                    "Current User: $($osInfo.UserName)",
                    "Uptime: $uptimeString",
                    "",
                    "CPU: $($cpuInfo.Name)",
                    "Cores: $($cpuInfo.NumberOfCores)  |  Clock: $($cpuInfo.MaxClockSpeed) MHz",
                    "",
                    "Total RAM: $totalMemoryGB GB",
                    "",
                    $diskOutput,
                    "",
                    "IP Address: $ipAddress",
                    "DNS Servers: $dnsServers"
                ) -join "`r`n"
            }
        }
        finally {
            Remove-CimSession -CimSession $cimSession -ErrorAction SilentlyContinue
        }
    } -OnComplete {
        param($result, $ctx)
        $r = $result | Select-Object -First 1
        if ($r.Success) {
            Append-Output $r.Data -Header "System Information - $($ctx.Computer)"
            [Logger]::Info("Retrieved system information for $($ctx.Computer)")
        } else {
            Append-Output "ERROR: $($r.Error)" -Header "System Info Failed - $($ctx.Computer)"
        }
    }
})

# Resolve Button Event
$btnResolve.Add_Click({
    $hostnameOrIp = [InputValidator]::SanitizeInput($txtHostname.Text)

    if (Validate-Hostname $hostnameOrIp) {
        Append-Output "Please enter a valid hostname or IP address." -Header "Validation Error"
        return
    }

    Update-WindowTitle -Hostname $hostnameOrIp
    $input = $hostnameOrIp

    Invoke-Async -Label "Resolve $input" -Arguments @($input) -Context @{ Computer = $input } -ScriptBlock {
        param($target)

        $isIP = $target -match '^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'

        if ($isIP) {
            $resolved = Resolve-DnsName -Name $target -Type PTR -ErrorAction Stop
            return @{ Success = $true; Data = "Resolved IP to hostname: $($resolved.NameHost)" }
        } else {
            $resolved = Resolve-DnsName -Name $target -ErrorAction Stop
            $ips = $resolved | Where-Object { $_.QueryType -eq "A" -or $_.QueryType -eq "AAAA" } | Select-Object -ExpandProperty IPAddress
            if ($ips) {
                return @{ Success = $true; Data = "Resolved '$target' to:`r`n$($ips -join "`r`n")" }
            } else {
                return @{ Success = $true; Data = "No IP addresses found for '$target'." }
            }
        }
    } -OnComplete {
        param($result, $ctx)
        $r = $result | Select-Object -First 1
        if ($r.Success) {
            Append-Output $r.Data -Header "DNS Resolution - $($ctx.Computer)"
            [Logger]::Info("Resolved $($ctx.Computer)")
        }
    }
})

# Open PowerShell Session Button Event (non-blocking, just launches process)
$btnOpenPSSession.Add_Click({
    $hostnameOrIp = [InputValidator]::SanitizeInput($txtHostname.Text)

    if (Validate-Hostname $hostnameOrIp) {
        Append-Output "Please enter a valid hostname or IP address." -Header "Validation Error"
        return
    }

    try {
        $command = "Enter-PSSession -ComputerName '$hostnameOrIp' -ErrorAction Stop"
        Start-Process powershell.exe -ArgumentList "-NoExit", "-Command", $command
        Append-Output "Opened remote PowerShell session in new window." -Header "PS Session - $hostnameOrIp"
        Update-StatusBar "PS Session opened for $hostnameOrIp"
        [Logger]::Info("Opened PowerShell session to $hostnameOrIp")
    } catch {
        Append-Output "ERROR: $($_.Exception.Message)" -Header "PS Session Failed - $hostnameOrIp"
        [Logger]::Error("PS Session error: $($_.Exception.Message)")
    }
})

# GPUpdate Button Click Event
$btnGpUpdate.Add_Click({
    $hostnameOrIp = [InputValidator]::SanitizeInput($txtHostname.Text)

    if (Validate-Hostname $hostnameOrIp) {
        Append-Output "Please enter a valid hostname or IP address." -Header "Validation Error"
        return
    }

    $confirmResult = [System.Windows.MessageBox]::Show(
        "This will force a Group Policy update on $hostnameOrIp.`r`n`r`nThis may temporarily affect the user's session. Continue?",
        "Confirm GPUpdate",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    )
    if ($confirmResult -ne [System.Windows.MessageBoxResult]::Yes) {
        Update-StatusBar "GPUpdate cancelled"
        return
    }

    Update-WindowTitle -Hostname $hostnameOrIp
    $computer = $hostnameOrIp

    Invoke-Async -Label "GPUpdate on $computer" -Arguments @($computer) -Context @{ Computer = $computer } -ScriptBlock {
        param($comp)
        $output = Invoke-Command -ComputerName $comp -ScriptBlock { gpupdate /force 2>&1 | Out-String } -ErrorAction Stop
        return @{ Success = $true; Data = $output }
    } -OnComplete {
        param($result, $ctx)
        $r = $result | Select-Object -First 1
        if ($r.Success) {
            Append-Output $r.Data -Header "GPUpdate - $($ctx.Computer)"
        }
    }
})

# MSRA Button Click Event (non-blocking)
$btnMSRA.Add_Click({
    $hostnameOrIp = [InputValidator]::SanitizeInput($txtHostname.Text)

    if (Validate-Hostname $hostnameOrIp) {
        Append-Output "Please enter a valid hostname or IP address." -Header "Validation Error"
        return
    }

    try {
        Start-Process "msra" -ArgumentList "/offerRA $hostnameOrIp"
        Append-Output "MSRA launched." -Header "Remote Assistance - $hostnameOrIp"
        Update-StatusBar "MSRA launched for $hostnameOrIp"
        [Logger]::Info("Launched MSRA for $hostnameOrIp")
    } catch {
        Append-Output "ERROR: $($_.Exception.Message)" -Header "MSRA Failed - $hostnameOrIp"
        [Logger]::Error("MSRA error: $($_.Exception.Message)")
    }
})

# RDC Button Click Event (non-blocking)
$btnRDC.Add_Click({
    $hostnameOrIp = [InputValidator]::SanitizeInput($txtHostname.Text)

    if (Validate-Hostname $hostnameOrIp) {
        Append-Output "Please enter a valid hostname or IP address." -Header "Validation Error"
        return
    }

    try {
        Start-Process "mstsc" -ArgumentList "/v:$hostnameOrIp"
        Append-Output "Remote Desktop launched." -Header "RDC - $hostnameOrIp"
        Update-StatusBar "RDC launched for $hostnameOrIp"
        [Logger]::Info("Launched RDC for $hostnameOrIp")
    } catch {
        Append-Output "ERROR: $($_.Exception.Message)" -Header "RDC Failed - $hostnameOrIp"
        [Logger]::Error("RDC error: $($_.Exception.Message)")
    }
})

# Event Log Button Click Event (non-blocking)
$btnEventLog.Add_Click({
    $hostnameOrIp = [InputValidator]::SanitizeInput($txtHostname.Text)

    if (Validate-Hostname $hostnameOrIp) {
        Append-Output "Please enter a valid hostname or IP address." -Header "Validation Error"
        return
    }

    try {
        Start-Process "eventvwr.msc" -ArgumentList "/computer:$hostnameOrIp"
        Append-Output "Event Viewer opened." -Header "Event Log - $hostnameOrIp"
        Update-StatusBar "Event Viewer opened for $hostnameOrIp"
        [Logger]::Info("Opened Event Viewer for $hostnameOrIp")
    } catch {
        Append-Output "ERROR: $($_.Exception.Message)" -Header "Event Viewer Failed - $hostnameOrIp"
        [Logger]::Error("Event Viewer error: $($_.Exception.Message)")
    }
})

# IncidentIQ Button Click Event (non-blocking)
$btnIncident.Add_Click({
    Start-Process "https://sidneycityschools.incidentiq.com/"
    Update-StatusBar "IncidentIQ opened in browser"
})

# Get Installed Software Button Click Event
$btnGetInstalledSoftware.Add_Click({
    $remoteMachine = [InputValidator]::SanitizeInput($txtHostname.Text)

    if (Validate-Hostname $remoteMachine) {
        Append-Output "Please enter a valid hostname or IP address." -Header "Validation Error"
        return
    }

    $credential = Get-Credential -Message "Enter credentials for $remoteMachine"
    if (-not $credential) {
        Append-Output "Operation cancelled: No credentials provided." -Header "Cancelled"
        return
    }

    Update-WindowTitle -Hostname $remoteMachine
    $computer = $remoteMachine

    Invoke-Async -Label "Installed Software on $computer" -Arguments @($computer, $credential) -Context @{ Computer = $computer } -ScriptBlock {
        param($comp, $cred)
        $software = Invoke-Command -ComputerName $comp -Credential $cred -ErrorAction Stop -ScriptBlock {
            Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*,
                              HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*,
                              HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction SilentlyContinue |
                              Select-Object DisplayName, DisplayVersion, InstallDate |
                              Where-Object { $_.DisplayName -ne $null } |
                              Sort-Object DisplayName
        }
        if ($software) {
            $lines = @()
            foreach ($s in $software) {
                $lines += "$($s.DisplayName)  v$($s.DisplayVersion)  [$($s.InstallDate)]"
            }
            return @{ Success = $true; Data = ($lines -join "`r`n"); Count = $software.Count }
        }
        return @{ Success = $true; Data = "No installed software found."; Count = 0 }
    } -OnComplete {
        param($result, $ctx)
        $r = $result | Select-Object -First 1
        if ($r.Success) {
            $header = "Installed Software - $($ctx.Computer)"
            if ($r.Count) { $header += " ($($r.Count) items)" }
            Append-Output $r.Data -Header $header
            [Logger]::Info("Retrieved installed software for $($ctx.Computer)")
        }
    }
})

# Get Up Time Button Click Event
$btnGetUpTime.Add_Click({
    $remoteMachine = [InputValidator]::SanitizeInput($txtHostname.Text)

    if (Validate-Hostname $remoteMachine) {
        Append-Output "Please enter a valid hostname or IP address." -Header "Validation Error"
        return
    }

    Update-WindowTitle -Hostname $remoteMachine
    $computer = $remoteMachine

    Invoke-Async -Label "Uptime on $computer" -Arguments @($computer) -Context @{ Computer = $computer } -ScriptBlock {
        param($comp)
        $cimSession = New-CimSession -ComputerName $comp -ErrorAction Stop
        try {
            $osInfo = Get-CimInstance -CimSession $cimSession -ClassName Win32_OperatingSystem
            $lastBoot = $osInfo.LastBootUpTime
            if ($lastBoot) {
                $uptime = (Get-Date) - $lastBoot
                $uptimeString = "{0:D2} days {1:D2} hrs {2:D2} mins {3:D2} secs" -f $uptime.Days, $uptime.Hours, $uptime.Minutes, $uptime.Seconds
                return @{ Success = $true; Data = "Uptime: $uptimeString`r`nLast Boot: $($lastBoot.ToString('yyyy-MM-dd HH:mm:ss'))" }
            } else {
                return @{ Success = $true; Data = "Could not retrieve last boot time." }
            }
        }
        finally {
            Remove-CimSession -CimSession $cimSession -ErrorAction SilentlyContinue
        }
    } -OnComplete {
        param($result, $ctx)
        $r = $result | Select-Object -First 1
        if ($r.Success) {
            Append-Output $r.Data -Header "Uptime - $($ctx.Computer)"
            [Logger]::Info("Retrieved uptime for $($ctx.Computer)")
        }
    }
})

# Disk Space Check Button Click Event
$btnDiskCheck.Add_Click({
    $remoteMachine = [InputValidator]::SanitizeInput($txtHostname.Text)
    if (Validate-Hostname $remoteMachine) {
        Append-Output "Please enter a valid hostname or IP address." -Header "Validation Error"
        return
    }

    Update-WindowTitle -Hostname $remoteMachine
    $computer = $remoteMachine

    Invoke-Async -Label "Disk Check on $computer" -Arguments @($computer) -Context @{ Computer = $computer } -ScriptBlock {
        param($comp)
        $data = Invoke-Command -ComputerName $comp -ErrorAction Stop -ScriptBlock {
            $disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
            $output = @()
            foreach ($disk in $disks) {
                $totalGB = [math]::Round($disk.Size / 1GB, 1)
                $freeGB  = [math]::Round($disk.FreeSpace / 1GB, 1)
                $usedGB  = [math]::Round(($disk.Size - $disk.FreeSpace) / 1GB, 1)
                $pctFree = if ($disk.Size -gt 0) { [math]::Round(($disk.FreeSpace / $disk.Size) * 100, 0) } else { 0 }
                $filled  = [math]::Round((100 - $pctFree) / 5)
                $bar     = "[" + ("#" * $filled) + ("-" * (20 - $filled)) + "]"
                $status  = if ($pctFree -lt 10) { "!! CRITICAL" }
                           elseif ($pctFree -lt 20) { "! WARNING" }
                           else { "OK" }
                $output += "Drive $($disk.DeviceID)"
                $output += "  $bar  $pctFree% used"
                $output += "  Total: $totalGB GB   Used: $usedGB GB   Free: $freeGB GB"
                $output += "  Status: $status"
                $output += ""
            }
            return $output -join "`r`n"
        }
        return @{ Success = $true; Data = $data }
    } -OnComplete {
        param($result, $ctx)
        $r = $result | Select-Object -First 1
        if ($r.Success) {
            Append-Output $r.Data -Header "Disk Space - $($ctx.Computer)"
        }
    }
})

# Reset Wi-Fi Adapter Button Click Event
$btnResetWiFi.Add_Click({
    $remoteMachine = [InputValidator]::SanitizeInput($txtHostname.Text)
    if (Validate-Hostname $remoteMachine) {
        Append-Output "Please enter a valid hostname or IP address." -Header "Validation Error"
        return
    }

    $confirmResult = [System.Windows.MessageBox]::Show(
        "This will reset the Wi-Fi adapter on $remoteMachine.`r`n`r`nNetwork connectivity will be interrupted briefly. Continue?",
        "Confirm Wi-Fi Reset",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Warning
    )
    if ($confirmResult -ne [System.Windows.MessageBoxResult]::Yes) {
        Update-StatusBar "Wi-Fi reset cancelled"
        return
    }

    Update-WindowTitle -Hostname $remoteMachine
    $computer = $remoteMachine

    Invoke-Async -Label "Reset Wi-Fi on $computer" -Arguments @($computer) -Context @{ Computer = $computer } -ScriptBlock {
        param($comp)
        $data = Invoke-Command -ComputerName $comp -ErrorAction Stop -ScriptBlock {
            $WiFiDevice = Get-PnpDevice -Class Net -ErrorAction SilentlyContinue |
                Where-Object { $_.FriendlyName -match 'Wi-Fi|WiFi|Wireless|WLAN|802\.11' -and $_.InstanceId -notmatch 'ROOT\\' }

            if ($WiFiDevice) {
                if ($WiFiDevice -is [array]) { $WiFiDevice = $WiFiDevice[0] }

                $output = @(
                    "Target: $($WiFiDevice.FriendlyName)",
                    "Initial Status: $($WiFiDevice.Status)",
                    "",
                    "Disabling adapter..."
                )

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
                    $output += "WARNING: Device status is '$($Check.Status)'. A reboot may be required."
                }

                return $output -join "`r`n"
            } else {
                return "ERROR: Could not find a Wi-Fi adapter on this machine."
            }
        }
        return @{ Success = $true; Data = $data }
    } -OnComplete {
        param($result, $ctx)
        $r = $result | Select-Object -First 1
        if ($r.Success) {
            Append-Output $r.Data -Header "Wi-Fi Reset - $($ctx.Computer)"
        }
    }
})

# Health Scan Button Click Event
$btnHealthScan.Add_Click({
    $remoteMachine = [InputValidator]::SanitizeInput($txtHostname.Text)
    if (Validate-Hostname $remoteMachine) {
        Append-Output "Please enter a valid hostname or IP address." -Header "Validation Error"
        return
    }

    Update-WindowTitle -Hostname $remoteMachine
    $computer = $remoteMachine

    Invoke-Async -Label "Health Scan on $computer" -Arguments @($computer) -Context @{ Computer = $computer } -ScriptBlock {
        param($comp)

        # Connectivity checks
        $conn = @{ CanResolve = $false; CanPing = $false; CanWinRM = $false }
        try { Resolve-DnsName -Name $comp -ErrorAction Stop | Out-Null; $conn.CanResolve = $true } catch { }
        try { $conn.CanPing = Test-Connection -ComputerName $comp -Count 1 -Quiet } catch { }
        try { Test-WSMan -ComputerName $comp -ErrorAction Stop | Out-Null; $conn.CanWinRM = $true } catch { }

        # Remote data
        $remoteData = Invoke-Command -ComputerName $comp -ErrorAction Stop -ScriptBlock {
            $os       = Get-CimInstance Win32_OperatingSystem
            $disks    = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
            $battery  = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
            $firewall = Get-NetFirewallProfile | Select-Object Name, Enabled
            $user     = quser 2>$null | Select-Object -Skip 1 | ForEach-Object {
                if ($_ -match '^\s*>?\s*(\S+)') { $matches[1] }
            } | Select-Object -First 1
            return @{ OS = $os; Disks = $disks; Battery = $battery; Firewall = $firewall; User = $user }
        }

        $uptime    = (Get-Date) - $remoteData.OS.LastBootUpTime
        $uptimeStr = "{0}d {1}h {2}m" -f $uptime.Days, $uptime.Hours, $uptime.Minutes
        $freeRamGB = [math]::Round($remoteData.OS.FreePhysicalMemory / 1MB, 1)
        $totRamGB  = [math]::Round($remoteData.OS.TotalVisibleMemorySize / 1MB, 1)

        $output = @(
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
            $fwState = if ($profile.Enabled) { "ENABLED" } else { "!! DISABLED" }
            if (-not $profile.Enabled) { $fwDisabled += $profile.Name }
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

        return @{ Success = $true; Data = ($output -join "`r`n"); IssueCount = $issues.Count }
    } -OnComplete {
        param($result, $ctx)
        $r = $result | Select-Object -First 1
        if ($r.Success) {
            Append-Output $r.Data -Header "Health Scan - $($ctx.Computer)"
            [Logger]::Info("Health scan complete on $($ctx.Computer) - $($r.IssueCount) issue(s)")
        }
    }
})

# Fix MDT Error Button Click Event
$btnFixMDT.Add_Click({
    try {
        $remoteMachine = [InputValidator]::SanitizeInput($txtHostname.Text)

        if (Validate-Hostname $remoteMachine) {
            Append-Output "Please enter a valid hostname or IP address." -Header "Validation Error"
            return
        }

        $credential = Get-Credential -Message "Enter administrator credentials for $remoteMachine"
        if (-not $credential) {
            Append-Output "Operation cancelled: No credentials provided." -Header "Cancelled"
            return
        }

        Update-WindowTitle -Hostname $remoteMachine
        $computer = $remoteMachine

        Invoke-Async -Label "MDT Cleanup on $computer" -Arguments @($computer, $credential) -Context @{ Computer = $computer } -ScriptBlock {
            param($comp, $cred)

            $cleanupResult = Invoke-Command -ComputerName $comp -Credential $cred -ErrorAction Stop -ScriptBlock {
                $issuesFound = 0
                $issuesFixed = 0
                $output = @()

                $output += "=== TARGETED DIAGNOSTIC SCAN ==="
                $output += "Checking common startup locations..."
                $output += ""

                # Check Winlogon keys
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

                # Check WMI Event Consumers
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

                # Check Startup Folders
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
                                $filenameMatch = $item.Name -match "LiteTouch|MININT|MDT"

                                if ($item.Extension -eq ".lnk") {
                                    try {
                                        $shell = New-Object -ComObject WScript.Shell
                                        $shortcut = $shell.CreateShortcut($item.FullName)
                                        $output += "      Target: $($shortcut.TargetPath)"
                                        $output += "      Arguments: $($shortcut.Arguments)"

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
                        $output += "    *** LITETOUCH IS RUNNING ***"
                        $issuesFound++
                    }
                } else {
                    $output += "  No LiteTouch processes currently running"
                }
                $output += ""

                # Check Registry Run Keys
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
                                        if ($prop.Value -match $pattern) { $matched = $true; break }
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

                # Remove Auto-Logon Settings
                $winlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
                try {
                    $autoLogonEnabled = (Get-ItemProperty -Path $winlogonPath -Name "AutoAdminLogon" -ErrorAction SilentlyContinue).AutoAdminLogon
                    if ($autoLogonEnabled -eq "1") {
                        $issuesFound++
                        $defaultUser = (Get-ItemProperty -Path $winlogonPath -Name "DefaultUserName" -ErrorAction SilentlyContinue).DefaultUserName
                        $defaultDomain = (Get-ItemProperty -Path $winlogonPath -Name "DefaultDomainName" -ErrorAction SilentlyContinue).DefaultDomainName
                        try {
                            Set-ItemProperty -Path $winlogonPath -Name "AutoAdminLogon" -Value "0" -Force -ErrorAction Stop
                            Remove-ItemProperty -Path $winlogonPath -Name "DefaultPassword" -ErrorAction SilentlyContinue
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

                # Remove Scheduled Tasks
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

                # Remove Directories
                $criticalPaths = @("C:\MININT", "C:\DeploymentShare", "C:\_SMSTaskSequence")
                foreach ($path in $criticalPaths) {
                    if (Test-Path $path) {
                        $issuesFound++
                        try {
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

                # Check Group Policy Startup Scripts
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

                return @{
                    IssuesFound = $issuesFound
                    IssuesFixed = $issuesFixed
                    Output = $output
                }
            }

            return @{
                Success = $true
                Data = $cleanupResult
            }
        } -OnComplete {
            param($result, $ctx)
            $r = $result | Select-Object -First 1

            if ($r.Success -and $r.Data) {
                $d = $r.Data
                $summary = @(
                    "Issues Found: $($d.IssuesFound)",
                    "Issues Fixed: $($d.IssuesFixed)",
                    "",
                    ($d.Output -join "`r`n")
                )

                if ($d.IssuesFound -eq 0) {
                    $summary += "`r`nNo MDT artifacts found. System is clean."
                }
                elseif ($d.IssuesFixed -gt 0) {
                    $summary += "`r`nSUCCESS: MDT artifacts have been removed."
                    $summary += "NEXT STEPS: 1) Restart the computer  2) Verify the error no longer appears"
                }
                else {
                    $summary += "`r`nWARNING: Issues were found but could not be fixed. Check administrator credentials."
                }

                Append-Output ($summary -join "`r`n") -Header "MDT Cleanup - $($ctx.Computer)"
                [Logger]::Info("MDT cleanup completed on $($ctx.Computer) - $($d.IssuesFixed)/$($d.IssuesFound) fixed")
            }
        }
    } catch {
        Append-Output "ERROR: $($_.Exception.Message)" -Header "MDT Cleanup Failed"
        [Logger]::Error("MDT cleanup error: $($_.Exception.Message)")
    }
})

# Clear Print Queue Button Click Event
$btnClearPrintQueue.Add_Click({
    $remoteMachine = [InputValidator]::SanitizeInput($txtHostname.Text)

    if (Validate-Hostname $remoteMachine) {
        Append-Output "Please enter a valid hostname or IP address." -Header "Validation Error"
        return
    }

    $confirmResult = [System.Windows.MessageBox]::Show(
        "This will clear all print jobs on $remoteMachine and restart the Print Spooler service.`r`n`r`nContinue?",
        "Clear Print Queue",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Warning
    )

    if ($confirmResult -ne [System.Windows.MessageBoxResult]::Yes) {
        Update-StatusBar "Print queue clear cancelled"
        return
    }

    Update-WindowTitle -Hostname $remoteMachine
    $computer = $remoteMachine

    Invoke-Async -Label "Clear Print Queue on $computer" -Arguments @($computer) -Context @{ Computer = $computer } -ScriptBlock {
        param($comp)
        $data = Invoke-Command -ComputerName $comp -ErrorAction Stop -ScriptBlock {
            $output = @()

            $output += "Stopping Print Spooler service..."
            Stop-Service -Name Spooler -Force -ErrorAction Stop
            Start-Sleep -Seconds 2

            $spoolPath = "$env:SystemRoot\System32\spool\PRINTERS"
            if (Test-Path $spoolPath) {
                $files = Get-ChildItem -Path $spoolPath -File
                $fileCount = $files.Count
                if ($fileCount -gt 0) {
                    $output += "Removing $fileCount print job file(s)..."
                    $files | Remove-Item -Force -ErrorAction SilentlyContinue
                } else {
                    $output += "No print job files found in spool folder."
                }
            }

            try {
                $printers = Get-Printer -ErrorAction SilentlyContinue
                $totalJobsCleared = 0
                foreach ($printer in $printers) {
                    $jobs = Get-PrintJob -PrinterName $printer.Name -ErrorAction SilentlyContinue
                    if ($jobs) {
                        $totalJobsCleared += $jobs.Count
                        $jobs | Remove-PrintJob -ErrorAction SilentlyContinue
                    }
                }
                if ($totalJobsCleared -gt 0) {
                    $output += "Cleared $totalJobsCleared queued print job(s)."
                }
            } catch {
                $output += "Note: Could not query printer queues via cmdlet."
            }

            $output += "Starting Print Spooler service..."
            Start-Service -Name Spooler -ErrorAction Stop
            Start-Sleep -Seconds 2

            $spoolerStatus = (Get-Service -Name Spooler).Status
            $output += "Print Spooler service status: $spoolerStatus"
            $output += ""
            $output += "Print queue clear operation completed successfully!"

            return $output -join "`r`n"
        }
        return @{ Success = $true; Data = $data }
    } -OnComplete {
        param($result, $ctx)
        $r = $result | Select-Object -First 1
        if ($r.Success) {
            Append-Output $r.Data -Header "Print Queue - $($ctx.Computer)"
        }
    }
})

# Clear DNS Cache Button Click Event
$btnClearDNS.Add_Click({
    $remoteMachine = [InputValidator]::SanitizeInput($txtHostname.Text)

    if (Validate-Hostname $remoteMachine) {
        Append-Output "Please enter a valid hostname or IP address." -Header "Validation Error"
        return
    }

    Update-WindowTitle -Hostname $remoteMachine
    $computer = $remoteMachine

    Invoke-Async -Label "Clear DNS on $computer" -Arguments @($computer) -Context @{ Computer = $computer } -ScriptBlock {
        param($comp)
        $data = Invoke-Command -ComputerName $comp -ErrorAction Stop -ScriptBlock {
            $flushOutput = ipconfig /flushdns 2>&1 | Out-String

            try {
                $cacheStats = Get-DnsClientCache -ErrorAction SilentlyContinue
                $cacheCount = if ($cacheStats) { $cacheStats.Count } else { 0 }
            } catch {
                $cacheCount = "Unknown"
            }

            $output = @(
                $flushOutput.Trim(),
                "",
                "Current cached entries: $cacheCount",
                "",
                "DNS cache flushed successfully."
            ) -join "`r`n"

            return $output
        }
        return @{ Success = $true; Data = $data }
    } -OnComplete {
        param($result, $ctx)
        $r = $result | Select-Object -First 1
        if ($r.Success) {
            Append-Output $r.Data -Header "DNS Cache Clear - $($ctx.Computer)"
        }
    }
})

# Remote Restart Button Click Event
$btnRestart.Add_Click({
    $remoteMachine = [InputValidator]::SanitizeInput($txtHostname.Text)
    if (Validate-Hostname $remoteMachine) {
        Append-Output "Please enter a valid hostname or IP address." -Header "Validation Error"
        return
    }

    $confirmResult = [System.Windows.MessageBox]::Show(
        "This will RESTART $remoteMachine.`r`n`r`nUnsaved work will be lost.`r`n`r`nContinue?",
        "Confirm Restart",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Warning
    )
    if ($confirmResult -ne [System.Windows.MessageBoxResult]::Yes) {
        Update-StatusBar "Restart cancelled"
        return
    }

    Update-WindowTitle -Hostname $remoteMachine
    $computer = $remoteMachine

    Invoke-Async -Label "Restart $computer" -Arguments @($computer) -Context @{ Computer = $computer } -ScriptBlock {
        param($comp)
        Restart-Computer -ComputerName $comp -Force -ErrorAction Stop
        return @{ Success = $true; Data = "Restart command sent successfully to $comp.`r`nThe remote computer should restart within a few seconds." }
    } -OnComplete {
        param($result, $ctx)
        $r = $result | Select-Object -First 1
        if ($r.Success) {
            Append-Output $r.Data -Header "Remote Restart - $($ctx.Computer)"
            [Logger]::Info("Restart command sent to $($ctx.Computer)")
        }
    }
})

# Firewall Status Button Click Event
$btnFirewallStatus.Add_Click({
    $remoteMachine = [InputValidator]::SanitizeInput($txtHostname.Text)

    if (Validate-Hostname $remoteMachine) {
        Append-Output "Please enter a valid hostname or IP address." -Header "Validation Error"
        return
    }

    Update-WindowTitle -Hostname $remoteMachine
    $computer = $remoteMachine

    Invoke-Async -Label "Firewall Status on $computer" -Arguments @($computer) -Context @{ Computer = $computer } -ScriptBlock {
        param($comp)
        $data = Invoke-Command -ComputerName $comp -ErrorAction Stop -ScriptBlock {
            $profiles = Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction

            $output = @()
            foreach ($profile in $profiles) {
                $status = if ($profile.Enabled) { "ENABLED" } else { "DISABLED" }
                $output += "Profile: $($profile.Name)"
                $output += "  Status: $status"
                $output += "  Default Inbound: $($profile.DefaultInboundAction)"
                $output += "  Default Outbound: $($profile.DefaultOutboundAction)"
                $output += ""
            }

            $enabledCount = ($profiles | Where-Object { $_.Enabled }).Count
            $totalCount = $profiles.Count

            if ($enabledCount -eq $totalCount) {
                $output += "All firewall profiles are ENABLED (Secure)"
            }
            elseif ($enabledCount -eq 0) {
                $output += "WARNING: All firewall profiles are DISABLED (Security Risk!)"
            }
            else {
                $output += "WARNING: Some firewall profiles are disabled (Inconsistent State)"
            }

            return $output -join "`r`n"
        }
        return @{ Success = $true; Data = $data }
    } -OnComplete {
        param($result, $ctx)
        $r = $result | Select-Object -First 1
        if ($r.Success) {
            Append-Output $r.Data -Header "Firewall Status - $($ctx.Computer)"
        }
    }
})

# Remote Log Off Button Click Event
$btnLogOff.Add_Click({
    $remoteMachine = [InputValidator]::SanitizeInput($txtHostname.Text)
    if (Validate-Hostname $remoteMachine) {
        Append-Output "Please enter a valid hostname or IP address." -Header "Validation Error"
        return
    }

    Update-WindowTitle -Hostname $remoteMachine
    $computer = $remoteMachine

    # Step 1: Query sessions asynchronously
    Invoke-Async -Label "Query Sessions on $computer" -Arguments @($computer) -Context @{ Computer = $computer } -ScriptBlock {
        param($comp)
        $sessions = Invoke-Command -ComputerName $comp -ErrorAction Stop -ScriptBlock {
            quser 2>$null | Out-String
        }
        if (-not $sessions -or $sessions.Trim() -eq "") {
            return @{ Success = $true; Data = $null }
        }
        return @{ Success = $true; Data = $sessions.Trim() }
    } -OnComplete {
        param($result, $ctx)
        $r = $result | Select-Object -First 1
        $comp = $ctx.Computer

        if (-not $r.Data) {
            Append-Output "No active user sessions found." -Header "Sessions - $comp"
            return
        }

        Append-Output $r.Data -Header "Active Sessions - $comp"

        $sessionInput = [Microsoft.VisualBasic.Interaction]::InputBox(
            "Enter the session ID to log off (see output above):",
            "Remote Log Off - $comp",
            ""
        )
        if (-not $sessionInput -or $sessionInput -notmatch '^\d+$') {
            Update-StatusBar "Log off cancelled"
            return
        }

        $sid = $sessionInput
        # Step 2: Perform log off asynchronously
        Invoke-Async -Label "Log Off Session $sid on $comp" -Arguments @($comp, $sid) -Context @{ Computer = $comp } -ScriptBlock {
            param($computer, $sessionId)
            Invoke-Command -ComputerName $computer -ScriptBlock {
                param($s)
                logoff $s 2>&1 | Out-Null
            } -ArgumentList $sessionId -ErrorAction Stop
            return @{ Success = $true; Data = "Session $sessionId logged off successfully." }
        } -OnComplete {
            param($result2, $ctx2)
            $r2 = $result2 | Select-Object -First 1
            if ($r2.Success) {
                Append-Output $r2.Data -Header "Log Off - $($ctx2.Computer)"
                [Logger]::Info("Logged off session on $($ctx2.Computer)")
            }
        }
    }
})

# Clear Output Button Click Event
$btnClearOutput.Add_Click({
    $terminalOutputBox.Document.Blocks.Clear()
    Update-StatusBar "Output cleared"
    Update-WindowTitle
    Set-HostnameColor ([System.Windows.Media.Brushes]::White)
})

# Copy to Clipboard Button Click Event
$btnCopyOutput.Add_Click({
    $txt = Get-OutputText
    if ($txt.Trim()) {
        Set-Clipboard -Value $txt
        Update-StatusBar "Output copied to clipboard"
    } else {
        Update-StatusBar "Nothing to copy"
    }
})

# ============================================================
# Placeholder Text and ComboBox Setup
# ============================================================

$txtHostname.Add_GotFocus({
    if ($txtHostname.Text -eq "Enter Hostname/IP") {
        $txtHostname.Text = ""
        $txtHostname.Foreground = [System.Windows.Media.Brushes]::Black
        if ($script:HostnameInnerBox) { $script:HostnameInnerBox.Foreground = [System.Windows.Media.Brushes]::Black }
    }
})
$txtHostname.Add_LostFocus({
    if ($txtHostname.Text -eq "") {
        $txtHostname.Text = "Enter Hostname/IP"
        $txtHostname.Foreground = [System.Windows.Media.Brushes]::Gray
        if ($script:HostnameInnerBox) { $script:HostnameInnerBox.Foreground = [System.Windows.Media.Brushes]::Gray }
    }
})

# Update window title when hostname changes
$txtHostname.Add_SelectionChanged({
    $text = $txtHostname.Text
    if ($text -and $text -ne "Enter Hostname/IP") {
        Update-WindowTitle -Hostname $text
    }
})

# Populate recent hosts dropdown
Load-HostHistory | ForEach-Object { $txtHostname.Items.Add($_) }

# Grab the inner editable TextBox after the ComboBox template is applied
$Window.Add_Loaded({
    $script:HostnameInnerBox = $txtHostname.Template.FindName("PART_EditableTextBox", $txtHostname)
    if ($script:HostnameInnerBox) {
        $script:HostnameInnerBox.Foreground = [System.Windows.Media.Brushes]::Gray
    }
})

# Cleanup on window close
$Window.Add_Closed({
    # Stop timer
    if ($script:AsyncTimer) {
        $script:AsyncTimer.Stop()
    }

    # Dispose all active runspaces
    foreach ($item in $script:ActiveRunspaces) {
        if ($item.PowerShell) {
            try { $item.PowerShell.Stop() } catch { }
            $item.PowerShell.Dispose()
        }
    }

    # Close and dispose runspace pool
    if ($script:RunspacePool) {
        $script:RunspacePool.Close()
        $script:RunspacePool.Dispose()
    }

    [Logger]::Info("Multi-Tool application closed")
})

# Show the window (blocking call - must be last)
$Window.ShowDialog()
