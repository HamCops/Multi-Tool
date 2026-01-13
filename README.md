# Multi-Tool - Windows System Administration GUI

A PowerShell WPF-based graphical interface for remote Windows system administration. This tool provides IT administrators with a centralized interface for common remote management tasks, diagnostics, and system maintenance operations.

## 📋 Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Capabilities](#capabilities)
- [Security](#security)
- [Architecture](#architecture)
- [Troubleshooting](#troubleshooting)

## ✨ Features (18 Buttons)

### Network Operations
- **DNS Resolution** - Resolve hostnames to IP addresses (forward and reverse lookup)
- **Ping Test** - Test network connectivity with detailed results
- **Remote Connectivity Validation** - Comprehensive testing (DNS, ping, WinRM)

### System Information
- **Get System Info** - Comprehensive system details (OS, CPU, RAM, disks, network)
- **Get Up Time** - Display system uptime and last boot time
- **Show Current User** - Display currently logged-in user
- **Get Installed Software** - Query all installed applications on remote machines
- **Computer AD Info** - Display Active Directory computer information

### Remote Management
- **Open PS Session** - Launch interactive PowerShell session to remote computers
- **Run GPUpdate** - Force Group Policy updates on target machines
- **Open Event Log** - Launch Event Viewer connected to remote systems
- **Remote Shutdown** - Safely shut down remote computers with confirmation

### Remote Tools
- **Launch MSRA** - Launch Microsoft Remote Assistance to target machine
- **Launch RDC** - Open Remote Desktop Connection to specified computer

### System Maintenance
- **Clear Print Queue** - Clear stuck print jobs on remote machines
- **Clear DNS Cache** - Flush DNS resolver cache on target systems
- **Fix MDT Error** - Remove Microsoft Deployment Toolkit artifacts causing startup errors

### Security & Compliance
- **Firewall Status** - Check Windows Firewall state across all profiles
- **BitLocker Status** - Display drive encryption status and recovery key info
- **Defender Status** - ⭐ **Enhanced** - View Windows Defender status + recent threats detected in last 24 hours

### Web Portals
- **Open IncidentIQ** - Quick access to ticketing system

## 🔧 Requirements

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

## 📦 Installation

### Download
1. Clone or download this repository
2. Navigate to the project folder
3. The main file is `Multi-Tool.PS1` (~1650 lines, fully self-contained)

### No Installation Required
This is a standalone PowerShell script with no external dependencies. Just download and run.

## 🚀 Usage

### Method 1: Direct Execution (Recommended)
```powershell
# Navigate to the directory
cd C:\Path\To\Multi-Tool

# Run the script
powershell.exe -ExecutionPolicy Bypass -File "Multi-Tool.PS1"
```

### Method 2: From PowerShell Console
```powershell
# If execution policy allows
.\Multi-Tool.PS1

# Or with bypass
powershell.exe -ExecutionPolicy Bypass -File ".\Multi-Tool.PS1"
```

### Method 3: Windows Run Dialog (Win+R)
```
powershell.exe -ExecutionPolicy Bypass -File "C:\Path\To\Multi-Tool\Multi-Tool.PS1"
```

### Method 4: Create Desktop Shortcut
1. Right-click on Desktop → New → Shortcut
2. Target: `powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\Path\To\Multi-Tool\Multi-Tool.PS1"`
3. Name: Multi-Tool
4. (Optional) Change icon to a relevant system icon

### Basic Workflow
1. **Launch** the application using one of the methods above
2. **Enter** a hostname or IP address in the text field
3. **Resolve** the hostname (optional but recommended)
4. **Click** any button to perform the desired operation
5. **View** results in the terminal output box at the bottom

### Example Operations

#### Get System Information
```
1. Enter hostname: "WORKSTATION01"
2. Click "Resolve" to verify hostname
3. Click "Get System Info"
4. View OS, architecture, uptime in output box
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

## 🎯 Capabilities

### Input Validation
- **Automatic Sanitization**: Strips dangerous characters from input
- **Format Validation**: Validates hostnames (RFC 1123) and IPv4 addresses
- **Injection Prevention**: Prevents command injection through input fields

### Connectivity Testing
Multi-layer connectivity validation:
- DNS resolution test
- ICMP ping test
- WinRM availability check
- Detailed failure reporting

### Logging & Auditing
- **Log Location**: `%TEMP%\MultiTool.log`
- **Log Levels**: INFO, WARN, ERROR
- **Audit Trail**: All operations logged with timestamps
- **User Tracking**: Records which user performed which operations

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
- Non-blocking UI during operations

## 🔒 Security

### Security Rating: ⭐⭐⭐⭐ (4/5)

The Multi-Tool has been hardened against common security vulnerabilities and follows industry best practices for PowerShell GUI applications.

### ✅ Security Features Implemented

#### 1. Input Validation & Sanitization
- **InputValidator Class**: Validates all user input before use
- **Regex Validation**: RFC 1123 hostnames, IPv4 addresses
- **Character Filtering**: Removes special characters that could enable injection
- **No Command Injection**: User input never directly executed in commands

#### 2. Secure Credential Handling
- **Get-Credential**: Uses Windows secure credential prompt
- **No Plaintext Storage**: Credentials never stored in variables longer than needed
- **PSCredential Objects**: Credentials passed as secure objects to remote sessions
- **Memory Cleanup**: Credential objects disposed after use

#### 3. Comprehensive Logging
- **Audit Trail**: All operations logged to `%TEMP%\MultiTool.log`
- **Timestamped Entries**: ISO 8601 format timestamps
- **Severity Levels**: INFO, WARN, ERROR for filtering
- **Security Events**: Failed operations, invalid inputs, errors logged

#### 4. Error Handling
- **Try-Catch Blocks**: Every operation wrapped in error handling
- **No Information Leakage**: Generic errors shown to user, details in logs
- **Graceful Failures**: Application continues running after errors
- **User Feedback**: Clear, non-technical error messages

#### 5. Resource Management
- **CIM Session Cleanup**: All CIM sessions disposed in finally blocks
- **Runspace Disposal**: Background runspaces cleaned up on exit
- **No Memory Leaks**: Proper disposal of WPF and .NET resources

### 🟡 Known Limitations

#### 1. Credential Caching (By Design)
- **Current**: Credentials requested per operation
- **Impact**: Users must re-enter credentials frequently
- **Rationale**: Security over convenience - prevents credential exposure
- **Mitigation**: Consider Windows Credential Manager integration in future

#### 2. Download Verification (Low Risk)
- **Current**: Windows 11 installer downloaded without hash verification
- **Impact**: Theoretical MITM attack risk
- **Mitigation**: HTTPS used, Microsoft's trusted domain
- **Recommendation**: Add Authenticode signature verification

### 🔐 Security Best Practices

#### For Administrators
1. **Least Privilege**: Only grant admin rights to users who need this tool
2. **Audit Logs**: Regularly review `%TEMP%\MultiTool.log` files
3. **Network Segmentation**: Limit WinRM to management VLANs
4. **Credential Rotation**: Rotate service account passwords regularly

#### For Users
1. **Verify Hostnames**: Always use "Resolve" button before operations
2. **Check Results**: Review output for unexpected behavior
3. **Use Personal Accounts**: Avoid sharing credentials
4. **Report Issues**: Log security concerns with IT team

### Compliance & Standards
- ✅ No hardcoded credentials
- ✅ Input validation on all user inputs
- ✅ Audit logging for all operations
- ✅ Proper error handling
- ✅ Secure credential handling (Get-Credential)
- ✅ Resource cleanup (no leaks)
- ✅ No execution of arbitrary user commands

### Security Review
A comprehensive security review was conducted (see `InitialWrite\Up.md`). All critical vulnerabilities have been addressed:
- ✅ **0 Critical Issues**
- ⚠️ **2 Medium Issues** (convenience/defense-in-depth)
- ℹ️ **4 Low Priority** enhancements

## 🏗️ Architecture

### Technology Stack
- **Language**: PowerShell 5.1+
- **GUI Framework**: Windows Presentation Foundation (WPF)
- **Markup**: XAML for UI definition
- **Remoting**: PowerShell Remoting (WinRM)
- **Queries**: CIM (not legacy WMI)

### Code Structure
```
Multi-Tool.PS1 (~1650 lines)
├── WPF Assembly Loading (Lines 1-3)
├── Utility Classes (Lines 5-40)
│   ├── InputValidator (hostname/IP validation)
│   └── Logger (audit trail logging)
├── Configuration (Lines 42-53)
│   └── AppConfig hashtable
├── XAML GUI Definition (Lines 54-105)
│   └── 18 feature buttons
├── XAML Loading (Lines 107-110)
├── Control References (Lines 112-140)
├── Helper Functions (Lines 142-320)
│   ├── Get-SafeDateTime
│   ├── Test-RemoteConnectivity
│   ├── Invoke-RemoteOperation
│   ├── Get-SystemInfoOptimized
│   ├── Download-VerifiedFile
│   └── Update-ConnectionStatus
└── Event Handlers (Lines 323-1580)
    └── 18 button click handlers
```

### Key Design Patterns
- **Class-Based Utilities**: InputValidator and Logger classes
- **Configuration Object**: Centralized settings in hashtable
- **Wrapper Functions**: Standard patterns for remote operations
- **Error Result Objects**: Consistent return structure (Success, Data, Message)

### Dependencies
- **None** - Fully self-contained single file
- Uses only built-in PowerShell modules
- WPF assemblies (included with .NET Framework)

## 🐛 Troubleshooting

### Application Won't Start

**Issue**: Script execution prevented
```
Solution: Run with bypass flag
powershell.exe -ExecutionPolicy Bypass -File "tool.txt"
```

**Issue**: WPF assemblies not found
```
Solution: Ensure .NET Framework 4.5+ is installed
- Download from Microsoft
- Reboot after installation
```

### Remote Operations Fail

**Issue**: "Access Denied" or authentication errors
```
Solution 1: Verify you have administrator rights on target machine
Solution 2: Provide explicit credentials when prompted
Solution 3: Ensure target machine is in same domain
```

**Issue**: "WinRM cannot process the request"
```
Solution: Enable WinRM on target machine
Run on target: winrm quickconfig
Or via Group Policy: Enable Windows Remote Management
```

**Issue**: Firewall blocking connection
```
Solution: Allow WinRM through firewall
- Inbound Rules: Windows Remote Management (HTTP-In)
- Ports: TCP 5985 (HTTP) or 5986 (HTTPS)
```

### MDT Cleanup Issues

**Issue**: "No issues found" but error persists
```
Possible Causes:
1. Group Policy startup script (check: gpresult /h report.html)
2. PDQ Deploy agent configuration
3. SCCM/MDT server still pushing policy
4. Network logon script in Active Directory

Solution: Check logs, examine Group Policy, verify network scripts
```

**Issue**: "Access Denied" during cleanup
```
Solution: Ensure you provide Domain Admin or Local Admin credentials
Some registry keys require elevated privileges
```

### Performance Issues

**Issue**: UI freezes during operations
```
Expected: Some operations take time (software inventory, GPUpdate)
The progress bar indicates operation is running
Do not close the application - let it complete
```

**Issue**: High memory usage
```
Normal: WPF applications use more memory than console apps
Cleanup: Close and reopen application if it's been running for hours
```

### Log File Location

**Find Logs**: Navigate to `%TEMP%\MultiTool.log`
```powershell
# Open log location
explorer $env:TEMP

# View log in notepad
notepad "$env:TEMP\MultiTool.log"
```

## 📝 Additional Documentation

- **CLAUDE.md** - Guidance for future development and code modifications
- **InitialWrite\Up.md** - Comprehensive security review and implementation status
- **Multi-Tool.code-workspace** - VS Code workspace configuration

## 🤝 Contributing

This tool was developed for internal use. If you need to modify:
1. Read `CLAUDE.md` for architecture guidance
2. Follow existing patterns (InputValidator, Logger, error handling)
3. Test thoroughly on non-production systems first
4. Update documentation after changes

## 📄 License

Internal tool for organizational use. 

## ⚠️ Disclaimer

This tool performs administrative operations on remote systems. Always:
- Verify the target hostname before executing commands
- Test on non-production systems first
- Ensure you have proper authorization
- Maintain audit logs for compliance
- Follow your organization's IT policies

**Use at your own risk. Improper use may cause system disruptions or data loss.**

---

**Version**: 2.1 (Enhanced Defender Check, Streamlined Features)  
**Last Updated**: 2026-01-13  
**Maintained By**: IT Department

## 📝 Recent Changes (v2.1)

### Added
- ⭐ **Enhanced Defender Status Check** - Now includes threat detection from last 24 hours
  - Queries Windows Defender Operational event log
  - Shows Event ID 1116 (threats detected)
  - Displays threat name, path, time, and action taken
  - Comprehensive health summary with issue detection

### Removed
- ❌ Logoff User button (security policy change)
- ❌ Upgrade to Windows 11 button (centralized deployment preferred)

### Cleaned Up
- Removed old backup files
- Removed implementation notes (outdated)
- Removed integrated defender check script (functionality now built-in)
