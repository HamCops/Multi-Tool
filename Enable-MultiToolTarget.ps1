<#
.SYNOPSIS
    Configures a Windows machine to be managed by Multi-Tool.

.DESCRIPTION
    Multi-Tool drives remote machines over WinRM (PowerShell Remoting / CIM) and
    launches mstsc, eventvwr, and msra against them. This script enables the
    target-side prerequisites so those operations work:

        - PowerShell Remoting / WinRM (TCP 5985)
        - WinRM, Remote Desktop, and Remote Event Log firewall rules
        - Remote Desktop (RDP)
        - Remote Assistance (optional, off by default)

    Run this ON THE TARGET MACHINE from an ELEVATED PowerShell prompt.

    For a domain, prefer Group Policy over running this on every box - see the
    "GROUP POLICY" notes at the bottom of this file.

.PARAMETER EnableRemoteAssistance
    Also enable Remote Assistance (for the Multi-Tool "Launch MSRA" button).
    Off by default because it widens the attack surface and on Windows Server
    requires the Remote-Assistance feature to be installed first.

.PARAMETER RestrictToSubnet
    Optional CIDR (e.g. "10.20.0.0/16") to scope the WinRM inbound rule to a
    management subnet instead of allowing any source. Recommended.

.PARAMETER WhatIf
    Show what would change without changing anything.

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -File .\Enable-MultiToolTarget.ps1

.EXAMPLE
    .\Enable-MultiToolTarget.ps1 -EnableRemoteAssistance -RestrictToSubnet "10.20.0.0/16"

.NOTES
    Enabling remote management widens the attack surface. Scope the firewall
    rules to your management VLAN (-RestrictToSubnet) and keep the local
    Administrators group tight.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch] $EnableRemoteAssistance,
    [string] $RestrictToSubnet
)

# --- Must run elevated --------------------------------------------------------
$identity  = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run from an elevated (Run as Administrator) PowerShell prompt."
    exit 1
}

$ErrorActionPreference = 'Stop'
$results = [System.Collections.Generic.List[object]]::new()

function Add-Result {
    param([string] $Step, [string] $Status, [string] $Detail = "")
    $results.Add([pscustomobject]@{ Step = $Step; Status = $Status; Detail = $Detail })
    $color = switch ($Status) { 'OK' { 'Green' } 'SKIPPED' { 'Yellow' } default { 'Red' } }
    Write-Host ("[{0,-7}] {1} {2}" -f $Status, $Step, $Detail) -ForegroundColor $color
}

Write-Host "`nConfiguring this machine ($env:COMPUTERNAME) for Multi-Tool management...`n" -ForegroundColor Cyan

# --- 1. PowerShell Remoting / WinRM ------------------------------------------
try {
    if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Enable PowerShell Remoting (WinRM)")) {
        Enable-PSRemoting -Force -ErrorAction Stop | Out-Null
    }
    Add-Result "PowerShell Remoting (WinRM)" "OK" "service running, listener on TCP 5985"
} catch {
    Add-Result "PowerShell Remoting (WinRM)" "FAILED" $_.Exception.Message
}

# Ensure the WinRM service starts automatically on boot
try {
    if ($PSCmdlet.ShouldProcess("WinRM service", "Set startup type to Automatic")) {
        Set-Service -Name WinRM -StartupType Automatic -ErrorAction Stop
    }
    Add-Result "WinRM service startup" "OK" "Automatic"
} catch {
    Add-Result "WinRM service startup" "FAILED" $_.Exception.Message
}

# --- 2. Firewall rules --------------------------------------------------------
$firewallGroups = @(
    @{ Name = "Windows Remote Management";   Why = "WinRM (TCP 5985)" }
    @{ Name = "Remote Desktop";              Why = "RDP / mstsc" }
    @{ Name = "Remote Event Log Management"; Why = "eventvwr" }
)
if ($EnableRemoteAssistance) {
    $firewallGroups += @{ Name = "Remote Assistance"; Why = "msra" }
}

foreach ($group in $firewallGroups) {
    try {
        if ($PSCmdlet.ShouldProcess($group.Name, "Enable firewall rule group")) {
            Enable-NetFirewallRule -DisplayGroup $group.Name -ErrorAction Stop
        }
        Add-Result "Firewall: $($group.Name)" "OK" $group.Why
    } catch {
        Add-Result "Firewall: $($group.Name)" "FAILED" $_.Exception.Message
    }
}

