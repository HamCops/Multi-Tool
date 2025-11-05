<#
.SYNOPSIS
    Removes Microsoft Deployment Toolkit (MDT) startup artifacts that cause LiteTouch.wsf errors.

.DESCRIPTION
    This script performs a comprehensive cleanup of MDT/WDT deployment artifacts that persist
    after deployment completion, causing startup errors. It includes privilege validation,
    robust logging, safety prompts, and backup capabilities.

.PARAMETER Silent
    Suppresses all confirmation prompts. Use with caution.

.PARAMETER LogPath
    Custom path for the log file. Default: %TEMP%\MDT-Cleanup-YYYYMMDD-HHMMSS.log

.PARAMETER BackupPath
    Custom path for backup files. Default: %TEMP%\MDT-Cleanup-Backup-YYYYMMDD-HHMMSS

.PARAMETER SkipBackup
    Skip creating backups of registry entries and files before deletion.

.PARAMETER Force
    Force deletion of all artifacts without safety checks.

.EXAMPLE
    .\Fix-MDT-Startup-Error.ps1
    Runs the script with interactive prompts and default settings.

.EXAMPLE
    .\Fix-MDT-Startup-Error.ps1 -Silent
    Runs the script without any confirmation prompts.

.EXAMPLE
    .\Fix-MDT-Startup-Error.ps1 -LogPath "C:\Logs\mdt-cleanup.log"
    Runs the script with a custom log file location.

.NOTES
    Author: System Administrator
    Version: 2.0.0
    Requires: PowerShell 5.1 or higher, Administrator privileges
    Last Modified: 2025-01-05
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false)]
    [switch]$Silent,

    [Parameter(Mandatory = $false)]
    [string]$LogPath,

    [Parameter(Mandatory = $false)]
    [string]$BackupPath,

    [Parameter(Mandatory = $false)]
    [switch]$SkipBackup,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

#Requires -RunAsAdministrator

# Script configuration
$ErrorActionPreference = "Continue"
$WarningPreference = "Continue"
$VerbosePreference = if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"]) { "Continue" } else { "SilentlyContinue" }

# Initialize script variables
$script:IssuesFound = 0
$script:IssuesFixed = 0
$script:IssuesFailed = 0
$script:BackupCreated = $false
$script:LogFileHandle = $null
$script:StartTime = Get-Date
$script:ExitCode = 0

# Timestamp format for logs
$script:TimestampFormat = "yyyy-MM-dd HH:mm:ss.fff"

# Initialize paths
if (-not $LogPath) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $LogPath = Join-Path $env:TEMP "MDT-Cleanup-$timestamp.log"
}

if (-not $BackupPath) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $BackupPath = Join-Path $env:TEMP "MDT-Cleanup-Backup-$timestamp"
}

#region Logging Functions

function Write-Log {
    <#
    .SYNOPSIS
        Writes a message to both console and log file with timestamp.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG", "CRITICAL")]
        [string]$Level = "INFO",

        [Parameter(Mandatory = $false)]
        [switch]$NoConsole
    )

    $timestamp = Get-Date -Format $script:TimestampFormat
    $logMessage = "[$timestamp] [$Level] $Message"

    # Write to log file
    try {
        Add-Content -Path $LogPath -Value $logMessage -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to write to log file: $_"
    }

    # Write to console with color coding
    if (-not $NoConsole) {
        $color = switch ($Level) {
            "SUCCESS" { "Green" }
            "WARNING" { "Yellow" }
            "ERROR" { "Red" }
            "CRITICAL" { "Magenta" }
            "DEBUG" { "Gray" }
            default { "White" }
        }

        $symbol = switch ($Level) {
            "SUCCESS" { "[✓]" }
            "WARNING" { "[!]" }
            "ERROR" { "[✗]" }
            "CRITICAL" { "[!!!]" }
            "DEBUG" { "[→]" }
            default { "[i]" }
        }

        Write-Host "$symbol $Message" -ForegroundColor $color
    }
}

