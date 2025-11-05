# MDT Cleanup Tool Integration

## Overview
The MDT/WDT cleanup tool has been successfully integrated into the Multi-Tool PowerShell GUI application as a button feature.

## What Was Done

### 1. Created Industry-Standard MDT Cleanup Script
**Location**: `Fix-MDT-Startup-Error.ps1`

**Features**:
- **Privilege Validation**: Automatically checks for Administrator rights
- **Robust Logging**: Timestamped logs with severity levels (INFO, SUCCESS, WARNING, ERROR, CRITICAL)
- **Safety Prompts**: Interactive confirmation before each risky operation
- **Automatic Backups**: Creates backups of all registry entries, files, and scheduled tasks before deletion
- **Comprehensive Reporting**: Detailed final report with statistics and next steps
- **Exit Codes**: Proper exit codes for scripting integration (0=success, 1=partial, 2=no changes, 3+=errors)

**Parameters**:
```powershell
-Silent          # Suppress confirmation prompts
-Force           # Skip all safety checks
-SkipBackup      # Don't create backups
-LogPath         # Custom log file location
-BackupPath      # Custom backup location
```

### 2. Integrated into Multi-Tool GUI
**File Modified**: `tool.txt`

**Changes Made**:

#### A. Added Button to XAML (Line 90)
```xml
<Button Name="btnFixMDT" Content="Fix MDT Error" Width="180" Margin="5"/>
```

#### B. Added Control Retrieval (Line 122)
```powershell
$btnFixMDT = $Window.FindName("btnFixMDT")
```

#### C. Added Event Handler (Lines 851-889)
The button launches the cleanup script in an elevated PowerShell window with proper error handling and user feedback.

## How To Use

### Option 1: Via Multi-Tool GUI
1. Open Multi-Tool (`tool.txt`)
2. Click the **"Fix MDT Error"** button
3. Accept the UAC elevation prompt
4. Follow the prompts in the cleanup script
5. Review the log file when complete
6. Restart the computer

### Option 2: Standalone Script
```powershell
# Interactive mode with prompts and backups
.\Fix-MDT-Startup-Error.ps1

# Silent mode (no prompts)
.\Fix-MDT-Startup-Error.ps1 -Silent

# Skip backups
.\Fix-MDT-Startup-Error.ps1 -SkipBackup

# Custom log location
.\Fix-MDT-Startup-Error.ps1 -LogPath "C:\Logs\mdt-fix.log"

# Force mode (skip all safety checks - use with caution)
.\Fix-MDT-Startup-Error.ps1 -Force
```

## What The Script Fixes

The cleanup script addresses the following MDT/WDT deployment artifacts:

1. **Registry Startup Entries**
   - `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run`
   - `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce`
   - Both 32-bit and 64-bit registry locations
   - User-level startup entries

2. **Scheduled Tasks**
   - Tasks referencing LiteTouch, MDT, BDD, or DeploymentShare

3. **Directories**
   - `C:\MININT` (critical path - with extra confirmation)
   - `C:\DeploymentShare`
   - `C:\_SMSTaskSequence`

4. **Startup Shortcuts**
   - All-users and current-user startup folders
   - Shortcuts pointing to MDT/LiteTouch components

## Log Files and Backups

### Default Locations
- **Log File**: `%TEMP%\MDT-Cleanup-YYYYMMDD-HHMMSS.log`
- **Backup Folder**: `%TEMP%\MDT-Cleanup-Backup-YYYYMMDD-HHMMSS\`

### Backup Structure
```
MDT-Cleanup-Backup-YYYYMMDD-HHMMSS/
├── Registry/          # Exported .reg files
├── Files/             # Backed up directories and files
├── ScheduledTasks/    # Exported task definitions (.xml)
└── Shortcuts/         # Backed up .lnk files
```

### Log Format
```
[2025-01-05 14:23:45.123] [INFO] Script started by user: admin on computer: WORKSTATION01
[2025-01-05 14:23:45.456] [SUCCESS] Administrator privileges validated successfully
[2025-01-05 14:23:46.789] [INFO] Found registry value: HKLM:\SOFTWARE\...\Run\LiteTouch
[2025-01-05 14:23:47.012] [SUCCESS] Successfully removed registry value: HKLM:\SOFTWARE\...\Run\LiteTouch
```

## Safety Features

### 1. Privilege Validation
- Verifies Administrator rights before any operations
- Terminates safely if insufficient privileges

### 2. Interactive Confirmations
Each deletion shows:
```
┌─────────────────────────────────────────────────────────────┐
│                    CONFIRMATION REQUIRED                    │
├─────────────────────────────────────────────────────────────┤
│ Operation: Delete Registry Value                           │
│ Target:    HKLM:\SOFTWARE\...\Run\LiteTouch               │
│ Reason:    MDT startup artifact                            │
└─────────────────────────────────────────────────────────────┘

