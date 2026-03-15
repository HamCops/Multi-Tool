# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Multi-Tool is a PowerShell WPF GUI application for Windows system administration tasks. It provides a graphical interface for remote system management including network diagnostics, system information gathering, remote connections, security compliance checks, and MDT/WDT deployment cleanup.

## Architecture

### Core Structure

The application is entirely self-contained in `Multi-Tool.PS1` (~1650 lines) with the following sections:

1. **WPF Assembly Loading** (Lines 1-3): Loads required .NET assemblies
2. **Utility Classes** (Lines 5-40): InputValidator and Logger classes
3. **Configuration** (Lines 42-52): Global configuration hashtable
4. **XAML GUI** (Lines 54-105): Complete WPF interface definition
5. **XAML Loading** (Lines 107-110): Parse and load the UI
6. **Control References** (Lines 112-125): Store references to UI controls
7. **Utility Functions** (Lines 127-200): Helper functions for remote operations
8. **Event Handlers** (Lines 200+): Click handlers for each button

### Key Components

**InputValidator Class**: Provides input sanitization and validation
- `IsValidHostname()`: RFC 1123 hostname validation
- `IsValidIPv4()`: IPv4 address validation
- `SanitizeInput()`: Strips dangerous characters
- `IsValidHostnameOrIP()`: Combined validation

**Logger Class**: Centralized logging to `%TEMP%\MultiTool.log`
- `Info()`, `Warn()`, `Error()`: Log level methods
- Thread-safe file operations with SilentlyContinue

**AppConfig**: Global configuration hashtable
- Network timeouts and retry settings
- URL constants for downloads and web portals

**Utility Functions**:
- `Get-SafeDateTime`: Handles multiple datetime formats from WMI/CIM
- `Test-RemoteConnectivity`: Comprehensive connectivity testing (DNS, ping, WinRM)
- `Invoke-RemoteOperation`: Standardized remote command execution with error handling

### Feature Areas

1. **Network Operations**: DNS resolution, ping, connectivity validation
2. **System Information**: OS details, hardware, uptime, installed software via CIM queries
3. **Remote Management**: PowerShell sessions, GPUpdate, Event Viewer
4. **Remote Tools**: MSRA (Remote Assistance), RDC (Remote Desktop Connection)
5. **Windows 11 Upgrade**: Downloads and launches Windows 11 setup assistant
6. **MDT/WDT Cleanup**: Fully embedded scriptblock executed via `Invoke-Command` for deployment artifact removal

## Running and Testing

### Execution
```powershell
# Direct execution
.\Multi-Tool.PS1

# With explicit policy bypass
powershell.exe -ExecutionPolicy Bypass -File "Multi-Tool.PS1"

# From Windows Run dialog (Win+R)
powershell.exe -ExecutionPolicy Bypass -File "C:\path\to\Multi-Tool.PS1"
```

### Testing Strategy
1. **Local Testing**: Use `localhost` or local hostname first
2. **Remote Testing**: Verify WinRM enabled on targets (`winrm quickconfig`)
3. **Credentials**: Ensure domain/local admin rights for remote operations
4. **Network**: Test with both hostname and IP address inputs

## Code Conventions

### Input Validation Pattern
**ALWAYS** validate user input before remote operations:
```powershell
$hostname = $txtHostname.Text
if (-not [InputValidator]::IsValidHostnameOrIP($hostname)) {
    $terminalOutputBox.Text = "ERROR: Invalid hostname or IP address"
    [Logger]::Error("Invalid input: $hostname")
    return
}
$hostname = [InputValidator]::SanitizeInput($hostname)
```

### Remote Operation Pattern
Use the standardized `Invoke-RemoteOperation` helper:
```powershell
$result = Invoke-RemoteOperation -ComputerName $hostname -ScriptBlock {
    # Remote commands here
} -OperationName "Operation Description"

if ($result.Success) {
    $terminalOutputBox.Text = $result.Data
} else {
    $terminalOutputBox.Text = "ERROR: $($result.Message)"
}
```

### UI Thread Safety
Wrap UI updates in dispatcher for async operations:
```powershell
$Window.Dispatcher.Invoke([action]{
    $terminalOutputBox.Text = $result
    $progressBar.Visibility = [System.Windows.Visibility]::Hidden
})
```

### Error Handling
Use try-catch with logging:
```powershell
try {
    # Operation
    [Logger]::Info("Operation started")
    # ...
} catch {
    [Logger]::Error("Operation failed: $($_.Exception.Message)")
    $terminalOutputBox.Text = "ERROR: $($_.Exception.Message)"
}
```

### Progress Indication
For long-running operations:
```powershell
$progressBar.Visibility = [System.Windows.Visibility]::Visible
$progressBar.Value = 0
# ... operation with periodic updates
$progressBar.Value = 50
# ... completion
$progressBar.Visibility = [System.Windows.Visibility]::Hidden
```

## Adding New Features

### Adding a Button and Handler

1. **Add button to XAML** (around line 90):
```xml
<Button Name="btnNewFeature" Content="New Feature" Width="180" Margin="5"/>
```

2. **Get control reference** (around line 125):
```powershell
$btnNewFeature = $Window.FindName("btnNewFeature")
```

3. **Add click event handler** (after other handlers):
```powershell
$btnNewFeature.Add_Click({
    try {
        $hostname = $txtHostname.Text
        if (-not [InputValidator]::IsValidHostnameOrIP($hostname)) {
            $terminalOutputBox.Text = "ERROR: Invalid hostname or IP"
            return
        }
        $hostname = [InputValidator]::SanitizeInput($hostname)
        
        [Logger]::Info("New feature invoked for $hostname")
        
        # Your feature logic here
        
        $terminalOutputBox.Text = "Feature completed"
    }
    catch {
        [Logger]::Error("Feature error: $($_.Exception.Message)")
        $terminalOutputBox.Text = "ERROR: $($_.Exception.Message)"
    }
})
```