function Write-SectionHeader {
    param([string]$Title)
    $separator = "=" * 80
    Write-Log -Message $separator -Level "INFO"
    Write-Log -Message $Title -Level "INFO"
    Write-Log -Message $separator -Level "INFO"
}

function Write-SubSection {
    param([string]$Title)
    Write-Host "`n$Title" -ForegroundColor Cyan
    Write-Log -Message $Title -Level "INFO" -NoConsole
}

#endregion

#region Privilege and Environment Validation

function Test-AdministratorPrivilege {
    <#
    .SYNOPSIS
        Validates that the script is running with administrator privileges.
    #>
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

        if (-not $isAdmin) {
            Write-Log -Message "Administrator privileges required but not detected" -Level "CRITICAL"
            Write-Log -Message "Please run this script as Administrator" -Level "ERROR"
            return $false
        }

        Write-Log -Message "Administrator privileges validated successfully" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log -Message "Failed to validate administrator privileges: $_" -Level "ERROR"
        return $false
    }
}

function Test-SystemEnvironment {
    <#
    .SYNOPSIS
        Validates the system environment and prerequisites.
    #>
    Write-Log -Message "Validating system environment..." -Level "INFO"

    # Check PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    Write-Log -Message "PowerShell Version: $psVersion" -Level "INFO"

    if ($psVersion.Major -lt 5) {
        Write-Log -Message "PowerShell 5.1 or higher is required. Current version: $psVersion" -Level "ERROR"
        return $false
    }

    # Check OS version
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
    Write-Log -Message "Operating System: $($osInfo.Caption) [$($osInfo.Version)]" -Level "INFO"
    Write-Log -Message "Computer Name: $($env:COMPUTERNAME)" -Level "INFO"
    Write-Log -Message "Current User: $($env:USERNAME)" -Level "INFO"

    # Check disk space for backup
    if (-not $SkipBackup) {
        $drive = (Get-Item $env:TEMP).PSDrive
        $freeSpace = (Get-PSDrive $drive.Name).Free
        $freeSpaceMB = [math]::Round($freeSpace / 1MB, 2)

        Write-Log -Message "Available disk space on $($drive.Name): $freeSpaceMB MB" -Level "INFO"

        if ($freeSpaceMB -lt 100) {
            Write-Log -Message "Low disk space detected. Consider using -SkipBackup or freeing up space." -Level "WARNING"
        }
    }

    return $true
}

#endregion

#region Backup Functions

function Initialize-Backup {
    <#
    .SYNOPSIS
        Creates the backup directory structure.
    #>
    if ($SkipBackup) {
        Write-Log -Message "Backup creation skipped by user request" -Level "WARNING"
        return $true
    }

    try {
        Write-Log -Message "Initializing backup directory: $BackupPath" -Level "INFO"

        if (Test-Path $BackupPath) {
            Write-Log -Message "Backup directory already exists, using existing location" -Level "WARNING"
        }
        else {
            New-Item -Path $BackupPath -ItemType Directory -Force | Out-Null
            Write-Log -Message "Backup directory created successfully" -Level "SUCCESS"
        }

        # Create subdirectories
        $subDirs = @("Registry", "Files", "ScheduledTasks", "Shortcuts")
        foreach ($dir in $subDirs) {
            $path = Join-Path $BackupPath $dir
            New-Item -Path $path -ItemType Directory -Force | Out-Null
        }

        $script:BackupCreated = $true
        return $true
    }
    catch {
        Write-Log -Message "Failed to initialize backup directory: $_" -Level "ERROR"
        return $false
    }
}

function Backup-RegistryKey {
    <#
    .SYNOPSIS
        Backs up a registry key before deletion.
    #>
    param(
        [string]$Path,
        [string]$Name
    )

    if ($SkipBackup) { return $true }

    try {
        $backupFile = Join-Path $BackupPath "Registry\$($Path.Replace(':', '').Replace('\', '_'))_$Name.reg"
        $regPath = $Path.Replace("HKLM:", "HKEY_LOCAL_MACHINE").Replace("HKCU:", "HKEY_CURRENT_USER")

        # Export using reg.exe for reliability
        $null = reg export "$regPath" "$backupFile" /y 2>&1

        if (Test-Path $backupFile) {
            Write-Log -Message "Registry backup created: $backupFile" -Level "DEBUG"
            return $true
        }
    }
    catch {
        Write-Log -Message "Failed to backup registry key: $_" -Level "WARNING"
    }

    return $false
}