Proceed with this operation? [Y/N]
```

### 3. Critical Path Protection
Extra confirmation for critical directories like `C:\MININT`

### 4. Automatic Backups
- Registry keys exported to .reg files
- Files and directories copied to backup location
- Scheduled tasks exported to XML
- Can be restored if needed

### 5. Comprehensive Logging
Every action is logged with:
- Timestamp (millisecond precision)
- Severity level
- Detailed operation description
- Success/failure status

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success - All issues resolved or no issues found |
| 1 | Partial Success - Some operations failed |
| 2 | No Changes - User declined all operations |
| 3 | Insufficient Privileges |
| 4 | System Environment Validation Failed |
| 5 | Backup Initialization Failed (user declined to continue) |
| 6 | User Cancelled |
| 99 | Unexpected Critical Error |

## Troubleshooting

### Script Not Found Error
If you see: `ERROR: MDT cleanup script not found`
- Ensure `Fix-MDT-Startup-Error.ps1` is in the same directory as `tool.txt`
- Both files should be in: `/home/cam/Projects/Multi-Tool/`

### UAC Prompt Cancelled
- The script requires Administrator privileges
- User must accept the UAC elevation prompt
- If cancelled, no changes will be made

### Some Operations Failed
- Check the log file for specific errors
- Common issues:
  - File/directory in use
  - Insufficient permissions (even with admin rights)
  - Corrupted registry entries
- Try running in Safe Mode if persistent failures occur

### Error Still Appears After Cleanup
If the LiteTouch.wsf error persists:
1. Review the log file to confirm all artifacts were removed
2. Check for Group Policy settings: `gpresult /h report.html`
3. Check PDQ Deploy agent configuration
4. Check network logon scripts in Active Directory

## Files Included

```
/home/cam/Projects/Multi-Tool/
├── tool.txt                           # Main Multi-Tool GUI (modified)
├── Fix-MDT-Startup-Error.ps1          # MDT cleanup script (new)
└── INTEGRATION-NOTES.md               # This file (new)

/home/cam/Projects/Random-Talks/windows/
├── Fix-MDT-Startup-Error.ps1          # Original script location
└── README-MDT-Fix.md                  # Detailed documentation
```

## Code Quality

The cleanup script follows industry best practices:
- ✓ Proper error handling with try-catch blocks
- ✓ Input validation and sanitization
- ✓ Comment-based help with examples
- ✓ Parameter validation
- ✓ Proper resource disposal
- ✓ Transaction-like behavior (backup before delete)
- ✓ Comprehensive logging
- ✓ User-friendly prompts and feedback
- ✓ Exit codes for automation
- ✓ Thread-safe operations
- ✓ No hardcoded credentials
- ✓ Follows PowerShell best practices

## Support

For issues or questions:
1. Check the log file: `%TEMP%\MDT-Cleanup-*.log`
2. Review backup files if restoration is needed
3. Consult the detailed README: `/home/cam/Projects/Random-Talks/windows/README-MDT-Fix.md`
4. Check Windows Event Viewer for additional details

## Version History

**v2.0.0** (2025-01-05)
- Initial integration into Multi-Tool GUI
- Added industry-standard logging
- Added safety prompts and backups
- Added privilege validation
- Added comprehensive error handling
- Added detailed reporting