### Extending System Information Queries

Use CIM instead of legacy WMI:
```powershell
$cimSession = New-CimSession -ComputerName $hostname -ErrorAction Stop
try {
    $osInfo = Get-CimInstance -CimSession $cimSession -ClassName Win32_OperatingSystem
    $cpuInfo = Get-CimInstance -CimSession $cimSession -ClassName Win32_Processor
    # Format output
    $output = @(
        "OS: $($osInfo.Caption)"
        "CPU: $($cpuInfo.Name)"
    ) -join "`r`n"
}
finally {
    Remove-CimSession -CimSession $cimSession -ErrorAction SilentlyContinue
}
```

## MDT/WDT Cleanup Feature

The MDT cleanup functionality is fully embedded in `Multi-Tool.PS1` and requires no external files.

**What It Does**: 
- Executes remote cleanup of MDT/WDT deployment artifacts via PowerShell remoting
- Removes registry run keys, scheduled tasks, directories (C:\MININT, etc.), startup shortcuts
- Disables auto-logon if configured by MDT
- Checks WMI event consumers, group policy scripts, and running LiteTouch processes

**How It Works**:
- Prompts for credentials for the target machine
- Executes a large embedded scriptblock via `Invoke-Command`
- Returns detailed diagnostic output showing what was found and removed
- Provides summary of issues found vs. issues fixed

## Security Considerations

### Current Implementations
- ✅ Input validation via InputValidator class
- ✅ Input sanitization removes dangerous characters
- ✅ Logging for audit trail
- ✅ Error handling prevents information leakage

### Remaining Concerns (from InitialWrite\Up.md)
- Credential management: Currently uses prompts, should integrate Windows Credential Manager
- Web downloads: Windows 11 installer downloads without hash verification
- Remote execution: Limited to PowerShell remoting (requires WinRM)

### Best Practices When Modifying
- Always use `[InputValidator]::IsValidHostnameOrIP()` before remote operations
- Never concatenate user input directly into commands
- Use `-ErrorAction Stop` with try-catch for predictable error handling
- Log security-relevant operations with `[Logger]::Info()` or `[Logger]::Warn()`

### Known Issues with Active Directory Queries

**WARNING**: Some environments may have corrupted Active Directory or WMI data that causes type conversion errors when using cmdlets like `Get-ADComputer`, `Get-MpComputerStatus`, or certain `Get-CimInstance` queries.

**Symptoms**:
- Error: "Cannot convert System.Object[] to System.UInt32" or similar type conversion errors
- Buttons that query AD/WMI properties fail even with proper error handling
- The issue persists across different query methods (Get-ADComputer, Get-ADObject, ADSI searcher)

**Root Cause**:
- Active Directory properties contain array values where PowerShell cmdlets expect scalar values
- This is a data integrity issue in the AD database, not a code issue
- Common in environments with custom AD schema extensions or historical data corruption

**Solutions**:
1. **Avoid problematic cmdlets**: Use simpler alternatives like `quser` command instead of CIM queries, or LDAP searches with individual property queries
2. **Clean Active Directory**: Work with domain administrators to identify and fix AD objects with array properties where single values are expected
3. **Update PowerShell modules**: Ensure RSAT tools and ActiveDirectory module are up-to-date
4. **Query properties individually**: Instead of requesting multiple properties at once, query them one at a time with error suppression for each

**Disabled Features** (buttons remain in XAML but handlers are non-functional due to AD corruption in target environment):
- Computer AD Info (`btnGetComputerInfo`) — Get-ADComputer queries
- Windows Defender Status (`btnDefenderStatus`) — Get-MpComputerStatus queries
- Show Current User (`btnShowCurrentUser`) — Get-CimInstance Win32_ComputerSystem queries

## File Structure

```
/home/cam/Projects/Multi-Tool/
├── Multi-Tool.PS1                # Main application (PowerShell + WPF) - fully self-contained
├── README.md                     # Project documentation
├── CLAUDE.md                     # This file - development guide
└── Multi-Tool.code-workspace     # VS Code workspace
```

**Note**: The application is entirely self-contained in `Multi-Tool.PS1` with no external script dependencies.

## Dependencies

**PowerShell Modules** (built-in):
- No external modules required
- Uses WPF assemblies (PresentationFramework, WindowsBase, PresentationCore)
- Uses standard cmdlets: Invoke-Command, Get-CimInstance, Test-Connection, etc.

**Windows Features Required**:
- PowerShell 5.1+ (Windows PowerShell with .NET Framework)
- WinRM enabled on target machines for remote operations
- Admin privileges for elevated operations (MDT cleanup, some remote commands)

## Common Patterns

### DateTime Handling
Use `Get-SafeDateTime` for WMI/CIM datetime conversions:
```powershell
$lastBoot = Get-SafeDateTime -DateTimeValue $osInfo.LastBootUpTime
if ($lastBoot) {
    $uptime = (Get-Date) - $lastBoot
}
```

### CIM Session Management
Always use try-finally for cleanup:
```powershell
$cimSession = New-CimSession -ComputerName $hostname
try {
    # Query operations
}
finally {
    Remove-CimSession -CimSession $cimSession -ErrorAction SilentlyContinue
}
```

### Credential Handling
Request when needed, pass through to remote commands:
```powershell
$credential = Get-Credential -Message "Enter credentials for $hostname"
Invoke-RemoteOperation -ComputerName $hostname -Credential $credential -ScriptBlock { ... }
```