function Backup-File {
    <#
    .SYNOPSIS
        Backs up a file or directory before deletion.
    #>
    param([string]$Path)

    if ($SkipBackup) { return $true }

    try {
        $fileName = Split-Path $Path -Leaf
        $backupFile = Join-Path $BackupPath "Files\$fileName"

        if (Test-Path $Path -PathType Container) {
            Copy-Item -Path $Path -Destination $backupFile -Recurse -Force -ErrorAction Stop
        }
        else {
            Copy-Item -Path $Path -Destination $backupFile -Force -ErrorAction Stop
        }

        Write-Log -Message "File backup created: $backupFile" -Level "DEBUG"
        return $true
    }
    catch {
        Write-Log -Message "Failed to backup file '$Path': $_" -Level "WARNING"
        return $false
    }
}

#endregion

#region Safety Prompts

function Confirm-RiskyOperation {
    <#
    .SYNOPSIS
        Prompts user for confirmation before performing risky operations.
    #>
    param(
        [string]$Operation,
        [string]$Target,
        [string]$Reason
    )

    if ($Silent -or $Force) {
        Write-Log -Message "Auto-confirmed (Silent/Force mode): $Operation on '$Target'" -Level "WARNING"
        return $true
    }

    Write-Host "`n" -NoNewline
    Write-Host "┌─────────────────────────────────────────────────────────────┐" -ForegroundColor Yellow
    Write-Host "│                    CONFIRMATION REQUIRED                    │" -ForegroundColor Yellow
    Write-Host "├─────────────────────────────────────────────────────────────┤" -ForegroundColor Yellow
    Write-Host "│ Operation: " -ForegroundColor Yellow -NoNewline
    Write-Host $Operation.PadRight(48) -ForegroundColor White -NoNewline
    Write-Host "│" -ForegroundColor Yellow
    Write-Host "│ Target:    " -ForegroundColor Yellow -NoNewline
    Write-Host $Target.PadRight(48).Substring(0, [Math]::Min(48, $Target.Length)) -ForegroundColor White -NoNewline
    Write-Host "│" -ForegroundColor Yellow
    Write-Host "│ Reason:    " -ForegroundColor Yellow -NoNewline
    Write-Host $Reason.PadRight(48).Substring(0, [Math]::Min(48, $Reason.Length)) -ForegroundColor White -NoNewline
    Write-Host "│" -ForegroundColor Yellow
    Write-Host "└─────────────────────────────────────────────────────────────┘" -ForegroundColor Yellow

    $response = Read-Host "`nProceed with this operation? [Y/N]"

    $confirmed = $response -eq 'Y' -or $response -eq 'y'
    Write-Log -Message "User response for '$Operation' on '$Target': $response (Confirmed: $confirmed)" -Level "INFO" -NoConsole

    return $confirmed
}

#endregion

#region Core Cleanup Functions

function Remove-RegistryValue {
    <#
    .SYNOPSIS
        Safely removes a registry value with logging and backup.
    #>
    param(
        [string]$Path,
        [string]$Name
    )

    try {
        if (-not (Test-Path $Path)) {
            Write-Log -Message "Registry path does not exist: $Path" -Level "DEBUG"
            return $false
        }

        $value = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue

        if (-not $value) {
            Write-Log -Message "Registry value not found: $Path\$Name" -Level "DEBUG"
            return $false
        }

        $script:IssuesFound++

        # Log the current value
        Write-Log -Message "Found registry value: $Path\$Name = $($value.$Name)" -Level "INFO"

        # Confirm risky operations
        if (-not (Confirm-RiskyOperation -Operation "Delete Registry Value" -Target "$Path\$Name" -Reason "MDT startup artifact")) {
            Write-Log -Message "User declined deletion of registry value: $Path\$Name" -Level "WARNING"
            return $false
        }

        # Backup
        Backup-RegistryKey -Path $Path -Name $Name

        # Remove
        Remove-ItemProperty -Path $Path -Name $Name -Force -ErrorAction Stop
        Write-Log -Message "Successfully removed registry value: $Path\$Name" -Level "SUCCESS"

        $script:IssuesFixed++
        return $true
    }
    catch {
        Write-Log -Message "Failed to remove registry value '$Path\$Name': $_" -Level "ERROR"
        $script:IssuesFailed++
        return $false
    }
}