# Optionally scope the WinRM rule to a management subnet
if ($RestrictToSubnet) {
    try {
        if ($PSCmdlet.ShouldProcess($RestrictToSubnet, "Scope WinRM rules to remote subnet")) {
            Get-NetFirewallRule -DisplayGroup "Windows Remote Management" |
                Where-Object { $_.Enabled -eq 'True' } |
                Set-NetFirewallRule -RemoteAddress $RestrictToSubnet -ErrorAction Stop
        }
        Add-Result "Scope WinRM to subnet" "OK" $RestrictToSubnet
    } catch {
        Add-Result "Scope WinRM to subnet" "FAILED" $_.Exception.Message
    }
}

# --- 3. Remote Desktop (RDP) --------------------------------------------------
try {
    if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Enable Remote Desktop")) {
        Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" `
            -Name "fDenyTSConnections" -Value 0 -ErrorAction Stop
    }
    Add-Result "Remote Desktop (RDP)" "OK" "fDenyTSConnections = 0"
} catch {
    Add-Result "Remote Desktop (RDP)" "FAILED" $_.Exception.Message
}

# --- 4. Remote Assistance (optional) -----------------------------------------
if ($EnableRemoteAssistance) {
    try {
        if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Allow Remote Assistance")) {
            Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Remote Assistance" `
                -Name "fAllowToGetHelp" -Value 1 -ErrorAction Stop
        }
        Add-Result "Remote Assistance" "OK" "fAllowToGetHelp = 1"
    } catch {
        Add-Result "Remote Assistance" "FAILED" "$($_.Exception.Message) (on Server, run: Add-WindowsFeature Remote-Assistance)"
    }
}

# --- Summary ------------------------------------------------------------------
Write-Host "`n--- Summary ---" -ForegroundColor Cyan
$results | Format-Table -AutoSize

$failed = @($results | Where-Object { $_.Status -eq 'FAILED' })
if ($failed.Count -gt 0) {
    Write-Host "$($failed.Count) step(s) failed. Review the messages above." -ForegroundColor Red
} else {
    Write-Host "Done. From the admin workstation, verify with:" -ForegroundColor Green
    Write-Host "    Test-WSMan -ComputerName $env:COMPUTERNAME" -ForegroundColor Gray
}

<#
================================================================================
 REMAINING MANUAL / ENVIRONMENT STEPS
================================================================================

 ADMIN RIGHTS
   The account Multi-Tool authenticates as needs LOCAL ADMIN on this machine:
       Add-LocalGroupMember -Group "Administrators" -Member "DOMAIN\YourAdminUser"
   In a domain this is normally pushed via GPO (Restricted Groups) or LAPS.

 WORKGROUP / CROSS-DOMAIN TARGETS
   The tool uses -Authentication Negotiate. Same-domain just works. For a
   workgroup or different domain, on the ADMIN WORKSTATION (not here) add this
   machine to TrustedHosts and supply explicit credentials:
       Set-Item WSMan:\localhost\Client\TrustedHosts -Value "THISMACHINE" -Concatenate

 PUBLIC NETWORK PROFILE
   The default WinRM firewall rule only covers the Domain/Private profiles. If
   this machine is on a "Public" network, the connection will be blocked.

================================================================================
 GROUP POLICY (preferred for a fleet - apply once per OU instead of per box)
================================================================================

   1. WinRM service:  Computer Config > Preferences > Control Panel Settings >
      Services > WinRM > Startup: Automatic.

   2. WinRM listener:  Computer Config > Policies > Admin Templates > Windows
      Components > Windows Remote Management (WinRM) > WinRM Service >
      "Allow remote server management through WinRM" = Enabled.

   3. Firewall:  Computer Config > Policies > Windows Defender Firewall >
      Inbound Rules - enable the predefined groups: Windows Remote Management,
      Remote Desktop, Remote Event Log Management (and Remote Assistance if used).
      Scope RemoteAddress to your management subnet/VLAN.

   4. RDP:  Admin Templates > Windows Components > Remote Desktop Services >
      Remote Desktop Session Host > Connections >
      "Allow users to connect remotely..." = Enabled.

   5. Remote Assistance:  Admin Templates > System > Remote Assistance >
      "Offer Remote Assistance" = Enabled (list helper accounts).
#>
