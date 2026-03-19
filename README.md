# Multi-Tool - Windows System Administration GUI

A PowerShell WPF-based graphical interface for remote Windows system administration. Provides IT administrators with a centralized interface for common remote management tasks, diagnostics, and system maintenance operations.

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Capabilities](#capabilities)
- [Security](#security)
- [Architecture](#architecture)
- [Troubleshooting](#troubleshooting)

## Features (20 Buttons)

### Diagnostics
- **Resolve** - Resolve hostnames to IP addresses (forward and reverse lookup); validates connectivity and colors the hostname field green/orange/red
- **Ping** - Test network connectivity with detailed results
- **Get System Info** - Comprehensive system details (OS, CPU, RAM, disks, network)
- **Get Up Time** - Display system uptime and last boot time
- **Firewall Status** - Check Windows Firewall state across all profiles
- **Health Scan** - Full system health scan
- **Disk Space Check** - Check disk usage; warns when free space falls below 20%
- **Reset Wi-Fi Adapter** - Reset the Wi-Fi adapter on the target machine

### Remote Tools
- **Open PS Session** - Launch interactive PowerShell session to remote computers
- **Launch MSRA** - Launch Microsoft Remote Assistance to the target machine
- **Launch RDC** - Open Remote Desktop Connection to the specified computer
- **Open Event Log** - Launch Event Viewer connected to remote systems

### Management
- **Run GPUpdate** - Force Group Policy updates on target machines
- **Get Installed Software** - Query all installed applications on remote machines
- **Remote Log Off** - Log off the current user session on a remote machine
- **Clear Print Queue** - Clear stuck print jobs on remote machines
- **Clear DNS Cache** - Flush DNS resolver cache on target systems
- **Remote Restart** - Restart remote computers with confirmation

### Utilities
- **Open IncidentIQ** - Quick access to the IncidentIQ ticketing portal
- **Fix MDT Error** - Remove Microsoft Deployment Toolkit artifacts causing startup errors
- **Clear Output** - Clear the output box and reset status (Ctrl+L)
- **Copy to Clipboard** - Copy output box contents to clipboard (Ctrl+Shift+C)

## Requirements

### Local Machine (Where Multi-Tool Runs)
- **OS**: Windows 10/11 or Windows Server 2016+
- **PowerShell**: Version 5.1 or higher (Windows PowerShell)
- **.NET Framework**: 4.5+ (for WPF support)
- **Execution Policy**: RemoteSigned or Bypass (see Installation)

### Remote Machines (Target Systems)
- **WinRM Enabled**: Required for remote operations
  ```powershell
  winrm quickconfig
  ```
- **Network Access**: Firewall must allow WinRM (TCP 5985/5986)
- **Administrator Rights**: User must have admin rights on target machines
- **Same Domain**: Recommended for credential pass-through (or provide explicit credentials)

## Installation

### Download
1. Clone or download this repository
2. Navigate to the project folder
3. The main file is `Multi-Tool.PS1` (~1635 lines, fully self-contained)

### No Installation Required
This is a standalone PowerShell script with no external dependencies. Just download and run.

## Usage

### Method 1: Direct Execution (Recommended)
```powershell
cd C:\Path\To\Multi-Tool
powershell.exe -ExecutionPolicy Bypass -File "Multi-Tool.PS1"
```

### Method 2: From PowerShell Console
```powershell
.\Multi-Tool.PS1

# Or with bypass
powershell.exe -ExecutionPolicy Bypass -File ".\Multi-Tool.PS1"
```

### Method 3: Windows Run Dialog (Win+R)
```
powershell.exe -ExecutionPolicy Bypass -File "C:\Path\To\Multi-Tool\Multi-Tool.PS1"
```

### Method 4: Create Desktop Shortcut
1. Right-click on Desktop > New > Shortcut
2. Target: `powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\Path\To\Multi-Tool\Multi-Tool.PS1"`
3. Name: Multi-Tool
4. (Optional) Change icon to a relevant system icon

### Basic Workflow
1. **Launch** the application using one of the methods above
2. **Enter** a hostname or IP address in the hostname field
3. **Click Resolve** to verify the hostname (colors the field green/orange/red based on connectivity)
4. **Click** any button to perform the desired operation
5. **View** results in the terminal output box at the bottom

### Hostname History
The hostname field is a dropdown that remembers the last 10 hosts you connected to, stored at `%APPDATA%\MultiTool\hostHistory.txt`.

### Keyboard Shortcuts
| Shortcut | Action |
|---|---|
| Enter | Ping |
| Ctrl+F | Search output |
| Ctrl+L | Clear output |
| Ctrl+Shift+C | Copy output to clipboard |

### Example Operations

#### Get System Information
```
1. Enter hostname: "WORKSTATION01"
2. Click "Resolve" to verify hostname
3. Click "Get System Info"
4. View OS, architecture, uptime, hardware info in output box
```

#### Run Remote GPUpdate
```
1. Enter hostname: "DESKTOP-ABC123"
2. Click "Run GPUpdate"
3. Provide credentials if prompted
4. Wait for completion (progress bar shows status)
```

#### Clean MDT Artifacts
```
1. Enter hostname or IP: "192.168.1.50"
2. Click "Fix MDT Error"
3. Provide administrator credentials
4. Review diagnostic output showing artifacts found/removed
5. Restart target machine when prompted
```

## Capabilities

### Input Validation
- **Automatic Sanitization**: Strips dangerous characters from input
- **Format Validation**: Validates hostnames (RFC 1123) and IPv4 addresses
- **Injection Prevention**: Prevents command injection through input fields

### Connectivity Testing
Multi-layer connectivity validation via the Resolve button:
- DNS resolution test
- ICMP ping test
- WinRM availability check
- Color-coded feedback (green = fully reachable, orange = partial, red = unreachable)

### Logging & Auditing
- **Log Location**: `%TEMP%\MultiTool.log`
- **Log Levels**: INFO, WARN, ERROR
- **Audit Trail**: All operations logged with timestamps

### Error Handling
- Try-catch blocks on all operations
- User-friendly error messages
- Detailed logging for troubleshooting
- Graceful degradation on failures

### Remote Operations
All remote operations use:
- PowerShell Remoting (WinRM)
- Credential prompts when needed
- CIM sessions for queries (not legacy WMI)
- Proper resource cleanup (sessions disposed)

### Progress Indication
- Visual progress bar for long operations
- Status updates in terminal output
- Operation counter in status bar

## Security

### Security Features

- **Input Validation & Sanitization**: `InputValidator` class validates all user input via RFC 1123 hostname and IPv4 regex; dangerous characters stripped before use
- **Secure Credential Handling**: Uses `Get-Credential` (Windows secure prompt); credentials passed as `PSCredential` objects, never stored as plaintext
- **Comprehensive Logging**: All operations logged to `%TEMP%\MultiTool.log` with ISO 8601 timestamps and severity levels
- **Error Handling**: Every operation wrapped in try-catch; generic messages shown to users, details in logs
- **Resource Management**: CIM sessions and runspaces disposed in `finally` blocks

### Known Limitations

- **Credential Caching**: Credentials requested per operation (by design — security over convenience)
- **Download Verification**: Windows 11 installer URL present in config but hash verification not implemented

### Best Practices

1. Only grant admin rights to users who need this tool
2. Regularly review `%TEMP%\MultiTool.log`
3. Limit WinRM access to management VLANs
4. Always verify the target hostname before executing commands
5. Test on non-production systems first

## Architecture

### Technology Stack
- **Language**: PowerShell 5.1+
- **GUI Framework**: Windows Presentation Foundation (WPF)
- **Markup**: XAML for UI definition
- **Remoting**: PowerShell Remoting (WinRM)
- **Queries**: CIM (not legacy WMI)

### Code Structure
```
Multi-Tool.PS1 (~1635 lines)
├── WPF Assembly Loading (Lines 1-5)
├── Utility Classes (Lines 7-39)
│   ├── InputValidator (hostname/IP validation & sanitization)
│   └── Logger (audit trail logging)
├── Configuration (Lines 41-53)
│   └── AppConfig hashtable (timeouts, URLs)
├── XAML GUI Definition (Lines 55-187)
│   └── 4 Expander sections: Diagnostics, Remote Tools, Management, Utilities
├── XAML Loading (Lines 189-190)
├── Control References (Lines 192-217)
├── Utility Functions (Lines 219-416)
│   ├── Get-SafeDateTime
│   ├── Test-RemoteConnectivity
│   ├── Invoke-RemoteOperation
│   ├── Get-SystemInfoOptimized
│   ├── Update-ConnectionStatus
│   ├── Load-HostHistory / Save-HostHistory
│   └── Validate-Hostname
└── Event Handlers (Lines 418+)
    └── Click handlers for each button
```

### Key Design Patterns
- **Class-Based Utilities**: `InputValidator` and `Logger` classes
- **Configuration Object**: Centralized settings in `$Global:AppConfig` hashtable
- **Wrapper Functions**: `Invoke-RemoteOperation` standardizes remote calls and error handling
- **Error Result Objects**: Consistent return structure (`Success`, `Data`, `Message`)
- **ComboBox Hostname Field**: Enables recent-host dropdown; inner `PART_EditableTextBox` manipulated directly for background color feedback

### Dependencies
- **None** - Fully self-contained single file
- Uses only built-in PowerShell modules and WPF assemblies included with .NET Framework

## Troubleshooting

### Application Won't Start

**Script execution prevented**
```powershell
powershell.exe -ExecutionPolicy Bypass -File "Multi-Tool.PS1"
```

**WPF assemblies not found**
```
Ensure .NET Framework 4.5+ is installed. Download from Microsoft and reboot.
```

### Remote Operations Fail

**"Access Denied" or authentication errors**
```
1. Verify you have administrator rights on the target machine
2. Provide explicit credentials when prompted
3. Ensure target machine is in the same domain
```

**"WinRM cannot process the request"**
```powershell
# Run on target machine:
winrm quickconfig
```

**Firewall blocking connection**
```
Allow inbound: Windows Remote Management (HTTP-In)
Ports: TCP 5985 (HTTP) or TCP 5986 (HTTPS)
```

### MDT Cleanup Issues

**"No issues found" but error persists**
```
Possible causes:
- Group Policy startup script (check: gpresult /h report.html)
- PDQ Deploy agent configuration
- SCCM/MDT server still pushing policy
- Network logon script in Active Directory
```

**"Access Denied" during cleanup**
```
Provide Domain Admin or Local Admin credentials.
Some registry keys require elevated privileges.
```

### Performance

**UI appears to freeze during operations**
```
Expected behavior — some operations (software inventory, GPUpdate) take time.
The progress bar confirms the operation is running. Do not close the application.
```

### Log File

```powershell
# Open log in Notepad
notepad "$env:TEMP\MultiTool.log"
```

## File Structure

```
Multi-Tool/
├── Multi-Tool.PS1              # Main application — fully self-contained
├── README.md                   # This file
├── CLAUDE.md                   # Development guide for AI-assisted modifications
└── Multi-Tool.code-workspace   # VS Code workspace
```

## Disclaimer

This tool performs administrative operations on remote systems. Always:
- Verify the target hostname before executing commands
- Test on non-production systems first
- Ensure you have proper authorization
- Follow your organization's IT policies

**Use at your own risk. Improper use may cause system disruptions.**

---

**Last Updated**: 2026-03-19
**Maintained By**: IT Department