function Remove-RegistryKey {
    <#
    .SYNOPSIS
        Safely removes a registry key with logging and backup.
    #>
    param([string]$Path)

    try {
        if (-not (Test-Path $Path)) {
            Write-Log -Message "Registry key does not exist: $Path" -Level "DEBUG"
            return $false
        }

        $script:IssuesFound++
        Write-Log -Message "Found registry key: $Path" -Level "INFO"

        if (-not (Confirm-RiskyOperation -Operation "Delete Registry Key" -Target $Path -Reason "MDT startup artifact")) {
            Write-Log -Message "User declined deletion of registry key: $Path" -Level "WARNING"
            return $false
        }

        # Backup
        Backup-RegistryKey -Path $Path -Name ""

        # Remove
        Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
        Write-Log -Message "Successfully removed registry key: $Path" -Level "SUCCESS"

        $script:IssuesFixed++
        return $true
    }
    catch {
        Write-Log -Message "Failed to remove registry key '$Path': $_" -Level "ERROR"
        $script:IssuesFailed++
        return $false
    }
}

function Remove-ScheduledTaskSafely {
    <#
    .SYNOPSIS
        Safely removes a scheduled task with logging and backup.
    #>
    param([Microsoft.Management.Infrastructure.CimInstance]$Task)

    try {
        $script:IssuesFound++
        $taskName = $Task.TaskName
        $taskPath = $Task.TaskPath

        Write-Log -Message "Found scheduled task: $taskPath$taskName" -Level "INFO"
        Write-Log -Message "Task Description: $($Task.Description)" -Level "DEBUG"
        Write-Log -Message "Task Actions: $($Task.Actions.Execute)" -Level "DEBUG"

        if (-not (Confirm-RiskyOperation -Operation "Delete Scheduled Task" -Target "$taskPath$taskName" -Reason "References MDT/LiteTouch")) {
            Write-Log -Message "User declined deletion of scheduled task: $taskName" -Level "WARNING"
            return $false
        }

        # Backup task definition
        if (-not $SkipBackup) {
            $backupFile = Join-Path $BackupPath "ScheduledTasks\$($taskName.Replace('\', '_')).xml"
            Export-ScheduledTask -TaskName $taskName -TaskPath $taskPath | Out-File $backupFile -ErrorAction SilentlyContinue
            Write-Log -Message "Scheduled task backed up to: $backupFile" -Level "DEBUG"
        }

        # Remove
        Unregister-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Confirm:$false -ErrorAction Stop
        Write-Log -Message "Successfully removed scheduled task: $taskName" -Level "SUCCESS"

        $script:IssuesFixed++
        return $true
    }
    catch {
        Write-Log -Message "Failed to remove scheduled task '$($Task.TaskName)': $_" -Level "ERROR"
        $script:IssuesFailed++
        return $false
    }
}

function Remove-DirectorySafely {
    <#
    .SYNOPSIS
        Safely removes a directory with logging and backup.
    #>
    param(
        [string]$Path,
        [bool]$IsCritical = $true
    )

    try {
        if (-not (Test-Path $Path)) {
            Write-Log -Message "Directory does not exist: $Path" -Level "DEBUG"
            return $false
        }

        $script:IssuesFound++
        $itemCount = (Get-ChildItem -Path $Path -Recurse -ErrorAction SilentlyContinue | Measure-Object).Count
        $size = (Get-ChildItem -Path $Path -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        $sizeMB = [math]::Round($size / 1MB, 2)

        Write-Log -Message "Found directory: $Path (Items: $itemCount, Size: $sizeMB MB)" -Level "INFO"

        $reason = if ($IsCritical) { "MDT deployment directory (CRITICAL PATH)" } else { "MDT deployment directory" }

        if (-not (Confirm-RiskyOperation -Operation "Delete Directory" -Target $Path -Reason $reason)) {
            Write-Log -Message "User declined deletion of directory: $Path" -Level "WARNING"
            return $false
        }

        # Backup
        Backup-File -Path $Path

        # Take ownership and grant permissions
        Write-Log -Message "Taking ownership of directory: $Path" -Level "INFO"
        $takeownOutput = takeown /F $Path /R /D Y 2>&1
        Write-Log -Message "Takeown output: $takeownOutput" -Level "DEBUG" -NoConsole

        Write-Log -Message "Granting full control permissions: $Path" -Level "INFO"
        $icaclsOutput = icacls $Path /grant administrators:F /T 2>&1
        Write-Log -Message "Icacls output: $icaclsOutput" -Level "DEBUG" -NoConsole

        # Remove
        Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
        Write-Log -Message "Successfully removed directory: $Path" -Level "SUCCESS"

        $script:IssuesFixed++
        return $true
    }
    catch {
        Write-Log -Message "Failed to remove directory '$Path': $_" -Level "ERROR"
        $script:IssuesFailed++
        return $false
    }
}

function Remove-ShortcutSafely {
    <#
    .SYNOPSIS
        Safely removes a shortcut file with logging and backup.
    #>
    param(
        [string]$ShortcutPath,
        [string]$TargetPath
    )

    try {
        $script:IssuesFound++
        Write-Log -Message "Found startup shortcut: $ShortcutPath -> $TargetPath" -Level "INFO"

        if (-not (Confirm-RiskyOperation -Operation "Delete Shortcut" -Target $ShortcutPath -Reason "Points to MDT/LiteTouch")) {
            Write-Log -Message "User declined deletion of shortcut: $ShortcutPath" -Level "WARNING"
            return $false
        }

        # Backup
        Backup-File -Path $ShortcutPath

        # Remove
        Remove-Item -Path $ShortcutPath -Force -ErrorAction Stop
        Write-Log -Message "Successfully removed shortcut: $ShortcutPath" -Level "SUCCESS"

        $script:IssuesFixed++
        return $true
    }
    catch {
        Write-Log -Message "Failed to remove shortcut '$ShortcutPath': $_" -Level "ERROR"
        $script:IssuesFailed++
        return $false
    }
}

#endregion

#region Cleanup Operations

function Remove-MDTRegistryEntries {
    <#
    .SYNOPSIS
        Scans and removes MDT-related registry entries.
    #>
    Write-SubSection "[1] Scanning Registry for MDT Startup Entries"

    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
    )

    $mdtPatterns = @("LiteTouch", "MININT", "DeploymentShare", "BDD", "MDT")
    $foundEntries = 0

    foreach ($regPath in $registryPaths) {
        Write-Log -Message "Scanning: $regPath" -Level "DEBUG"

        if (-not (Test-Path $regPath)) {
            Write-Log -Message "Registry path not found: $regPath" -Level "DEBUG"
            continue
        }

        try {
            $properties = Get-ItemProperty -Path $regPath -ErrorAction Stop

            foreach ($prop in $properties.PSObject.Properties) {
                # Skip built-in properties
                if ($prop.Name -match "^PS") { continue }

                $value = $prop.Value
                $matched = $false

                foreach ($pattern in $mdtPatterns) {
                    if ($value -match $pattern) {
                        $matched = $true
                        break
                    }
                }

                if ($matched) {
                    $foundEntries++
                    Remove-RegistryValue -Path $regPath -Name $prop.Name
                }
            }
        }
        catch {
            Write-Log -Message "Error scanning registry path '$regPath': $_" -Level "WARNING"
        }
    }

    if ($foundEntries -eq 0) {
        Write-Log -Message "No MDT registry entries found" -Level "INFO"
    }
    else {
        Write-Log -Message "Found $foundEntries MDT registry entries" -Level "INFO"
    }
}

function Remove-MDTScheduledTasks {
    <#
    .SYNOPSIS
        Scans and removes MDT-related scheduled tasks.
    #>
    Write-SubSection "[2] Scanning for MDT Scheduled Tasks"

    try {
        $allTasks = Get-ScheduledTask -ErrorAction Stop
        $mdtTasks = $allTasks | Where-Object {
            $_.TaskName -match "LiteTouch|MDT|BDD|DeploymentShare" -or
            $_.Actions.Execute -match "LiteTouch|MININT"
        }

        if ($mdtTasks.Count -eq 0) {
            Write-Log -Message "No MDT-related scheduled tasks found" -Level "INFO"
            return
        }

        Write-Log -Message "Found $($mdtTasks.Count) MDT-related scheduled tasks" -Level "INFO"

        foreach ($task in $mdtTasks) {
            Remove-ScheduledTaskSafely -Task $task
        }
    }
    catch {
        Write-Log -Message "Error scanning scheduled tasks: $_" -Level "ERROR"
    }
}

function Remove-MDTDirectories {
    <#
    .SYNOPSIS
        Scans and removes MDT-related directories.
    #>
    Write-SubSection "[3] Scanning for MDT Directories"

    $criticalPaths = @(
        @{Path = "C:\MININT"; Critical = $true},
        @{Path = "C:\DeploymentShare"; Critical = $false},
        @{Path = "C:\_SMSTaskSequence"; Critical = $false}
    )

    $foundDirs = 0

    foreach ($pathInfo in $criticalPaths) {
        if (Test-Path $pathInfo.Path) {
            $foundDirs++
            Remove-DirectorySafely -Path $pathInfo.Path -IsCritical $pathInfo.Critical
        }
        else {
            Write-Log -Message "Directory not found: $($pathInfo.Path)" -Level "DEBUG"
        }
    }

    if ($foundDirs -eq 0) {
        Write-Log -Message "No MDT directories found" -Level "INFO"
    }
}

function Remove-MDTStartupShortcuts {
    <#
    .SYNOPSIS
        Scans and removes MDT-related startup shortcuts.
    #>
    Write-SubSection "[4] Scanning Startup Folders for MDT Shortcuts"

    $startupFolders = @(
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup",
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
    )

    $foundShortcuts = 0

    foreach ($folder in $startupFolders) {
        Write-Log -Message "Scanning: $folder" -Level "DEBUG"

        if (-not (Test-Path $folder)) {
            Write-Log -Message "Startup folder not found: $folder" -Level "DEBUG"
            continue
        }

        $shortcuts = Get-ChildItem -Path $folder -Filter "*.lnk" -ErrorAction SilentlyContinue

        foreach ($shortcut in $shortcuts) {
            try {
                $shell = New-Object -ComObject WScript.Shell
                $target = $shell.CreateShortcut($shortcut.FullName).TargetPath

                if ($target -match "LiteTouch|MININT|MDT") {
                    $foundShortcuts++
                    Remove-ShortcutSafely -ShortcutPath $shortcut.FullName -TargetPath $target
                }
            }
            catch {
                Write-Log -Message "Error processing shortcut '$($shortcut.FullName)': $_" -Level "WARNING"
            }
        }
    }

    if ($foundShortcuts -eq 0) {
        Write-Log -Message "No MDT-related startup shortcuts found" -Level "INFO"
    }
}

#endregion

#region Reporting

function Show-FinalReport {
    <#
    .SYNOPSIS
        Displays a comprehensive final report.
    #>
    $endTime = Get-Date
    $duration = $endTime - $script:StartTime

    Write-Host "`n"
    Write-SectionHeader "CLEANUP OPERATION COMPLETED"

    Write-Host "`nEXECUTION SUMMARY:" -ForegroundColor Cyan
    Write-Host "  Start Time:       " -NoNewline; Write-Host $script:StartTime.ToString("yyyy-MM-dd HH:mm:ss") -ForegroundColor White
    Write-Host "  End Time:         " -NoNewline; Write-Host $endTime.ToString("yyyy-MM-dd HH:mm:ss") -ForegroundColor White
    Write-Host "  Duration:         " -NoNewline; Write-Host "$($duration.Minutes)m $($duration.Seconds)s" -ForegroundColor White

    Write-Host "`nOPERATION STATISTICS:" -ForegroundColor Cyan
    Write-Host "  Issues Found:     " -NoNewline
    Write-Host $script:IssuesFound -ForegroundColor $(if ($script:IssuesFound -gt 0) { "Yellow" } else { "Green" })

    Write-Host "  Issues Fixed:     " -NoNewline
    Write-Host $script:IssuesFixed -ForegroundColor $(if ($script:IssuesFixed -gt 0) { "Green" } else { "Yellow" })

    Write-Host "  Issues Failed:    " -NoNewline
    Write-Host $script:IssuesFailed -ForegroundColor $(if ($script:IssuesFailed -gt 0) { "Red" } else { "Green" })

    Write-Host "`nOUTPUT FILES:" -ForegroundColor Cyan
    Write-Host "  Log File:         " -NoNewline; Write-Host $LogPath -ForegroundColor White

    if ($script:BackupCreated) {
        Write-Host "  Backup Location:  " -NoNewline; Write-Host $BackupPath -ForegroundColor White
    }

    # Determine overall status
    if ($script:IssuesFound -eq 0) {
        Write-Host "`nSTATUS: " -NoNewline -ForegroundColor Cyan
        Write-Host "NO ISSUES FOUND" -ForegroundColor Green
        Write-Log -Message "Cleanup completed: No MDT artifacts were found" -Level "SUCCESS"
        $script:ExitCode = 0
    }
    elseif ($script:IssuesFailed -eq 0 -and $script:IssuesFixed -gt 0) {
        Write-Host "`nSTATUS: " -NoNewline -ForegroundColor Cyan
        Write-Host "SUCCESS" -ForegroundColor Green
        Write-Log -Message "Cleanup completed successfully: $script:IssuesFixed issues fixed" -Level "SUCCESS"
        $script:ExitCode = 0
    }
    elseif ($script:IssuesFailed -gt 0) {
        Write-Host "`nSTATUS: " -NoNewline -ForegroundColor Cyan
        Write-Host "PARTIAL SUCCESS" -ForegroundColor Yellow
        Write-Log -Message "Cleanup completed with errors: $script:IssuesFixed fixed, $script:IssuesFailed failed" -Level "WARNING"
        $script:ExitCode = 1
    }
    else {
        Write-Host "`nSTATUS: " -NoNewline -ForegroundColor Cyan
        Write-Host "NO CHANGES MADE" -ForegroundColor Yellow
        Write-Log -Message "Cleanup completed: No changes were made (user declined all operations)" -Level "WARNING"
        $script:ExitCode = 2
    }

    # Next steps
    Write-Host "`nNEXT STEPS:" -ForegroundColor Cyan

    if ($script:IssuesFixed -gt 0) {
        Write-Host "  1. " -NoNewline; Write-Host "Restart the computer" -ForegroundColor White
        Write-Host "  2. " -NoNewline; Write-Host "Verify the error no longer appears" -ForegroundColor White
        Write-Host "  3. " -NoNewline; Write-Host "Review the log file for details: $LogPath" -ForegroundColor Gray
    }
    elseif ($script:IssuesFound -eq 0) {
        Write-Host "  1. " -NoNewline; Write-Host "If the error persists, check:" -ForegroundColor White
        Write-Host "     - Group Policy settings (run: gpresult /h gpreport.html)" -ForegroundColor Gray
        Write-Host "     - PDQ Deploy agent configuration" -ForegroundColor Gray
        Write-Host "     - Network logon scripts" -ForegroundColor Gray
    }

    if ($script:IssuesFailed -gt 0) {
        Write-Host "`n  " -NoNewline
        Write-Host "WARNING: Some operations failed. Check log for details." -ForegroundColor Red
        Write-Host "  Consider running the script again or performing manual cleanup." -ForegroundColor Yellow
    }

    if ($script:BackupCreated -and -not $SkipBackup) {
        Write-Host "`n  " -NoNewline
        Write-Host "Backups have been created at: $BackupPath" -ForegroundColor Cyan
        Write-Host "  You can restore from these backups if needed." -ForegroundColor Gray
    }

    Write-Host "`n" + ("=" * 80) + "`n"

    Write-Log -Message "Script execution completed with exit code: $script:ExitCode" -Level "INFO"
}

#endregion

#region Main Execution

function Start-MDTCleanup {
    <#
    .SYNOPSIS
        Main entry point for the cleanup operation.
    #>

    try {
        # Initialize log file
        try {
            "MDT/WDT Cleanup Script - Log File" | Out-File -FilePath $LogPath -Encoding UTF8
            "=" * 80 | Out-File -FilePath $LogPath -Append
            "" | Out-File -FilePath $LogPath -Append
        }
        catch {
            Write-Warning "Failed to initialize log file: $_"
            $script:LogPath = Join-Path $env:TEMP "MDT-Cleanup-Fallback.log"
            Write-Warning "Using fallback log path: $script:LogPath"
        }

        # Display banner
        Write-SectionHeader "MDT/WDT CLEANUP SCRIPT v2.0.0"
        Write-Log -Message "Script started by user: $env:USERNAME on computer: $env:COMPUTERNAME" -Level "INFO"

        # Validate privileges
        Write-SubSection "Validating Execution Environment"
        if (-not (Test-AdministratorPrivilege)) {
            Write-Log -Message "Script execution terminated: Insufficient privileges" -Level "CRITICAL"
            $script:ExitCode = 3
            return
        }

        # Validate system environment
        if (-not (Test-SystemEnvironment)) {
            Write-Log -Message "Script execution terminated: System environment validation failed" -Level "CRITICAL"
            $script:ExitCode = 4
            return
        }

        # Initialize backup
        if (-not $SkipBackup) {
            if (-not (Initialize-Backup)) {
                Write-Log -Message "Failed to initialize backup. Continue without backup?" -Level "WARNING"

                if (-not $Silent -and -not $Force) {
                    $response = Read-Host "Continue without backup? [Y/N]"
                    if ($response -ne 'Y' -and $response -ne 'y') {
                        Write-Log -Message "Script execution terminated by user" -Level "WARNING"
                        $script:ExitCode = 5
                        return
                    }
                }
            }
        }

        # Display operation mode
        Write-Host "`nOPERATION MODE:" -ForegroundColor Cyan
        if ($Silent) { Write-Host "  Silent Mode: ENABLED" -ForegroundColor Yellow }
        if ($Force) { Write-Host "  Force Mode: ENABLED" -ForegroundColor Red }
        if ($SkipBackup) { Write-Host "  Backup: DISABLED" -ForegroundColor Yellow }
        else { Write-Host "  Backup: ENABLED" -ForegroundColor Green }

        # Final confirmation before proceeding
        if (-not $Silent -and -not $Force) {
            Write-Host "`n" -NoNewline
            $proceed = Read-Host "Ready to scan for MDT artifacts. Proceed? [Y/N]"
            if ($proceed -ne 'Y' -and $proceed -ne 'y') {
                Write-Log -Message "Script execution cancelled by user" -Level "WARNING"
                $script:ExitCode = 6
                return
            }
        }

        Write-Host "`n"
        Write-SectionHeader "BEGINNING CLEANUP OPERATIONS"

        # Execute cleanup operations
        Remove-MDTRegistryEntries
        Remove-MDTScheduledTasks
        Remove-MDTDirectories
        Remove-MDTStartupShortcuts

        # Display final report
        Show-FinalReport
    }
    catch {
        Write-Log -Message "Unexpected error during cleanup: $_" -Level "CRITICAL"
        Write-Log -Message "Stack Trace: $($_.ScriptStackTrace)" -Level "DEBUG"
        $script:ExitCode = 99
    }
    finally {
        Write-Log -Message "Script execution ended" -Level "INFO"
    }
}

# Execute main function
Start-MDTCleanup

# Exit with appropriate code
exit $script:ExitCode

#endregion
